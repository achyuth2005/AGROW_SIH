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
            farmer_context=request.farmer_context
        )
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=7860)
