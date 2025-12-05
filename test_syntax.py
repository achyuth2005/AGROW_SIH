
def test_func(center_lat, center_lon):
    prompt = f"""
FIELD METADATA:
- Location: Latitude {center_lat:.4f}, Longitude {center_lon:.4f}
"""
    print(prompt)

test_func(12.34567, 78.91011)
