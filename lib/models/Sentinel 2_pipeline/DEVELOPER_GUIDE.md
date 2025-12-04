# Crop Stress Detection Pipeline - Developer Guide

## Overview

This production-ready pipeline performs comprehensive crop stress analysis using Sentinel-2 satellite imagery, deep learning models, and LLM-powered insights.

**Pipeline Architecture:**
1. **Data Acquisition**: Fetch Sentinel-2 L2A imagery from Copernicus Data Space Ecosystem
2. **Vegetation Indices**: Calculate 13 indices (NDVI, EVI, NDWI, NDRE, RECI, SMI, NDSI, PRI, PSRI, MCARI, SASI, SOMI, SFI)
3. **Temporal Analysis**: Extract temporal statistics and trends
4. **Stress Detection**: CNN + LSTM spatial-temporal encoding with K-Means clustering (k=3)
5. **Anomaly Detection**: Isolation Forest for unusual patterns
6. **LLM Analysis**: Gemini-powered comprehensive crop and soil insights

---

## Quick Start

### 1. Installation

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Environment Setup

Create a `.env` file in the project root:

```env
# Sentinel Hub Credentials (Copernicus Data Space Ecosystem)
SH_CLIENT_ID=your_client_id_here
SH_CLIENT_SECRET=your_client_secret_here

# Google Gemini API Key
GEMINI_API_KEY=your_gemini_api_key_here
```

**How to get credentials:**
- **Sentinel Hub**: Register at https://dataspace.copernicus.eu/
- **Gemini API**: Get key from https://makersuite.google.com/app/apikey

### 3. Run Pipeline

```python
from crop_stress_pipeline import CropStressPipeline

# Initialize pipeline
pipeline = CropStressPipeline()

# Define parameters
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
    'output_path': 'results.json'
}

# Run analysis
results = pipeline.run(**params)
```

---

## File Structure

```
production_pipeline/
├── crop_stress_pipeline.py          # Main pipeline script
├── vegetation_indices.py             # Vegetation indices calculation
├── stress_detection_preprocessing.py # Data preprocessing for DL model
├── stress_detection_model.py         # CNN+LSTM stress detection model
├── llm_analysis.py                   # LLM integration and prompt engineering
├── requirements.txt                  # Python dependencies
├── .env                              # Environment variables (create this)
├── DEVELOPER_GUIDE.md               # This file
└── crop_stress_pipeline.log         # Auto-generated log file
```

---

## API Reference

### CropStressPipeline Class

#### `__init__(config_path: str = None)`
Initialize pipeline with environment configuration.

**Args:**
- `config_path`: Optional path to .env file

#### `run(center_lat, center_lon, crop_type, analysis_date, field_size_hectares, farmer_context, output_path=None)`
Execute complete pipeline.

**Args:**
- `center_lat` (float): Field center latitude
- `center_lon` (float): Field center longitude  
- `crop_type` (str): Crop type (e.g., 'Wheat', 'Rice', 'Corn')
- `analysis_date` (str): Target date in 'YYYY-MM-DD' format
- `field_size_hectares` (float): Field size in hectares
- `farmer_context` (dict): Farmer profile with keys:
  - `role`: Farmer role
  - `years_farming`: Years of experience
  - `irrigation_method`: Irrigation type
  - `farming_goal`: Primary farming objective
- `output_path` (str, optional): Path to save JSON results

**Returns:**
- `dict`: Complete analysis results

---

## Output Format

The pipeline generates a JSON file with the following structure:

```json
{
  "metadata": {
    "crop_type": "Wheat",
    "analysis_date": "2024-01-15",
    "location": {"lat": 30.23, "lon": 75.83},
    "field_size_hectares": 0.04,
    "farmer_context": {...},
    "num_images": 10,
    "date_range": ["2023-10-15", "2024-01-15"]
  },
  "vegetation_indices_summary": {
    "indices": {
      "NDVI": {
        "latest": {"mean": 0.65, "std": 0.12},
        "max_in_field": 0.82,
        "min_in_field": 0.41,
        "change": 0.15
      },
      ...
    }
  },
  "stress_detection": {
    "field_statistics": {
      "overall_stress": {"mean": 0.45, "std": 0.15},
      "stress_distribution": {"low": 15, "moderate": 20, "high": 5}
    },
    "cluster_statistics": [
      {
        "cluster_id": 0,
        "percentage": 40.0,
        "stress_score": {"mean": 0.25, "std": 0.05},
        "band_statistics": {...},
        "temporal_trends": {
          "B04": {"change": -0.01, "trend_direction": "stable"},
          "B08": {"change": 0.05, "trend_direction": "increasing"}
        }
      }
    ],
    "anomaly_information": {
      "total_anomalies": 2,
      "anomaly_percentage": 5.0
    }
  },
  "llm_analysis": {
    "soil_moisture": {
      "level": "moderate",
      "maximum_value": 0.65,
      "minimum_value": 0.32,
      "analysis": "..."
    },
    "vegetation_stress": {...},
    "overall_health": {
      "status": "good",
      "key_concerns": ["..."],
      "recommendations": ["..."]
    }
  }
}
```

---

## Logging

All pipeline operations are logged to:
- **Console**: Real-time progress
- **File**: `crop_stress_pipeline.log`

**Log Levels:**
- `INFO`: Normal operations
- `ERROR`: Failures and exceptions

**Example Log Output:**
```
2024-12-04 16:45:00 - INFO - Pipeline initialized successfully
2024-12-04 16:45:05 - INFO - Fetching satellite data...
2024-12-04 16:45:30 - INFO - Found 10 suitable images
2024-12-04 16:46:00 - INFO - Calculated 13 indices
2024-12-04 16:46:15 - INFO - Stress detection complete
2024-12-04 16:46:30 - INFO - LLM analysis complete
2024-12-04 16:46:35 - INFO - PIPELINE COMPLETED SUCCESSFULLY
```

---

## Configuration Parameters

### Clustering
- **Number of clusters**: Fixed at 3 (low, moderate, high stress)
- **Contamination**: 0.1 (10% expected anomalies)

### Spatial Resolution
- **Default**: 10m per pixel
- **Patch size**: 8x8 pixels
- **Stride**: 4 pixels (50% overlap)

### Temporal Analysis
- **Images**: 10 most recent cloud-free images
- **Search window**: 90 days before + 30 days after target date
- **Cloud threshold**: < 20%

### Deep Learning Model
- **Spatial encoder**: CNN (32→64→128 filters)
- **Temporal encoder**: Bidirectional LSTM (64 units)
- **Embedding dimensions**: 128

---

## Error Handling

Common errors and solutions:

### 1. Missing Credentials
```
ValueError: Sentinel Hub credentials not found
```
**Solution**: Ensure `.env` file exists with valid credentials

### 2. No Images Found
```
IndexError: list index out of range
```
**Solution**: Adjust `analysis_date` or expand search window

### 3. LLM API Error
```
google.api_core.exceptions.PermissionDenied
```
**Solution**: Verify `GEMINI_API_KEY` is valid and has quota

### 4. Insufficient Patches
```
WARNING: Only X patches generated
```
**Solution**: Increase AOI size or reduce `patch_size`

---

## Performance Optimization

### Memory Usage
- **Typical**: 2-4 GB RAM
- **Large AOIs**: Consider batch processing

### Processing Time
- **Small field (0.04 ha)**: ~2-3 minutes
- **Medium field (1 ha)**: ~5-10 minutes
- **Large field (10 ha)**: ~20-30 minutes

**Bottlenecks:**
1. Satellite data download (~30%)
2. Deep learning inference (~40%)
3. LLM API call (~20%)
4. Index calculation (~10%)

---

## Integration Guide

### REST API Wrapper

```python
from flask import Flask, request, jsonify
from crop_stress_pipeline import CropStressPipeline

app = Flask(__name__)
pipeline = CropStressPipeline()

@app.route('/analyze', methods=['POST'])
def analyze():
    data = request.json
    try:
        results = pipeline.run(
            center_lat=data['lat'],
            center_lon=data['lon'],
            crop_type=data['crop_type'],
            analysis_date=data['date'],
            field_size_hectares=data['field_size'],
            farmer_context=data['farmer_context']
        )
        return jsonify(results)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

### Batch Processing

```python
import pandas as pd

# Load field data
fields = pd.read_csv('fields.csv')

# Process each field
for _, field in fields.iterrows():
    results = pipeline.run(
        center_lat=field['lat'],
        center_lon=field['lon'],
        crop_type=field['crop'],
        analysis_date=field['date'],
        field_size_hectares=field['size'],
        farmer_context={...},
        output_path=f"results_{field['id']}.json"
    )
```

---

## Troubleshooting

### Enable Debug Logging

```python
import logging
logging.getLogger().setLevel(logging.DEBUG)
```

### Test Individual Components

```python
# Test Sentinel Hub connection
from sentinelhub import SHConfig
config = SHConfig()
config.sh_client_id = "your_id"
config.sh_client_secret = "your_secret"
# Should not raise errors

# Test LLM connection
import google.generativeai as genai
genai.configure(api_key="your_key")
model = genai.GenerativeModel('gemini-flash-latest')
response = model.generate_content("Hello")
print(response.text)
```

---

## Support

For issues or questions:
1. Check logs in `crop_stress_pipeline.log`
2. Review this guide
3. Contact: SIH ML Team

---

## Version History

- **v1.0** (2024-12-04): Initial production release
  - 13 vegetation indices
  - CNN+LSTM stress detection
  - Fixed 3-cluster configuration
  - Gemini LLM integration
  - Comprehensive logging
