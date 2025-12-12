"""
Field Storage Manager
Handles persistent storage of prediction results with field hashing and locking.
"""

import os
import json
import hashlib
import threading
import time
from datetime import datetime
from typing import Optional, Dict, List, Tuple
from enum import Enum
import pandas as pd


class JobStatus(str, Enum):
    PENDING = "pending"
    FETCHING_SAR = "fetching_sar"
    FETCHING_S2 = "fetching_s2"
    PREDICTING_SAR = "predicting_sar"
    PREDICTING_S2 = "predicting_s2"
    COMPUTING_INDICES = "computing_indices"
    COMPLETE = "complete"
    ERROR = "error"


class FieldStorage:
    """
    Manages persistent storage for field prediction data.
    
    Storage structure:
        field_data/
        ├── {field_hash}/
        │   ├── metadata.json
        │   ├── sar_data.csv
        │   ├── sentinel2_data.csv
        │   ├── sar_predictions.csv
        │   ├── sentinel2_predictions.csv
        │   └── indices.csv
    """
    
    BASE_DIR = "field_data"
    _locks: Dict[str, threading.Lock] = {}
    _global_lock = threading.Lock()
    
    @classmethod
    def get_field_hash(cls, polygon_coords: List[Tuple[float, float]]) -> str:
        """
        Generate unique hash for field coordinates.
        Sorted to ensure same field = same hash regardless of order.
        """
        # Sort and round coordinates for consistency
        sorted_coords = sorted([(round(lon, 6), round(lat, 6)) for lon, lat in polygon_coords])
        coord_str = json.dumps(sorted_coords, sort_keys=True)
        return hashlib.sha256(coord_str.encode()).hexdigest()[:12]
    
    @classmethod
    def get_field_dir(cls, field_hash: str) -> str:
        """Get directory path for a field."""
        return os.path.join(cls.BASE_DIR, field_hash)
    
    @classmethod
    def field_exists(cls, field_hash: str) -> bool:
        """Check if field data exists and is complete."""
        metadata = cls.get_metadata(field_hash)
        return metadata is not None and metadata.get("status") == JobStatus.COMPLETE
    
    @classmethod
    def get_metadata(cls, field_hash: str) -> Optional[Dict]:
        """Get field metadata."""
        meta_path = os.path.join(cls.get_field_dir(field_hash), "metadata.json")
        if os.path.exists(meta_path):
            with open(meta_path, 'r') as f:
                return json.load(f)
        return None
    
    @classmethod
    def update_metadata(cls, field_hash: str, **kwargs):
        """Update field metadata."""
        field_dir = cls.get_field_dir(field_hash)
        os.makedirs(field_dir, exist_ok=True)
        
        meta_path = os.path.join(field_dir, "metadata.json")
        metadata = {}
        if os.path.exists(meta_path):
            with open(meta_path, 'r') as f:
                metadata = json.load(f)
        
        metadata.update(kwargs)
        metadata["updated_at"] = datetime.now().isoformat()
        
        with open(meta_path, 'w') as f:
            json.dump(metadata, f, indent=2)
    
    @classmethod
    def acquire_lock(cls, field_hash: str) -> bool:
        """
        Try to acquire lock for a field.
        Returns True if lock acquired, False if already locked.
        """
        with cls._global_lock:
            if field_hash not in cls._locks:
                cls._locks[field_hash] = threading.Lock()
            
            lock = cls._locks[field_hash]
            return lock.acquire(blocking=False)
    
    @classmethod
    def release_lock(cls, field_hash: str):
        """Release lock for a field."""
        with cls._global_lock:
            if field_hash in cls._locks:
                try:
                    cls._locks[field_hash].release()
                except RuntimeError:
                    pass  # Already released
    
    @classmethod
    def is_locked(cls, field_hash: str) -> bool:
        """Check if a field is currently locked (job running)."""
        with cls._global_lock:
            if field_hash not in cls._locks:
                return False
            return cls._locks[field_hash].locked()
    
    @classmethod
    def save_csv(cls, field_hash: str, filename: str, df: pd.DataFrame):
        """Save a CSV file to field storage."""
        field_dir = cls.get_field_dir(field_hash)
        os.makedirs(field_dir, exist_ok=True)
        df.to_csv(os.path.join(field_dir, filename), index=False)
    
    @classmethod
    def load_csv(cls, field_hash: str, filename: str) -> Optional[pd.DataFrame]:
        """Load a CSV file from field storage."""
        csv_path = os.path.join(cls.get_field_dir(field_hash), filename)
        if os.path.exists(csv_path):
            return pd.read_csv(csv_path)
        return None
    
    @classmethod
    def get_all_data(cls, field_hash: str) -> Optional[Dict]:
        """Get all stored data for a field."""
        if not cls.field_exists(field_hash):
            return None
        
        result = {
            "metadata": cls.get_metadata(field_hash),
            "sar_data": None,
            "sentinel2_data": None,
            "sar_predictions": None,
            "sentinel2_predictions": None,
            "indices": None
        }
        
        for key in ["sar_data", "sentinel2_data", "sar_predictions", "sentinel2_predictions", "indices"]:
            df = cls.load_csv(field_hash, f"{key}.csv")
            if df is not None:
                result[key] = df.to_dict(orient="records")
        
        return result
    
    @classmethod
    def list_fields(cls) -> List[Dict]:
        """List all stored fields."""
        fields = []
        if not os.path.exists(cls.BASE_DIR):
            return fields
        
        for field_hash in os.listdir(cls.BASE_DIR):
            field_dir = os.path.join(cls.BASE_DIR, field_hash)
            if os.path.isdir(field_dir):
                metadata = cls.get_metadata(field_hash)
                if metadata:
                    fields.append({
                        "hash": field_hash,
                        **metadata
                    })
        
        return fields
    
    @classmethod
    def cleanup_old_fields(cls, max_age_days: int = 30):
        """Remove fields older than max_age_days."""
        if not os.path.exists(cls.BASE_DIR):
            return
        
        cutoff = datetime.now().timestamp() - (max_age_days * 24 * 60 * 60)
        
        for field_hash in os.listdir(cls.BASE_DIR):
            metadata = cls.get_metadata(field_hash)
            if metadata:
                created = datetime.fromisoformat(metadata.get("created_at", datetime.now().isoformat()))
                if created.timestamp() < cutoff:
                    import shutil
                    shutil.rmtree(cls.get_field_dir(field_hash))
