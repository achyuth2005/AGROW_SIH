"""
AGROW Sentinel-2 Crop Analysis Service
=======================================
FastAPI service for Sentinel-2 satellite data processing and crop stress detection.
Deployed on Hugging Face Spaces.

ENDPOINTS:
    POST /analyze      - Run full crop stress analysis pipeline
    GET /latest-image-date - Quick check for latest available satellite image

INPUT (AnalysisRequest):
    - center_lat/center_lon: Field location
    - crop_type: Type of crop (e.g., "Wheat", "Rice")
    - analysis_date: Target date (YYYY-MM-DD)
    - field_size_hectares: Field size
    - farmer_context: Dict with farmer profile info
    - skip_llm: Skip LLM analysis (for chatbot integration)

OUTPUT:
    - vegetation_indices_summary: NDVI, NDWI, EVI, etc.
    - stress_detection: CNN+Clustering stress zones
    - llm_analysis: AI-generated insights

DEPENDENCIES:
    - crop_stress_pipeline.py: Main analysis pipeline
    - vegetation_indices.py: Index calculations
    - stress_detection_model.py: CNN stress detection
    - llm_analysis.py: Groq LLM integration
    
DEPLOYMENT:
    Hugging Face Space: aniket2006-agrow-sentinel2
    Port: 7860
"""

import os
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Dict, Any, Optional
from crop_stress_pipeline import CropStressPipeline

app = FastAPI(title="Sentinel-2 Crop Stress Pipeline")

# Initialize pipeline
pipeline = CropStressPipeline()

class AnalysisRequest(BaseModel):
    center_lat: float
    center_lon: float
    crop_type: str
    analysis_date: str
    field_size_hectares: float
    farmer_context: Dict[str, Any]
    skip_llm: bool = False  # When True, skip LLM analysis to save API calls

@app.get("/")
def home():
    return {"status": "running", "message": "Sentinel-2 Crop Stress Pipeline API"}

@app.post("/analyze")
async def analyze_crop(request: AnalysisRequest):
    try:
        results = pipeline.run(
            center_lat=request.center_lat,
            center_lon=request.center_lon,
            crop_type=request.crop_type,
            analysis_date=request.analysis_date,
            field_size_hectares=request.field_size_hectares,
            farmer_context=request.farmer_context,
            skip_llm=request.skip_llm  # Pass skip_llm flag
        )
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# LIGHTWEIGHT ENDPOINT: Check latest available image (no analysis)
# Used for cache invalidation decisions on frontend
# ============================================================================
@app.get("/latest-image-date")
async def get_latest_image_date(lat: float, lon: float):
    """
    Quick check for latest available Sentinel-2 image.
    Does NOT run the full analysis pipeline.
    Response time: ~200-500ms
    """
    try:
        from sentinelhub import SentinelHubCatalog, BBox, CRS, DataCollection
        from datetime import datetime, timedelta, timezone
        
        # Create small bounding box around point
        bbox = BBox(
            bbox=[lon - 0.001, lat - 0.001, lon + 0.001, lat + 0.001],
            crs=CRS.WGS84
        )
        
        # Search last 30 days
        end_date = datetime.now(timezone.utc)
        start_date = end_date - timedelta(days=30)
        
        catalog = SentinelHubCatalog(config=pipeline.config)
        search = catalog.search(
            DataCollection.SENTINEL2_L2A,
            bbox=bbox,
            time=(start_date, end_date),
            filter='eo:cloud_cover < 30'
        )
        
        # Get most recent image
        latest_date = None
        for item in search:
            date_str = item['properties']['datetime'][:10]
            if latest_date is None or date_str > latest_date:
                latest_date = date_str
        
        return {
            "latest_date": latest_date,
            "checked_at": datetime.now(timezone.utc).isoformat(),
            "status": "ok" if latest_date else "no_images"
        }
    except Exception as e:
        return {
            "latest_date": None,
            "error": str(e),
            "status": "error"
        }


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=7860)
