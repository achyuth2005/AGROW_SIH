# Satellite Data Pipeline - Integration Guide

## For the App Developer

This module provides a simple function to fetch satellite RGB images for any polygon coordinates.

---

## Quick Start

### 1. Install Dependencies
```bash
pip install sentinelhub-py numpy pillow
```

### 2. Get Sentinel Hub Credentials
- Sign up at: https://www.sentinel-hub.com/
- Create an OAuth client
- Copy Client ID and Client Secret

### 3. Use the Pipeline

```python
from satellite_pipeline import fetch_satellite_rgb_for_polygon

# Frontend sends polygon coordinates (list of [lon, lat] pairs)
polygon_coords = [
    [75.840, 30.890],
    [75.860, 30.890],
    [75.860, 30.910],
    [75.840, 30.910],
    [75.840, 30.890]  # Close the polygon
]

# Fetch satellite image
result = fetch_satellite_rgb_for_polygon(
    polygon_coords=polygon_coords,
    client_id="YOUR_CLIENT_ID",
    client_secret="YOUR_CLIENT_SECRET",
    days_back=30  # Search last 30 days
)

if result['success']:
    # result['rgb_image'] is a numpy array (Height, Width, 3)
    # Values are in range [0, 1]
    
    # Option 1: Save as file
    from satellite_pipeline import save_rgb_image
    save_rgb_image(result['rgb_image'], 'output.png')
    
    # Option 2: Convert to base64 for web
    from satellite_pipeline import rgb_to_base64
    base64_str = rgb_to_base64(result['rgb_image'])
    # Send base64_str to frontend
    
    # Metadata
    print(f"Date: {result['timestamp']}")
    print(f"Cloud Cover: {result['cloud_cover']}%")
    print(f"Size: {result['dimensions']}")
else:
    print(f"Error: {result['error']}")
```

---

## Integration Examples

### Flask API
```python
from flask import Flask, request, jsonify
from satellite_pipeline import fetch_satellite_rgb_for_polygon, rgb_to_base64

app = Flask(__name__)

@app.route('/api/satellite', methods=['POST'])
def get_satellite_image():
    data = request.json
    
    result = fetch_satellite_rgb_for_polygon(
        polygon_coords=data['polygon'],
        client_id="YOUR_CLIENT_ID",
        client_secret="YOUR_CLIENT_SECRET",
        days_back=data.get('days_back', 30)
    )
    
    if result['success']:
        return jsonify({
            'success': True,
            'image': rgb_to_base64(result['rgb_image']),
            'timestamp': result['timestamp'],
            'cloud_cover': result['cloud_cover']
        })
    else:
        return jsonify({'success': False, 'error': result['error']}), 400

if __name__ == '__main__':
    app.run(debug=True)
```

### FastAPI
```python
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
from satellite_pipeline import fetch_satellite_rgb_for_polygon, rgb_to_base64

app = FastAPI()

class PolygonRequest(BaseModel):
    polygon: List[List[float]]
    days_back: int = 30

@app.post("/api/satellite")
def get_satellite_image(request: PolygonRequest):
    result = fetch_satellite_rgb_for_polygon(
        polygon_coords=request.polygon,
        client_id="YOUR_CLIENT_ID",
        client_secret="YOUR_CLIENT_SECRET",
        days_back=request.days_back
    )
    
    if result['success']:
        return {
            'success': True,
            'image': rgb_to_base64(result['rgb_image']),
            'timestamp': result['timestamp'],
            'cloud_cover': result['cloud_cover']
        }
    else:
        return {'success': False, 'error': result['error']}
```

---

## Frontend Integration

### JavaScript Example
```javascript
// Send polygon to backend
const polygon = [
    [75.840, 30.890],
    [75.860, 30.890],
    [75.860, 30.910],
    [75.840, 30.910],
    [75.840, 30.890]
];

fetch('/api/satellite', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({polygon: polygon, days_back: 30})
})
.then(response => response.json())
.then(data => {
    if (data.success) {
        // Display image
        const img = document.getElementById('satellite-image');
        img.src = 'data:image/png;base64,' + data.image;
        
        // Show metadata
        document.getElementById('date').textContent = data.timestamp;
        document.getElementById('cloud').textContent = data.cloud_cover + '%';
    } else {
        console.error('Error:', data.error);
    }
});
```

---

## Important Notes

1. **Polygon Format**: Coordinates must be `[longitude, latitude]` (NOT lat/lon)
2. **Polygon Closure**: Last coordinate should match first coordinate to close the polygon
3. **Size Limits**: Keep polygon area reasonable (< 100 km²) to avoid timeout
4. **Cloud Cover**: Function automatically finds the least cloudy image
5. **Resolution**: Default is 10m (Sentinel-2 native). Can be changed via `resolution` parameter

---

## Return Value Structure

```python
{
    'success': True/False,
    'rgb_image': numpy.ndarray,  # Shape: (Height, Width, 3), Range: [0, 1]
    'timestamp': '2024-11-15',   # Date of satellite acquisition
    'cloud_cover': 12.5,         # Percentage
    'dimensions': (223, 218),    # (Height, Width) in pixels
    'bbox': {                    # Bounding box of polygon
        'min_lon': 75.840,
        'max_lon': 75.860,
        'min_lat': 30.890,
        'max_lat': 30.910
    },
    'error': None                # Error message if failed
}
```

---

## Error Handling

Common errors:
- `"No Sentinel-2 data found"` → Increase `days_back` parameter
- `"Failed to download"` → Check internet connection / credentials
- `"Invalid credentials"` → Verify Client ID and Secret

---

## Performance Tips

1. **Cache results**: Same polygon + date = same image
2. **Async processing**: Use background tasks for large requests
3. **Thumbnail generation**: Resize large images before sending to frontend
4. **Rate limiting**: Sentinel Hub has API limits (check your plan)

---

## Questions?

The developer can use Antigravity AI to:
- Debug integration issues
- Modify the pipeline (e.g., add more bands, change enhancement)
- Optimize for their specific use case
- Add caching, error recovery, etc.

The code is well-documented and modular, so AI can easily understand and modify it!
