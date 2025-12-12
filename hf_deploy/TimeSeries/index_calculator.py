"""
Vegetation Index Calculator
Computes all vegetation indices from satellite bands.
"""

import pandas as pd
import numpy as np
from typing import Dict, List


class IndexCalculator:
    """
    Computes vegetation and soil indices from satellite band data.
    
    Sentinel-2 Bands used:
    - B02: Blue (490nm)
    - B03: Green (560nm)
    - B04: Red (665nm)
    - B05: Red Edge 1 (705nm)
    - B06: Red Edge 2 (740nm)
    - B07: Red Edge 3 (783nm)
    - B08: NIR (842nm)
    - B8A: Narrow NIR (865nm)
    - B11: SWIR 1 (1610nm)
    - B12: SWIR 2 (2190nm)
    """
    
    @staticmethod
    def safe_divide(a, b, fill_value=0):
        """Safe division avoiding divide by zero."""
        with np.errstate(divide='ignore', invalid='ignore'):
            result = np.where(b != 0, a / b, fill_value)
            result = np.where(np.isfinite(result), result, fill_value)
        return result
    
    @classmethod
    def compute_ndvi(cls, df: pd.DataFrame) -> pd.Series:
        """Normalized Difference Vegetation Index"""
        if 'B08' not in df or 'B04' not in df:
            return pd.Series([None] * len(df))
        nir, red = df['B08'], df['B04']
        return cls.safe_divide(nir - red, nir + red)
    
    @classmethod
    def compute_ndwi(cls, df: pd.DataFrame) -> pd.Series:
        """Normalized Difference Water Index"""
        if 'B03' not in df or 'B08' not in df:
            return pd.Series([None] * len(df))
        green, nir = df['B03'], df['B08']
        return cls.safe_divide(green - nir, green + nir)
    
    @classmethod
    def compute_evi(cls, df: pd.DataFrame) -> pd.Series:
        """Enhanced Vegetation Index"""
        if not all(b in df for b in ['B08', 'B04', 'B02']):
            return pd.Series([None] * len(df))
        nir, red, blue = df['B08'], df['B04'], df['B02']
        denom = nir + 6 * red - 7.5 * blue + 1
        return 2.5 * cls.safe_divide(nir - red, denom)
    
    @classmethod
    def compute_ndre(cls, df: pd.DataFrame) -> pd.Series:
        """Normalized Difference Red Edge Index (Nitrogen)"""
        if 'B08' not in df or 'B05' not in df:
            return pd.Series([None] * len(df))
        nir, re1 = df['B08'], df['B05']
        return cls.safe_divide(nir - re1, nir + re1)
    
    @classmethod
    def compute_savi(cls, df: pd.DataFrame, L: float = 0.5) -> pd.Series:
        """Soil Adjusted Vegetation Index"""
        if 'B08' not in df or 'B04' not in df:
            return pd.Series([None] * len(df))
        nir, red = df['B08'], df['B04']
        return (1 + L) * cls.safe_divide(nir - red, nir + red + L)
    
    @classmethod
    def compute_gndvi(cls, df: pd.DataFrame) -> pd.Series:
        """Green NDVI"""
        if 'B08' not in df or 'B03' not in df:
            return pd.Series([None] * len(df))
        nir, green = df['B08'], df['B03']
        return cls.safe_divide(nir - green, nir + green)
    
    @classmethod
    def compute_moisture_index(cls, df: pd.DataFrame) -> pd.Series:
        """Moisture Stress Index using SWIR"""
        if 'B8A' not in df or 'B11' not in df:
            return pd.Series([None] * len(df))
        nir, swir = df['B8A'], df['B11']
        return cls.safe_divide(nir - swir, nir + swir)
    
    @classmethod
    def compute_chlorophyll_index(cls, df: pd.DataFrame) -> pd.Series:
        """Chlorophyll Index using Red Edge"""
        if 'B07' not in df or 'B05' not in df:
            return pd.Series([None] * len(df))
        re3, re1 = df['B07'], df['B05']
        return cls.safe_divide(re3, re1) - 1
    
    @classmethod
    def compute_sar_rvi(cls, df: pd.DataFrame) -> pd.Series:
        """Radar Vegetation Index from SAR"""
        if 'VV_mean_dB' not in df or 'VH_mean_dB' not in df:
            return pd.Series([None] * len(df))
        vv, vh = df['VV_mean_dB'], df['VH_mean_dB']
        # Convert from dB back to linear for RVI calculation
        vv_lin = 10 ** (vv / 10)
        vh_lin = 10 ** (vh / 10)
        return cls.safe_divide(4 * vh_lin, vv_lin + vh_lin)
    
    @classmethod
    def compute_all_indices(cls, sentinel2_df: pd.DataFrame, sar_df: pd.DataFrame = None) -> pd.DataFrame:
        """
        Compute all indices for given dataframes.
        
        Args:
            sentinel2_df: DataFrame with Sentinel-2 band columns (B01-B12)
            sar_df: Optional DataFrame with SAR columns (VV_mean_dB, VH_mean_dB)
            
        Returns:
            DataFrame with 'ds' column and all computed indices
        """
        results = {}
        
        # Ensure ds column exists
        if 'ds' in sentinel2_df.columns:
            results['ds'] = sentinel2_df['ds']
        
        # Optical indices
        results['NDVI'] = cls.compute_ndvi(sentinel2_df)
        results['NDWI'] = cls.compute_ndwi(sentinel2_df)
        results['EVI'] = cls.compute_evi(sentinel2_df)
        results['NDRE'] = cls.compute_ndre(sentinel2_df)
        results['SAVI'] = cls.compute_savi(sentinel2_df)
        results['GNDVI'] = cls.compute_gndvi(sentinel2_df)
        results['MSI'] = cls.compute_moisture_index(sentinel2_df)
        results['CI'] = cls.compute_chlorophyll_index(sentinel2_df)
        
        # SAR indices
        if sar_df is not None and not sar_df.empty:
            # Align by date if possible
            if 'ds' in sar_df.columns and 'ds' in results:
                sar_merged = sentinel2_df.merge(sar_df, on='ds', how='left')
                results['RVI'] = cls.compute_sar_rvi(sar_merged)
            else:
                results['RVI'] = pd.Series([None] * len(sentinel2_df))
        
        # Create DataFrame, dropping None columns
        df = pd.DataFrame({k: v for k, v in results.items() if v is not None})
        
        # Round values
        for col in df.columns:
            if col != 'ds' and df[col].dtype in ['float64', 'float32']:
                df[col] = df[col].round(4)
        
        return df
    
    @classmethod
    def compute_indices_for_predictions(cls, s2_pred_df: pd.DataFrame) -> pd.DataFrame:
        """Compute indices from Sentinel-2 predictions."""
        return cls.compute_all_indices(s2_pred_df, None)
