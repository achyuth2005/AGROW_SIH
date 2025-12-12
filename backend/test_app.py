from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Optional, Dict, Any

app = FastAPI(title="Agroww SAR Analysis API - Test Mode")

class AnalysisRequest(BaseModel):
    coordinates: List[float]
    date: str
    crop_type: str
    farmer_context: Optional[Dict[str, Any]] = None

@app.get("/")
def read_root():
    return {"message": "Test backend is running - SAR pipeline disabled"}

@app.post("/analyze")
async def analyze_field(request: AnalysisRequest):
    """Test endpoint that returns mock data"""
    print(f"Received request: {request.crop_type} on {request.date}")
    
    # Return mock success response
    return {
        "date": request.date,
        "stressed_patches": [
            {"lat": 30.9070, "lon": 75.8360, "status": "High Stress"},
            {"lat": 30.9075, "lon": 75.8365, "status": "High Stress"}
        ],
        "health_summary": {
            "greenness_status": "Test mode: Mock greenness data",
            "greenness_level": "moderate",
            "nitrogen_status": "Test mode: Mock nitrogen data",
            "nitrogen_level": "moderate",
            "biomass_status": "Test mode: Mock biomass data",
            "biomass_level": "moderate",
            "heat_stress_status": "Test mode: Mock heat stress data",
            "heat_stress_level": "low",
            "overall_crop_health": "Test backend running successfully. Real SAR analysis requires GDAL installation.",
            "crop_phenology_state": "Testing"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)
