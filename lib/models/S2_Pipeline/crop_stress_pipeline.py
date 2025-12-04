"""
Crop Stress Detection Pipeline - Production Version
====================================================

Complete pipeline for crop monitoring using Sentinel-2 satellite data.
Includes vegetation indices calculation, deep learning stress detection,
and LLM-powered analysis.

Author: SIH ML Team
Version: 1.0
"""

import os
import sys
import json
import logging
import numpy as np
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv
from dateutil import parser

from sentinelhub import (
    SHConfig, BBox, CRS, DataCollection, SentinelHubRequest,
    MimeType, bbox_to_dimensions, SentinelHubCatalog
)

# Import custom modules
from vegetation_indices import calculate_indices_temporal, get_summary_report, get_temporal_statistics
from stress_detection_preprocessing import preprocess_for_model
from stress_detection_model import StressDetectionModel, prepare_llm_context, get_stress_category
from llm_analysis import analyze_with_llm

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('crop_stress_pipeline.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class CropStressPipeline:
    """
    Production pipeline for crop stress detection and analysis.
    """
    
    def __init__(self, config_path: str = None):
        """
        Initialize pipeline with configuration.
        
        Args:
            config_path: Path to .env file with credentials
        """
        # Load environment variables
        if config_path:
            load_dotenv(config_path)
        else:
            load_dotenv()
        
        # Configure Sentinel Hub
        self.config = SHConfig()
        self.config.sh_client_id = os.environ.get('SH_CLIENT_ID')
        self.config.sh_client_secret = os.environ.get('SH_CLIENT_SECRET')
        self.config.sh_base_url = 'https://sh.dataspace.copernicus.eu'
        self.config.sh_token_url = 'https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token'
        
        if not self.config.sh_client_id or not self.config.sh_client_secret:
            raise ValueError('Sentinel Hub credentials not found in environment variables')
        
        # Define custom CDSE data collection
        self.SENTINEL2_L2A_CDSE = DataCollection.define(
            "SENTINEL2_L2A_CDSE",
            api_id="sentinel-2-l2a",
            service_url="https://sh.dataspace.copernicus.eu",
            collection_type="Sentinel-2",
            is_timeless=False
        )
        
        logger.info("Pipeline initialized successfully")
        logger.info(f"Sentinel Hub: {self.config.sh_base_url}")
        logger.info(f"Client ID: {self.config.sh_client_id[:20]}...")
    
    def create_evalscript(self) -> str:
        """Create evalscript for Sentinel-2 data retrieval."""
        return """
//VERSION=3
function setup() {
    return {
        input: [{
            bands: ["B01", "B02", "B03", "B04", "B05", "B06", "B07", "B08", "B8A", "B09", "B11", "B12", "SCL"],
            units: "DN"
        }],
        output: {
            bands: 13,
            sampleType: "FLOAT32"
        }
    };
}

function evaluatePixel(sample) {
    return [
        sample.B01 / 10000,
        sample.B02 / 10000,
        sample.B03 / 10000,
        sample.B04 / 10000,
        sample.B05 / 10000,
        sample.B06 / 10000,
        sample.B07 / 10000,
        sample.B08 / 10000,
        sample.B8A / 10000,
        sample.B09 / 10000,
        sample.B11 / 10000,
        sample.B12 / 10000,
        sample.SCL
    ];
}
"""
    
    def fetch_satellite_data(self, center_lat: float, center_lon: float,
                            analysis_date: str, num_images: int = 10,
                            resolution: int = 10) -> tuple:
        """
        Fetch Sentinel-2 satellite data for the specified location and date range.
        
        Args:
            center_lat: Latitude of field center
            center_lon: Longitude of field center
            analysis_date: Target analysis date (YYYY-MM-DD)
            num_images: Number of temporal images to fetch
            resolution: Spatial resolution in meters
            
        Returns:
            Tuple of (all_images, selected_dates, bbox, size)
        """
        logger.info("=" * 60)
        logger.info("FETCHING SATELLITE DATA")
        logger.info("=" * 60)
        
        # Create bounding box
        coords_wgs84 = BBox(
            bbox=[center_lon - 0.001, center_lat - 0.001,
                  center_lon + 0.001, center_lat + 0.001],
            crs=CRS.WGS84
        )
        
        size = bbox_to_dimensions(coords_wgs84, resolution=resolution)
        logger.info(f"AOI size: {size[0]}x{size[1]} pixels at {resolution}m resolution")
        
        # Search for cloud-free images
        target_date = datetime.strptime(analysis_date, '%Y-%m-%d').replace(tzinfo=timezone.utc)
        search_start = target_date - timedelta(days=90)
        search_end = target_date + timedelta(days=30)
        
        logger.info(f"Searching for {num_images} cloud-free images...")
        logger.info(f"Date range: {search_start.date()} to {search_end.date()}")
        
        catalog = SentinelHubCatalog(config=self.config)
        search_iterator = catalog.search(
            DataCollection.SENTINEL2_L2A,
            bbox=coords_wgs84,
            time=(search_start, search_end),
            filter='eo:cloud_cover < 20'
        )
        
        all_timestamps = []
        for item in search_iterator:
            timestamp = item['properties']['datetime']
            cloud_cover = item['properties'].get('eo:cloud_cover', 0)
            all_timestamps.append((timestamp, cloud_cover))
        
        # Sort by proximity to target date
        all_timestamps.sort(key=lambda x: abs((parser.isoparse(x[0]) - target_date).days))
        selected_dates = [t[0] for t in all_timestamps[:num_images]]
        
        logger.info(f"Found {len(selected_dates)} suitable images:")
        for i, (date, cloud) in enumerate(all_timestamps[:num_images]):
            logger.info(f"  [{i+1}] {date[:10]} (Cloud: {cloud:.1f}%)")
        
        # Fetch data for all timestamps
        logger.info("Fetching satellite data...")
        all_images = []
        evalscript = self.create_evalscript()
        
        for i, date in enumerate(selected_dates):
            request = SentinelHubRequest(
                evalscript=evalscript,
                input_data=[SentinelHubRequest.input_data(
                    data_collection=self.SENTINEL2_L2A_CDSE,
                    time_interval=(date, date)
                )],
                responses=[SentinelHubRequest.output_response('default', MimeType.TIFF)],
                bbox=coords_wgs84,
                size=size,
                config=self.config
            )
            
            data = request.get_data()[0]
            valid_pct = 100 * np.sum(data[:,:,12] > 0) / (data.shape[0] * data.shape[1])
            all_images.append(data)
            logger.info(f"  [{i+1}/{len(selected_dates)}] {date[:10]} - {valid_pct:.1f}% valid pixels")
        
        all_images = np.array(all_images)
        logger.info(f"Data shape: {all_images.shape} (time, height, width, bands)")
        logger.info("=" * 60)
        
        return all_images, selected_dates, coords_wgs84, size
    
    def calculate_vegetation_indices(self, all_images: np.ndarray,
                                     selected_dates: list) -> tuple:
        """
        Calculate all 13 vegetation indices and temporal statistics.
        
        Args:
            all_images: Satellite imagery array
            selected_dates: List of image dates
            
        Returns:
            Tuple of (indices_data, summary_report, temporal_stats)
        """
        logger.info("=" * 60)
        logger.info("CALCULATING VEGETATION INDICES")
        logger.info("=" * 60)
        
        indices_data = calculate_indices_temporal(all_images)
        logger.info(f"Calculated {len(indices_data)} indices:")
        for index_name in indices_data.keys():
            logger.info(f"  - {index_name}")
        
        summary_report = get_summary_report(indices_data, selected_dates)
        temporal_stats = get_temporal_statistics(indices_data)
        
        logger.info("\nSummary Statistics:")
        logger.info(f"Analysis Period: {selected_dates[0][:10]} to {selected_dates[-1][:10]}")
        logger.info(f"Number of Images: {summary_report['num_images']}")
        
        for index_name, stats in summary_report['indices'].items():
            logger.info(f"\n{index_name}:")
            logger.info(f"  Latest Mean: {stats['latest']['mean']:.4f}")
            logger.info(f"  Max in Field: {stats['max_in_field']:.4f}")
            logger.info(f"  Min in Field: {stats['min_in_field']:.4f}")
            logger.info(f"  Temporal Change: {stats['change']:+.4f}")
        
        logger.info("=" * 60)
        return indices_data, summary_report, temporal_stats
    
    def run_stress_detection(self, all_images: np.ndarray,
                            selected_dates: list,
                            n_clusters: int = 3) -> tuple:
        """
        Run deep learning stress detection pipeline.
        
        Args:
            all_images: Satellite imagery array
            selected_dates: List of image dates
            n_clusters: Number of stress clusters (default: 3)
            
        Returns:
            Tuple of (stress_results, stress_llm_context, patches, patch_coords, metadata)
        """
        logger.info("=" * 60)
        logger.info("STRESS DETECTION PIPELINE")
        logger.info("=" * 60)
        
        # Preprocess data
        logger.info("Preprocessing data for stress detection...")
        patches, patch_coords, metadata = preprocess_for_model(
            all_images,
            patch_size=8,
            stride=4
        )
        
        logger.info(f"Original shape: {metadata['original_shape']}")
        logger.info(f"Selected bands: {metadata['selected_bands']}")
        logger.info(f"Number of patches: {metadata['num_patches']}")
        logger.info(f"Patch shape: {patches.shape}")
        
        # Build and run stress detection model
        logger.info("Building stress detection model...")
        stress_model = StressDetectionModel(
            patch_size=metadata['patch_size'],
            num_bands=metadata['num_bands'],
            num_timestamps=len(selected_dates),
            spatial_embedding_dim=128,
            temporal_embedding_dim=128
        )
        
        logger.info(f"Running stress detection with {n_clusters} clusters...")
        stress_results = stress_model.predict(patches, n_clusters=n_clusters, contamination=0.1)
        
        logger.info("\nStress Detection Results:")
        logger.info(f"  Spatial embeddings: {stress_results['spatial_embeddings'].shape}")
        logger.info(f"  Temporal embeddings: {stress_results['temporal_embeddings'].shape}")
        logger.info(f"  Stress scores: min={stress_results['stress_scores'].min():.3f}, "
                   f"max={stress_results['stress_scores'].max():.3f}, "
                   f"mean={stress_results['stress_scores'].mean():.3f}")
        logger.info(f"  Clusters: {n_clusters}")
        logger.info(f"  Anomalies: {np.sum(stress_results['anomaly_labels'] == -1)}")
        
        # Prepare context for LLM
        logger.info("Preparing stress detection context for LLM...")
        stress_llm_context = prepare_llm_context(
            stress_results,
            patch_coords,
            patches,
            metadata
        )
        
        # Log stress distribution
        stress_categories = [get_stress_category(score) for score in stress_results['stress_scores']]
        unique_categories, counts = np.unique(stress_categories, return_counts=True)
        
        logger.info("\nStress Category Distribution:")
        for category, count in zip(unique_categories, counts):
            pct = 100 * count / len(stress_categories)
            logger.info(f"  {category}: {count} patches ({pct:.1f}%)")
        
        logger.info(f"\nOverall Field Stress Score: {stress_results['stress_scores'].mean():.3f}")
        logger.info(f"Field Stress Category: {get_stress_category(stress_results['stress_scores'].mean())}")
        logger.info("=" * 60)
        
        return stress_results, stress_llm_context, patches, patch_coords, metadata
    
    def run_llm_analysis(self, summary_report: dict, temporal_stats: dict,
                        stress_llm_context: dict, crop_type: str,
                        farmer_context: dict, center_lat: float,
                        center_lon: float, field_size_hectares: float) -> dict:
        """
        Run LLM analysis on vegetation indices and stress detection results.
        
        Args:
            summary_report: Vegetation indices summary
            temporal_stats: Temporal statistics
            stress_llm_context: Stress detection context
            crop_type: Type of crop
            farmer_context: Farmer profile information
            center_lat: Field latitude
            center_lon: Field longitude
            field_size_hectares: Field size in hectares
            
        Returns:
            LLM analysis results dictionary
        """
        logger.info("=" * 60)
        logger.info("LLM ANALYSIS")
        logger.info("=" * 60)
        
        logger.info("Analyzing with LLM (Gemini)...")
        llm_analysis = analyze_with_llm(
            summary_report=summary_report,
            crop_type=crop_type,
            farmer_context=farmer_context,
            center_lat=center_lat,
            center_lon=center_lon,
            field_size_hectares=field_size_hectares,
            temporal_stats=temporal_stats,
            stress_context=stress_llm_context
        )
        
        logger.info("\nLLM Analysis Results:")
        logger.info(f"  Soil Moisture: {llm_analysis['soil_moisture']['level']}")
        logger.info(f"  Soil Salinity: {llm_analysis['soil_salinity']['level']}")
        logger.info(f"  Organic Matter: {llm_analysis['organic_matter']['level']}")
        logger.info(f"  Soil Fertility: {llm_analysis['soil_fertility']['level']}")
        logger.info(f"  Vegetation Stress: {llm_analysis['vegetation_stress']['level']}")
        logger.info(f"  Photosynthetic Stress: {llm_analysis['photosynthetic_stress']['level']}")
        logger.info(f"  Overall Health: {llm_analysis['overall_health']['status']}")
        logger.info("=" * 60)
        
        return llm_analysis
    
    def run(self, center_lat: float, center_lon: float, crop_type: str,
            analysis_date: str, field_size_hectares: float,
            farmer_context: dict, output_path: str = None) -> dict:
        """
        Run complete crop stress detection pipeline.
        
        Args:
            center_lat: Field center latitude
            center_lon: Field center longitude
            crop_type: Type of crop being analyzed
            analysis_date: Target analysis date (YYYY-MM-DD)
            field_size_hectares: Field size in hectares
            farmer_context: Dictionary with farmer profile information
            output_path: Path to save results JSON (optional)
            
        Returns:
            Complete analysis results dictionary
        """
        logger.info("\n" + "=" * 60)
        logger.info("CROP STRESS DETECTION PIPELINE - STARTING")
        logger.info("=" * 60)
        logger.info(f"Crop Type: {crop_type}")
        logger.info(f"Analysis Date: {analysis_date}")
        logger.info(f"Location: ({center_lat:.4f}, {center_lon:.4f})")
        logger.info(f"Field Size: {field_size_hectares} hectares")
        logger.info("=" * 60)
        
        try:
            # Step 1: Fetch satellite data
            all_images, selected_dates, bbox, size = self.fetch_satellite_data(
                center_lat, center_lon, analysis_date
            )
            
            # Step 2: Calculate vegetation indices
            indices_data, summary_report, temporal_stats = self.calculate_vegetation_indices(
                all_images, selected_dates
            )
            
            # Step 3: Run stress detection
            stress_results, stress_llm_context, patches, patch_coords, metadata = self.run_stress_detection(
                all_images, selected_dates, n_clusters=3
            )
            
            # Step 4: Run LLM analysis
            llm_analysis = self.run_llm_analysis(
                summary_report, temporal_stats, stress_llm_context,
                crop_type, farmer_context, center_lat, center_lon,
                field_size_hectares
            )
            
            # Compile results
            results = {
                'metadata': {
                    'crop_type': crop_type,
                    'analysis_date': analysis_date,
                    'location': {'lat': center_lat, 'lon': center_lon},
                    'field_size_hectares': field_size_hectares,
                    'farmer_context': farmer_context,
                    'num_images': len(selected_dates),
                    'date_range': [selected_dates[0][:10], selected_dates[-1][:10]]
                },
                'vegetation_indices_summary': summary_report,
                'stress_detection': stress_llm_context,
                'llm_analysis': llm_analysis
            }
            
            # Save results
            if output_path:
                with open(output_path, 'w') as f:
                    json.dump(results, f, indent=2)
                logger.info(f"\nResults saved to: {output_path}")
            
            logger.info("\n" + "=" * 60)
            logger.info("PIPELINE COMPLETED SUCCESSFULLY")
            logger.info("=" * 60)
            
            return results
            
        except Exception as e:
            logger.error(f"Pipeline failed with error: {str(e)}", exc_info=True)
            raise


if __name__ == "__main__":
    # Example usage
    pipeline = CropStressPipeline()
    
    # Define field parameters
    params = {
        'center_lat': 30.2300,
        'center_lon': 75.8300,
        'crop_type': 'Wheat',
        'analysis_date': '2024-01-15',
        'field_size_hectares': 0.04,
        'farmer_context': {
            'role': 'Owner-Operator',
            'years_farming': 15,
            'irrigation_method': 'Drip Irrigation',
            'farming_goal': 'Maximize yield while maintaining soil health'
        },
        'output_path': 'crop_analysis_results.json'
    }
    
    # Run pipeline
    results = pipeline.run(**params)
