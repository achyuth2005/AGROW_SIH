---
title: AGROW Heatmap Service
emoji: 🗺️
colorFrom: green
colorTo: yellow
sdk: docker
pinned: false
license: mit
---

# AGROW Heatmap Service

This service generates heatmap images from Sentinel-2 satellite data for agricultural field visualization.

## Features

- Generate vegetation index heatmaps (NDVI, EVI, NDWI, NDRE, SMI)
- Custom colormap optimized for agricultural analysis
- Returns images as base64 or direct PNG

## API Endpoints

### POST `/generate-heatmap`

Generate a heatmap for the specified location and index type.

**Request:**
```json
{
  "center_lat": 26.1885,
  "center_lon": 91.6894,
  "field_size_hectares": 10.0,
  "index_type": "NDVI"
}
```

**Response:**
```json
{
  "success": true,
  "index_type": "NDVI",
  "min_value": 0.2,
  "max_value": 0.85,
  "mean_value": 0.65,
  "image_base64": "...",
  "timestamp": "2025-12-05T10:30:00"
}
```

### GET `/generate-heatmap-image`

Get heatmap as PNG image directly.

**Query Parameters:**
- `center_lat`: Field center latitude
- `center_lon`: Field center longitude
- `field_size_hectares`: Field size (default: 10.0)
- `index_type`: Index type (default: "NDVI")

## Supported Indices

| Index | Description |
|-------|-------------|
| NDVI  | Normalized Difference Vegetation Index - General crop health |
| EVI   | Enhanced Vegetation Index - Dense vegetation monitoring |
| NDWI  | Normalized Difference Water Index - Water/moisture content |
| NDRE  | Normalized Difference Red Edge Index - Chlorophyll content |
| SMI   | Soil Moisture Index - Soil water content |

## Environment Variables

Required secrets in HF Space:
- `SH_CLIENT_ID`: Sentinel Hub client ID
- `SH_CLIENT_SECRET`: Sentinel Hub client secret
