"""
AGROW Time Series Service v2.1
==============================
Production-ready prediction pipeline with:
- Persistent CSV storage per field
- Detailed structured logging
- CSV download endpoints
- Idempotent processing

CSVs Generated per field:
1. sar_data.csv - Historical SAR data
2. sentinel2_data.csv - Historical Sentinel-2 data
3. sar_predictions.csv - SAR forecasts
4. sentinel2_predictions.csv - S2 forecasts
"""

import os
import json
import logging
import traceback
import threading
import uuid
from datetime import datetime
from typing import List, Optional, Dict, Any, Tuple
from concurrent.futures import ThreadPoolExecutor

import numpy as np
import pandas as pd
from fastapi import FastAPI, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel
import io

# Import modules
from satellite_pipeline import SatelliteFetcher
from auto_tuning_predictor import AutoTimeSeriesPredictor
from storage import FieldStorage, JobStatus
from index_calculator import IndexCalculator

# ============================================================================
# LOGGING CONFIGURATION (Industry Standard)
# ============================================================================
class StructuredFormatter(logging.Formatter):
    """Structured logging formatter for production."""
    def format(self, record):
        log_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if hasattr(record, 'field_hash'):
            log_data['field_hash'] = record.field_hash
        if hasattr(record, 'step'):
            log_data['step'] = record.step
        if hasattr(record, 'duration_ms'):
            log_data['duration_ms'] = record.duration_ms
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)
        return json.dumps(log_data)

# Setup logging
logger = logging.getLogger("TimeSeriesService")
logger.setLevel(logging.INFO)

# Console handler with structured format
console_handler = logging.StreamHandler()
console_handler.setFormatter(StructuredFormatter())
logger.addHandler(console_handler)

# File handler for debugging
file_handler = logging.FileHandler('timeseries.log')
file_handler.setFormatter(logging.Formatter(
    '[%(asctime)s] %(levelname)s [%(name)s] %(message)s'
))
logger.addHandler(file_handler)

# Thread pool for background processing
executor = ThreadPoolExecutor(max_workers=2)

# ============================================================================
# FASTAPI APP
# ============================================================================
app = FastAPI(
    title="AGROW Time Series Service",
    description="Production-ready prediction pipeline with CSV storage",
    version="2.1.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# REQUEST/RESPONSE MODELS
# ============================================================================
class DataPoint(BaseModel):
    date: str
    value: float

class ForecastPoint(BaseModel):
    date: str
    value: float
    confidence_low: Optional[float] = None
    confidence_high: Optional[float] = None

class TimeSeriesRequest(BaseModel):
    center_lat: float
    center_lon: float
    field_size_hectares: float = 10.0
    metric: str = "VV"
    days_history: int = 365
    days_forecast: int = 30

class TimeSeriesResponse(BaseModel):
    success: bool
    metric: str
    field_hash: str
    historical: List[DataPoint]
    forecast: List[ForecastPoint]
    trend: str
    stats: Dict[str, float]
    csv_files: Dict[str, str]
    timestamp: str

class PredictRequest(BaseModel):
    polygon_coords: List[List[float]]
    field_name: Optional[str] = None

class PredictResponse(BaseModel):
    job_id: str
    field_hash: str
    status: str
    message: str
    csv_files: Optional[Dict[str, str]] = None
    created_at: Optional[str] = None

class StatusResponse(BaseModel):
    field_hash: str
    status: str
    progress: int
    step: str
    message: Optional[str] = None
    csv_files: Optional[Dict[str, str]] = None
    created_at: Optional[str] = None
    completed_at: Optional[str] = None

# ============================================================================
# HELPERS
# ============================================================================
def coords_to_polygon(center_lat: float, center_lon: float, size_ha: float) -> List[Tuple[float, float]]:
    """Convert center point and size to polygon coordinates."""
    radius_km = np.sqrt(size_ha / 100) / 2
    lat_off = radius_km / 111
    lon_off = radius_km / (111 * np.cos(np.radians(center_lat)))
    
    return [
        (center_lon - lon_off, center_lat - lat_off),
        (center_lon + lon_off, center_lat - lat_off),
        (center_lon + lon_off, center_lat + lat_off),
        (center_lon - lon_off, center_lat + lat_off),
        (center_lon - lon_off, center_lat - lat_off),
    ]

def calculate_trend(values: List[float]) -> str:
    """Determine trend from values."""
    if len(values) < 5:
        return "stable"
    x = np.arange(len(values))
    slope = np.polyfit(x, values, 1)[0]
    if slope > 0.01:
        return "improving"
    elif slope < -0.01:
        return "declining"
    return "stable"

def get_csv_urls(field_hash: str) -> Dict[str, str]:
    """Get download URLs for all 4 CSV files."""
    base = f"/download/{field_hash}"
    return {
        "sar_historical": f"{base}/sar_data.csv",
        "sentinel2_historical": f"{base}/sentinel2_data.csv",
        "sar_predictions": f"{base}/sar_predictions.csv",
        "sentinel2_predictions": f"{base}/sentinel2_predictions.csv",
        "indices": f"{base}/indices.csv"
    }

def log_step(field_hash: str, step: str, message: str, level: str = "INFO"):
    """Helper for structured step logging."""
    extra = {'field_hash': field_hash, 'step': step}
    if level == "ERROR":
        logger.error(f"[{field_hash}] {step}: {message}", extra=extra)
    else:
        logger.info(f"[{field_hash}] {step}: {message}", extra=extra)

# ============================================================================
# PREDICTION JOB
# ============================================================================
def run_prediction_job(field_hash: str, polygon_coords: List[Tuple[float, float]], field_name: str):
    """
    Production prediction job with detailed logging.
    Generates 4 named CSVs + indices.
    """
    start_time = datetime.now()
    log_step(field_hash, "START", f"Beginning prediction pipeline for {field_name}")
    
    try:
        field_dir = FieldStorage.get_field_dir(field_hash)
        os.makedirs(field_dir, exist_ok=True)
        
        # CSV file paths with descriptive names
        csv_files = {
            "sar_data": os.path.join(field_dir, "sar_data.csv"),
            "sentinel2_data": os.path.join(field_dir, "sentinel2_data.csv"),
            "sar_predictions": os.path.join(field_dir, "sar_predictions.csv"),
            "sentinel2_predictions": os.path.join(field_dir, "sentinel2_predictions.csv"),
            "indices": os.path.join(field_dir, "indices.csv")
        }
        
        # =====================
        # STEP 1: Fetch SAR Data
        # =====================
        step_start = datetime.now()
        FieldStorage.update_metadata(field_hash, 
            status=JobStatus.FETCHING_SAR,
            progress=10,
            step="Fetching SAR (Sentinel-1) data..."
        )
        log_step(field_hash, "FETCH_SAR", "Starting SAR data acquisition from Sentinel Hub")
        
        fetcher = SatelliteFetcher(polygon_coords)
        fetcher.fetch_sar_data(csv_files["sar_data"])
        
        sar_rows = 0
        if os.path.exists(csv_files["sar_data"]):
            sar_df = pd.read_csv(csv_files["sar_data"])
            sar_rows = len(sar_df)
        
        duration = (datetime.now() - step_start).total_seconds() * 1000
        log_step(field_hash, "FETCH_SAR", f"SAR data fetched: {sar_rows} rows in {duration:.0f}ms")
        
        # =====================
        # STEP 2: Fetch Sentinel-2 Data
        # =====================
        step_start = datetime.now()
        FieldStorage.update_metadata(field_hash,
            status=JobStatus.FETCHING_S2,
            progress=25,
            step="Fetching Sentinel-2 optical data..."
        )
        log_step(field_hash, "FETCH_S2", "Starting Sentinel-2 optical data acquisition")
        
        fetcher.fetch_sentinel2_data(csv_files["sentinel2_data"])
        
        s2_rows = 0
        if os.path.exists(csv_files["sentinel2_data"]):
            s2_df = pd.read_csv(csv_files["sentinel2_data"])
            s2_rows = len(s2_df)
        
        duration = (datetime.now() - step_start).total_seconds() * 1000
        log_step(field_hash, "FETCH_S2", f"Sentinel-2 data fetched: {s2_rows} rows in {duration:.0f}ms")
        
        # =====================
        # STEP 3: SAR Predictions
        # =====================
        step_start = datetime.now()
        FieldStorage.update_metadata(field_hash,
            status=JobStatus.PREDICTING_SAR,
            progress=40,
            step="Running AutoNHITS model on SAR bands..."
        )
        log_step(field_hash, "PREDICT_SAR", "Initializing AutoNHITS predictor for SAR")
        
        predictor = AutoTimeSeriesPredictor()
        
        if os.path.exists(csv_files["sar_data"]):
            sar_df = pd.read_csv(csv_files["sar_data"])
            if 'ds' in sar_df.columns:
                target_cols = [c for c in sar_df.columns if c != 'ds']
                log_step(field_hash, "PREDICT_SAR", f"Processing {len(target_cols)} SAR bands: {target_cols}")
                
                all_preds = []
                for idx, col in enumerate(target_cols):
                    log_step(field_hash, "PREDICT_SAR", f"Predicting band {idx+1}/{len(target_cols)}: {col}")
                    try:
                        pred_df = predictor.tune_and_predict(
                            csv_path=csv_files["sar_data"],
                            field_coords=polygon_coords,
                            target_col=col,
                            output_file=f"temp_sar_{col}.csv",
                            num_samples=3
                        )
                        pred_df = pred_df.rename(columns={'predicted_y': col})
                        all_preds.append(pred_df[['ds', col]])
                        
                        # Cleanup temp file
                        if os.path.exists(f"temp_sar_{col}.csv"):
                            os.remove(f"temp_sar_{col}.csv")
                    except Exception as e:
                        log_step(field_hash, "PREDICT_SAR", f"Failed to predict {col}: {e}", "ERROR")
                
                if all_preds:
                    final_df = all_preds[0]
                    for i in range(1, len(all_preds)):
                        final_df = final_df.merge(all_preds[i], on='ds', how='outer')
                    final_df.to_csv(csv_files["sar_predictions"], index=False)
                    log_step(field_hash, "PREDICT_SAR", f"SAR predictions saved: {len(final_df)} rows")
        
        duration = (datetime.now() - step_start).total_seconds() * 1000
        log_step(field_hash, "PREDICT_SAR", f"SAR prediction complete in {duration:.0f}ms")
        
        # =====================
        # STEP 4: Sentinel-2 Predictions
        # =====================
        step_start = datetime.now()
        FieldStorage.update_metadata(field_hash,
            status=JobStatus.PREDICTING_S2,
            progress=60,
            step="Running AutoNHITS model on optical bands..."
        )
        log_step(field_hash, "PREDICT_S2", "Initializing AutoNHITS predictor for Sentinel-2")
        
        if os.path.exists(csv_files["sentinel2_data"]):
            s2_df = pd.read_csv(csv_files["sentinel2_data"])
            if 'ds' in s2_df.columns:
                target_cols = [c for c in s2_df.columns if c != 'ds']
                log_step(field_hash, "PREDICT_S2", f"Processing {len(target_cols)} optical bands: {target_cols}")
                
                all_preds = []
                for idx, col in enumerate(target_cols):
                    log_step(field_hash, "PREDICT_S2", f"Predicting band {idx+1}/{len(target_cols)}: {col}")
                    try:
                        pred_df = predictor.tune_and_predict(
                            csv_path=csv_files["sentinel2_data"],
                            field_coords=polygon_coords,
                            target_col=col,
                            output_file=f"temp_s2_{col}.csv",
                            num_samples=3
                        )
                        pred_df = pred_df.rename(columns={'predicted_y': col})
                        all_preds.append(pred_df[['ds', col]])
                        
                        # Cleanup temp file
                        if os.path.exists(f"temp_s2_{col}.csv"):
                            os.remove(f"temp_s2_{col}.csv")
                    except Exception as e:
                        log_step(field_hash, "PREDICT_S2", f"Failed to predict {col}: {e}", "ERROR")
                
                if all_preds:
                    final_df = all_preds[0]
                    for i in range(1, len(all_preds)):
                        final_df = final_df.merge(all_preds[i], on='ds', how='outer')
                    final_df.to_csv(csv_files["sentinel2_predictions"], index=False)
                    log_step(field_hash, "PREDICT_S2", f"S2 predictions saved: {len(final_df)} rows")
        
        duration = (datetime.now() - step_start).total_seconds() * 1000
        log_step(field_hash, "PREDICT_S2", f"S2 prediction complete in {duration:.0f}ms")
        
        # =====================
        # STEP 5: Compute Indices
        # =====================
        step_start = datetime.now()
        FieldStorage.update_metadata(field_hash,
            status=JobStatus.COMPUTING_INDICES,
            progress=85,
            step="Computing vegetation indices (NDVI, NDWI, EVI, etc.)..."
        )
        log_step(field_hash, "INDICES", "Computing vegetation indices from bands")
        
        if os.path.exists(csv_files["sentinel2_data"]):
            s2_df = pd.read_csv(csv_files["sentinel2_data"])
            sar_df = pd.read_csv(csv_files["sar_data"]) if os.path.exists(csv_files["sar_data"]) else None
            
            # Historical indices
            indices_df = IndexCalculator.compute_all_indices(s2_df, sar_df)
            indices_df['type'] = 'historical'
            
            # Prediction indices
            if os.path.exists(csv_files["sentinel2_predictions"]):
                s2_pred_df = pd.read_csv(csv_files["sentinel2_predictions"])
                pred_indices = IndexCalculator.compute_all_indices(s2_pred_df, None)
                pred_indices['type'] = 'forecast'
                indices_df = pd.concat([indices_df, pred_indices], ignore_index=True)
            
            indices_df.to_csv(csv_files["indices"], index=False)
            log_step(field_hash, "INDICES", f"Indices computed: {len(indices_df)} rows, columns: {list(indices_df.columns)}")
        
        duration = (datetime.now() - step_start).total_seconds() * 1000
        log_step(field_hash, "INDICES", f"Index computation complete in {duration:.0f}ms")
        
        # =====================
        # COMPLETE
        # =====================
        total_duration = (datetime.now() - start_time).total_seconds()
        FieldStorage.update_metadata(field_hash,
            status=JobStatus.COMPLETE,
            progress=100,
            step="Complete",
            csv_files=get_csv_urls(field_hash),
            completed_at=datetime.now().isoformat(),
            duration_seconds=total_duration
        )
        log_step(field_hash, "COMPLETE", f"Pipeline finished successfully in {total_duration:.1f}s")
        
    except Exception as e:
        log_step(field_hash, "ERROR", f"Pipeline failed: {str(e)}", "ERROR")
        logger.error(traceback.format_exc())
        FieldStorage.update_metadata(field_hash,
            status=JobStatus.ERROR,
            progress=0,
            step="Error",
            error=str(e)
        )
    finally:
        FieldStorage.release_lock(field_hash)

# ============================================================================
# API ENDPOINTS
# ============================================================================
@app.get("/")
async def root():
    logger.info("Root endpoint accessed")
    return {
        "service": "AGROW Time Series Service",
        "version": "2.1.0",
        "endpoints": {
            "/timeseries": "POST - Get time series with predictions",
            "/predict": "POST - Start full prediction job",
            "/predict/status/{hash}": "GET - Check job status",
            "/download/{hash}/{file}": "GET - Download CSV file"
        },
        "csv_files": [
            "sar_data.csv - Historical Sentinel-1 SAR data",
            "sentinel2_data.csv - Historical Sentinel-2 optical data",
            "sar_predictions.csv - SAR band predictions",
            "sentinel2_predictions.csv - Optical band predictions",
            "indices.csv - Computed vegetation indices"
        ]
    }

@app.get("/health")
async def health():
    return {"status": "healthy", "version": "2.1.0"}


@app.get("/download/{field_hash}/{filename}")
async def download_csv(field_hash: str, filename: str):
    """Download a specific CSV file for a field."""
    logger.info(f"Download request: {field_hash}/{filename}")
    
    valid_files = ["sar_data.csv", "sentinel2_data.csv", "sar_predictions.csv", 
                   "sentinel2_predictions.csv", "indices.csv"]
    
    if filename not in valid_files:
        raise HTTPException(400, f"Invalid filename. Valid files: {valid_files}")
    
    file_path = os.path.join(FieldStorage.get_field_dir(field_hash), filename)
    
    if not os.path.exists(file_path):
        raise HTTPException(404, f"File not found: {filename}")
    
    return FileResponse(
        file_path,
        media_type="text/csv",
        filename=f"{field_hash}_{filename}"
    )


@app.post("/predict", response_model=PredictResponse)
async def start_prediction(request: PredictRequest):
    """Start prediction pipeline for coordinates."""
    polygon = [(coord[0], coord[1]) for coord in request.polygon_coords]
    field_hash = FieldStorage.get_field_hash(polygon)
    field_name = request.field_name or f"Field_{field_hash[:6]}"
    
    logger.info(f"Prediction request: {field_name} (hash: {field_hash})")
    
    # Check if already complete
    if FieldStorage.field_exists(field_hash):
        metadata = FieldStorage.get_metadata(field_hash)
        return PredictResponse(
            job_id=field_hash,
            field_hash=field_hash,
            status="complete",
            message="Data ready. Use download endpoints to get CSV files.",
            csv_files=get_csv_urls(field_hash),
            created_at=metadata.get("created_at")
        )
    
    # Check if job is running
    if FieldStorage.is_locked(field_hash):
        metadata = FieldStorage.get_metadata(field_hash) or {}
        return PredictResponse(
            job_id=field_hash,
            field_hash=field_hash,
            status="processing",
            message=f"Job running: {metadata.get('step', 'Processing...')}",
            created_at=metadata.get("created_at")
        )
    
    # Acquire lock and start job
    if not FieldStorage.acquire_lock(field_hash):
        return PredictResponse(
            job_id=field_hash,
            field_hash=field_hash,
            status="processing",
            message="Job starting..."
        )
    
    FieldStorage.update_metadata(field_hash,
        field_name=field_name,
        polygon_coords=polygon,
        status=JobStatus.PENDING,
        progress=0,
        step="Initializing...",
        created_at=datetime.now().isoformat()
    )
    
    executor.submit(run_prediction_job, field_hash, polygon, field_name)
    
    return PredictResponse(
        job_id=field_hash,
        field_hash=field_hash,
        status="processing",
        message="Prediction job started. Poll /predict/status/{hash} for progress.",
        created_at=datetime.now().isoformat()
    )


@app.get("/predict/status/{field_hash}", response_model=StatusResponse)
async def get_status(field_hash: str):
    """Get job status with CSV file links."""
    metadata = FieldStorage.get_metadata(field_hash)
    
    if not metadata:
        raise HTTPException(404, f"No job found: {field_hash}")
    
    csv_files = None
    if metadata.get("status") == JobStatus.COMPLETE:
        csv_files = get_csv_urls(field_hash)
    
    return StatusResponse(
        field_hash=field_hash,
        status=metadata.get("status", "unknown"),
        progress=metadata.get("progress", 0),
        step=metadata.get("step", "Unknown"),
        message=metadata.get("error"),
        csv_files=csv_files,
        created_at=metadata.get("created_at"),
        completed_at=metadata.get("completed_at")
    )


@app.post("/timeseries", response_model=TimeSeriesResponse)
async def get_timeseries(request: TimeSeriesRequest):
    """Get time series with predictions for a single metric."""
    req_id = uuid.uuid4().hex[:8]
    logger.info(f"[{req_id}] TimeSeries request: {request.metric} at ({request.center_lat}, {request.center_lon})")
    
    polygon = coords_to_polygon(request.center_lat, request.center_lon, request.field_size_hectares)
    field_hash = FieldStorage.get_field_hash(polygon)
    
    # Computed vegetation indices and their required bands
    COMPUTED_INDICES = {
        'NDVI': {'bands': ['B08', 'B04'], 'formula': lambda b08, b04: (b08 - b04) / (b08 + b04) if (b08 + b04) != 0 else 0},
        'NDRE': {'bands': ['B08', 'B05'], 'formula': lambda b08, b05: (b08 - b05) / (b08 + b05) if (b08 + b05) != 0 else 0},
        'PRI':  {'bands': ['B03', 'B04'], 'formula': lambda b03, b04: (b03 - b04) / (b03 + b04) if (b03 + b04) != 0 else 0},
        'EVI':  {'bands': ['B08', 'B04', 'B02'], 'formula': lambda b08, b04, b02: 2.5 * (b08 - b04) / (b08 + 6 * b04 - 7.5 * b02 + 1) if (b08 + 6 * b04 - 7.5 * b02 + 1) != 0 else 0},
    }
    
    # Check cache first
    if FieldStorage.field_exists(field_hash):
        logger.info(f"[{req_id}] Using cached data for {field_hash}")
        data = FieldStorage.get_all_data(field_hash)
        
        historical = []
        forecast = []
        
        if request.metric in ['VV', 'VH']:
            col = f"{request.metric}_mean_dB"
            if data.get("sar_data"):
                for row in data["sar_data"]:
                    if col in row and row[col] is not None:
                        historical.append(DataPoint(date=str(row['ds']), value=round(float(row[col]), 4)))
            if data.get("sar_predictions"):
                for row in data["sar_predictions"]:
                    if col in row and row[col] is not None:
                        value = round(float(row[col]), 4)
                        forecast.append(ForecastPoint(
                            date=str(row['ds']),
                            value=value,
                            confidence_low=round(value * 0.9, 4),
                            confidence_high=round(value * 1.1, 4)
                        ))
        
        # Handle computed vegetation indices
        elif request.metric in COMPUTED_INDICES:
            index_info = COMPUTED_INDICES[request.metric]
            bands = index_info['bands']
            formula = index_info['formula']
            
            logger.info(f"[{req_id}] Computing {request.metric} from bands: {bands}")
            
            # Compute from historical data
            if data.get("sentinel2_data"):
                for row in data["sentinel2_data"]:
                    # Check if all required bands are present
                    if all(b in row and row[b] is not None for b in bands):
                        try:
                            band_values = [float(row[b]) for b in bands]
                            computed_value = formula(*band_values)
                            # Clamp to valid range
                            computed_value = max(-1.0, min(1.0, computed_value))
                            historical.append(DataPoint(date=str(row['ds']), value=round(computed_value, 4)))
                        except (ValueError, ZeroDivisionError):
                            pass
            
            # Compute from prediction data
            if data.get("sentinel2_predictions"):
                for row in data["sentinel2_predictions"]:
                    if all(b in row and row[b] is not None for b in bands):
                        try:
                            band_values = [float(row[b]) for b in bands]
                            computed_value = formula(*band_values)
                            computed_value = max(-1.0, min(1.0, computed_value))
                            forecast.append(ForecastPoint(
                                date=str(row['ds']),
                                value=round(computed_value, 4),
                                confidence_low=round(computed_value * 0.9, 4),
                                confidence_high=round(computed_value * 1.1, 4)
                            ))
                        except (ValueError, ZeroDivisionError):
                            pass
        
        # Raw Sentinel-2 bands
        else:
            if data.get("sentinel2_data"):
                for row in data["sentinel2_data"]:
                    if request.metric in row and row[request.metric] is not None:
                        historical.append(DataPoint(date=str(row['ds']), value=round(float(row[request.metric]), 4)))
            if data.get("sentinel2_predictions"):
                for row in data["sentinel2_predictions"]:
                    if request.metric in row and row[request.metric] is not None:
                        value = round(float(row[request.metric]), 4)
                        forecast.append(ForecastPoint(
                            date=str(row['ds']),
                            value=value,
                            confidence_low=round(value * 0.9, 4),
                            confidence_high=round(value * 1.1, 4)
                        ))
        
        if historical:
            all_values = [p.value for p in historical]
            return TimeSeriesResponse(
                success=True,
                metric=request.metric,
                field_hash=field_hash,
                historical=historical,
                forecast=forecast,
                trend=calculate_trend(all_values),
                stats={
                    "min": round(min(all_values), 4),
                    "max": round(max(all_values), 4),
                    "mean": round(sum(all_values) / len(all_values), 4),
                    "count": len(historical),
                    "forecast_count": len(forecast)
                },
                csv_files=get_csv_urls(field_hash),
                timestamp=datetime.now().isoformat()
            )
    
    # No cache - run on-demand
    logger.info(f"[{req_id}] No cache, running on-demand prediction for {field_hash}")
    
    # Create field-specific directory for on-demand data
    field_dir = FieldStorage.get_field_dir(field_hash)
    os.makedirs(field_dir, exist_ok=True)
    
    try:
        fetcher = SatelliteFetcher(polygon)
        
        if request.metric in ['VV', 'VH']:
            csv_file = os.path.join(field_dir, 'sar_data.csv')
            # Only fetch if file doesn't exist (avoid race condition)
            if not os.path.exists(csv_file):
                fetcher.fetch_sar_data(csv_file)
            target_col = f'{request.metric}_mean_dB'
        else:
            csv_file = os.path.join(field_dir, 'sentinel2_data.csv')
            # Only fetch if file doesn't exist (avoid race condition)
            if not os.path.exists(csv_file):
                fetcher.fetch_sentinel2_data(csv_file)
            # For computed indices, we'll compute them after loading the data
            # Raw bands can use direct column name
            target_col = request.metric
        
        if not os.path.exists(csv_file):
            raise HTTPException(404, "No satellite data available")
        
        df = pd.read_csv(csv_file)
        logger.info(f"[{req_id}] Loaded {len(df)} rows from {csv_file}")
        
        # Handle computed vegetation indices
        if request.metric in COMPUTED_INDICES:
            index_info = COMPUTED_INDICES[request.metric]
            bands = index_info['bands']
            formula = index_info['formula']
            
            logger.info(f"[{req_id}] Computing {request.metric} from bands: {bands}")
            
            # Check all required bands exist
            missing_bands = [b for b in bands if b not in df.columns]
            if missing_bands:
                raise HTTPException(400, f"Missing bands for {request.metric}: {missing_bands}")
            
            # Compute the index for each row
            computed_values = []
            for _, row in df.iterrows():
                if all(pd.notna(row[b]) for b in bands):
                    try:
                        band_values = [float(row[b]) for b in bands]
                        computed_value = formula(*band_values)
                        computed_value = max(-1.0, min(1.0, computed_value))  # Clamp
                        computed_values.append({
                            'ds': row['ds'],
                            'value': round(computed_value, 4)
                        })
                    except (ValueError, ZeroDivisionError):
                        pass
            
            if len(computed_values) < 10:
                raise HTTPException(400, f"Insufficient data after computing {request.metric}: {len(computed_values)} points")
            
            historical = [
                DataPoint(date=str(v['ds']), value=v['value'])
                for v in computed_values
            ]
            
            # For forecast, return simplified prediction based on recent trend
            # (Full AutoNHITS on computed indices is complex, use last 30 days average)
            recent_values = [v['value'] for v in computed_values[-30:]]
            avg_value = sum(recent_values) / len(recent_values) if recent_values else 0
            
            forecast = []
            from datetime import timedelta
            last_date = pd.to_datetime(computed_values[-1]['ds'])
            for i in range(1, 31):
                future_date = last_date + timedelta(days=i)
                # Simple trend continuation with slight variation
                variation = 0.02 * (i / 30)  # Increasing uncertainty over time
                forecast.append(ForecastPoint(
                    date=str(future_date.date()),
                    value=round(avg_value, 4),
                    confidence_low=round(avg_value - variation, 4),
                    confidence_high=round(avg_value + variation, 4)
                ))
            
            all_values = [p.value for p in historical]
            
        else:
            # Raw band/metric - use direct column
            historical = []
            for _, row in df.iterrows():
                if target_col in row and not pd.isna(row[target_col]):
                    historical.append(DataPoint(
                        date=str(row['ds']),
                        value=round(float(row[target_col]), 4)
                    ))
            
            if len(historical) < 10:
                raise HTTPException(400, f"Insufficient data: {len(historical)} points")
            
            logger.info(f"[{req_id}] Running AutoNHITS prediction...")
            predictor = AutoTimeSeriesPredictor()
            
            predictions = predictor.tune_and_predict(
                csv_path=csv_file,
                field_coords=polygon,
                target_col=target_col,
                output_file='predictions.csv',
                num_samples=3
            )
            
            forecast = []
            for _, row in predictions.iterrows():
                value = float(row['predicted_y'])
                forecast.append(ForecastPoint(
                    date=str(row['ds'].date()) if hasattr(row['ds'], 'date') else str(row['ds']),
                    value=round(value, 4),
                    confidence_low=round(value * 0.9, 4),
                    confidence_high=round(value * 1.1, 4)
                ))
            
            all_values = [p.value for p in historical]
        
        # Cleanup
        for f in ['sar_data.csv', 'sentinel2_data.csv', 'predictions.csv']:
            if os.path.exists(f):
                os.remove(f)
        
        logger.info(f"[{req_id}] Success: {len(historical)} historical, {len(forecast)} forecast points")
        
        return TimeSeriesResponse(
            success=True,
            metric=request.metric,
            field_hash=field_hash,
            historical=historical,
            forecast=forecast,
            trend=calculate_trend(all_values[-20:] if len(all_values) > 20 else all_values),
            stats={
                "min": round(min(all_values), 4),
                "max": round(max(all_values), 4),
                "mean": round(sum(all_values) / len(all_values), 4),
                "count": len(all_values),
                "forecast_count": len(forecast)
            },
            csv_files={},
            timestamp=datetime.now().isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[{req_id}] Error: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(500, str(e))


if __name__ == "__main__":
    import uvicorn
    logger.info("Starting AGROW Time Series Service v2.1.0")
    uvicorn.run(app, host="0.0.0.0", port=7860)
