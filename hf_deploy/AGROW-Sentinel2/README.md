---
title: Sentinel-2 Pipeline
emoji: 🛰️
colorFrom: green
colorTo: blue
sdk: docker
app_port: 7860
pinned: false
---

# Crop Stress Detection Pipeline - Production Package

## Overview

Production-ready pipeline for comprehensive crop stress analysis using Sentinel-2 satellite imagery, deep learning, and LLM-powered insights.

**Version:** 1.0  
**Date:** 2024-12-04  
**Python:** 3.9+

---

## Features

✅ **13 Vegetation Indices**: NDVI, EVI, NDWI, NDRE, RECI, SMI, NDSI, PRI, PSRI, MCARI, SASI, SOMI, SFI  
✅ **Temporal Analysis**: Multi-temporal statistics and trend detection  
✅ **Deep Learning**: CNN + LSTM spatial-temporal encoding  
✅ **Stress Clustering**: K-Means clustering (k=3: low, moderate, high)  
✅ **Anomaly Detection**: Isolation Forest for unusual patterns  
✅ **LLM Analysis**: Gemini-powered comprehensive insights  
✅ **Production Logging**: Comprehensive logging for monitoring  
✅ **JSON Output**: Structured results for easy integration

---

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure Environment

Copy `.env.template` to `.env` and fill in your credentials:

```env
SH_CLIENT_ID=your_sentinel_hub_client_id
SH_CLIENT_SECRET=your_sentinel_hub_secret
GEMINI_API_KEY=your_gemini_api_key
```

### 3. Run Pipeline

```python
from crop_stress_pipeline import CropStressPipeline

pipeline = CropStressPipeline()

results = pipeline.run(
    center_lat=30.2300,
    center_lon=75.8300,
    crop_type='Wheat',
    analysis_date='2024-01-15',
    field_size_hectares=0.04,
    farmer_context={
        'role': 'Owner-Operator',
        'years_farming': 15,
        'irrigation_method': 'Drip Irrigation',
        'farming_goal': 'Maximize yield'
    },
    output_path='results.json'
)
```

---

## Package Contents

### Core Files (9 files)

| File | Description | Size |
|------|-------------|------|
| `crop_stress_pipeline.py` | Main pipeline orchestrator | ~15 KB |
| `vegetation_indices.py` | 13 vegetation indices calculation | ~8 KB |
| `stress_detection_preprocessing.py` | Data preprocessing for DL | ~7 KB |
| `stress_detection_model.py` | CNN+LSTM stress detection | ~19 KB |
| `llm_analysis.py` | LLM integration & prompts | ~19 KB |
| `requirements.txt` | Python dependencies | ~200 B |
| `.env.template` | Environment variables template | ~150 B |
| `DEVELOPER_GUIDE.md` | Complete documentation | ~12 KB |
| `DEPLOYMENT_CHECKLIST.md` | Deployment guide | ~6 KB |

### Optional Files

| File | Description |
|------|-------------|
| `example_usage.py` | Example usage script |
| `README.md` | This file |

**Total Package Size:** ~90 KB (excluding dependencies)

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  INPUT PARAMETERS                        │
│  (lat, lon, crop_type, date, farmer_context)           │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│         STEP 1: SATELLITE DATA ACQUISITION              │
│  • Sentinel Hub API (CDSE)                              │
│  • 10 cloud-free images (< 20% cloud cover)            │
│  • 10m resolution, 13 spectral bands                    │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│       STEP 2: VEGETATION INDICES CALCULATION            │
│  • 13 indices calculated per pixel per timestamp        │
│  • Temporal statistics (mean, std, trend, rolling avg)  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│        STEP 3: STRESS DETECTION (DEEP LEARNING)         │
│  • Preprocessing: 8x8 patches, stride=4                 │
│  • Spatial Encoding: CNN (32→64→128 filters)           │
│  • Temporal Encoding: Bidirectional LSTM (64 units)     │
│  • Clustering: K-Means (k=3)                            │
│  • Anomaly Detection: Isolation Forest (10% contam.)    │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│          STEP 4: LLM ANALYSIS (GEMINI)                  │
│  • Input: Indices + Temporal Stats + Stress Context     │
│  • Output: Soil, stress, fertility, health insights     │
│  • Format: Structured JSON                              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                  JSON OUTPUT FILE                        │
│  • Metadata, indices, stress detection, LLM analysis    │
└─────────────────────────────────────────────────────────┘
```

---

## Output Format

```json
{
  "metadata": {
    "crop_type": "Wheat",
    "analysis_date": "2024-01-15",
    "location": {"lat": 30.23, "lon": 75.83},
    "num_images": 10
  },
  "vegetation_indices_summary": {
    "indices": {
      "NDVI": {
        "latest": {"mean": 0.65},
        "change": 0.15
      }
    }
  },
  "stress_detection": {
    "field_statistics": {
      "overall_stress": {"mean": 0.45}
    },
    "cluster_statistics": [
      {
        "cluster_id": 0,
        "stress_score": {"mean": 0.25},
        "temporal_trends": {
          "B08": {"trend_direction": "increasing"}
        }
      }
    ]
  },
  "llm_analysis": {
    "soil_moisture": {"level": "moderate"},
    "overall_health": {"status": "good"}
  }
}
```

---

## System Requirements

### Minimum
- **CPU**: 2 cores
- **RAM**: 4 GB
- **Disk**: 1 GB free space
- **Python**: 3.9+
- **Internet**: Required (API calls)

### Recommended
- **CPU**: 4+ cores
- **RAM**: 8 GB
- **Disk**: 5 GB free space
- **Python**: 3.10+
- **GPU**: Optional (speeds up DL inference)

---

## API Credentials

### Sentinel Hub (CDSE)
- **Register**: https://dataspace.copernicus.eu/
- **Free Tier**: 30,000 processing units/month
- **Usage**: ~100 PU per field analysis

### Google Gemini
- **Get Key**: https://makersuite.google.com/app/apikey
- **Free Tier**: 60 requests/minute, 1500/day
- **Usage**: 1 request per field analysis

---

## Performance

| Field Size | Processing Time | Memory Usage |
|------------|----------------|--------------|
| 0.04 ha (small) | 2-3 minutes | 2-3 GB |
| 1 ha (medium) | 5-10 minutes | 3-5 GB |
| 10 ha (large) | 20-30 minutes | 6-8 GB |

**Bottlenecks:**
1. Satellite data download (30%)
2. Deep learning inference (40%)
3. LLM API call (20%)
4. Index calculation (10%)

---

## Configuration

### Fixed Parameters (Production)
- **Clusters**: 3 (low, moderate, high stress)
- **Patch Size**: 8x8 pixels
- **Stride**: 4 pixels
- **Contamination**: 0.1 (10% anomalies)
- **Resolution**: 10m per pixel
- **Images**: 10 most recent cloud-free

### Customizable Parameters
- `center_lat`, `center_lon`: Field location
- `crop_type`: Crop being analyzed
- `analysis_date`: Target date
- `field_size_hectares`: Field size
- `farmer_context`: Farmer profile

---

## Logging

All operations logged to:
- **Console**: Real-time progress
- **File**: `crop_stress_pipeline.log`

**Log Levels:**
- `INFO`: Normal operations
- `ERROR`: Failures

**Example:**
```
2024-12-04 18:45:00 - INFO - Pipeline initialized
2024-12-04 18:45:30 - INFO - Found 10 suitable images
2024-12-04 18:46:00 - INFO - Calculated 13 indices
2024-12-04 18:46:30 - INFO - PIPELINE COMPLETED SUCCESSFULLY
```

---

## Error Handling

Common errors and solutions:

| Error | Solution |
|-------|----------|
| Missing credentials | Check `.env` file |
| No images found | Adjust `analysis_date` |
| LLM API error | Verify `GEMINI_API_KEY` |
| Out of memory | Reduce AOI size or increase RAM |

---

## Integration Examples

### REST API

```python
from flask import Flask, request, jsonify
from crop_stress_pipeline import CropStressPipeline

app = Flask(__name__)
pipeline = CropStressPipeline()

@app.route('/analyze', methods=['POST'])
def analyze():
    data = request.json
    results = pipeline.run(**data)
    return jsonify(results)
```

### Batch Processing

```python
import pandas as pd

fields = pd.read_csv('fields.csv')

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

## Files to Send to Developer

**Required (9 files):**
1. `crop_stress_pipeline.py`
2. `vegetation_indices.py`
3. `stress_detection_preprocessing.py`
4. `stress_detection_model.py`
5. `llm_analysis.py`
6. `requirements.txt`
7. `.env.template`
8. `DEVELOPER_GUIDE.md`
9. `DEPLOYMENT_CHECKLIST.md`

**Optional:**
- `example_usage.py`
- `README.md`

---

## Support

- **Documentation**: See `DEVELOPER_GUIDE.md`
- **Deployment**: See `DEPLOYMENT_CHECKLIST.md`
- **Logs**: Check `crop_stress_pipeline.log`

---

## License

Internal use only - SIH ML Team

---

## Version History

- **v1.0** (2024-12-04): Initial production release
  - 13 vegetation indices
  - CNN+LSTM stress detection
  - Fixed 3-cluster configuration
  - Gemini LLM integration
  - Production logging
  - No visualizations (production-ready)
