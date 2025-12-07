"""
SAR Prediction Pipeline
-----------------------
Fetches nearest SAR data, processes it, runs stress analysis, and queries LLM.
"""

import os
import numpy as np
import pandas as pd
import rasterio
import datetime
from datetime import timedelta
import warnings
import json
import requests
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

from sentinelhub import (
    SHConfig, 
    SentinelHubRequest,
    SentinelHubCatalog,
    DataCollection, 
    MimeType, 
    BBox, 
    CRS,
    bbox_to_dimensions
)

# Import existing modules for feature engineering and analysis
try:
    from feature_engineering import FeatureEngineer
    from clustering import StressAnalyzer
except ImportError:
    print("Warning: Custom modules not found. Ensure feature_engineering.py and clustering.py are present.")

# Import Gemini Integration
try:
    from gemini_llm_integration import prepare_llm_input
except ImportError:
    print("Warning: gemini_llm_integration.py not found. LLM features will be disabled.")

# ============================================================================
# USER INPUTS (DEFAULTS)
# ============================================================================

# Coordinates for ICAR-Indian Institute of Maize Research, Ludhiana
# Format: [min_lon, min_lat, max_lon, max_lat]
INPUT_COORDINATES = [75.8350, 30.9060, 75.8370, 30.9090]

INPUT_DATE = '2024-01-15'
CROP_TYPE = 'Maize'

# Enhanced farmer context
FARMER_CONTEXT = {
    "role": "research agronomist",
    "tech_familiarity": "high",
    "farming_methods": "precision agriculture",
    "years_farming": 15,
    "irrigation_method": "furrow/sprinkler",
    "farm_work_style": "institutional",
    "farming_goal": "hybrid seed production and yield optimization",
    "additional_notes": "Winter maize trial. Sandy loam soil."
}

# Config
RESOLUTION = 10
PATCH_SIZE = 16
OUT_DIR = os.path.join(os.getcwd(), 'sar_prediction_output')

# ============================================================================
# 1. SETUP & DATA ACQUISITION
# ============================================================================

def setup_sentinelhub():
    """Configure Sentinel Hub credentials and data collection."""
    config = SHConfig()
    
    config.sh_client_id = "sh-709c1173-fc33-4a0e-90e4-b84161ed5b9d"
    config.sh_client_secret = "IdopxGFFr3NKFJ4Y2ywJRVfmM5eBB9b4"
    config.sh_base_url = "https://sh.dataspace.copernicus.eu"
    config.sh_token_url = "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token"
    
    S1 = DataCollection.define(
        name="SENTINEL1_IW_CDSE",
        api_id="sentinel-1-grd",
        service_url="https://sh.dataspace.copernicus.eu"
    )
    
    os.makedirs(OUT_DIR, exist_ok=True)
    return config, S1

def find_nearest_date(catalog, collection, bbox, target_date_str, max_days_diff=10):
    """Find the nearest available date to the target date."""
    target_date = datetime.datetime.strptime(target_date_str, "%Y-%m-%d")
    start_date = (target_date - timedelta(days=max_days_diff)).strftime("%Y-%m-%d")
    end_date = (target_date + timedelta(days=max_days_diff)).strftime("%Y-%m-%d")
    
    results = catalog.search(
        collection=collection,
        bbox=bbox,
        time=(start_date, end_date),
        filter="sar:instrument_mode = 'IW'"
    )
    
    scenes = list(results)
    if not scenes:
        return None
        
    available_dates = sorted(list(set([scene['properties']['datetime'].split('T')[0] for scene in scenes])))
    nearest_date = min(available_dates, key=lambda x: abs(datetime.datetime.strptime(x, "%Y-%m-%d") - target_date))
    return nearest_date

def fetch_sar_data(config, S1, date_str, aoi_coords, resolution, out_dir):
    """Download SAR data for a specific date."""
    AOI_BBOX = BBox(bbox=aoi_coords, crs=CRS.WGS84)
    size = bbox_to_dimensions(AOI_BBOX, resolution=resolution)
    
    evalscript = """
    //VERSION=3
    function setup() {
      return {
        input: ["VV", "VH", "dataMask"],
        output: [
          { id: "VV", bands: 1, sampleType: "FLOAT32" },
          { id: "VH", bands: 1, sampleType: "FLOAT32" }
        ]
      };
    }
    
    function evaluatePixel(sample) {
      let vv_db = (sample.VV > 0) ? 10 * Math.log(sample.VV) / Math.LN10 : -9999;
      let vh_db = (sample.VH > 0) ? 10 * Math.log(sample.VH) / Math.LN10 : -9999;
      return { VV: [vv_db], VH: [vh_db] };
    }
    """
    
    dt = datetime.datetime.strptime(date_str, "%Y-%m-%d")
    next_day = (dt + datetime.timedelta(days=1)).strftime("%Y-%m-%d")
    
    request = SentinelHubRequest(
        evalscript=evalscript,
        input_data=[
            SentinelHubRequest.input_data(
                data_collection=S1,
                time_interval=(date_str, next_day),
                mosaicking_order="leastRecent",
                other_args={"processing": {"backCoeff": "GAMMA0_TERRAIN", "orthorectify": True}}
            )
        ],
        responses=[
            SentinelHubRequest.output_response('VV', MimeType.TIFF),
            SentinelHubRequest.output_response('VH', MimeType.TIFF)
        ],
        bbox=AOI_BBOX,
        size=size,
        config=config
    )
    
    data = request.get_data()
    
    if data and len(data) > 0:
        data_dict = data[0]
        vv_path = os.path.join(out_dir, f"S1_{date_str}_VV.tif")
        vh_path = os.path.join(out_dir, f"S1_{date_str}_VH.tif")
        
        transform = rasterio.transform.from_bounds(*AOI_BBOX, width=size[0], height=size[1])
        
        if 'VV.tif' in data_dict:
            with rasterio.open(vv_path, 'w', driver='GTiff', height=size[1], width=size[0],
                               count=1, dtype=data_dict['VV.tif'].dtype, crs=CRS.WGS84.pyproj_crs(), transform=transform) as dst:
                dst.write(data_dict['VV.tif'], 1)
                
        if 'VH.tif' in data_dict:
            with rasterio.open(vh_path, 'w', driver='GTiff', height=size[1], width=size[0],
                               count=1, dtype=data_dict['VH.tif'].dtype, crs=CRS.WGS84.pyproj_crs(), transform=transform) as dst:
                dst.write(data_dict['VH.tif'], 1)
                
        return vv_path, vh_path
    return None, None

def process_to_dataframe(vv_path, vh_path, date_str):
    """Convert GeoTIFFs to DataFrame."""
    if not vv_path or not os.path.exists(vv_path):
        return pd.DataFrame()
        
    with rasterio.open(vv_path) as src:
        vv_data = src.read(1)
        transform = src.transform
        
    with rasterio.open(vh_path) as src:
        vh_data = src.read(1)
        
    height, width = vv_data.shape
    rows, cols = np.meshgrid(np.arange(height), np.arange(width), indexing='ij')
    xs, ys = rasterio.transform.xy(transform, rows.flatten(), cols.flatten())
    
    records = []
    for i in range(len(xs)):
        vv = vv_data.flatten()[i]
        vh = vh_data.flatten()[i]
        if vv > -9999 and vh > -9999:
            records.append({
                'timestamp': pd.to_datetime(date_str),
                'row': rows.flatten()[i],
                'col': cols.flatten()[i],
                'lon': xs[i],
                'lat': ys[i],
                'VV_dB': vv,
                'VH_dB': vh,
                'VV_VH_ratio_dB': vv - vh
            })
            
    return pd.DataFrame(records)

def fetch_weather_data(lat, lon, start_date, end_date):
    """
    Fetch weather data from Open-Meteo API (FREE, no API key needed).
    Returns daily weather data for the specified period.
    """
    url = "https://archive-api.open-meteo.com/v1/archive"
    
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": start_date,
        "end_date": end_date,
        "daily": [
            "temperature_2m_max",
            "temperature_2m_min",
            "temperature_2m_mean",
            "precipitation_sum",
            "rain_sum",
            "windspeed_10m_max",
            "et0_fao_evapotranspiration"
        ],
        "timezone": "Asia/Kolkata"
    }
    
    try:
        response = requests.get(url, params=params)
        if response.status_code == 200:
            data = response.json()
            df_weather = pd.DataFrame({
                'date': pd.to_datetime(data['daily']['time']),
                'temp_max': data['daily']['temperature_2m_max'],
                'temp_min': data['daily']['temperature_2m_min'],
                'temp_mean': data['daily']['temperature_2m_mean'],
                'precipitation': data['daily']['precipitation_sum'],
                'rain': data['daily']['rain_sum'],
                'wind_speed': data['daily']['windspeed_10m_max'],
                'evapotranspiration': data['daily']['et0_fao_evapotranspiration']
            })
            return df_weather
        else:
            print(f"Weather API error: {response.status_code}")
            return pd.DataFrame()
    except Exception as e:
        print(f"Error fetching weather data: {e}")
        return pd.DataFrame()

# ============================================================================
# 2. PIPELINE EXECUTION & ANALYSIS
# ============================================================================

def run_sar_prediction_pipeline(coords, target_date_str, crop_type, farmer_context):
    print(f"Starting SAR Prediction Pipeline for {crop_type} on {target_date_str}...")
    
    # 1. Setup
    config, S1 = setup_sentinelhub()
    bbox = BBox(bbox=coords, crs=CRS.WGS84)
    catalog = SentinelHubCatalog(config=config)
    
    # 2. Find Nearest Date
    nearest_date = find_nearest_date(catalog, S1, bbox, target_date_str)
    if not nearest_date:
        return {"error": "No SAR data found near target date"}
    print(f"[OK] Nearest SAR data found: {nearest_date}")
    
    # 3. Fetch Data
    vv_path, vh_path = fetch_sar_data(config, S1, nearest_date, coords, RESOLUTION, OUT_DIR)
    
    # 4. Process to DataFrame
    df = process_to_dataframe(vv_path, vh_path, nearest_date)
    if df.empty:
        return {"error": "Failed to extract pixel data"}
    print(f"[OK] Data extracted: {len(df)} pixels")
    
    # 5. Feature Engineering & Patching
    patch_size = PATCH_SIZE
    height = df['row'].max() + 1
    width = df['col'].max() + 1
    
    vv_img = np.full((height, width), -9999.0)
    vh_img = np.full((height, width), -9999.0)
    
    for _, row in df.iterrows():
        r, c = int(row['row']), int(row['col'])
        vv_img[r, c] = row['VV_dB']
        vh_img[r, c] = row['VH_dB']
        
    patches = []
    patch_coords = []
    
    for r in range(0, height - patch_size + 1, patch_size):
        for c in range(0, width - patch_size + 1, patch_size):
            p_vv = vv_img[r:r+patch_size, c:c+patch_size]
            p_vh = vh_img[r:r+patch_size, c:c+patch_size]
            
            if np.mean(p_vv == -9999) > 0.1:
                continue
                
            p_ratio = p_vv - p_vh
            patch = np.stack([p_vv, p_vh, p_ratio], axis=-1)
            patches.append(patch)
            patch_coords.append((r, c))
            
    patches = np.array(patches)
    print(f"[OK] Generated {len(patches)} patches")
    
    if len(patches) == 0:
         return {"error": "AOI too small for patch analysis"}

    # 6. Analysis (Clustering/Anomaly Detection)
    print("Computing SAR statistical features...")
    feature_list = []
    for i, patch in enumerate(patches):
        # patch shape: (32, 32, 3) -> VV, VH, Ratio
        vv = patch[:, :, 0]
        vh = patch[:, :, 1]
        ratio = patch[:, :, 2]
        
        stats = {
            'vv_mean': np.mean(vv),
            'vv_std': np.std(vv),
            'vh_mean': np.mean(vh),
            'vh_std': np.std(vh),
            'ratio_mean': np.mean(ratio),
            'ratio_std': np.std(ratio)
        }
        feature_list.append(stats)
        
    features = pd.DataFrame(feature_list)
    print(f"[OK] Computed features for {len(features)} patches")
    
    # Clustering
    embeddings = features.values 
    analyzer = StressAnalyzer(n_clusters=3, contamination=0.1)
    analysis = analyzer.analyze(embeddings)
    
    # Identify stressed patches
    stressed_indices = np.where(analysis['anomaly_labels'] == -1)[0]
    
    stressed_patches_info = []
    for idx in stressed_indices:
        r, c = patch_coords[idx]
        center_r, center_c = r + patch_size//2, c + patch_size//2
        pixel_info = df[(df['row'] == center_r) & (df['col'] == center_c)]
        if not pixel_info.empty:
            lat = pixel_info.iloc[0]['lat']
            lon = pixel_info.iloc[0]['lon']
            stressed_patches_info.append({"lat": lat, "lon": lon, "status": "High Stress"})
            
    # 7. LLM Integration
    print("Fetching weather data...")
    center_lat = (coords[1] + coords[3]) / 2
    center_lon = (coords[0] + coords[2]) / 2
    
    target_date = datetime.datetime.strptime(nearest_date, "%Y-%m-%d")
    weather_start = (target_date - timedelta(days=7)).strftime("%Y-%m-%d")
    weather_end = nearest_date
    
    df_weather = fetch_weather_data(center_lat, center_lon, weather_start, weather_end)
    
    print("Calling Gemini LLM...")
    llm_result, _, _ = prepare_llm_input(
        features=features,
        stressed_indices=stressed_indices,
        patches=patches,
        df_weather=df_weather,
        CROP_TYPE=crop_type,
        nearest_date=nearest_date,
        center_lat=center_lat,
        center_lon=center_lon,
        PATCH_SIZE=patch_size,
        RESOLUTION=RESOLUTION,
        FARMER_CONTEXT=farmer_context
    )
    
    # Final Output
    final_output = {
        "date": nearest_date,
        "stressed_patches": stressed_patches_info,
        "health_summary": llm_result
    }
    
    return final_output

if __name__ == "__main__":
    result = run_sar_prediction_pipeline(INPUT_COORDINATES, INPUT_DATE, CROP_TYPE, FARMER_CONTEXT)
    
    print("\\n" + "="*80)
    print("FINAL OUTPUT FOR BACKEND")
    print("="*80)
    print(json.dumps(result, indent=2))
