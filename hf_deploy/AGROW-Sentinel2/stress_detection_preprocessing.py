"""
Stress Detection Preprocessing Module
======================================

Prepares Sentinel-2 multi-spectral data for stress detection model.
Includes band harmonization and normalization.
"""

import numpy as np
from typing import Tuple, List

# Band indices in the 12-band Sentinel-2 data
BAND_INDICES = {
    'B02': 1,   # Blue
    'B03': 2,   # Green
    'B04': 3,   # Red
    'B05': 4,   # Red Edge 1
    'B08': 7,   # NIR
    'B8A': 8,   # NIR Narrow
    'B11': 10,  # SWIR1
    'B12': 11   # SWIR2
}

# Selected bands for stress detection (8 major bands)
SELECTED_BANDS = ['B02', 'B03', 'B04', 'B05', 'B08', 'B8A', 'B11', 'B12']


def extract_major_bands(all_images: np.ndarray) -> np.ndarray:
    """
    Extract 8 major bands from 12-band Sentinel-2 data.
    
    Args:
        all_images: Array of shape (time, height, width, 12)
        
    Returns:
        Array of shape (time, height, width, 8) with selected bands
    """
    band_idx = [BAND_INDICES[band] for band in SELECTED_BANDS]
    return all_images[:, :, :, band_idx]


def harmonize_bands(images: np.ndarray) -> np.ndarray:
    """
    Harmonize band data to same scale [0, 1].
    
    Sentinel-2 reflectance values are already in [0, 1] range after DN/10000 conversion.
    This function ensures all bands are properly normalized and handles any outliers.
    
    Args:
        images: Array of shape (time, height, width, bands)
        
    Returns:
        Harmonized array with values clipped to [0, 1]
    """
    # Clip to [0, 1] range to handle any outliers
    harmonized = np.clip(images, 0, 1)
    
    # Additional per-band normalization to ensure uniform scale
    # Use percentile-based normalization to handle outliers
    time, height, width, bands = harmonized.shape
    
    for b in range(bands):
        band_data = harmonized[:, :, :, b]
        
        # Calculate 2nd and 98th percentiles to handle outliers
        p2 = np.nanpercentile(band_data, 2)
        p98 = np.nanpercentile(band_data, 98)
        
        # Normalize to [0, 1] using percentiles
        if p98 > p2:
            harmonized[:, :, :, b] = np.clip((band_data - p2) / (p98 - p2), 0, 1)
    
    return harmonized


def handle_nan_values(images: np.ndarray, method='mean') -> np.ndarray:
    """
    Handle NaN values in the data.
    
    Args:
        images: Array of shape (time, height, width, bands)
        method: 'mean', 'zero', or 'interpolate'
        
    Returns:
        Array with NaN values handled
    """
    if method == 'zero':
        return np.nan_to_num(images, nan=0.0)
    elif method == 'mean':
        # Replace NaN with temporal mean for each pixel
        return np.where(np.isnan(images), 
                       np.nanmean(images, axis=0, keepdims=True), 
                       images)
    elif method == 'interpolate':
        # Simple linear interpolation along time axis
        result = images.copy()
        time, height, width, bands = images.shape
        
        for h in range(height):
            for w in range(width):
                for b in range(bands):
                    pixel_series = result[:, h, w, b]
                    if np.any(np.isnan(pixel_series)):
                        # Interpolate NaN values
                        mask = ~np.isnan(pixel_series)
                        if np.any(mask):
                            indices = np.arange(time)
                            result[:, h, w, b] = np.interp(
                                indices, indices[mask], pixel_series[mask]
                            )
                        else:
                            result[:, h, w, b] = 0.0
        return result
    else:
        return images


def create_patches(images: np.ndarray, patch_size: int = 4, stride: int = 2) -> Tuple[np.ndarray, List]:
    """
    Create overlapping patches from images for spatial analysis.
    
    Args:
        images: Array of shape (time, height, width, bands)
        patch_size: Size of each patch
        stride: Stride for patch extraction
        
    Returns:
        patches: Array of shape (num_patches, time, patch_size, patch_size, bands)
        patch_coords: List of (h_start, w_start) coordinates for each patch
    """
    time, height, width, bands = images.shape
    patches = []
    patch_coords = []
    
    for h in range(0, height - patch_size + 1, stride):
        for w in range(0, width - patch_size + 1, stride):
            patch = images[:, h:h+patch_size, w:w+patch_size, :]
            
            # Only include patches with sufficient valid data
            valid_ratio = np.sum(~np.isnan(patch)) / patch.size
            if valid_ratio > 0.5:  # At least 50% valid data
                patches.append(patch)
                patch_coords.append((h, w))
    
    if len(patches) == 0:
        # If no valid patches, create at least one from center
        h_center = (height - patch_size) // 2
        w_center = (width - patch_size) // 2
        patch = images[:, h_center:h_center+patch_size, w_center:w_center+patch_size, :]
        patches.append(patch)
        patch_coords.append((h_center, w_center))
    
    return np.array(patches), patch_coords


def preprocess_for_model(all_images: np.ndarray, 
                         patch_size: int = 4,
                         stride: int = 2) -> Tuple[np.ndarray, List, dict]:
    """
    Complete preprocessing pipeline for stress detection model.
    
    Args:
        all_images: Raw images of shape (time, height, width, 12)
        patch_size: Size of patches for spatial analysis
        stride: Stride for patch extraction
        
    Returns:
        patches: Preprocessed patches ready for model
        patch_coords: Coordinates of each patch
        metadata: Dictionary with preprocessing information
    """
    print("Preprocessing data for stress detection model...")
    
    # Step 1: Extract major bands
    print("  [1/4] Extracting 8 major bands...")
    major_bands = extract_major_bands(all_images)
    
    # Step 2: Harmonize bands to same scale
    print("  [2/4] Harmonizing bands to [0, 1] scale...")
    harmonized = harmonize_bands(major_bands)
    
    # Step 3: Handle NaN values
    print("  [3/4] Handling NaN values...")
    clean_data = handle_nan_values(harmonized, method='mean')
    
    # Step 4: Create patches
    print("  [4/4] Creating spatial patches...")
    patches, patch_coords = create_patches(clean_data, patch_size, stride)
    
    metadata = {
        'original_shape': all_images.shape,
        'selected_bands': SELECTED_BANDS,
        'num_bands': len(SELECTED_BANDS),
        'patch_size': patch_size,
        'stride': stride,
        'num_patches': len(patches),
        'harmonized': True
    }
    
    print(f"[OK] Preprocessing complete. Created {len(patches)} patches.")
    print(f"     Patch shape: {patches.shape}")
    
    return patches, patch_coords, metadata
