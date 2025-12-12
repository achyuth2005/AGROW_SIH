"""
Prediction Pipeline
Orchestrates satellite data fetching and time series prediction.
"""

import os
import pandas as pd
from satellite_pipeline import SatelliteFetcher
from auto_tuning_predictor import AutoTimeSeriesPredictor

class PredictionOrchestrator:
    """
    Orchestrates the entire pipeline:
    1. Fetch Satellite Data (SAR & Sentinel-2)
    2. Generate Predictions for ALL bands using AutoNHITS
    """
    
    def __init__(self, polygon_coords):
        """
        Initialize the orchestrator.
        
        Args:
            polygon_coords (list): List of (lon, lat) tuples defining the polygon.
        """
        self.polygon_coords = polygon_coords
        self.sar_csv = 'sar_data.csv'
        self.sentinel2_csv = 'sentinel2_data.csv'
        
        self.sar_pred_csv = 'sar_predictions.csv'
        self.sentinel2_pred_csv = 'sentinel2_predictions.csv'

    def run(self):
        """Run the full pipeline."""
        print("="*60)
        print("STARTING PREDICTION PIPELINE")
        print("="*60)
        
        # 1. Fetch Satellite Data
        print("\n[1/2] Fetching Satellite Data...")
        fetcher = SatelliteFetcher(self.polygon_coords)
        fetcher.run_all()
        # print("Skipping fetch for verification (using existing CSVs)...")
        
        # 2. Generate Predictions
        print("\n[2/2] Generating Predictions...")
        predictor = AutoTimeSeriesPredictor()
        
        # --- SAR Prediction ---
        print("\n" + "-"*30)
        print("Predicting SAR Data (All Bands)")
        print("-"*30)
        self._predict_all_bands(
            predictor, 
            input_csv=self.sar_csv, 
            output_csv=self.sar_pred_csv
        )

        # --- Sentinel-2 Prediction ---
        print("\n" + "-"*30)
        print("Predicting Sentinel-2 Data (All Bands)")
        print("-"*30)
        self._predict_all_bands(
            predictor, 
            input_csv=self.sentinel2_csv, 
            output_csv=self.sentinel2_pred_csv
        )
            
        print("\n" + "="*60)
        print("PIPELINE COMPLETE")
        print(f"SAR Predictions: {self.sar_pred_csv}")
        print(f"Sentinel-2 Predictions: {self.sentinel2_pred_csv}")
        print("="*60)

    def _predict_all_bands(self, predictor, input_csv, output_csv):
        """
        Helper to predict all numerical columns in a CSV.
        """
        if not os.path.exists(input_csv):
            print(f"❌ Input file not found: {input_csv}")
            return

        df = pd.read_csv(input_csv)
        if 'ds' not in df.columns:
            print(f"❌ 'ds' column missing in {input_csv}")
            return
            
        # Identify target columns (all except 'ds')
        target_cols = [c for c in df.columns if c != 'ds']
        print(f"Found {len(target_cols)} targets: {target_cols}")
        
        all_preds = []
        
        for col in target_cols:
            print(f"\n>> Predicting {col}...")
            try:
                # We use a temporary output file for individual band predictions
                temp_out = f"temp_pred_{col}.csv"
                
                pred_df = predictor.tune_and_predict(
                    csv_path=input_csv,
                    field_coords=self.polygon_coords,
                    target_col=col,
                    output_file=temp_out,
                    num_samples=5 
                )
                
                # Rename predicted column to the band name
                pred_df = pred_df.rename(columns={'predicted_y': col})
                
                if not all_preds:
                    all_preds.append(pred_df)
                else:
                    # Merge on 'ds'
                    all_preds.append(pred_df[['ds', col]])
                
                # Clean up temp file
                if os.path.exists(temp_out):
                    os.remove(temp_out)
                    
            except Exception as e:
                print(f"❌ Failed to predict {col}: {e}")
        
        # Merge all predictions
        if all_preds:
            final_df = all_preds[0]
            for i in range(1, len(all_preds)):
                final_df = final_df.merge(all_preds[i], on='ds', how='outer')
            
            final_df.to_csv(output_csv, index=False)
            print(f"✓ Saved combined predictions to {output_csv}")
        else:
            print("⚠ No predictions generated.")

if __name__ == "__main__":
    # Example Usage
    POLYGON = [
        (75.829, 30.229),
        (75.831, 30.229),
        (75.831, 30.231),
        (75.829, 30.231),
        (75.829, 30.229)
    ]
    
    pipeline = PredictionOrchestrator(POLYGON)
    pipeline.run()
