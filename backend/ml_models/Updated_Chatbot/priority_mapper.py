"""
Priority Context Mapper for Agricultural Chatbot
=================================================
Maps detected intents to prioritized context selection.
Following Developer Specification exactly.
"""

from typing import Dict, List, Any, Optional

# =============================================================================
# INTENT TO CONTEXT PRIORITY MAPPING (From Developer Spec)
# =============================================================================

INTENT_CONTEXT_PRIORITIES = {
    "vegetation_health": {
        "priority_1": ["NDVI", "EVI", "NDRE", "RECI", "temporal_trends.NDVI"],
        "priority_2": ["clustering.stressed_patches", "anomalies", "PSRI", "PRI"],
        "priority_3": ["weather.temperature", "SMI", "B05", "B08", "weather.heat_stress"],
        "priority_4": ["SAR.VV", "SAR.VH", "previous_analysis", "farmer_actions"]
    },
    
    "water_stress": {
        "priority_1": ["SMI", "NDWI", "SAR.VV", "SAR.VH", "soil_indicators.moisture"],
        "priority_2": ["temporal_trends.SMI", "weather.precipitation", "weather.evapotranspiration"],
        "priority_3": ["NDVI", "clustering.moisture_clusters", "B11", "B12", "sentinel2_bands.B11"],
        "priority_4": ["farmer_actions.irrigation", "forecast.rain", "previous_analysis"]
    },
    
    "nutrient_status": {
        "priority_1": ["NDRE", "RECI", "MCARI", "B05", "B06", "B07", "sentinel2_bands.B05"],
        "priority_2": ["NDVI", "EVI", "temporal_trends.NDRE"],
        "priority_3": ["SMI", "SFI", "SOMI", "clustering.nutrient_clusters", "soil_indicators.fertility"],
        "priority_4": ["farmer_actions.fertilizer", "weather", "previous_analysis"]
    },
    
    "pest_disease": {
        "priority_1": ["anomalies", "PSRI", "PRI", "spatial_patterns.hotspots", "clustering.outliers"],
        "priority_2": ["NDVI", "temporal_trends.sudden_changes", "clustering.stressed_patches"],
        "priority_3": ["weather.humidity", "weather.temperature", "B04", "B05"],
        "priority_4": ["farmer_actions.spraying", "previous_analysis", "historical_issues"]
    },
    
    "zone_specific": {
        "priority_1": ["clustering.zone_stats", "patch_assignments", "spatial_embeddings", "clustering.clusters"],
        "priority_2": ["anomalies.in_zone", "vegetation_indices", "all_indices.zone_values"],
        "priority_3": ["temporal_trends.zone_specific", "temporal_trends"],
        "priority_4": ["previous_analysis.zone_notes", "farmer_actions.zone_specific"]
    },
    
    "forecast_query": {
        "priority_1": ["forecast.predictions", "temporal_trends", "weather.forecast", "weather_data"],
        "priority_2": ["NDVI", "SMI", "current_stress_level", "health_summary"],
        "priority_3": ["historical_patterns", "growth_stage", "clustering"],
        "priority_4": ["farmer_actions.planned", "previous_analysis"]
    },
    
    "action_recommendation": {
        "priority_1": ["health_summary", "NDVI", "SMI", "anomalies", "stressed_patches"],
        "priority_2": ["weather", "weather.forecast", "clustering.priority_zones"],
        "priority_3": ["temporal_trends", "soil_indicators"],
        "priority_4": ["farmer_actions", "previous_analysis", "recommendations_history"]
    },
    
    "comparison": {
        "priority_1": ["temporal_trends", "historical.NDVI", "historical.SMI"],
        "priority_2": ["change_detection", "improvement_metrics"],
        "priority_3": ["weather.historical", "farmer_actions.historical"],
        "priority_4": ["previous_analysis", "baseline_values"]
    },
    
    "general_query": {
        "priority_1": ["NDVI", "health_summary", "weather", "field_info"],
        "priority_2": ["SMI", "anomalies", "clustering.summary", "vegetation_indices"],
        "priority_3": ["temporal_trends", "forecast", "soil_indicators"],
        "priority_4": ["farmer_actions", "previous_analysis"]
    }
}


# =============================================================================
# PRIORITY CONTEXT MAPPER
# =============================================================================

class PriorityContextMapper:
    """
    Maps intents to prioritized context for selective retrieval.
    Key principle: NOT all context at once - priority-based selection.
    """
    
    def __init__(self):
        self.priority_map = INTENT_CONTEXT_PRIORITIES
    
    def get_context_priorities(self, intent: str) -> Dict[str, List[str]]:
        """Get context priorities for a given intent."""
        return self.priority_map.get(intent, self.priority_map["general_query"])
    
    def extract_priority_context(
        self, 
        intent: str, 
        full_context: Dict[str, Any],
        priority_levels: List[int] = [1, 2, 3, 4]
    ) -> Dict[str, Dict[str, Any]]:
        """
        Extract context based on priority levels.
        
        Args:
            intent: Detected intent
            full_context: Complete context data from aggregator
            priority_levels: Which priority levels to include
            
        Returns:
            {
                "priority_1": {...},
                "priority_2": {...},
                ...
            }
        """
        priorities = self.get_context_priorities(intent)
        result = {}
        
        for level in priority_levels:
            key = f"priority_{level}"
            if key in priorities:
                result[key] = self._extract_fields(
                    full_context, 
                    priorities[key]
                )
        
        return result
    
    def _extract_fields(
        self, 
        context: Dict[str, Any], 
        field_paths: List[str]
    ) -> Dict[str, Any]:
        """Extract specific fields from context using dot notation paths."""
        extracted = {}
        
        for path in field_paths:
            value = self._get_nested_value(context, path)
            if value is not None:
                # Use last part of path as key
                key = path.split(".")[-1]
                extracted[key] = value
        
        return extracted
    
    def _get_nested_value(self, data: Dict, path: str) -> Any:
        """Get nested value using dot notation (e.g., 'weather.temperature')."""
        if not data or not path:
            return None
        
        keys = path.split(".")
        current = data
        
        for key in keys:
            if isinstance(current, dict):
                # Try exact match first
                if key in current:
                    current = current[key]
                # Try case-insensitive match
                elif key.upper() in current:
                    current = current[key.upper()]
                elif key.lower() in current:
                    current = current[key.lower()]
                else:
                    return None
            else:
                return None
        
        return current
    
    def build_staged_context(
        self,
        intent: str,
        full_context: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Build context organized by reasoning stages.
        
        Returns:
            {
                "claim_context": {...},      # Priority 1 - for initial hypothesis
                "validate_context": {...},   # Priority 2 - supporting evidence
                "contradict_context": {...}, # Priority 3 - causal factors
                "confirm_context": {...}     # Priority 4 - validation
            }
        """
        priority_context = self.extract_priority_context(intent, full_context)
        
        # Also add full vegetation indices if available for easier access
        veg = full_context.get("vegetation_indices", {})
        
        claim = priority_context.get("priority_1", {})
        validate = priority_context.get("priority_2", {})
        contradict = priority_context.get("priority_3", {})
        confirm = priority_context.get("priority_4", {})
        
        # Enrich with direct index access if not already present
        if veg:
            for idx in ["NDVI", "EVI", "NDRE", "SMI", "NDWI"]:
                if idx in veg and idx not in claim:
                    claim[idx] = veg[idx]
        
        # Add field info to claim context
        field_info = full_context.get("field_info", {})
        if field_info:
            claim["crop_type"] = field_info.get("crop_type")
            claim["area_acres"] = field_info.get("area_acres")
        
        # Add SAR data to confirm context
        sar = full_context.get("sar_bands", {})
        if sar and "VV" not in confirm:
            confirm["SAR"] = sar
        
        # Add farmer actions if available
        farmer = full_context.get("farmer_actions", {})
        if farmer:
            confirm["farmer_actions"] = farmer
        
        # Add previous analysis
        prev = full_context.get("previous_analysis", {})
        if prev:
            confirm["previous_analysis"] = prev
        
        return {
            "claim_context": claim,
            "validate_context": validate,
            "contradict_context": contradict,
            "confirm_context": confirm
        }
    
    def get_context_for_stage(
        self,
        stage: str,
        intent: str,
        full_context: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Get context for a specific reasoning stage."""
        staged = self.build_staged_context(intent, full_context)
        
        stage_map = {
            "claim": "claim_context",
            "validate": "validate_context", 
            "contradict": "contradict_context",
            "confirm": "confirm_context"
        }
        
        return staged.get(stage_map.get(stage, "claim_context"), {})
