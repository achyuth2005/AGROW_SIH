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
from llm_analysis import configure_gemini, prepare_indices_context, format_stress_context

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
log_detail("GEMINI_API_KEY", "✓" if os.environ.get('GEMINI_API_KEY') else "✗")

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
    'nitrogen_level': 'NDRE',
    'photosynthetic_capacity': 'PRI',
}

# Metrics that require CNN+Clustering+LLM
LLM_METRICS = {
    'pest_risk': {'primary_index': 'NDVI', 'use_stress': True},
    'disease_risk': {'primary_index': 'PSRI', 'use_stress': True},
    'nutrient_stress': {'primary_index': 'GNDVI', 'use_stress': True},
    'stress_zones': {'primary_index': 'NDVI', 'use_stress': True},
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
    config.sh_client_id = os.environ.get('SH_CLIENT_ID', '')
    config.sh_client_secret = os.environ.get('SH_CLIENT_SECRET', '')
    config.sh_base_url = 'https://sh.dataspace.copernicus.eu'
    config.sh_token_url = 'https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token'
    return config

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
    # Patch analysis (for pixel-wise)
    num_patches: Optional[int] = None
    health_summary: Optional[dict] = None
    # LLM analysis (for risk metrics)
    level: Optional[str] = None
    analysis: Optional[str] = None
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
                           show_boundary: bool = True, is_stress: bool = False) -> tuple:
    """Generate heatmap from index data."""
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
    
    if show_boundary:
        h, w = data_norm.shape
        rect = plt.Rectangle((w*0.02, h*0.02), w*0.96, h*0.96, fill=False,
                              edgecolor='white', linewidth=2, linestyle='--', alpha=0.7)
        ax.add_patch(rect)
    
    cbar = plt.colorbar(im, ax=ax, shrink=0.8, pad=0.02)
    cbar.set_label(f'{index_type}' if not is_stress else 'Stress Score', fontsize=10)
    
    ax.set_title(f'{index_type} Heatmap' if not is_stress else 'Stress Heatmap', fontsize=14, fontweight='bold')
    ax.axis('off')
    
    buf = io.BytesIO()
    plt.savefig(buf, format='png', bbox_inches='tight', facecolor='white')
    plt.close(fig)
    buf.seek(0)
    
    return base64.b64encode(buf.getvalue()).decode('utf-8'), min_val, max_val, mean_val

# ============================================================================
# LLM ANALYSIS (for risk metrics)
# ============================================================================
def run_llm_analysis(metric: str, stress_context: dict, indices_data: dict) -> dict:
    """Call Gemini LLM with full context from stress detection."""
    try:
        import google.generativeai as genai
        
        api_key = os.environ.get("GEMINI_API_KEY")
        if not api_key:
            return {"level": "Unknown", "analysis": "GEMINI_API_KEY not set", "recommendations": []}
        
        genai.configure(api_key=api_key, transport='rest')
        model = genai.GenerativeModel('gemini-flash-latest')
        
        # Format stress context
        stress_text = format_stress_context(stress_context)
        
        # Create targeted prompt based on metric
        prompt = f"""
CROP STRESS ANALYSIS REQUEST

{stress_text}

METRIC TO ANALYZE: {metric.upper().replace('_', ' ')}

Based on the stress detection results above, provide analysis for {metric}.

Respond with ONLY a valid JSON object (no markdown):
{{
    "level": "Low" or "Moderate" or "High",
    "analysis": "4-5 words describing the current state",
    "temporal_trend": "Improving" or "Stable" or "Worsening",
    "recommendations": ["action 1", "action 2"]
}}
"""
        
        response = model.generate_content(prompt)
        response_text = response.text.strip()
        
        # Clean markdown if present
        if response_text.startswith("```"):
            lines = response_text.split("\n")
            response_text = "\n".join(lines[1:-1])
        if response_text.startswith("json"):
            response_text = response_text[4:].strip()
        
        import json
        return json.loads(response_text)
        
    except Exception as e:
        logger.error(f"LLM analysis failed: {e}")
        return {"level": "Moderate", "analysis": "Analysis unavailable", "recommendations": ["Manual inspection recommended"]}

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
                index_data, index_type, request.gaussian_sigma, request.show_field_boundary
            )
            
            log_section(f"SUCCESS [{req_id}]")
            
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
            
            # Run LLM analysis
            llm_result = run_llm_analysis(request.metric, stress_context, {'primary': index_data})
            
            log_step(6, 6, "Generating heatmap")
            
            # Generate stress-based heatmap
            # Create stress map from patch scores
            h, w = img_data.shape[:2]
            stress_map = np.zeros((h, w))
            for i, (py, px) in enumerate(patch_coords):
                stress_map[py:py+4, px:px+4] = stress_results['stress_scores'][i]
            
            img_b64, min_v, max_v, mean_v = generate_heatmap_image(
                stress_map, "Stress", request.gaussian_sigma, request.show_field_boundary, is_stress=True
            )
            
            # Get cluster distribution
            cluster_dist = stress_context['field_statistics']['stress_distribution']
            
            log_section(f"SUCCESS [{req_id}]")
            
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
                level=llm_result.get('level', 'Unknown'),
                analysis=llm_result.get('analysis', ''),
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


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)
