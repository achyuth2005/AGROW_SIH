# Developer Handover: SAR Prediction Model Integration

This document outlines the files and steps required to integrate the SAR-based crop stress prediction model into the application backend.

## 1. Core Files for Deployment

You need to deploy the following files to your backend server (e.g., Python/Flask/Django/FastAPI environment):

| File Name | Purpose |
| :--- | :--- |
| **`SAR_prediction.py`** | **Main Entry Point.** Contains the `run_sar_prediction_pipeline` function. This is what your API endpoint should call. |
| **`gemini_llm_integration.py`** | Handles communication with Google Gemini API to generate the structured health assessment JSON. |
| **`feature_engineering.py`** | Helper module for computing statistical features from SAR data. |
| **`clustering.py`** | Helper module for the unsupervised clustering algorithm (Isolation Forest/K-Means) to detect stress zones. |
| **`requirements_crop_stress.txt`** | List of Python dependencies required to run the pipeline. |
| **`.env`** | Configuration file containing API keys and secrets. **Do not commit this to version control.** |

## 2. Integration Instructions

### A. Environment Setup
1.  Install dependencies:
    ```bash
    pip install -r requirements_crop_stress.txt
    ```
2.  **Environment Variables:**
    *   A `.env` file has been created in the root directory containing the necessary credentials (`SH_CLIENT_ID`, `SH_CLIENT_SECRET`, `GEMINI_API_KEY`).
    *   The scripts are configured to automatically load these variables using `python-dotenv`.
    *   **Security Note:** Do not commit the `.env` file to version control. Ensure these variables are set securely in your production environment.

### B. Calling the Pipeline
Import the main function in your API view/controller:

```python
from SAR_prediction import run_sar_prediction_pipeline

# Example API Endpoint Logic
def analyze_field(request):
    # 1. Parse request data
    data = request.json
    coords = data.get('coordinates') # [min_lon, min_lat, max_lon, max_lat]
    date = data.get('date')          # 'YYYY-MM-DD'
    crop = data.get('crop_type')     # e.g., 'Maize', 'Rice'
    
    # 2. Construct Farmer Context (from user profile)
    farmer_context = {
        "role": "farmer",
        "tech_familiarity": "moderate",
        "farming_methods": "conventional",
        "years_farming": 10,
        "irrigation_method": "rainfed",
        "farm_work_style": "family-operated",
        "farming_goal": "maximize yield",
        "additional_notes": "Previous season had pest issues."
    }

    # 3. Run Pipeline
    try:
        result = run_sar_prediction_pipeline(coords, date, crop, farmer_context)
        return jsonify(result)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
```

### C. Output Format
The pipeline returns a JSON object with the following structure:

```json
{
  "date": "2024-01-15",
  "stressed_patches": [
    {"lat": 30.907, "lon": 75.836, "status": "High Stress"},
    ...
  ],
  "health_summary": {
    "greenness_status": "...",
    "greenness_level": "moderate",
    "nitrogen_status": "...",
    "nitrogen_level": "low",
    "biomass_status": "...",
    "biomass_level": "high",
    "heat_stress_status": "...",
    "heat_stress_level": "low",
    "overall_crop_health": "...",
    "crop_phenology_state": "..."
  }
}
```

## 3. Important Notes
*   **Execution Time:** The pipeline fetches satellite data and weather data in real-time. This can take **10-30 seconds**. It is recommended to run this as a background task (e.g., Celery, RQ) and use WebSockets or polling to return the result to the user.
*   **Sentinel Hub Credentials:** The script currently uses a specific Sentinel Hub account. Ensure you have sufficient credits or switch to your own enterprise credentials.
*   **Gemini Model:** The integration uses `gemini-flash-latest` for speed and cost-efficiency.
