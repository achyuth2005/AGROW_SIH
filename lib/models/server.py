from flask import Flask, request, jsonify
from satellite_pipeline import fetch_satellite_rgb_for_polygon, rgb_to_base64
import os

app = Flask(__name__)

# TODO: Replace with actual credentials or use environment variables
CLIENT_ID = "sh-709c1173-fc33-4a0e-90e4-b84161ed5b9d"
CLIENT_SECRET = "IdopxGFFr3NKFJ4Y2ywJRVfmM5eBB9b4"

@app.route('/api/satellite', methods=['POST'])
def get_satellite_image():
    data = request.json
    
    if not data or 'polygon' not in data:
        return jsonify({'success': False, 'error': 'Missing polygon data'}), 400

    print(f"Received request for polygon: {data['polygon']}")

    result = fetch_satellite_rgb_for_polygon(
        polygon_coords=data['polygon'],
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
        days_back=data.get('days_back', 30)
    )
    
    if result['success']:
        return jsonify({
            'success': True,
            'image': rgb_to_base64(result['rgb_image']),
            'timestamp': result['timestamp'],
            'cloud_cover': result['cloud_cover'],
            'bbox': result['bbox'],
            'dimensions': result['dimensions']
        })
    else:
        return jsonify({'success': False, 'error': result['error']}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
