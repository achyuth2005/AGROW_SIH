"""
Satellite Data Pipeline - Production Module
============================================

This module provides functions to fetch and reconstruct RGB images from Sentinel-2 satellite data.
The developer can integrate this into any web framework (Flask, FastAPI, Django, etc.)

USAGE EXAMPLE:
--------------
from satellite_pipeline import fetch_satellite_rgb_for_polygon

# Frontend sends polygon coordinates
polygon_coords = [
    [75.840, 30.890],  # [lon, lat]
    [75.860, 30.890],
    [75.860, 30.910],
    [75.840, 30.910],
    [75.840, 30.890]
]

# Fetch and get RGB image
result = fetch_satellite_rgb_for_polygon(
    polygon_coords=polygon_coords,
    days_back=30
)

if result['success']:
    # result['rgb_image'] is a numpy array (H, W, 3) in range [0, 1]
    # Convert to PIL Image or base64 for frontend
    from PIL import Image
    img = Image.fromarray((result['rgb_image'] * 255).astype('uint8'))
    img.save('output.png')
"""

import numpy as np
from typing import List, Tuple, Dict, Optional
import datetime
from sentinelhub import (
    SHConfig, SentinelHubRequest, DataCollection,
    MimeType, BBox, CRS, bbox_to_dimensions, SentinelHubCatalog
)


# ============================================================================
# CONFIGURATION
# ============================================================================

def create_config(client_id: str, client_secret: str) -> SHConfig:
    """
    Create Sentinel Hub configuration.
    
    Args:
        client_id: Sentinel Hub client ID
        client_secret: Sentinel Hub client secret
    
    Returns:
        Configured SHConfig object
    """
    config = SHConfig()
    config.sh_client_id = client_id
    config.sh_client_secret = client_secret
    return config


# ============================================================================
# POLYGON TO BBOX CONVERSION
# ============================================================================

def polygon_to_bbox(polygon_coords: List[List[float]]) -> BBox:
    """
    Convert polygon coordinates to bounding box.
    
    Args:
        polygon_coords: List of [lon, lat] pairs defining the polygon
                       Example: [[75.84, 30.89], [75.86, 30.89], ...]
    
    Returns:
        BBox object for Sentinel Hub API
    """
    lons = [coord[0] for coord in polygon_coords]
    lats = [coord[1] for coord in polygon_coords]
    
    min_lon, max_lon = min(lons), max(lons)
    min_lat, max_lat = min(lats), max(lats)
    
    return BBox(bbox=[min_lon, min_lat, max_lon, max_lat], crs=CRS.WGS84)


# ============================================================================
# SENTINEL-2 DATA FETCHING
# ============================================================================

def find_best_date(
    bbox: BBox,
    days_back: int,
    config: SHConfig,
    max_cloud_cover: float = 50.0
) -> Optional[Tuple[str, float]]:
    """
    Find the best (least cloudy) Sentinel-2 acquisition date.
    
    Args:
        bbox: Bounding box
        days_back: Number of days to search back from today
        config: Sentinel Hub configuration
        max_cloud_cover: Maximum acceptable cloud cover percentage
    
    Returns:
        Tuple of (date_string, cloud_cover_percentage) or None
    """
    end_date = datetime.date.today()
    start_date = end_date - datetime.timedelta(days=days_back)
    
    try:
        catalog = SentinelHubCatalog(config=config)
        search_iterator = catalog.search(
            collection=DataCollection.SENTINEL2_L2A,
            bbox=bbox,
            time=(start_date.isoformat(), end_date.isoformat())
        )
        
        items = list(search_iterator)
        if not items:
            return None
        
        # Filter by cloud cover and find best
        valid_items = [
            item for item in items
            if item['properties'].get('eo:cloud_cover', 100) <= max_cloud_cover
        ]
        
        if not valid_items:
            # If no items below threshold, take the best available
            valid_items = items
        
        best_item = min(valid_items, key=lambda x: x['properties'].get('eo:cloud_cover', 100))
        best_date = best_item['properties']['datetime'][:10]
        cloud_cover = best_item['properties'].get('eo:cloud_cover', 0)
        
        return best_date, cloud_cover
        
    except Exception as e:
        print(f"Error searching catalog: {e}")
        return None


def fetch_sentinel2_data(
    bbox: BBox,
    date: str,
    config: SHConfig,
    resolution: int = 10
) -> Optional[np.ndarray]:
    """
    Fetch Sentinel-2 RGB bands for a specific date.
    
    Args:
        bbox: Bounding box
        date: Date string (YYYY-MM-DD)
        config: Sentinel Hub configuration
        resolution: Spatial resolution in meters (10m recommended)
    
    Returns:
        Array of shape (H, W, 4) containing [R, G, B, SCL] or None
    """
    # Evalscript to fetch RGB + Scene Classification Layer
    evalscript = """
    //VERSION=3
    function setup() {
      return {
        input: ["B04", "B03", "B02", "SCL"],
        output: { bands: 4, sampleType: "FLOAT32" }
      };
    }
    function evaluatePixel(sample) {
      return [sample.B04, sample.B03, sample.B02, sample.SCL];
    }
    """
    
    try:
        request = SentinelHubRequest(
            evalscript=evalscript,
            input_data=[SentinelHubRequest.input_data(
                data_collection=DataCollection.SENTINEL2_L2A,
                time_interval=(date, date)
            )],
            responses=[SentinelHubRequest.output_response("default", MimeType.TIFF)],
            bbox=bbox,
            size=bbox_to_dimensions(bbox, resolution=resolution),
            config=config
        )
        
        data = request.get_data(save_data=False)
        if data and len(data) > 0:
            return data[0]
        return None
        
    except Exception as e:
        print(f"Error fetching data for {date}: {e}")
        return None


# ============================================================================
# IMAGE ENHANCEMENT
# ============================================================================

def enhance_rgb(
    rgb_array: np.ndarray,
    brightness: float = 3.5,
    gamma: float = 1.0,
    contrast_stretch: bool = True
) -> np.ndarray:
    """
    Enhance RGB image for better visualization.
    
    Args:
        rgb_array: Input array (H, W, 3 or 4)
        brightness: Brightness multiplier
        gamma: Gamma correction factor
        contrast_stretch: Apply 2% linear contrast stretch
    
    Returns:
        Enhanced RGB array (H, W, 3) in range [0, 1]
    """
    # Extract RGB channels (ignore SCL if present)
    rgb = rgb_array[:, :, :3].copy()
    
    # Optional: Contrast stretching (removes extreme outliers)
    if contrast_stretch:
        p2, p98 = np.percentile(rgb, (2, 98))
        if p98 > p2:
            rgb = np.clip((rgb - p2) / (p98 - p2), 0, 1)
    
    # Apply brightness
    rgb = rgb * brightness
    
    # Apply gamma correction
    if gamma != 1.0:
        rgb = np.power(np.clip(rgb, 0, 1), gamma)
    
    # Final clipping
    return np.clip(rgb, 0, 1)


# ============================================================================
# MAIN PIPELINE FUNCTION
# ============================================================================

def fetch_satellite_rgb_for_polygon(
    polygon_coords: List[List[float]],
    client_id: str,
    client_secret: str,
    days_back: int = 30,
    resolution: int = 10,
    brightness: float = 3.5,
    max_cloud_cover: float = 50.0
) -> Dict:
    """
    Main pipeline: Fetch and reconstruct RGB image for a polygon area.
    
    Args:
        polygon_coords: List of [lon, lat] coordinate pairs
                       Example: [[75.84, 30.89], [75.86, 30.91], ...]
        client_id: Sentinel Hub client ID
        client_secret: Sentinel Hub client secret
        days_back: Days to search back from today (default: 30)
        resolution: Spatial resolution in meters (default: 10)
        brightness: Enhancement factor (default: 3.5)
        max_cloud_cover: Max acceptable cloud cover % (default: 50)
    
    Returns:
        Dictionary with:
        {
            'success': bool,
            'rgb_image': np.ndarray (H, W, 3) or None,  # Values in [0, 1]
            'timestamp': str or None,
            'cloud_cover': float or None,
            'dimensions': tuple (H, W) or None,
            'bbox': dict or None,  # {'min_lon', 'max_lon', 'min_lat', 'max_lat'}
            'error': str or None
        }
    """
    result = {
        'success': False,
        'rgb_image': None,
        'timestamp': None,
        'cloud_cover': None,
        'dimensions': None,
        'bbox': None,
        'error': None
    }
    
    try:
        # Step 1: Create configuration
        config = create_config(client_id, client_secret)
        
        # Step 2: Convert polygon to bounding box
        bbox = polygon_to_bbox(polygon_coords)
        result['bbox'] = {
            'min_lon': bbox.min_x,
            'max_lon': bbox.max_x,
            'min_lat': bbox.min_y,
            'max_lat': bbox.max_y
        }
        
        # Step 3: Find best date
        date_info = find_best_date(bbox, days_back, config, max_cloud_cover)
        if not date_info:
            result['error'] = f"No Sentinel-2 data found in last {days_back} days"
            return result
        
        best_date, cloud_cover = date_info
        
        # Step 4: Fetch data
        raw_data = fetch_sentinel2_data(bbox, best_date, config, resolution)
        if raw_data is None:
            result['error'] = "Failed to download satellite data"
            return result
        
        # Step 5: Enhance RGB
        rgb_enhanced = enhance_rgb(raw_data, brightness=brightness)
        
        # Step 6: Populate result
        result['success'] = True
        result['rgb_image'] = rgb_enhanced
        result['timestamp'] = best_date
        result['cloud_cover'] = cloud_cover
        result['dimensions'] = (rgb_enhanced.shape[0], rgb_enhanced.shape[1])
        
        return result
        
    except Exception as e:
        result['error'] = str(e)
        return result


# ============================================================================
# UTILITY FUNCTIONS FOR WEB INTEGRATION
# ============================================================================

def rgb_to_base64(rgb_array: np.ndarray, format: str = 'PNG') -> str:
    """
    Convert RGB numpy array to base64 string for web transmission.
    
    Args:
        rgb_array: RGB array (H, W, 3) in range [0, 1]
        format: Image format ('PNG', 'JPEG')
    
    Returns:
        Base64 encoded string
    """
    from PIL import Image
    import base64
    from io import BytesIO
    
    # Convert to uint8
    img_uint8 = (rgb_array * 255).astype('uint8')
    img_pil = Image.fromarray(img_uint8)
    
    # Encode to base64
    buffered = BytesIO()
    img_pil.save(buffered, format=format)
    img_str = base64.b64encode(buffered.getvalue()).decode()
    
    return img_str


def save_rgb_image(rgb_array: np.ndarray, filepath: str):
    """
    Save RGB array as image file.
    
    Args:
        rgb_array: RGB array (H, W, 3) in range [0, 1]
        filepath: Output file path (e.g., 'output.png')
    """
    from PIL import Image
    
    img_uint8 = (rgb_array * 255).astype('uint8')
    img_pil = Image.fromarray(img_uint8)
    img_pil.save(filepath)


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    # Example polygon (farmland in Punjab)
    polygon = [
        [75.8385, 30.8900],
        [75.8615, 30.8900],
        [75.8615, 30.9100],
        [75.8385, 30.9100],
        [75.8385, 30.8900]
    ]
    
    # Credentials (replace with actual)
    SH_CLIENT_ID = "713b1096-4c36-4bf6-b03c-ce01aa297fb6"
    SH_CLIENT_SECRET = "waVNOwoXx7HyH9rImt2BDayZC1jkbqk3"
    
    # Fetch RGB
    result = fetch_satellite_rgb_for_polygon(
        polygon_coords=polygon,
        client_id=SH_CLIENT_ID,
        client_secret=SH_CLIENT_SECRET,
        days_back=30
    )
    
    if result['success']:
        print(f"SUCCESS!")
        print(f"   Date: {result['timestamp']}")
        print(f"   Cloud Cover: {result['cloud_cover']:.1f}%")
        print(f"   Dimensions: {result['dimensions']}")
        
        # Save image
        save_rgb_image(result['rgb_image'], 'satellite_output.png')
        print(f"   Saved: satellite_output.png")
    else:
        print(f"FAILED: {result['error']}")
