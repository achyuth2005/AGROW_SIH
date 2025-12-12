# Production Pipeline - Files to Send to Developer

## Core Pipeline Files (Required)

1. **crop_stress_pipeline.py** - Main pipeline orchestrator
2. **vegetation_indices.py** - Vegetation indices calculation module
3. **stress_detection_preprocessing.py** - Data preprocessing for deep learning
4. **stress_detection_model.py** - CNN+LSTM stress detection model
5. **llm_analysis.py** - LLM integration and prompt engineering

## Configuration Files (Required)

6. **requirements.txt** - Python dependencies
7. **.env.template** - Environment variables template (rename to .env and fill in credentials)

## Documentation (Required)

8. **DEVELOPER_GUIDE.md** - Complete developer documentation
9. **DEPLOYMENT_CHECKLIST.md** - This file

---

## Deployment Checklist

### Pre-Deployment

- [ ] Install Python 3.9+ on target server
- [ ] Create virtual environment: `python -m venv venv`
- [ ] Activate virtual environment
- [ ] Install dependencies: `pip install -r requirements.txt`
- [ ] Copy `.env.template` to `.env`
- [ ] Fill in Sentinel Hub credentials in `.env`
- [ ] Fill in Gemini API key in `.env`
- [ ] Test Sentinel Hub connection
- [ ] Test Gemini API connection

### Testing

- [ ] Run test with sample coordinates
- [ ] Verify log file is created
- [ ] Verify JSON output is generated
- [ ] Check all 13 vegetation indices are calculated
- [ ] Verify stress detection runs successfully
- [ ] Confirm LLM analysis completes
- [ ] Review output JSON structure

### Production Deployment

- [ ] Set up logging directory with write permissions
- [ ] Configure log rotation (optional)
- [ ] Set up monitoring for pipeline failures
- [ ] Configure API rate limits (Gemini: 60 requests/min)
- [ ] Set up backup for output JSON files
- [ ] Document server specifications (min 4GB RAM)
- [ ] Create systemd service (Linux) or Windows Service (optional)

### Security

- [ ] Ensure `.env` file is NOT committed to version control
- [ ] Add `.env` to `.gitignore`
- [ ] Restrict file permissions on `.env` (chmod 600)
- [ ] Use environment-specific credentials (dev/staging/prod)
- [ ] Rotate API keys regularly
- [ ] Enable HTTPS for API endpoints (if exposing via REST)

### Monitoring

- [ ] Set up log monitoring (e.g., ELK stack, CloudWatch)
- [ ] Configure alerts for pipeline failures
- [ ] Monitor API quota usage (Sentinel Hub, Gemini)
- [ ] Track processing time metrics
- [ ] Monitor disk space for output files

---

## Quick Test Script

```python
# test_pipeline.py
from crop_stress_pipeline import CropStressPipeline

pipeline = CropStressPipeline()

# Test with PAU Experimental Farm
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
        'farming_goal': 'Maximize yield'
    },
    'output_path': 'test_results.json'
}

try:
    results = pipeline.run(**params)
    print("✓ Pipeline test successful!")
    print(f"✓ Output saved to: {params['output_path']}")
except Exception as e:
    print(f"✗ Pipeline test failed: {e}")
```

---

## Expected Output Structure

```
production_pipeline/
├── crop_stress_pipeline.py
├── vegetation_indices.py
├── stress_detection_preprocessing.py
├── stress_detection_model.py
├── llm_analysis.py
├── requirements.txt
├── .env.template
├── .env (create from template)
├── DEVELOPER_GUIDE.md
├── DEPLOYMENT_CHECKLIST.md
├── crop_stress_pipeline.log (auto-generated)
└── *.json (output files)
```

---

## API Quotas & Limits

### Sentinel Hub (CDSE)
- **Free tier**: 30,000 processing units/month
- **Rate limit**: ~10 requests/second
- **Typical usage**: ~100 PU per field analysis

### Google Gemini
- **Free tier**: 60 requests/minute
- **Rate limit**: 1500 requests/day (free)
- **Typical usage**: 1 request per field analysis

---

## Troubleshooting Common Issues

### Issue: "Sentinel Hub credentials not found"
**Solution**: Ensure `.env` file exists and contains valid credentials

### Issue: "No images found for date range"
**Solution**: Adjust `analysis_date` or check cloud cover threshold

### Issue: "Gemini API quota exceeded"
**Solution**: Wait for quota reset or upgrade to paid tier

### Issue: "Out of memory error"
**Solution**: Reduce AOI size or increase server RAM

---

## Support Contacts

- **Technical Issues**: Check logs in `crop_stress_pipeline.log`
- **API Issues**: Refer to DEVELOPER_GUIDE.md
- **Architecture Questions**: Review pipeline source code comments

---

## Version Information

- **Pipeline Version**: 1.0
- **Python Version**: 3.9+
- **TensorFlow Version**: 2.13+
- **Last Updated**: 2024-12-04
