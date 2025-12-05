"""
Vegetation Indices Calculator
==============================

This module provides functions to calculate 10 vegetation indices from Sentinel-2 data
and perform temporal analysis.

Indices:
- NDVI: Normalized Difference Vegetation Index
- EVI: Enhanced Vegetation Index
- NDWI: Normalized Difference Water Index
- NDRE: Normalized Difference Red Edge
- RECI: Red Edge Chlorophyll Index
- SMI: Soil Moisture Index
- NDSI: Normalized Difference Snow Index
- PRI: Photochemical Reflectance Index
- PSRI: Plant Senescence Reflectance Index
- MCARI: Modified Chlorophyll Absorption Ratio Index
- SASI: Salinity Index
- SOMI: Soil Organic Matter Index
- SFI: Soil Fertility Index
"""

import numpy as np
from typing import Dict, List, Tuple
import datetime
from datetime import timedelta

# ==================== INDEX CALCULATION FUNCTIONS ====================

def calculate_ndvi(img: np.ndarray) -> np.ndarray:
    """NDVI = (NIR - RED) / (NIR + RED)"""
    nir = img[:, :, 7]  # B08
    red = img[:, :, 3]  # B04
    return (nir - red) / (nir + red + 1e-10)

def calculate_evi(img: np.ndarray) -> np.ndarray:
    """EVI = 2.5 * ((NIR - RED) / (NIR + 6*RED - 7.5*BLUE + 1))"""
    nir = img[:, :, 7]  # B08
    red = img[:, :, 3]  # B04
    blue = img[:, :, 1]  # B02
    return 2.5 * ((nir - red) / (nir + 6*red - 7.5*blue + 1))

def calculate_ndwi(img: np.ndarray) -> np.ndarray:
    """NDWI = (GREEN - NIR) / (GREEN + NIR)"""
    green = img[:, :, 2]  # B03
    nir = img[:, :, 7]  # B08
    return (green - nir) / (green + nir + 1e-10)

def calculate_ndre(img: np.ndarray) -> np.ndarray:
    """NDRE = (NIR - RedEdge) / (NIR + RedEdge)"""
    nir = img[:, :, 7]  # B08
    red_edge = img[:, :, 4]  # B05
    return (nir - red_edge) / (nir + red_edge + 1e-10)

def calculate_reci(img: np.ndarray) -> np.ndarray:
    """RECI = (NIR / RedEdge) - 1"""
    nir = img[:, :, 7]  # B08
    red_edge = img[:, :, 4]  # B05
    return (nir / (red_edge + 1e-10)) - 1

def calculate_smi(img: np.ndarray) -> np.ndarray:
    """SMI = (SWIR1 - SWIR2) / (SWIR1 + SWIR2)"""
    swir1 = img[:, :, 10]  # B11
    swir2 = img[:, :, 11]  # B12
    return (swir1 - swir2) / (swir1 + swir2 + 1e-10)

def calculate_ndsi(img: np.ndarray) -> np.ndarray:
    """NDSI = (GREEN - SWIR1) / (GREEN + SWIR1)"""
    green = img[:, :, 2]  # B03
    swir1 = img[:, :, 10]  # B11
    return (green - swir1) / (green + swir1 + 1e-10)

def calculate_pri(img: np.ndarray) -> np.ndarray:
    """PRI = (B02 - B03) / (B02 + B03)"""
    b02 = img[:, :, 1]  # B02
    b03 = img[:, :, 2]  # B03
    return (b02 - b03) / (b02 + b03 + 1e-10)

def calculate_psri(img: np.ndarray) -> np.ndarray:
    """PSRI = (RED - GREEN) / NIR"""
    red = img[:, :, 3]  # B04
    green = img[:, :, 2]  # B03
    nir = img[:, :, 7]  # B08
    return (red - green) / (nir + 1e-10)

def calculate_mcari(img: np.ndarray) -> np.ndarray:
    """MCARI = ((B05 - B04) - 0.2 * (B05 - B03)) * (B05 / B04)"""
    b03 = img[:, :, 2]  # B03
    b04 = img[:, :, 3]  # B04
    b05 = img[:, :, 4]  # B05
    return ((b05 - b04) - 0.2 * (b05 - b03)) * (b05 / (b04 + 1e-10))

def calculate_sasi(img: np.ndarray) -> np.ndarray:
    """SASI (Salinity Index) = SQRT(B11 * B04)"""
    swir1 = img[:, :, 10]  # B11
    red = img[:, :, 3]  # B04
    return np.sqrt(swir1 * red)

def calculate_somi(img: np.ndarray) -> np.ndarray:
    """SOMI (Soil Organic Matter Index) = (B08 + B04) / (B11 + B12)"""
    nir = img[:, :, 7]  # B08
    red = img[:, :, 3]  # B04
    swir1 = img[:, :, 10]  # B11
    swir2 = img[:, :, 11]  # B12
    return (nir + red) / (swir1 + swir2 + 1e-10)

def calculate_sfi(img: np.ndarray) -> np.ndarray:
    """SFI (Soil Fertility Index) = (NDVI * SOMI) / SASI
    Combines vegetation health, organic matter, and salinity"""
    ndvi = calculate_ndvi(img)
    somi = calculate_somi(img)
    sasi = calculate_sasi(img)
    return (ndvi * somi) / (sasi + 1e-10)

def calculate_gndvi(img: np.ndarray) -> np.ndarray:
    """GNDVI (Green NDVI) = (NIR - GREEN) / (NIR + GREEN)
    Highly sensitive to chlorophyll content and nitrogen status"""
    nir = img[:, :, 7]   # B08
    green = img[:, :, 2]  # B03
    return (nir - green) / (nir + green + 1e-10)

# Index registry
INDEX_FUNCTIONS = {
    'NDVI': calculate_ndvi,
    'EVI': calculate_evi,
    'NDWI': calculate_ndwi,
    'NDRE': calculate_ndre,
    'RECI': calculate_reci,
    'SMI': calculate_smi,
    'NDSI': calculate_ndsi,
    'PRI': calculate_pri,
    'PSRI': calculate_psri,
    'MCARI': calculate_mcari,
    'SASI': calculate_sasi,
    'SOMI': calculate_somi,
    'SFI': calculate_sfi,
    'GNDVI': calculate_gndvi
}

# ==================== BATCH CALCULATION ====================

def calculate_all_indices(img: np.ndarray) -> Dict[str, np.ndarray]:
    """
    Calculate all 10 vegetation indices for a single image.
    
    Args:
        img: Image array of shape (height, width, 12) with reflectance values
        
    Returns:
        Dictionary mapping index names to 2D arrays
    """
    indices = {}
    for name, func in INDEX_FUNCTIONS.items():
        indices[name] = func(img)
    return indices

def calculate_indices_temporal(images: np.ndarray) -> Dict[str, np.ndarray]:
    """
    Calculate all indices for multiple time steps.
    
    Args:
        images: Array of shape (time, height, width, 12)
        
    Returns:
        Dictionary mapping index names to 3D arrays (time, height, width)
    """
    indices_data = {}
    
    for index_name, calc_func in INDEX_FUNCTIONS.items():
        index_series = []
        for img in images:
            index_map = calc_func(img)
            index_series.append(index_map)
        indices_data[index_name] = np.array(index_series)
    
    return indices_data

# ==================== STATISTICS ====================

def get_field_statistics(index_map: np.ndarray) -> Dict[str, float]:
    """
    Calculate statistics for a single index map.
    
    Returns:
        Dictionary with mean, std, min, max, median
    """
    return {
        'mean': float(np.nanmean(index_map)),
        'std': float(np.nanstd(index_map)),
        'min': float(np.nanmin(index_map)),
        'max': float(np.nanmax(index_map)),
        'median': float(np.nanmedian(index_map)),
        'valid_pixels': int(np.sum(~np.isnan(index_map)))
    }

def get_temporal_statistics(indices_temporal: Dict[str, np.ndarray]) -> Dict[str, Dict]:
    """
    Calculate temporal statistics for all indices.
    
    Args:
        indices_temporal: Dictionary with index names and 3D arrays (time, height, width)
        
    Returns:
        Dictionary with temporal stats for each index
    """
    temporal_stats = {}
    
    for index_name, data in indices_temporal.items():
        stats = {
            'mean_over_time': np.nanmean(data, axis=0),
            'std_over_time': np.nanstd(data, axis=0),
            'max_over_time': np.nanmax(data, axis=0),
            'min_over_time': np.nanmin(data, axis=0),
            'range': np.nanmax(data, axis=0) - np.nanmin(data, axis=0),
            'temporal_trend': data[-1] - data[0] if len(data) >= 2 else np.zeros_like(data[0]),
        }
        
        # Rolling average (window size = 3)
        if len(data) >= 3:
            rolling_avg = np.array([np.nanmean(data[max(0, i-2):i+1], axis=0) 
                                   for i in range(len(data))])
            stats['rolling_avg_3'] = rolling_avg
        
        temporal_stats[index_name] = stats
    
    return temporal_stats

def get_summary_report(indices_temporal: Dict[str, np.ndarray], 
                       dates: List[str]) -> Dict:
    """
    Generate a comprehensive summary report.
    
    Returns:
        Dictionary with summary statistics and temporal trends
    """
    report = {
        'dates': dates,
        'num_images': len(dates),
        'indices': {}
    }
    
    for index_name, data in indices_temporal.items():
        index_report = {
            'latest': get_field_statistics(data[-1]),
            'oldest': get_field_statistics(data[0]),
            'mean_values_over_time': [float(np.nanmean(data[i])) for i in range(len(dates))],
            'change': float(np.nanmean(data[-1]) - np.nanmean(data[0])),
            'max_in_field': float(np.nanmax(data)),
            'min_in_field': float(np.nanmin(data))
        }
        report['indices'][index_name] = index_report
    
    return report
