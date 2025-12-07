from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import uvicorn
import os
from .satellite_pipeline import fetch_satellite_rgb_for_polygon, rgb_to_base64

app = FastAPI()

# Request model
class PolygonRequest(BaseModel):
    polygon: List[List[float]]
    days_back: Optional[int] = 30

# Credentials (should be env vars in production)
CLIENT_ID = os.environ.get("SENTINEL_CLIENT_ID", "sh-709c1173-fc33-4a0e-90e4-b84161ed5b9d")
CLIENT_SECRET = os.environ.get("SENTINEL_CLIENT_SECRET", "IdopxGFFr3NKFJ4Y2ywJRVfmM5eBB9b4")

@app.get("/")
def read_root():
    return {"status": "running", "service": "Agrow Satellite API"}

@app.post("/api/satellite")
def get_satellite_image(request: PolygonRequest):
    print(f"Received request for polygon: {request.polygon}")
    
    result = fetch_satellite_rgb_for_polygon(
        polygon_coords=request.polygon,
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
        days_back=request.days_back
    )
    
    if result['success']:
        return {
            'success': True,
            'image': rgb_to_base64(result['rgb_image']),
            'timestamp': result['timestamp'],
            'cloud_cover': result['cloud_cover'],
            'bbox': result['bbox'],
            'dimensions': result['dimensions']
        }
    else:
        raise HTTPException(status_code=400, detail=result['error'])

if __name__ == "__main__":
    # Run with: uvicorn lib.models.fastapi_server:app --reload
    uvicorn.run(app, host="0.0.0.0", port=5001)
