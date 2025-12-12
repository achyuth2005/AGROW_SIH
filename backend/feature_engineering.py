"""
Feature Engineering Module for Crop Stress Detection Pipeline

Computes vegetation indices and temporal derivatives.
"""

import numpy as np
from typing import Dict


class FeatureEngineer:
    """Compute spectral indices and temporal features."""
    
    def __init__(self):
        """Initialize feature engineer."""
        self.epsilon = 1e-8
        
    def safe_divide(self, a: np.ndarray, b: np.ndarray) -> np.ndarray:
        """Safe division with epsilon to avoid division by zero."""
        return np.divide(a, b + self.epsilon)
    
    def compute_ndvi(self, patches: np.ndarray) -> np.ndarray:
        """
        Compute NDVI = (NIR - Red) / (NIR + Red).
        
        Args:
            patches: (N, H, W, C, T) where C includes B04 (Red) and B08 (NIR)
            
        Returns:
            NDVI array (N, H, W, T)
        """
        # Band indices: B02=0, B03=1, B04=2, B05=3, B06=4, B07=5, B08=6, B8A=7, B11=8, B12=9
        red = patches[:, :, :, 2, :]  # B04
        nir = patches[:, :, :, 6, :]  # B08
        
        ndvi = self.safe_divide(nir - red, nir + red)
        
        # Validate
        assert ndvi.shape == (patches.shape[0], patches.shape[1], patches.shape[2], patches.shape[4])
        assert not np.any(np.isnan(ndvi)), "NDVI contains NaN values"
        assert not np.any(np.isinf(ndvi)), "NDVI contains Inf values"
        
        print(f"[OK] Computed NDVI: shape {ndvi.shape}, range [{ndvi.min():.3f}, {ndvi.max():.3f}]")
        return ndvi
    
    def compute_ndre(self, patches: np.ndarray) -> np.ndarray:
        """
        Compute NDRE = (NIR - RedEdge) / (NIR + RedEdge).
        
        Args:
            patches: (N, H, W, C, T)
            
        Returns:
            NDRE array (N, H, W, T)
        """
        red_edge = patches[:, :, :, 3, :]  # B05
        nir = patches[:, :, :, 6, :]  # B08
        
        ndre = self.safe_divide(nir - red_edge, nir + red_edge)
        
        # Validate
        assert ndre.shape == (patches.shape[0], patches.shape[1], patches.shape[2], patches.shape[4])
        assert not np.any(np.isnan(ndre)), "NDRE contains NaN values"
        assert not np.any(np.isinf(ndre)), "NDRE contains Inf values"
        
        print(f"[OK] Computed NDRE: shape {ndre.shape}, range [{ndre.min():.3f}, {ndre.max():.3f}]")
        return ndre
    
    def compute_gndvi(self, patches: np.ndarray) -> np.ndarray:
        """
        Compute GNDVI = (NIR - Green) / (NIR + Green).
        
        Args:
            patches: (N, H, W, C, T)
            
        Returns:
            GNDVI array (N, H, W, T)
        """
        green = patches[:, :, :, 1, :]  # B03
        nir = patches[:, :, :, 6, :]  # B08
        
        gndvi = self.safe_divide(nir - green, nir + green)
        
        # Validate
        assert gndvi.shape == (patches.shape[0], patches.shape[1], patches.shape[2], patches.shape[4])
        assert not np.any(np.isnan(gndvi)), "GNDVI contains NaN values"
        assert not np.any(np.isinf(gndvi)), "GNDVI contains Inf values"
        
        print(f"[OK] Computed GNDVI: shape {gndvi.shape}, range [{gndvi.min():.3f}, {gndvi.max():.3f}]")
        return gndvi
    
    def compute_temporal_derivative(self, index: np.ndarray) -> np.ndarray:
        """
        Compute temporal derivative (rate of change).
        
        Args:
            index: (N, H, W, T) index values
            
        Returns:
            Derivative array (N, H, W, T-1)
        """
        derivative = np.diff(index, axis=3)
        
        # Validate
        assert derivative.shape == (index.shape[0], index.shape[1], index.shape[2], index.shape[3] - 1)
        
        print(f"[OK] Computed temporal derivative: shape {derivative.shape}")
        return derivative
    
    def compute_all_features(self, patches: np.ndarray) -> Dict[str, np.ndarray]:
        """
        Compute all features from patches.
        
        Args:
            patches: (N, H, W, C, T) patch cube
            
        Returns:
            Dictionary of computed features
        """
        print("Computing spectral indices...")
        
        # Compute indices
        ndvi = self.compute_ndvi(patches)
        ndre = self.compute_ndre(patches)
        gndvi = self.compute_gndvi(patches)
        
        # Compute temporal derivatives
        ndvi_deriv = self.compute_temporal_derivative(ndvi)
        ndre_deriv = self.compute_temporal_derivative(ndre)
        
        features = {
            'ndvi': ndvi,
            'ndre': ndre,
            'gndvi': gndvi,
            'ndvi_derivative': ndvi_deriv,
            'ndre_derivative': ndre_deriv
        }
        
        print(f"\n[OK] Computed {len(features)} feature types")
        return features


if __name__ == "__main__":
    # Example usage
    patches = np.random.rand(10, 32, 32, 10, 5)  # 10 patches, 32x32, 10 bands, 5 timesteps
    
    engineer = FeatureEngineer()
    features = engineer.compute_all_features(patches)
    
    print("\nFeature shapes:")
    for name, feat in features.items():
        print(f"  {name}: {feat.shape}")
