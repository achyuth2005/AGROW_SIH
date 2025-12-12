---
title: AGROW TimeSeries
emoji: 📈
colorFrom: green
colorTo: blue
sdk: docker
pinned: false
license: mit
---

# AGROW Time Series Service

Time series forecasting for satellite indices using AutoNHITS.

## Features

- Historical data from Sentinel-1 (SAR) and Sentinel-2 (Optical)
- AutoNHITS forecasting with weather integration
- Returns JSON data for interactive Flutter charts

## API Endpoints

### POST /timeseries

Generate time series with historical data and forecasts.

**Request:**
```json
{
  "center_lat": 26.1885,
  "center_lon": 91.6894,
  "field_size_hectares": 10.0,
  "metric": "VV"
}
```

**Response:**
```json
{
  "success": true,
  "metric": "VV",
  "historical": [{"date": "2024-01-01", "value": -12.5}, ...],
  "forecast": [{"date": "2024-12-01", "value": -11.8, "confidence_low": -12.5, "confidence_high": -11.0}],
  "trend": "improving",
  "stats": {"min": -15.2, "max": -8.5, "mean": -11.5}
}
```

## Supported Metrics

- **SAR:** VV, VH (Sentinel-1)
- **Optical:** B02-B12 (Sentinel-2)

## Required Secrets

- `SH_CLIENT_ID`
- `SH_CLIENT_SECRET`
