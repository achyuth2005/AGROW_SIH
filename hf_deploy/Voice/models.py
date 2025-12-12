"""
Pydantic Models for Agricultural Chatbot
=========================================
Structured data models matching the Developer Specification.
"""

from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime


# =============================================================================
# VEGETATION INDICES MODELS
# =============================================================================

class IndexValue(BaseModel):
    """Single vegetation index with value and interpretation."""
    current: Optional[float] = None
    trend_7d: Optional[float] = None
    trend_30d: Optional[float] = None
    min: Optional[float] = None
    max: Optional[float] = None
    interpretation: Optional[str] = None
    zone_values: Optional[Dict[str, float]] = None  # NW, NE, SW, SE


class VegetationIndices(BaseModel):
    """Complete vegetation indices data."""
    NDVI: Optional[IndexValue] = None
    EVI: Optional[IndexValue] = None
    NDRE: Optional[IndexValue] = None
    RECI: Optional[IndexValue] = None
    NDWI: Optional[IndexValue] = None
    SMI: Optional[IndexValue] = None
    PSRI: Optional[IndexValue] = None
    PRI: Optional[IndexValue] = None
    MCARI: Optional[IndexValue] = None
    SOMI: Optional[IndexValue] = None
    SFI: Optional[IndexValue] = None


# =============================================================================
# SAR DATA MODELS
# =============================================================================

class SARBands(BaseModel):
    """SAR band data from Sentinel-1."""
    VV: Optional[float] = None
    VH: Optional[float] = None
    VV_VH_ratio: Optional[float] = None
    VV_trend: Optional[str] = None  # "increasing", "decreasing", "stable"
    VH_trend: Optional[str] = None
    interpretation: Optional[str] = None


# =============================================================================
# CLUSTERING/STRESS MODELS
# =============================================================================

class ClusterStats(BaseModel):
    """Statistics for a stress cluster."""
    cluster_id: int
    num_patches: int
    percentage: float  # % of field
    stress_score_mean: float
    stress_score_std: Optional[float] = None
    dominant_location: Optional[str] = None  # "northeast", "southwest", etc.
    spectral_signature: Optional[Dict[str, float]] = None


class AnomalyPatch(BaseModel):
    """Detected anomaly patch."""
    patch_id: int
    location: Optional[str] = None
    anomaly_type: str  # "spectral_outlier", "temporal_anomaly", etc.
    stress_score: float
    coordinates: Optional[List[float]] = None


class ClusteringData(BaseModel):
    """All clustering and anomaly data."""
    clusters: List[ClusterStats] = []
    stressed_clusters: List[ClusterStats] = []
    anomalies_detected: int = 0
    anomaly_patches: List[AnomalyPatch] = []


# =============================================================================
# WEATHER MODELS
# =============================================================================

class WeatherData(BaseModel):
    """Weather information."""
    avg_temp_max: Optional[float] = None
    avg_temp_min: Optional[float] = None
    heat_stress_days: Optional[int] = None
    total_precipitation_mm: Optional[float] = None
    avg_humidity: Optional[float] = None
    consecutive_dry_days: Optional[int] = None
    heat_stress: bool = False
    drought_stress: bool = False


class WeatherForecast(BaseModel):
    """Weather forecast data."""
    rain_expected: bool = False
    rain_mm: Optional[float] = None
    temperature_trend: Optional[str] = None


# =============================================================================
# FARMER CONTEXT MODELS
# =============================================================================

class FarmerActions(BaseModel):
    """Farmer's recent actions."""
    last_irrigation: Optional[str] = None  # ISO date
    days_since_irrigation: Optional[int] = None
    last_fertilizer: Optional[str] = None
    days_since_fertilizer: Optional[int] = None
    last_spraying: Optional[str] = None
    notes: List[str] = []


class FarmerProfile(BaseModel):
    """Farmer profile information."""
    role: Optional[str] = None
    years_farming: Optional[int] = None
    irrigation_method: Optional[str] = None
    farming_goal: Optional[str] = None


# =============================================================================
# PRIORITY CONTEXT MODELS
# =============================================================================

class Priority1Context(BaseModel):
    """Primary evidence - most diagnostic data."""
    NDVI: Optional[Dict] = None
    EVI: Optional[Dict] = None
    NDRE: Optional[Dict] = None
    RECI: Optional[Dict] = None
    temporal_trends: Optional[Dict] = None


class Priority2Context(BaseModel):
    """Supporting evidence - clusters, anomalies."""
    clustering: Optional[Dict] = None
    anomalies: Optional[Dict] = None
    PSRI: Optional[Dict] = None


class Priority3Context(BaseModel):
    """Causal factors - weather, soil, bands."""
    weather: Optional[Dict] = None
    SMI: Optional[Dict] = None
    band_values: Optional[Dict] = None


class Priority4Context(BaseModel):
    """Validation - SAR, previous analysis, farmer actions."""
    SAR: Optional[Dict] = None
    previous_analysis: Optional[Dict] = None
    farmer_actions: Optional[Dict] = None


# =============================================================================
# REASONING STAGE MODELS
# =============================================================================

class ClaimStage(BaseModel):
    """Stage 3A: Initial claim output."""
    initial_claim: str
    hypothesis: str
    evidence_cited: List[str] = []
    confidence: float
    uncertainties: List[str] = []


class ValidateStage(BaseModel):
    """Stage 3B: Validation output."""
    validation_result: str  # "confirmed", "weakened", "neutral"
    confidence_updated: float
    spatial_notes: Optional[str] = None
    new_evidence_summary: Optional[str] = None


class ContradictStage(BaseModel):
    """Stage 3C: Contradiction output."""
    contradiction_found: bool
    contradicting_evidence: List[str] = []
    alternative_hypothesis: Optional[str] = None
    alternative_confidence: float = 0.0
    reasoning: Optional[str] = None


class ConfirmStage(BaseModel):
    """Stage 3D: Confirmation output."""
    final_diagnosis: str
    confidence: float
    causal_chain: Optional[str] = None
    root_cause: Optional[str] = None
    symptoms: List[str] = []
    evidence_summary: Optional[Dict[str, List[str]]] = None
    recommendation: Optional[str] = None


# =============================================================================
# REASONING TRACE MODELS
# =============================================================================

class StageTrace(BaseModel):
    """Trace for a single reasoning stage."""
    hypothesis: Optional[str] = None
    result: Optional[str] = None
    found: Optional[bool] = None
    alternative: Optional[str] = None
    final: Optional[str] = None
    confidence: float
    context_used: List[str]


class ReasoningTrace(BaseModel):
    """Complete reasoning trace for transparency."""
    intent_detected: str
    intent_confidence: float
    sub_intents: List[str]
    stages: Dict[str, StageTrace]
    causal_chain: Optional[str] = None
    evidence_summary: Dict[str, List[str]]


class ContextPriorityUsed(BaseModel):
    """Which context was used at each priority level."""
    priority_1: List[str] = []
    priority_2: List[str] = []
    priority_3: List[str] = []
    priority_4: List[str] = []


# =============================================================================
# API REQUEST/RESPONSE MODELS
# =============================================================================

class ChatRequest(BaseModel):
    """Chat request from Flutter app."""
    session_id: str
    message: str
    user_id: Optional[str] = None
    field_context: Optional[Dict[str, Any]] = None
    field_name: Optional[str] = None  # Optional specific field


class ResponseContent(BaseModel):
    """Main response content."""
    message: str
    confidence: float
    diagnosis: Optional[str] = None


class ChatResponse(BaseModel):
    """Full chat response matching spec."""
    response: ResponseContent
    session_id: str
    message_id: str
    timestamp: str
    reasoning_trace: Optional[ReasoningTrace] = None
    context_priority_used: Optional[ContextPriorityUsed] = None
    suggested_followups: List[str] = []


# =============================================================================
# FULL SATELLITE CONTEXT
# =============================================================================

class FullSatelliteContext(BaseModel):
    """Complete satellite context for reasoning."""
    field_info: Dict[str, Any] = {}
    vegetation_indices: Optional[VegetationIndices] = None
    sar_bands: Optional[SARBands] = None
    clustering: Optional[ClusteringData] = None
    weather: Optional[WeatherData] = None
    weather_forecast: Optional[WeatherForecast] = None
    farmer_actions: Optional[FarmerActions] = None
    previous_analysis: Optional[Dict[str, Any]] = None
    temporal_trends: Optional[Dict[str, Any]] = None
    band_values: Optional[Dict[str, float]] = None


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def create_empty_response(session_id: str, message: str = "Unable to process") -> ChatResponse:
    """Create a fallback empty response."""
    return ChatResponse(
        response=ResponseContent(
            message=message,
            confidence=0.0,
            diagnosis=None
        ),
        session_id=session_id,
        message_id="",
        timestamp=datetime.now().isoformat(),
        reasoning_trace=None,
        context_priority_used=None,
        suggested_followups=[]
    )
