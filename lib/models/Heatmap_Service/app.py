"""
AGROW Heatmap Service
=====================
Generates heatmap images from Sentinel-2 satellite data using the same
vegetation indices from the main Sentinel-2 pipeline.
"""

import os
import io
import re
import base64
import logging
from datetime import datetime, timedelta
from typing import Optional

import numpy as np
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
from PIL import Image
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel

from sentinelhub import (
    SHConfig, BBox, CRS, DataCollection, SentinelHubRequest,
    MimeType, bbox_to_dimensions, SentinelHubCatalog
)

# Import vegetation indices from S2 pipeline
from vegetation_indices import INDEX_FUNCTIONS, calculate_all_indices

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI
app = FastAPI(
    title="AGROW Heatmap Service",
    description="Generate heatmap images from Sentinel-2 vegetation indices",
    version="2.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Sentinel Hub configuration
def get_sh_config():
    config = SHConfig()
    config.sh_client_id = os.environ.get('SH_CLIENT_ID', '')
    config.sh_client_secret = os.environ.get('SH_CLIENT_SECRET', '')
    config.sh_base_url = 'https://sh.dataspace.copernicus.eu'
    config.sh_token_url = 'https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token'
    return config


# Request models
class HeatmapRequest(BaseModel):
    center_lat: float
    center_lon: float
    field_size_hectares: float = 10.0
    index_type: str = "NDVI"  # Any index from vegetation_indices.py


class HeatmapResponse(BaseModel):
    success: bool
    index_type: str
    min_value: float
    max_value: float
    mean_value: float
    image_base64: str
    timestamp: str
    image_date: Optional[str] = None


# Custom colormap for vegetation indices
def get_vegetation_colormap():
    """Create a colormap from red (low) to yellow (mid) to green (high)."""
    colors = [
        (0.8, 0.2, 0.2),   # Red (stress/low)
        (0.9, 0.6, 0.2),   # Orange
        (0.95, 0.9, 0.3),  # Yellow (moderate)
        (0.6, 0.8, 0.3),   # Light green
        (0.2, 0.6, 0.2),   # Dark green (healthy/high)
    ]
    return LinearSegmentedColormap.from_list('vegetation', colors, N=256)


def get_water_colormap():
    """Colormap for water-related indices (NDWI, SMI)."""
    colors = [
        (0.9, 0.6, 0.3),   # Brown (dry)
        (0.95, 0.9, 0.5),  # Yellow
        (0.5, 0.8, 0.9),   # Light blue
        (0.2, 0.5, 0.8),   # Blue
        (0.1, 0.3, 0.6),   # Dark blue (wet)
    ]
    return LinearSegmentedColormap.from_list('water', colors, N=256)


# Evalscript to fetch all 13 bands
FULL_BANDS_EVALSCRIPT = """
//VERSION=3
function setup() {
    return {
        input: [{
            bands: ["B01", "B02", "B03", "B04", "B05", "B06", "B07", "B08", "B8A", "B09", "B11", "B12", "dataMask"],
            units: "REFLECTANCE"
        }],
        output: {
            bands: 13,
            sampleType: "FLOAT32"
        }
    };
}

function evaluatePixel(sample) {
    return [
        sample.B01, sample.B02, sample.B03, sample.B04,
        sample.B05, sample.B06, sample.B07, sample.B08,
        sample.B8A, sample.B09, sample.B11, sample.B12,
        sample.dataMask
    ];
}
"""


def parse_timestamp(ts_str: str) -> datetime:
    """Parse ISO timestamp with variable fractional seconds."""
    ts_str = ts_str.replace('Z', '+00:00')
    match = re.match(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\.(\d+)([+-]\d{2}:\d{2})', ts_str)
    if match:
        base, frac, tz = match.groups()
        frac = frac.ljust(6, '0')[:6]
        ts_str = f"{base}.{frac}{tz}"
    return datetime.fromisoformat(ts_str)


def generate_heatmap_image(data: np.ndarray, index_type: str) -> tuple:
    """Generate a heatmap image from index data."""
    
    # Handle NaN values
    valid_mask = ~np.isnan(data)
    if not np.any(valid_mask):
        raise ValueError("No valid data pixels found")
    
    min_val = float(np.nanmin(data))
    max_val = float(np.nanmax(data))
    mean_val = float(np.nanmean(data))
    
    # Normalize data to 0-1 range for colormap
    data_normalized = np.clip((data - min_val) / (max_val - min_val + 1e-8), 0, 1)
    data_normalized = np.nan_to_num(data_normalized, nan=0.5)
    
    # Create figure
    fig, ax = plt.subplots(figsize=(8, 8), dpi=100)
    
    # Select colormap based on index type
    if index_type in ['NDWI', 'SMI']:
        cmap = get_water_colormap()
    else:
        cmap = get_vegetation_colormap()
    
    im = ax.imshow(data_normalized, cmap=cmap, interpolation='bilinear')
    
    # Add colorbar
    cbar = plt.colorbar(im, ax=ax, shrink=0.8, pad=0.02)
    cbar.set_label(f'{index_type} Value', fontsize=10)
    
    # Format colorbar ticks to show actual values
    cbar_ticks = np.linspace(0, 1, 5)
    cbar_labels = [f'{min_val + t * (max_val - min_val):.2f}' for t in cbar_ticks]
    cbar.set_ticks(cbar_ticks)
    cbar.set_ticklabels(cbar_labels)
    
    # Style
    ax.set_title(f'{index_type} Heatmap', fontsize=14, fontweight='bold')
    ax.axis('off')
    
    # Save to buffer
    buf = io.BytesIO()
    plt.savefig(buf, format='png', bbox_inches='tight', facecolor='white', edgecolor='none')
    plt.close(fig)
    buf.seek(0)
    
    # Convert to base64
    img_base64 = base64.b64encode(buf.getvalue()).decode('utf-8')
    
    return img_base64, min_val, max_val, mean_val


@app.get("/")
async def root():
    return {
        "service": "AGROW Heatmap Service",
        "version": "2.0.0",
        "status": "running",
        "supported_indices": list(INDEX_FUNCTIONS.keys()),
        "endpoints": {
            "/generate-heatmap": "POST - Generate heatmap from coordinates",
            "/generate-heatmap-image": "GET - Get heatmap as PNG directly",
            "/health": "GET - Health check"
        }
    }


@app.get("/health")
async def health():
    return {"status": "healthy", "indices_available": list(INDEX_FUNCTIONS.keys())}


@app.post("/generate-heatmap", response_model=HeatmapResponse)
async def generate_heatmap(request: HeatmapRequest):
    """Generate a heatmap image for the specified location and index type."""
    
    # Validate index type
    if request.index_type not in INDEX_FUNCTIONS:
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid index type '{request.index_type}'. Supported: {list(INDEX_FUNCTIONS.keys())}"
        )
    
    try:
        logger.info(f"Generating {request.index_type} heatmap for ({request.center_lat}, {request.center_lon})")
        
        config = get_sh_config()
        
        # Calculate bounding box from center and field size
        field_radius_km = np.sqrt(request.field_size_hectares / 100) / 2
        lat_offset = field_radius_km / 111
        lon_offset = field_radius_km / (111 * np.cos(np.radians(request.center_lat)))
        
        bbox = BBox(
            (
                request.center_lon - lon_offset,
                request.center_lat - lat_offset,
                request.center_lon + lon_offset,
                request.center_lat + lat_offset
            ),
            crs=CRS.WGS84
        )
        
        # Calculate resolution (10m per pixel)
        size = bbox_to_dimensions(bbox, resolution=10)
        size = (max(size[0], 64), max(size[1], 64))
        
        # Get recent date
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30)
        
        # Define data collection for CDSE
        SENTINEL2_L2A_CDSE = DataCollection.define_from(
            DataCollection.SENTINEL2_L2A,
            service_url='https://sh.dataspace.copernicus.eu'
        )
        
        # Create request for all 13 bands
        sh_request = SentinelHubRequest(
            evalscript=FULL_BANDS_EVALSCRIPT,
            input_data=[
                SentinelHubRequest.input_data(
                    data_collection=SENTINEL2_L2A_CDSE,
                    time_interval=(start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')),
                    mosaicking_order='leastCC'
                )
            ],
            responses=[SentinelHubRequest.output_response('default', MimeType.TIFF)],
            bbox=bbox,
            size=size,
            config=config
        )
        
        # Fetch data
        data = sh_request.get_data()[0]
        
        if data is None or data.size == 0:
            raise HTTPException(status_code=404, detail="No satellite data available for this location")
        
        logger.info(f"Fetched data shape: {data.shape}")
        
        # Calculate the requested index using the S2 pipeline function
        # Need to remove dataMask (last band) for index calculation
        img_data = data[:, :, :12]  # Remove dataMask
        
        index_func = INDEX_FUNCTIONS[request.index_type]
        index_data = index_func(img_data)
        
        logger.info(f"Calculated {request.index_type}: min={np.nanmin(index_data):.4f}, max={np.nanmax(index_data):.4f}")
        
        # Generate heatmap
        img_base64, min_val, max_val, mean_val = generate_heatmap_image(index_data, request.index_type)
        
        return HeatmapResponse(
            success=True,
            index_type=request.index_type,
            min_value=min_val,
            max_value=max_val,
            mean_value=mean_val,
            image_base64=img_base64,
            timestamp=datetime.now().isoformat(),
            image_date=end_date.strftime('%Y-%m-%d')
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error generating heatmap: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/generate-heatmap-image")
async def generate_heatmap_image_direct(
    center_lat: float,
    center_lon: float,
    field_size_hectares: float = 10.0,
    index_type: str = "NDVI"
):
    """Generate and return heatmap as PNG image directly."""
    
    request = HeatmapRequest(
        center_lat=center_lat,
        center_lon=center_lon,
        field_size_hectares=field_size_hectares,
        index_type=index_type
    )
    
    response = await generate_heatmap(request)
    
    # Decode base64 to bytes
    img_bytes = base64.b64decode(response.image_base64)
    
    return Response(content=img_bytes, media_type="image/png")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)
