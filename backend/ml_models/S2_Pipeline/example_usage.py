"""
Example usage script for Crop Stress Detection Pipeline
"""

from crop_stress_pipeline import CropStressPipeline
import json

def main():
    """
    Example: Analyze a wheat field in Punjab, India
    """
    
    # Initialize pipeline
    print("Initializing pipeline...")
    pipeline = CropStressPipeline()
    
    # Define field parameters
    field_params = {
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
        'output_path': 'example_results.json'
    }
    
    print("\nField Information:")
    print(f"  Location: ({field_params['center_lat']}, {field_params['center_lon']})")
    print(f"  Crop: {field_params['crop_type']}")
    print(f"  Date: {field_params['analysis_date']}")
    print(f"  Size: {field_params['field_size_hectares']} hectares")
    
    # Run pipeline
    print("\nRunning pipeline...")
    try:
        results = pipeline.run(**field_params)
        
        print("\n" + "="*60)
        print("PIPELINE COMPLETED SUCCESSFULLY")
        print("="*60)
        
        # Display key results
        print("\nKey Results:")
        print(f"  Overall Health: {results['llm_analysis']['overall_health']['status'].upper()}")
        print(f"  Soil Moisture: {results['llm_analysis']['soil_moisture']['level'].upper()}")
        print(f"  Vegetation Stress: {results['llm_analysis']['vegetation_stress']['level'].upper()}")
        
        print(f"\nFull results saved to: {field_params['output_path']}")
        
        # Pretty print a sample of the results
        print("\nSample Output (Vegetation Indices):")
        ndvi_stats = results['vegetation_indices_summary']['indices']['NDVI']
        print(f"  NDVI Latest Mean: {ndvi_stats['latest']['mean']:.4f}")
        print(f"  NDVI Change: {ndvi_stats['change']:+.4f}")
        
        return results
        
    except Exception as e:
        print(f"\nERROR: Pipeline failed - {str(e)}")
        print("Check crop_stress_pipeline.log for details")
        raise


if __name__ == "__main__":
    results = main()
