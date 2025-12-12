"""
============================================================================
FILE: app.py
============================================================================
PURPOSE: FastAPI web server that exposes the SAR analysis as an HTTP API.
         This is the entry point for the backend - the Flutter app 
         sends requests here to analyze farm fields.

WHAT THIS FILE DOES:
    1. Creates a web server using FastAPI (Python web framework)
    2. Defines an HTTP endpoint: POST /analyze
    3. Receives field coordinates and crop info from the mobile app
    4. Calls the SAR analysis pipeline (SAR_prediction.py)
    5. Returns analysis results as JSON

WHY FastAPI?
    - Fast: Built on modern async Python
    - Auto-documentation: Creates API docs at /docs
    - Type-safe: Validates request data automatically
    - Simple: Less boilerplate than Flask/Django

API ENDPOINTS:
    GET  /         - Health check (returns "API is running")
    POST /analyze  - Main analysis endpoint

DEPENDENCIES:
    - fastapi: Web framework
    - pydantic: Data validation
    - uvicorn: ASGI server to run the app
============================================================================
"""

# Python standard library
import os    # For file/environment operations
import json  # For JSON encoding/decoding

# FastAPI framework for building the web API
from fastapi import FastAPI, HTTPException

# Pydantic for request/response validation
# BaseModel lets us define strongly-typed request schemas
from pydantic import BaseModel

# Type hints for clearer code
from typing import List, Optional, Dict, Any

# Import our SAR analysis pipeline
# This is the core logic that fetches satellite data and runs analysis
from SAR_prediction import run_sar_prediction_pipeline

# =============================================================================
# CREATE THE FastAPI APPLICATION
# =============================================================================
# FastAPI() creates our web application instance.
# The 'title' appears in the auto-generated API documentation.
app = FastAPI(title="Agroww SAR Analysis API")


# =============================================================================
# REQUEST SCHEMA
# =============================================================================
# Pydantic BaseModel defines the expected structure of incoming requests.
# If a request doesn't match this schema, FastAPI returns a 422 error.

class AnalysisRequest(BaseModel):
    """
    Schema for field analysis requests from the mobile app.
    
    FIELDS:
        coordinates: Bounding box of the field [min_lon, min_lat, max_lon, max_lat]
                     Example: [75.8350, 30.9060, 75.8370, 30.9090]
        
        date: Target analysis date in "YYYY-MM-DD" format
              The API will find the nearest available satellite image.
        
        crop_type: What crop is planted - affects analysis interpretation
                   Examples: "wheat", "rice", "maize", "cotton"
        
        farmer_context: Optional additional context for personalized insights
                        Includes: role, farming methods, irrigation type, etc.
    """
    coordinates: List[float]  # [min_lon, min_lat, max_lon, max_lat]
    date: str                 # "YYYY-MM-DD" format
    crop_type: str            # Name of the crop being grown
    farmer_context: Optional[Dict[str, Any]] = None  # Optional extra context


# =============================================================================
# API ENDPOINTS
# =============================================================================

@app.get("/")
def read_root():
    """
    ENDPOINT: GET /
    PURPOSE: Health check endpoint to verify the API is running.
    
    USAGE:
        curl http://localhost:7860/
    
    RETURNS:
        {"message": "Agroww SAR Analysis API is running"}
    """
    return {"message": "Agroww SAR Analysis API is running"}


@app.post("/analyze")
async def analyze_field(request: AnalysisRequest):
    """
    ENDPOINT: POST /analyze
    PURPOSE: Main endpoint to analyze a farm field using SAR satellite data.
    
    REQUEST BODY (JSON):
        {
            "coordinates": [75.8350, 30.9060, 75.8370, 30.9090],
            "date": "2024-01-15",
            "crop_type": "wheat",
            "farmer_context": {
                "role": "farmer",
                "irrigation_method": "rainfed"
            }
        }
    
    RESPONSE (JSON):
        {
            "status": "success",
            "crop_health": "Good",
            "summary": "Field shows healthy vegetation...",
            "recommendations": ["Consider..."],
            "weather_data": [...],
            "health_summary": {...}
        }
    
    ERROR RESPONSES:
        400: Invalid coordinates (must have exactly 4 values)
        500: Server error during analysis
    
    PROCESSING STEPS:
        1. Validate coordinates format
        2. Apply default context if not provided
        3. Call SAR analysis pipeline
        4. Return results or error
    """
    try:
        # ---------------------------------------------------------------------
        # STEP 1: Validate coordinates
        # ---------------------------------------------------------------------
        # We need exactly 4 values for a bounding box
        if len(request.coordinates) != 4:
            raise HTTPException(
                status_code=400, 
                detail="Coordinates must be [min_lon, min_lat, max_lon, max_lat]"
            )
        
        # ---------------------------------------------------------------------
        # STEP 2: Apply default context if not provided
        # ---------------------------------------------------------------------
        # The farmer_context affects how the AI generates recommendations.
        # We use sensible defaults if the app doesn't provide context.
        context = request.farmer_context or {
            "role": "farmer",
            "tech_familiarity": "medium",
            "farming_methods": "traditional",
            "years_farming": 10,
            "irrigation_method": "rainfed",
            "farm_work_style": "individual",
            "farming_goal": "yield optimization",
            "additional_notes": "Standard crop cycle"
        }

        print(f"Received analysis request for {request.crop_type} on {request.date}")
        
        # ---------------------------------------------------------------------
        # STEP 3: Run the analysis pipeline
        # ---------------------------------------------------------------------
        # This calls SAR_prediction.py which:
        # - Fetches SAR data from Sentinel Hub
        # - Processes into patches
        # - Runs anomaly detection
        # - Gets LLM-generated insights
        result = run_sar_prediction_pipeline(
            request.coordinates,  # Field bounding box
            request.date,         # Target date
            request.crop_type,    # Crop being analyzed
            context               # Farmer context for AI
        )
        
        # ---------------------------------------------------------------------
        # STEP 4: Check for errors and return
        # ---------------------------------------------------------------------
        if "error" in result:
            # Pipeline returned an error - send as HTTP 500
            raise HTTPException(status_code=500, detail=result["error"])

        return result

    except Exception as e:
        # Log the error for debugging
        print(f"Error processing request: {str(e)}")
        # Return as HTTP 500 error
        raise HTTPException(status_code=500, detail=str(e))


# =============================================================================
# RUN THE SERVER
# =============================================================================
# This block only runs when executing `python app.py` directly.
# Hugging Face Spaces use `uvicorn app:app` instead.

if __name__ == "__main__":
    import uvicorn
    # Run the server on all interfaces (0.0.0.0) port 7860
    # Port 7860 is the default for Hugging Face Spaces
    uvicorn.run(app, host="0.0.0.0", port=7860)
