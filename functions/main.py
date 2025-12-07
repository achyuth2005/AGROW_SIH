from firebase_functions import https_fn, options
from firebase_admin import initialize_app
from satellite_pipeline import fetch_satellite_rgb_for_polygon, rgb_to_base64
import os

initialize_app()

# Hardcoded credentials for now (should be in Secret Manager in production)
CLIENT_ID = "sh-709c1173-fc33-4a0e-90e4-b84161ed5b9d"
CLIENT_SECRET = "IdopxGFFr3NKFJ4Y2ywJRVfmM5eBB9b4"

@https_fn.on_request(
    memory=options.MemoryOption.MB_512,
    max_instances=1,
    cors=options.CorsOptions(cors_origins="*", cors_methods=["post"])
)
def get_satellite_image(req: https_fn.Request) -> https_fn.Response:
    """
    Cloud Function to fetch satellite imagery.
    """
    try:
        data = req.get_json()
        
        if not data or 'polygon' not in data:
            return https_fn.Response("Missing polygon data", status=400)

        print(f"Received request for polygon: {data['polygon']}")

        result = fetch_satellite_rgb_for_polygon(
            polygon_coords=data['polygon'],
            client_id=CLIENT_ID,
            client_secret=CLIENT_SECRET,
            days_back=data.get('days_back', 30)
        )
        
        if result['success']:
            return https_fn.Response(
                status=200,
                response=rgb_to_base64(result['rgb_image']), # Returning just the image for simplicity? No, let's return JSON
                headers={'Content-Type': 'application/json'}
            )
            # Wait, the previous implementation returned a JSON object with metadata.
            # I should return JSON here too.
    except Exception as e:
        return https_fn.Response(f"Internal Error: {str(e)}", status=500)

    # Re-implementing the return logic properly
    if result['success']:
        import json
        response_data = {
            'success': True,
            'image': rgb_to_base64(result['rgb_image']),
            'timestamp': result['timestamp'],
            'cloud_cover': result['cloud_cover'],
            'bbox': result['bbox'],
            'dimensions': result['dimensions']
        }
        return https_fn.Response(
            json.dumps(response_data),
            status=200,
            headers={'Content-Type': 'application/json'}
        )
    else:
        return https_fn.Response(result['error'], status=400)
