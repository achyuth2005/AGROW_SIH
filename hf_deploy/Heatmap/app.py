"""
AGROW Heatmap Service
=====================
Multi-mode heatmap generation with pixel-wise indices AND CNN+Clustering+LLM analysis.

Version: 3.0.0 - Integrated Stress Detection

Modes (auto-detected from metric):
- Pixel-wise: SMI, SOMI, SFI, SASI, NDVI, NDRE, PRI, GNDVI
- CNN+LLM: pest_risk, disease_risk, nutrient_stress, stress_zones
"""

import os
import io
import base64
import logging
import traceback
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any

import numpy as np
from scipy.ndimage import gaussian_filter

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel

from sentinelhub import (
    SHConfig, BBox, CRS, DataCollection, SentinelHubRequest,
    MimeType, bbox_to_dimensions
)

# Import modules
from vegetation_indices import INDEX_FUNCTIONS, calculate_all_indices
from stress_detection_model import StressDetectionModel, get_stress_category, prepare_llm_context
from stress_detection_preprocessing import preprocess_for_model
from llm_analysis import prepare_indices_context, format_stress_context

# ============================================================================
# LOGGING
# ============================================================================
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger("HeatmapService")

def log_section(title: str):
    logger.info("=" * 50)
    logger.info(f"  {title}")
    logger.info("=" * 50)

def log_step(step_num: int, total: int, msg: str):
    logger.info(f"[Step {step_num}/{total}] {msg}")

def log_detail(key: str, value):
    logger.info(f"    • {key}: {value}")

# ============================================================================
# STARTUP
# ============================================================================
log_section("AGROW HEATMAP SERVICE v3.0.0")
log_detail("Mode", "Pixel-wise + CNN+Clustering+LLM")
log_detail("Pixel-wise indices", "SMI, SOMI, SFI, SASI, NDVI, NDRE, PRI, GNDVI")
log_detail("LLM metrics", "pest_risk, disease_risk, nutrient_stress, stress_zones")
log_detail("SH_CLIENT_ID", "✓" if os.environ.get('SH_CLIENT_ID') else "✗")
log_detail("GROQ_API_KEY", "✓" if os.environ.get('GROQ_API_KEY') else "✗ (hardcoded fallback)")

# ============================================================================
# METRIC CONFIGURATION
# ============================================================================
# Metrics that use simple pixel-wise index calculation
PIXELWISE_METRICS = {
    'soil_moisture': 'SMI',
    'soil_organic_matter': 'SOMI',
    'soil_fertility': 'SFI',
    'soil_salinity': 'SASI',
    'greenness': 'NDVI',
    'biomass': 'EVI',
    'nitrogen_level': 'NDRE',
    'photosynthetic_capacity': 'PRI',
    'leaf_health': 'GNDVI',
}

# Metrics that require CNN+Clustering+LLM reasoning
LLM_METRICS = {
    'pest_risk': {'primary_index': 'NDVI', 'use_stress': True},
    'disease_risk': {'primary_index': 'PSRI', 'use_stress': True},
    'nutrient_stress': {'primary_index': 'GNDVI', 'use_stress': True},
    'stress_zones': {'primary_index': 'NDVI', 'use_stress': True},
    'heat_stress': {'primary_index': 'NDVI', 'use_stress': True},
    'stress_pattern': {'primary_index': 'NDVI', 'use_stress': True},
}

ALL_METRICS = list(PIXELWISE_METRICS.keys()) + list(LLM_METRICS.keys())

# ============================================================================
# FASTAPI
# ============================================================================
app = FastAPI(
    title="AGROW Heatmap Service",
    description="Multi-mode heatmap with pixel-wise and CNN+LLM analysis",
    version="3.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# SENTINEL HUB CONFIG
# ============================================================================
def get_sh_config():
    config = SHConfig()
    config.sh_client_id = os.environ.get('SH_CLIENT_ID', 'sh-709c1173-fc33-4a0e-90e4-b84161ed5b9d')
    config.sh_client_secret = os.environ.get('SH_CLIENT_SECRET', 'IdopxGFFr3NKFJ4Y2ywJRVfmM5eBB9b4')
    config.sh_base_url = 'https://sh.dataspace.copernicus.eu'
    config.sh_token_url = 'https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token'
    return config


def extract_top_stress_zones(center_lat: float, center_lon: float, field_size_hectares: float, 
                             zones_per_category: int = 4) -> List[Dict]:
    """
    Run CNN+LSTM stress detection and extract stress zones by category with REAL coordinates.
    
    Returns 12 zones total:
    - 4 High stress zones (score >= 0.5)
    - 4 Moderate stress zones (0.25 <= score < 0.5)
    - 4 Low stress zones (score < 0.25)
    """
    try:
        config = get_sh_config()
        
        # Calculate bounding box
        radius_km = np.sqrt(field_size_hectares / 100) / 2
        lat_off = radius_km / 111
        lon_off = radius_km / (111 * np.cos(np.radians(center_lat)))
        
        bbox = BBox((
            center_lon - lon_off,  # SW lon
            center_lat - lat_off,  # SW lat
            center_lon + lon_off,  # NE lon
            center_lat + lat_off   # NE lat
        ), crs=CRS.WGS84)
        
        # BBox corner coordinates for pixel-to-geo conversion
        sw_lon, sw_lat, ne_lon, ne_lat = center_lon - lon_off, center_lat - lat_off, center_lon + lon_off, center_lat + lat_off
        
        size = bbox_to_dimensions(bbox, resolution=10)
        
        # Fetch Sentinel-2 data
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30)
        
        SENTINEL2 = DataCollection.define(
            "S2_CDSE", api_id="sentinel-2-l2a",
            service_url="https://sh.dataspace.copernicus.eu",
            collection_type="Sentinel-2", is_timeless=False
        )
        
        sh_request = SentinelHubRequest(
            evalscript=FULL_BANDS_EVALSCRIPT,
            input_data=[SentinelHubRequest.input_data(
                data_collection=SENTINEL2,
                time_interval=(start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')),
                mosaicking_order='leastCC'
            )],
            responses=[SentinelHubRequest.output_response('default', MimeType.TIFF)],
            bbox=bbox, size=size, config=config
        )
        
        data = sh_request.get_data()[0]
        if data is None or data.size == 0:
            logger.warning("[StressZones] No satellite data available")
            return []
        
        img_data = data[:, :, :12]
        h, w = img_data.shape[:2]
        
        # Preprocess for CNN+LSTM model
        all_images = np.expand_dims(img_data, axis=0)  # Add time dimension
        patches, patch_coords, metadata = preprocess_for_model(all_images, patch_size=4, stride=2)
        
        # Run stress detection model
        model = StressDetectionModel(patch_size=4, num_bands=metadata['num_bands'], num_timestamps=1)
        results = model.predict(patches, n_clusters=4)
        
        stress_scores = results['stress_scores']
        
        # Categorize patches by stress level
        high_indices = np.where(stress_scores >= 0.5)[0]
        moderate_indices = np.where((stress_scores >= 0.25) & (stress_scores < 0.5))[0]
        low_indices = np.where(stress_scores < 0.25)[0]
        
        # Sort each category by score (descending for high, ascending for low)
        high_indices = high_indices[np.argsort(stress_scores[high_indices])[::-1]][:zones_per_category]
        moderate_indices = moderate_indices[np.argsort(stress_scores[moderate_indices])[::-1]][:zones_per_category]
        low_indices = low_indices[np.argsort(stress_scores[low_indices])][:zones_per_category]  # Best low stress
        
        def create_zone(idx, zone_type, rank):
            patch_y, patch_x = patch_coords[idx]
            stress_score = float(stress_scores[idx])
            
            # Convert pixel coordinates to lat/lon
            lat = sw_lat + (1.0 - patch_y / h) * (ne_lat - sw_lat)  # Flip Y axis
            lon = sw_lon + (patch_x / w) * (ne_lon - sw_lon)
            
            return {
                'lat': lat,
                'lon': lon,
                'stress_score': stress_score,
                'severity': zone_type,
                'category': get_stress_category(stress_score),
                'patch_id': int(idx),
                'rank': rank,
                'zone_type': zone_type  # High, Moderate, or Low
            }
        
        all_zones = []
        
        # Add high stress zones (red)
        for rank, idx in enumerate(high_indices):
            all_zones.append(create_zone(idx, "High", rank + 1))
        
        # Add moderate stress zones (yellow)
        for rank, idx in enumerate(moderate_indices):
            all_zones.append(create_zone(idx, "Moderate", rank + 1))
        
        # Add low stress zones (green)
        for rank, idx in enumerate(low_indices):
            all_zones.append(create_zone(idx, "Low", rank + 1))
        
        logger.info(f"[StressZones] Extracted {len(all_zones)} stress zones: {len(high_indices)} high, {len(moderate_indices)} moderate, {len(low_indices)} low")
        return all_zones
        
    except Exception as e:
        logger.error(f"[StressZones] Failed to extract stress zones: {e}")
        logger.error(traceback.format_exc())
        return []

# ============================================================================
# REQUEST/RESPONSE MODELS
# ============================================================================
class HeatmapRequest(BaseModel):
    center_lat: float
    center_lon: float
    field_size_hectares: float
    metric: str  # e.g., "soil_moisture", "pest_risk"
    gaussian_sigma: float = 1.5
    show_field_boundary: bool = True
    overlay_mode: bool = False  # If True, generate clean heatmap for Google Maps overlay
    time_series_data: Optional[Dict[str, Any]] = None  # Historical + forecast time series for ALL indices
    weather_data: Optional[Dict[str, Any]] = None  # Weather data (temperature, humidity, precipitation)


class HeatmapResponse(BaseModel):
    success: bool
    metric: str
    mode: str  # "pixelwise" or "llm"
    index_used: str
    min_value: float
    max_value: float
    mean_value: float
    image_base64: str
    timestamp: str
    image_date: Optional[str] = None
    image_size: Optional[str] = None
    # Bounding box for geo-alignment [sw_lon, sw_lat, ne_lon, ne_lat]
    bbox: Optional[List[float]] = None
    # Separate colorbar image (horizontal) for UI display
    colorbar_base64: Optional[str] = None
    # Patch analysis (for pixel-wise)
    num_patches: Optional[int] = None
    health_summary: Optional[dict] = None
    # LLM analysis (for risk metrics)
    level: Optional[str] = None
    analysis: Optional[str] = None
    detailed_analysis: Optional[str] = None  # Detailed reasoning for timeseries + stress patterns
    stress_score: Optional[float] = None
    cluster_distribution: Optional[dict] = None
    recommendations: Optional[List[str]] = None

# ============================================================================
# COLORMAPS
# ============================================================================
def get_vegetation_colormap():
    colors = [(0.8, 0.2, 0.2), (0.9, 0.6, 0.2), (0.95, 0.9, 0.3), (0.6, 0.8, 0.3), (0.2, 0.6, 0.2)]
    return LinearSegmentedColormap.from_list('vegetation', colors, N=256)

def get_water_colormap():
    colors = [(0.9, 0.6, 0.3), (0.95, 0.9, 0.5), (0.5, 0.8, 0.9), (0.2, 0.5, 0.8), (0.1, 0.3, 0.6)]
    return LinearSegmentedColormap.from_list('water', colors, N=256)

def get_stress_colormap():
    colors = [(0.2, 0.7, 0.2), (0.8, 0.8, 0.2), (0.9, 0.5, 0.1), (0.8, 0.2, 0.2)]
    return LinearSegmentedColormap.from_list('stress', colors, N=256)

def generate_colorbar_image(min_val: float, max_val: float, index_type: str, is_stress: bool = False) -> str:
    """Generate a separate horizontal colorbar image for UI display."""
    if is_stress:
        cmap = get_stress_colormap()
        label = 'Stress Level'
    elif index_type in ['NDWI', 'SMI']:
        cmap = get_water_colormap()
        label = index_type
    else:
        cmap = get_vegetation_colormap()
        label = index_type
    
    fig, ax = plt.subplots(figsize=(6, 0.5), dpi=100)
    
    # Create gradient
    gradient = np.linspace(0, 1, 256).reshape(1, -1)
    ax.imshow(gradient, aspect='auto', cmap=cmap)
    
    # Labels
    ax.set_xticks([0, 127, 255])
    ax.set_xticklabels([f'{min_val:.2f}', f'{(min_val+max_val)/2:.2f}', f'{max_val:.2f}'], fontsize=8)
    ax.set_yticks([])
    ax.set_xlabel(label, fontsize=9)
    
    buf = io.BytesIO()
    plt.savefig(buf, format='png', bbox_inches='tight', pad_inches=0.1, facecolor='white')
    plt.close(fig)
    buf.seek(0)
    
    return base64.b64encode(buf.getvalue()).decode('utf-8')

# ============================================================================
# EVALSCRIPT
# ============================================================================
FULL_BANDS_EVALSCRIPT = """
//VERSION=3
function setup() {
    return {
        input: [{
            bands: ["B01", "B02", "B03", "B04", "B05", "B06", "B07", "B08", "B8A", "B09", "B11", "B12", "dataMask"],
            units: "REFLECTANCE"
        }],
        output: { bands: 13, sampleType: "FLOAT32" }
    };
}
function evaluatePixel(sample) {
    return [sample.B01, sample.B02, sample.B03, sample.B04, sample.B05, sample.B06, 
            sample.B07, sample.B08, sample.B8A, sample.B09, sample.B11, sample.B12, sample.dataMask];
}
"""

# ============================================================================
# PIXEL-WISE ANALYSIS
# ============================================================================
def get_health_category(value: float, index_type: str) -> str:
    if index_type in ['NDVI', 'EVI', 'NDRE', 'GNDVI']:
        if value >= 0.6: return 'Healthy'
        elif value >= 0.3: return 'Moderate'
        else: return 'Stressed'
    elif index_type in ['NDWI', 'SMI']:
        if value >= 0.2: return 'Adequate'
        elif value >= 0.0: return 'Moderate'
        else: return 'Dry'
    else:
        if value >= 0.5: return 'Healthy'
        elif value >= 0.25: return 'Moderate'
        else: return 'Stressed'


def analyze_patches_pixelwise(data: np.ndarray, index_type: str, target_patches: int = 150) -> tuple:
    """Divide field into ~100-200 patches for statistical analysis."""
    h, w = data.shape
    grid_size = max(10, min(15, int(np.sqrt(target_patches))))
    patch_h, patch_w = max(1, h // grid_size), max(1, w // grid_size)
    actual_rows = h // patch_h if patch_h > 0 else 1
    actual_cols = w // patch_w if patch_w > 0 else 1
    
    patches_list = []
    health_counts = {}
    
    for row in range(actual_rows):
        for col in range(actual_cols):
            y_start, y_end = row * patch_h, min((row + 1) * patch_h, h)
            x_start, x_end = col * patch_w, min((col + 1) * patch_w, w)
            patch = data[y_start:y_end, x_start:x_end]
            valid_pixels = np.sum(~np.isnan(patch))
            
            if valid_pixels > 0:
                mean_val = float(np.nanmean(patch))
                health = get_health_category(mean_val, index_type)
                patches_list.append({
                    'id': f"P{row}_{col}", 'mean': round(mean_val, 4),
                    'health': health, 'pixels': int(valid_pixels)
                })
                health_counts[health] = health_counts.get(health, 0) + 1
    
    total = len(patches_list)
    return patches_list, {
        'total_patches': total,
        'grid': f"{actual_rows}x{actual_cols}",
        'counts': health_counts,
        'percentages': {k: round(100 * v / total, 1) for k, v in health_counts.items()} if total > 0 else {}
    }

# ============================================================================
# HEATMAP GENERATION
# ============================================================================
def generate_heatmap_image(data: np.ndarray, index_type: str, gaussian_sigma: float = 1.5,
                           show_boundary: bool = True, is_stress: bool = False,
                           overlay_mode: bool = False) -> tuple:
    """Generate heatmap from index data.
    
    Args:
        overlay_mode: If True, generates clean heatmap without colorbar/title
                      for use as Google Maps overlay.
    """
    valid_mask = ~np.isnan(data)
    if not np.any(valid_mask):
        raise ValueError("No valid data pixels")
    
    min_val, max_val = float(np.nanmin(data)), float(np.nanmax(data))
    mean_val = float(np.nanmean(data))
    
    data_norm = np.clip((data - min_val) / (max_val - min_val + 1e-8), 0, 1)
    data_norm = np.nan_to_num(data_norm, nan=0.5)
    
    if gaussian_sigma > 0:
        data_norm = gaussian_filter(data_norm, sigma=gaussian_sigma)
    
    fig, ax = plt.subplots(figsize=(8, 8), dpi=100)
    
    if is_stress:
        cmap = get_stress_colormap()
    elif index_type in ['NDWI', 'SMI']:
        cmap = get_water_colormap()
    else:
        cmap = get_vegetation_colormap()
    
    im = ax.imshow(data_norm, cmap=cmap, interpolation='bilinear')
    
    # Skip boundary for overlay mode (Google Maps has its own boundary)
    if show_boundary and not overlay_mode:
        h, w = data_norm.shape
        rect = plt.Rectangle((w*0.02, h*0.02), w*0.96, h*0.96, fill=False,
                              edgecolor='white', linewidth=2, linestyle='--', alpha=0.7)
        ax.add_patch(rect)
    
    # Skip colorbar and title for overlay mode (clean image for map overlay)
    if not overlay_mode:
        cbar = plt.colorbar(im, ax=ax, shrink=0.8, pad=0.02)
        cbar.set_label(f'{index_type}' if not is_stress else 'Stress Score', fontsize=10)
        ax.set_title(f'{index_type} Heatmap' if not is_stress else 'Stress Heatmap', fontsize=14, fontweight='bold')
    
    ax.axis('off')
    
    buf = io.BytesIO()
    # Use tight layout with no padding for overlay mode
    if overlay_mode:
        plt.savefig(buf, format='png', bbox_inches='tight', pad_inches=0, transparent=True)
    else:
        plt.savefig(buf, format='png', bbox_inches='tight', facecolor='white')
    plt.close(fig)
    buf.seek(0)
    
    return base64.b64encode(buf.getvalue()).decode('utf-8'), min_val, max_val, mean_val

# ============================================================================
# LLM ANALYSIS (for risk metrics)
# ============================================================================

# Import API keys from centralized module (loaded from environment)
from groq_client import GROQ_API_KEYS, GROQ_MODEL

def run_llm_analysis(metric: str, stress_context: dict, indices_data: dict, 
                     time_series_data: dict = None, weather_data: dict = None) -> dict:
    """Call Groq LLM with full context from stress detection, timeseries, and weather.
    Uses cascading fallback through API keys."""
    from groq import Groq
    import json
    
    # Format stress context
    stress_text = format_stress_context(stress_context)
    
    # Format time series data for all indices
    ts_text = ""
    if time_series_data:
        ts_text = "\n\nTIME SERIES DATA (ALL INDICES - HISTORICAL + FORECAST):\n"
        ts_text += "=" * 50 + "\n"
        for index_name, ts_data in time_series_data.items():
            ts_text += f"\n{index_name}:\n"
            # Historical
            if ts_data.get('historical'):
                hist = ts_data['historical']
                if len(hist) > 0:
                    first_val = hist[0].get('value', 0) if isinstance(hist[0], dict) else 0
                    last_val = hist[-1].get('value', 0) if isinstance(hist[-1], dict) else 0
                    ts_text += f"  Historical ({len(hist)} points): from {first_val:.4f} to {last_val:.4f} (change: {last_val-first_val:+.4f})\n"
            # Forecast
            if ts_data.get('forecast'):
                fcast = ts_data['forecast']
                if len(fcast) > 0:
                    first_val = fcast[0].get('value', 0) if isinstance(fcast[0], dict) else 0
                    last_val = fcast[-1].get('value', 0) if isinstance(fcast[-1], dict) else 0
                    ts_text += f"  Forecast ({len(fcast)} days): from {first_val:.4f} to {last_val:.4f} (predicted: {last_val-first_val:+.4f})\n"
    
    # Format weather data
    weather_text = ""
    if weather_data:
        weather_text = "\n\nWEATHER CONDITIONS:\n"
        weather_text += "=" * 30 + "\n"
        if 'temperature' in weather_data:
            weather_text += f"- Temperature: {weather_data['temperature']}°C\n"
        if 'humidity' in weather_data:
            weather_text += f"- Humidity: {weather_data['humidity']}%\n"
        if 'precipitation' in weather_data:
            weather_text += f"- Precipitation: {weather_data['precipitation']} mm\n"
        if 'wind_speed' in weather_data:
            weather_text += f"- Wind Speed: {weather_data['wind_speed']} km/h\n"
        if 'conditions' in weather_data:
            weather_text += f"- Conditions: {weather_data['conditions']}\n"
        if 'forecast' in weather_data:
            weather_text += f"- Forecast: {weather_data['forecast']}\n"
    
    # Create targeted prompt based on metric
    prompt = f"""CROP STRESS ANALYSIS REQUEST

{stress_text}
{ts_text}
{weather_text}

METRIC TO ANALYZE: {metric.upper().replace('_', ' ')}

Based on the stress detection results, time series trends, and weather conditions above, provide analysis for {metric}.

Respond with ONLY a valid JSON object (no markdown):
{{
    "level": "Low" or "Moderate" or "High",
    "analysis": "4-5 words describing the current state",
    "detailed_analysis": "Two detailed sentences: First sentence explaining the reasoning behind time series index changes (what caused the trends). Second sentence explaining the observed stress patterns in the field over time and their likely causes.",
    "temporal_trend": "Improving" or "Stable" or "Worsening",
    "recommendations": ["action 1", "action 2", "action 3"]
}}
"""
    
    # Try each API key in sequence (cascading fallback)
    last_error = None
    for i, api_key in enumerate(GROQ_API_KEYS):
        try:
            logger.info(f"Trying Groq API key {i+1}/{len(GROQ_API_KEYS)}")
            client = Groq(api_key=api_key)
            
            chat_completion = client.chat.completions.create(
                messages=[
                    {"role": "system", "content": "You are an expert agricultural AI. Provide detailed, data-driven analysis. Respond with valid JSON only."},
                    {"role": "user", "content": prompt}
                ],
                model=GROQ_MODEL,
                temperature=0.7,
                max_tokens=1500,
            )
            
            response_text = chat_completion.choices[0].message.content.strip()
            
            # Clean markdown if present
            if response_text.startswith("```"):
                lines = response_text.split("\n")
                response_text = "\n".join(lines[1:-1])
            if response_text.startswith("json"):
                response_text = response_text[4:].strip()
            
            result = json.loads(response_text)
            logger.info(f"Groq API key {i+1} succeeded")
            return result
            
        except Exception as e:
            last_error = e
            logger.warning(f"Groq API key {i+1} failed: {e}")
            continue
    
    # All keys failed
    logger.error(f"All {len(GROQ_API_KEYS)} Groq API keys failed. Last error: {last_error}")
    return {
        "level": "Moderate", 
        "analysis": "Analysis unavailable", 
        "detailed_analysis": "Unable to generate detailed analysis due to API errors. All API keys exhausted. Please try refreshing.",
        "recommendations": ["Manual inspection recommended"]
    }

# ============================================================================
# API ENDPOINTS
# ============================================================================
@app.get("/")
async def root():
    return {
        "service": "AGROW Heatmap Service",
        "version": "3.0.0",
        "modes": {"pixelwise": list(PIXELWISE_METRICS.keys()), "llm": list(LLM_METRICS.keys())},
        "all_metrics": ALL_METRICS
    }

@app.get("/health")
async def health():
    return {"status": "healthy", "metrics": ALL_METRICS}


@app.post("/generate-heatmap", response_model=HeatmapResponse)
async def generate_heatmap(request: HeatmapRequest):
    """Generate heatmap - auto-detects mode based on metric."""
    
    req_id = datetime.now().strftime("%H%M%S")
    
    # Validate metric
    if request.metric not in ALL_METRICS:
        raise HTTPException(400, f"Invalid metric: {request.metric}. Valid: {ALL_METRICS}")
    
    # Determine mode
    is_llm_mode = request.metric in LLM_METRICS
    mode = "llm" if is_llm_mode else "pixelwise"
    
    log_section(f"REQUEST [{req_id}] - {mode.upper()} MODE")
    log_detail("Metric", request.metric)
    log_detail("Location", f"({request.center_lat:.6f}, {request.center_lon:.6f})")
    log_detail("Field Size", f"{request.field_size_hectares} ha")
    
    try:
        # Step 1: Config
        log_step(1, 6 if is_llm_mode else 5, "Loading Sentinel Hub config")
        config = get_sh_config()
        
        # Step 2: Bounding Box
        log_step(2, 6 if is_llm_mode else 5, "Calculating bounding box")
        radius_km = np.sqrt(request.field_size_hectares / 100) / 2
        lat_off = radius_km / 111
        lon_off = radius_km / (111 * np.cos(np.radians(request.center_lat)))
        
        bbox = BBox((
            request.center_lon - lon_off, request.center_lat - lat_off,
            request.center_lon + lon_off, request.center_lat + lat_off
        ), crs=CRS.WGS84)
        
        # Store bbox coordinates for response [sw_lon, sw_lat, ne_lon, ne_lat]
        bbox_coords = [
            request.center_lon - lon_off,  # SW lon
            request.center_lat - lat_off,  # SW lat
            request.center_lon + lon_off,  # NE lon
            request.center_lat + lat_off   # NE lat
        ]
        
        size = bbox_to_dimensions(bbox, resolution=10)
        log_detail("Image Size", f"{size[0]}×{size[1]} pixels")
        
        # Step 3: Fetch Data
        log_step(3, 6 if is_llm_mode else 5, "Fetching Sentinel-2 data")
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30)
        
        SENTINEL2 = DataCollection.define(
            "S2_CDSE", api_id="sentinel-2-l2a",
            service_url="https://sh.dataspace.copernicus.eu",
            collection_type="Sentinel-2", is_timeless=False
        )
        
        sh_request = SentinelHubRequest(
            evalscript=FULL_BANDS_EVALSCRIPT,
            input_data=[SentinelHubRequest.input_data(
                data_collection=SENTINEL2,
                time_interval=(start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')),
                mosaicking_order='leastCC'
            )],
            responses=[SentinelHubRequest.output_response('default', MimeType.TIFF)],
            bbox=bbox, size=size, config=config
        )
        
        data = sh_request.get_data()[0]
        if data is None or data.size == 0:
            raise HTTPException(404, "No satellite data available")
        
        log_detail("Data Shape", f"{data.shape}")
        
        # Get image data (remove dataMask)
        img_data = data[:, :, :12]
        
        # ================================================================
        # PIXEL-WISE MODE
        # ================================================================
        if not is_llm_mode:
            index_type = PIXELWISE_METRICS[request.metric]
            
            log_step(4, 5, f"Calculating {index_type} (pixel-wise)")
            index_func = INDEX_FUNCTIONS[index_type]
            index_data = index_func(img_data)
            
            log_step(5, 5, "Generating heatmap & patch analysis")
            patches_list, health_summary = analyze_patches_pixelwise(index_data, index_type)
            img_b64, min_v, max_v, mean_v = generate_heatmap_image(
                index_data, index_type, request.gaussian_sigma, request.show_field_boundary,
                overlay_mode=request.overlay_mode
            )
            
            log_section(f"SUCCESS [{req_id}]")
            
            # Generate colorbar if in overlay mode
            colorbar_b64 = None
            if request.overlay_mode:
                colorbar_b64 = generate_colorbar_image(min_v, max_v, index_type, is_stress=False)
            
            return HeatmapResponse(
                success=True,
                metric=request.metric,
                mode="pixelwise",
                index_used=index_type,
                min_value=min_v,
                max_value=max_v,
                mean_value=mean_v,
                image_base64=img_b64,
                timestamp=datetime.now().isoformat(),
                image_date=end_date.strftime('%Y-%m-%d'),
                image_size=f"{size[0]}x{size[1]}",
                bbox=bbox_coords,
                colorbar_base64=colorbar_b64,
                num_patches=len(patches_list),
                health_summary=health_summary
            )
        
        # ================================================================
        # LLM MODE (CNN + Clustering + LLM)
        # ================================================================
        else:
            metric_config = LLM_METRICS[request.metric]
            primary_index = metric_config['primary_index']
            
            log_step(4, 6, f"Running CNN stress detection (patch=4, stride=2)")
            
            # Reshape data for stress detection: (1, h, w, bands) -> (time, h, w, bands)
            all_images = img_data[np.newaxis, :, :, :]  # Add time dimension
            
            # Preprocess for stress model
            patches, patch_coords, metadata = preprocess_for_model(
                all_images, patch_size=4, stride=2
            )
            
            log_detail("Patches extracted", f"{len(patch_coords)}")
            log_detail("Patch shape", f"{patches.shape}")
            
            # Build and run stress model
            stress_model = StressDetectionModel(
                patch_size=metadata['patch_size'],
                num_bands=metadata['num_bands'],
                num_timestamps=1,
                spatial_embedding_dim=64,
                temporal_embedding_dim=64
            )
            
            stress_results = stress_model.predict(patches, n_clusters=3, contamination=0.1)
            
            # Prepare LLM context
            stress_context = prepare_llm_context(stress_results, patch_coords, patches, metadata)
            
            log_detail("Overall stress score", f"{stress_results['stress_scores'].mean():.3f}")
            log_detail("Clusters", f"{stress_results['n_clusters']}")
            
            log_step(5, 6, f"Running LLM analysis for {request.metric}")
            
            # Calculate primary index for visualization
            index_func = INDEX_FUNCTIONS[primary_index]
            index_data = index_func(img_data)
            
            # Run LLM analysis with timeseries and weather context
            llm_result = run_llm_analysis(
                request.metric, stress_context, {'primary': index_data},
                time_series_data=request.time_series_data,
                weather_data=request.weather_data
            )
            
            log_step(6, 6, "Generating heatmap")
            
            # Generate stress-based heatmap
            # Create stress map from patch scores
            h, w = img_data.shape[:2]
            stress_map = np.zeros((h, w))
            for i, (py, px) in enumerate(patch_coords):
                stress_map[py:py+4, px:px+4] = stress_results['stress_scores'][i]
            
            img_b64, min_v, max_v, mean_v = generate_heatmap_image(
                stress_map, "Stress", request.gaussian_sigma, request.show_field_boundary,
                is_stress=True, overlay_mode=request.overlay_mode
            )
            
            # Get cluster distribution
            cluster_dist = stress_context['field_statistics']['stress_distribution']
            
            log_section(f"SUCCESS [{req_id}]")
            
            # Generate colorbar if in overlay mode
            colorbar_b64 = None
            if request.overlay_mode:
                colorbar_b64 = generate_colorbar_image(min_v, max_v, "Stress", is_stress=True)
            
            return HeatmapResponse(
                success=True,
                metric=request.metric,
                mode="llm",
                index_used=primary_index,
                min_value=min_v,
                max_value=max_v,
                mean_value=mean_v,
                image_base64=img_b64,
                timestamp=datetime.now().isoformat(),
                image_date=end_date.strftime('%Y-%m-%d'),
                image_size=f"{size[0]}x{size[1]}",
                bbox=bbox_coords,
                colorbar_base64=colorbar_b64,
                level=llm_result.get('level', 'Unknown'),
                analysis=llm_result.get('analysis', ''),
                detailed_analysis=llm_result.get('detailed_analysis', ''),
                stress_score=float(stress_results['stress_scores'].mean()),
                cluster_distribution=cluster_dist,
                recommendations=llm_result.get('recommendations', [])
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[{req_id}] ERROR: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(500, str(e))


@app.get("/generate-heatmap-image")
async def get_heatmap_image(
    center_lat: float, center_lon: float, field_size_hectares: float,
    metric: str = "soil_moisture", gaussian_sigma: float = 1.5
):
    request = HeatmapRequest(
        center_lat=center_lat, center_lon=center_lon,
        field_size_hectares=field_size_hectares, metric=metric,
        gaussian_sigma=gaussian_sigma
    )
    response = await generate_heatmap(request)
    return Response(content=base64.b64decode(response.image_base64), media_type="image/png")


# ============================================================================
# TAKE ACTION REASONING ENDPOINT
# ============================================================================

class TakeActionRequest(BaseModel):
    """Request model for take-action reasoning."""
    center_lat: float
    center_lon: float
    field_size_hectares: float
    category: str  # e.g., "field_variability", "irrigation", "pest_risk"
    # Context data
    stress_clusters: Optional[List[Dict[str, Any]]] = None  # From CNN+LSTM model
    indices_timeseries: Optional[Dict[str, Any]] = None  # Historical + forecast for all indices
    farmer_profile: Optional[Dict[str, Any]] = None  # Questionnaire data
    weather_data: Optional[Dict[str, Any]] = None  # Current + forecast weather


class TakeActionResponse(BaseModel):
    """Response model for take-action reasoning."""
    success: bool
    category: str
    high_zones: List[Dict[str, Any]]  # High performing/stress zones with coordinates
    low_zones: List[Dict[str, Any]]  # Low performing/stress zones with coordinates
    recommendations: str  # Main recommendation text
    risk_suggestions: List[str]  # List of risk suggestions
    detailed_analysis: str  # Detailed LLM analysis
    stress_score: float
    cluster_distribution: Dict[str, int]


def run_take_action_llm(category: str, stress_clusters: list, indices_data: dict, 
                        farmer_profile: dict, weather_data: dict) -> dict:
    """Run LLM analysis for Take Action reasoning with comprehensive context."""
    from groq import Groq
    import json
    
    GROQ_MODEL = "llama-3.3-70b-versatile"
    
    # Format stress clusters
    cluster_text = "\n\nSTRESS CLUSTER DATA (CNN+LSTM Analysis):\n"
    cluster_text += "=" * 50 + "\n"
    if stress_clusters:
        for i, cluster in enumerate(stress_clusters):
            cluster_text += f"\nCluster {i+1}:\n"
            cluster_text += f"  - Location: ({cluster.get('lat', 0):.6f}, {cluster.get('lon', 0):.6f})\n"
            cluster_text += f"  - Stress Score: {cluster.get('stress_score', 0):.3f}\n"
            cluster_text += f"  - Category: {cluster.get('category', 'Unknown')}\n"
            cluster_text += f"  - Severity: {cluster.get('severity', 'Moderate')}\n"
    else:
        cluster_text += "No stress clusters detected - field appears healthy.\n"
    
    # Format indices timeseries
    ts_text = "\n\nINDICES TIME SERIES (Historical + Forecast):\n"
    ts_text += "=" * 50 + "\n"
    if indices_data:
        for index_name, data in indices_data.items():
            ts_text += f"\n{index_name}:\n"
            if data.get('historical'):
                hist = data['historical']
                if len(hist) > 0:
                    first_val = hist[0].get('value', 0) if isinstance(hist[0], dict) else 0
                    last_val = hist[-1].get('value', 0) if isinstance(hist[-1], dict) else 0
                    ts_text += f"  Historical: {first_val:.3f} → {last_val:.3f} (change: {last_val-first_val:+.3f})\n"
            if data.get('forecast'):
                fcast = data['forecast']
                if len(fcast) > 0:
                    first_val = fcast[0].get('value', 0) if isinstance(fcast[0], dict) else 0
                    last_val = fcast[-1].get('value', 0) if isinstance(fcast[-1], dict) else 0
                    ts_text += f"  Forecast: {first_val:.3f} → {last_val:.3f} (predicted: {last_val-first_val:+.3f})\n"
    
    # Format farmer profile
    farmer_text = "\n\nFARMER PROFILE (Questionnaire Data):\n"
    farmer_text += "=" * 40 + "\n"
    if farmer_profile:
        farmer_text += f"- Crop Type: {farmer_profile.get('crop_type', 'Unknown')}\n"
        farmer_text += f"- Field Size: {farmer_profile.get('field_size', 'Unknown')} hectares\n"
        farmer_text += f"- Irrigation Method: {farmer_profile.get('irrigation_method', 'Unknown')}\n"
        farmer_text += f"- Experience Level: {farmer_profile.get('experience', 'Unknown')}\n"
        farmer_text += f"- Primary Goal: {farmer_profile.get('primary_goal', 'Maximize yield')}\n"
        farmer_text += f"- Budget Constraints: {farmer_profile.get('budget', 'Moderate')}\n"
    else:
        farmer_text += "No farmer profile data available.\n"
    
    # Format weather data
    weather_text = "\n\nWEATHER CONDITIONS:\n"
    weather_text += "=" * 30 + "\n"
    if weather_data:
        weather_text += f"- Temperature: {weather_data.get('temperature', 'N/A')}°C\n"
        weather_text += f"- Humidity: {weather_data.get('humidity', 'N/A')}%\n"
        weather_text += f"- Precipitation: {weather_data.get('precipitation', 'N/A')} mm\n"
        weather_text += f"- Conditions: {weather_data.get('conditions', 'N/A')}\n"
        weather_text += f"- Forecast: {weather_data.get('forecast', 'N/A')}\n"
    else:
        weather_text += "No weather data available.\n"
    
    # Category-specific prompts
    category_prompts = {
        'field_variability': "high and low performing zones, zonal management recommendations",
        'yield_stability': "yield stability patterns, management priority zones",
        'irrigation': "SMI (Soil Moisture Index) analysis, soil moisture zones, irrigation scheduling, water stress detection, optimal watering times based on SMI trends, crop water demand by growth stage",
        'vegetation_health': "vegetation health patterns, chlorophyll status, growth anomalies",
        'nutrient': "nutrient deficiency zones, chlorophyll patterns, fertilization recommendations",
        'pest_damage': "pest risk zones, damage detection areas, treatment priorities"
    }
    
    focus = category_prompts.get(category, "comprehensive field analysis")
    
    prompt = f"""TAKE ACTION ANALYSIS REQUEST

{cluster_text}
{ts_text}
{farmer_text}
{weather_text}

CATEGORY: {category.upper().replace('_', ' ')}
FOCUS: {focus}

Based on the stress cluster data, indices trends, farmer profile, and weather conditions, provide actionable recommendations.
For EACH zone, provide a specific action recommendation based on that zone's stress level and location.

Respond with ONLY a valid JSON object:
{{
    "high_zones": [
        {{"lat": 0.0, "lon": 0.0, "score": 0.0, "label": "Zone description", "action": "Specific action for this zone based on stress level", "severity": "High"}}
    ],
    "low_zones": [
        {{"lat": 0.0, "lon": 0.0, "score": 0.0, "label": "Zone description", "action": "Specific action for this zone", "severity": "Moderate"}}
    ],
    "recommendations": "2-3 sentences of main recommendation based on overall data",
    "risk_suggestions": ["Risk 1 with action", "Risk 2 with action", "Risk 3 with action"],
    "detailed_analysis": "4-5 sentences explaining the stress patterns, their causes based on indices trends and weather, and specific actions to take considering the farmer's goals and constraints."
}}
"""
    
    # Try each API key with cascading fallback
    last_error = None
    for i, api_key in enumerate(GROQ_API_KEYS):
        try:
            logger.info(f"[TakeAction] Trying Groq API key {i+1}/{len(GROQ_API_KEYS)}")
            client = Groq(api_key=api_key)
            
            chat_completion = client.chat.completions.create(
                messages=[
                    {"role": "system", "content": "You are an expert agricultural advisor. Provide data-driven, actionable recommendations. Respond with valid JSON only."},
                    {"role": "user", "content": prompt}
                ],
                model=GROQ_MODEL,
                temperature=0.7,
                max_tokens=2000,
            )
            
            response_text = chat_completion.choices[0].message.content.strip()
            
            # Clean markdown if present
            if response_text.startswith("```"):
                lines = response_text.split("\n")
                response_text = "\n".join(lines[1:-1])
            if response_text.startswith("json"):
                response_text = response_text[4:].strip()
            
            result = json.loads(response_text)
            logger.info(f"[TakeAction] Groq API key {i+1} succeeded")
            return result
            
        except Exception as e:
            last_error = e
            logger.warning(f"[TakeAction] Groq API key {i+1} failed: {e}")
            continue
    
    # All keys failed - return fallback
    logger.error(f"[TakeAction] All API keys failed. Last error: {last_error}")
    return {
        "high_zones": [],
        "low_zones": [],
        "recommendations": "Unable to generate recommendations. Please try again.",
        "risk_suggestions": ["Manual field inspection recommended"],
        "detailed_analysis": "Analysis unavailable due to API errors. Please refresh to try again."
    }


@app.post("/take-action-reasoning", response_model=TakeActionResponse)
async def take_action_reasoning(request: TakeActionRequest):
    """Generate comprehensive LLM reasoning for Take Action pages."""
    
    try:
        logger.info(f"[TakeAction] Processing {request.category} for ({request.center_lat}, {request.center_lon})")
        
        # If no stress clusters provided, generate them using CNN+LSTM stress detection
        stress_clusters = request.stress_clusters or []
        
        if not stress_clusters:
            # Run CNN+LSTM stress detection to get 12 stress zones (4 high, 4 moderate, 4 low)
            logger.info("[TakeAction] Running CNN+LSTM stress detection for 12 categorized zones...")
            stress_zones = extract_top_stress_zones(
                center_lat=request.center_lat,
                center_lon=request.center_lon,
                field_size_hectares=request.field_size_hectares,
                zones_per_category=4  # 4 high, 4 moderate, 4 low = 12 total
            )
            stress_clusters = stress_zones
            logger.info(f"[TakeAction] Extracted {len(stress_clusters)} stress zones from CNN+LSTM")
        
        
        # Run LLM analysis
        llm_result = run_take_action_llm(
            category=request.category,
            stress_clusters=stress_clusters,
            indices_data=request.indices_timeseries or {},
            farmer_profile=request.farmer_profile or {},
            weather_data=request.weather_data or {}
        )
        
        # Calculate overall stress score
        stress_score = 0.0
        if stress_clusters:
            stress_score = sum(c.get('stress_score', 0) for c in stress_clusters) / len(stress_clusters)
        
        # Cluster distribution
        cluster_dist = {}
        for cluster in stress_clusters:
            cat = cluster.get('severity', 'Unknown')
            cluster_dist[cat] = cluster_dist.get(cat, 0) + 1
        
        return TakeActionResponse(
            success=True,
            category=request.category,
            high_zones=llm_result.get('high_zones', []),
            low_zones=llm_result.get('low_zones', []),
            recommendations=llm_result.get('recommendations', ''),
            risk_suggestions=llm_result.get('risk_suggestions', []),
            detailed_analysis=llm_result.get('detailed_analysis', ''),
            stress_score=stress_score,
            cluster_distribution=cluster_dist
        )
        
    except Exception as e:
        logger.error(f"[TakeAction] Error: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(500, str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)
