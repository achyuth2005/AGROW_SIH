"""
Context Aggregator for Agricultural Chatbot
=============================================
Fetches satellite data from HF Space APIs and formats for priority-based retrieval.
Supports all data sources: SAR, Sentinel-2, Heatmap, Weather APIs.
"""

import os
import logging
import requests
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta

logger = logging.getLogger("ContextAggregator")

# HF Space URLs - Your deployed backends
SAR_API_URL = os.getenv("SAR_API_URL", "https://aniket2006-agrow-backend-v2.hf.space")
SENTINEL2_API_URL = os.getenv("SENTINEL2_API_URL", "https://aniket2006-agrow-sentinel2.hf.space")
HEATMAP_API_URL = os.getenv("HEATMAP_API_URL", "https://aniket2006-heatmap.hf.space")


class ContextAggregator:
    """
    Aggregates satellite data from multiple HF Space APIs.
    Returns structured data organized by priority levels for reasoning stages.
    """
    
    def __init__(self, timeout: int = 45):
        self.timeout = timeout
        self._cache = {}
        self._cache_ttl = 300  # 5 minutes
    
    def fetch_full_context(
        self,
        coordinates: Dict[str, Any],
        crop_type: str = "Wheat",
        area_acres: float = 1.0,
        farmer_context: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """
        Fetch complete satellite context for a field.
        
        Args:
            coordinates: {"center_lat": float, "center_lon": float, "bbox": [...]}
            crop_type: Type of crop
            area_acres: Field size in acres
            farmer_context: Farmer profile and action data
            
        Returns:
            Structured context with all satellite data
        """
        context = {
            "fetch_timestamp": datetime.now().isoformat(),
            "field_info": {
                "crop_type": crop_type,
                "area_acres": area_acres,
                "coordinates": coordinates
            }
        }
        
        if not coordinates:
            return context
        
        center_lat = coordinates.get("center_lat")
        center_lon = coordinates.get("center_lon")
        bbox = coordinates.get("bbox")
        
        if not center_lat or not center_lon:
            return context
        
        # 1. Fetch SAR analysis (VV, VH bands, patches, predictions)
        sar_data = self._fetch_sar_data(bbox, crop_type, farmer_context)
        if sar_data:
            context["sar_bands"] = self._extract_sar_bands(sar_data)
            context["patches"] = sar_data.get("patches", [])
            context["stressed_patches"] = [p for p in sar_data.get("patches", []) 
                                           if p.get("stress_score", 0) > 0.5]
            context["health_summary"] = sar_data.get("health_summary", {})
            context["temporal_trends"] = sar_data.get("temporal_trends", {})
            context["weather_data"] = sar_data.get("weather_data", [])
        
        # 2. Fetch Sentinel-2 analysis (vegetation indices)
        field_hectares = area_acres * 0.404686
        s2_data = self._fetch_sentinel2_data(center_lat, center_lon, crop_type, 
                                             field_hectares, farmer_context)
        if s2_data:
            context["vegetation_indices"] = self._extract_vegetation_indices(s2_data)
            context["soil_indicators"] = self._extract_soil_indicators(s2_data)
            context["llm_analysis"] = s2_data.get("llm_analysis", {})
            context["sentinel2_bands"] = s2_data.get("band_values", {})
            context["clustering"] = self._extract_clustering(s2_data)
            context["anomalies"] = self._extract_anomalies(s2_data)
        
        # 3. Add farmer context if provided
        if farmer_context:
            context["farmer_profile"] = farmer_context.get("profile", {})
            context["farmer_actions"] = farmer_context.get("actions", {})
        
        # 4. Fetch comprehensive weather from Open-Meteo (free API)
        weather = self._fetch_weather_openmeteo(center_lat, center_lon)
        if weather:
            context["weather"] = weather
            logger.info("Weather data fetched from Open-Meteo")
        
        # 5. Compute historical trends from temporal data
        if context.get("temporal_trends") or context.get("vegetation_indices"):
            trends = self._compute_historical_trends(
                context.get("vegetation_indices", {}),
                context.get("temporal_trends", {})
            )
            context["historical_trends"] = trends
            logger.info(f"Historical trends computed: {trends.get('summary', 'N/A')}")
        
        # 6. Identify priority zones from patches
        patches = context.get("patches", []) + context.get("anomalies", {}).get("high_priority", [])
        if patches:
            zone_data = self._identify_priority_zones(patches)
            context["zone_analysis"] = zone_data
            if zone_data.get("most_critical"):
                logger.info(f"Priority zone: {zone_data['most_critical'].get('location', 'N/A')}")
        
        # 7. Add previous analysis if available
        if sar_data:
            context["previous_analysis"] = {
                "date": datetime.now().isoformat(),
                "source": "sar_analysis",
                "summary": sar_data.get("llm_analysis", {}).get("summary", "")
            }
        
        return context
    
    def _fetch_sar_data(
        self, 
        bbox: List[float], 
        crop_type: str,
        farmer_context: Optional[Dict]
    ) -> Optional[Dict]:
        """Fetch SAR analysis from HF Space."""
        if not bbox or len(bbox) < 4:
            return None
        
        try:
            response = requests.post(
                f"{SAR_API_URL}/analyze",
                json={
                    "coordinates": bbox,
                    "date": datetime.now().strftime("%Y-%m-%d"),
                    "crop_type": crop_type,
                    "farmer_context": farmer_context
                },
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                data = response.json()
                logger.info(f"SAR data fetched: {list(data.keys())}")
                return data
            else:
                logger.warning(f"SAR API error: {response.status_code}")
                return None
                
        except Exception as e:
            logger.error(f"SAR fetch error: {e}")
            return None
    
    def _fetch_sentinel2_data(
        self,
        center_lat: float,
        center_lon: float,
        crop_type: str,
        field_hectares: float,
        farmer_context: Optional[Dict]
    ) -> Optional[Dict]:
        """Fetch Sentinel-2 analysis from HF Space."""
        try:
            response = requests.post(
                f"{SENTINEL2_API_URL}/analyze",
                json={
                    "center_lat": center_lat,
                    "center_lon": center_lon,
                    "crop_type": crop_type,
                    "analysis_date": datetime.now().strftime("%Y-%m-%d"),
                    "field_size_hectares": field_hectares,
                    "farmer_context": farmer_context or {},
                    "skip_llm": True  # Chatbot does its own reasoning - skip Sentinel2's LLM call
                },
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                data = response.json()
                logger.info(f"Sentinel-2 data fetched: {list(data.keys())}")
                return data
            else:
                logger.warning(f"Sentinel-2 API error: {response.status_code}")
                return None
                
        except Exception as e:
            logger.error(f"Sentinel-2 fetch error: {e}")
            return None
    
    def _fetch_heatmap_metric(
        self,
        center_lat: float,
        center_lon: float,
        field_hectares: float,
        metric: str
    ) -> Optional[Dict]:
        """Fetch a specific heatmap metric."""
        try:
            response = requests.post(
                f"{HEATMAP_API_URL}/generate-heatmap",
                json={
                    "center_lat": center_lat,
                    "center_lon": center_lon,
                    "field_size_hectares": field_hectares,
                    "metric": metric,
                    "gaussian_sigma": 1.5,
                    "show_field_boundary": False
                },
                timeout=60
            )
            
            if response.status_code == 200:
                return response.json()
            return None
                
        except Exception as e:
            logger.error(f"Heatmap fetch error for {metric}: {e}")
            return None
    
    # =========================================================================
    # DATA EXTRACTION HELPERS
    # =========================================================================
    
    def _extract_sar_bands(self, data: Dict) -> Dict:
        """Extract SAR analysis data."""
        # SAR API returns: status, crop_health, health_summary, average_stress_score, etc.
        return {
            "crop_health": data.get("crop_health", "unknown"),
            "confidence": data.get("confidence_score", 0),
            "stress_score": data.get("average_stress_score", 0),
            "summary": data.get("summary", ""),
            "health_summary": data.get("health_summary", {}),
            "recommendations": data.get("recommendations", [])
        }
    
    def _interpret_sar(self, vv: Optional[float], vh: Optional[float]) -> str:
        """Interpret SAR band values."""
        if vv is None:
            return "no_data"
        if vv > -8:
            return "wet_soil_or_water"
        elif vv > -12:
            return "moist_soil"
        elif vv > -16:
            return "moderate_soil"
        else:
            return "dry_soil"
    
    def _extract_vegetation_indices(self, data: Dict) -> Dict:
        """Extract and structure vegetation indices."""
        # Try both possible keys from API response
        veg = data.get("vegetation_indices", {}) or data.get("vegetation_indices_summary", {})
        
        result = {}
        for idx in ["ndvi", "evi", "ndre", "reci", "ndwi", "smi", "psri", "pri", "mcari"]:
            if idx in veg:
                val = veg[idx]
                if isinstance(val, dict):
                    result[idx.upper()] = {
                        "current": val.get("mean"),
                        "min": val.get("min"),
                        "max": val.get("max"),
                        "trend": val.get("trend"),
                        "interpretation": self._interpret_index(idx, val.get("mean"))
                    }
                elif isinstance(val, (int, float)):
                    result[idx.upper()] = {
                        "current": val,
                        "interpretation": self._interpret_index(idx, val)
                    }
        
        # Add temporal trends if available
        trends = data.get("temporal_trends", {})
        if trends:
            for idx, trend in trends.items():
                if idx.upper() in result:
                    result[idx.upper()]["trend_7d"] = trend.get("change_7d")
                    result[idx.upper()]["trend_30d"] = trend.get("change_30d")
        
        return result
    
    def _interpret_index(self, index: str, value: Optional[float]) -> str:
        """Interpret vegetation index value."""
        if value is None:
            return "no_data"
        
        index = index.lower()
        
        if index == "ndvi":
            if value > 0.7: return "excellent_vegetation"
            elif value > 0.5: return "healthy_vegetation"
            elif value > 0.3: return "moderate_stress"
            elif value > 0.1: return "severe_stress"
            else: return "bare_soil_or_water"
        
        elif index == "ndre":
            if value > 0.5: return "high_chlorophyll"
            elif value > 0.3: return "adequate_chlorophyll"
            elif value > 0.1: return "low_chlorophyll"
            else: return "chlorophyll_deficiency"
        
        elif index == "smi":
            if value > 0.6: return "adequate_moisture"
            elif value > 0.4: return "moderate_moisture"
            elif value > 0.2: return "low_moisture"
            else: return "critical_moisture_deficit"
        
        elif index == "evi":
            if value > 0.5: return "high_biomass"
            elif value > 0.3: return "moderate_biomass"
            else: return "low_biomass"
        
        elif index == "psri":
            if value > 0.2: return "senescence_stress"
            elif value > 0: return "mild_stress"
            else: return "healthy"
        
        elif index == "pri":
            if value > 0.05: return "high_photosynthetic_efficiency"
            elif value > 0: return "moderate_efficiency"
            else: return "photosynthetic_stress"
        
        return "unknown"
    
    def _extract_soil_indicators(self, data: Dict) -> Dict:
        """Extract soil health indicators."""
        soil = data.get("soil_indicators", {})
        llm = data.get("llm_analysis", {})
        
        return {
            "moisture": {
                "level": llm.get("soil_moisture", {}).get("level", "unknown"),
                "SMI_value": soil.get("smi"),
                "status": llm.get("soil_moisture", {}).get("analysis", "")
            },
            "salinity": {
                "level": llm.get("soil_salinity", {}).get("level", "unknown"),
                "status": llm.get("soil_salinity", {}).get("analysis", "")
            },
            "organic_matter": {
                "level": llm.get("organic_matter", {}).get("level", "unknown"),
                "status": llm.get("organic_matter", {}).get("analysis", "")
            },
            "fertility": {
                "level": llm.get("soil_fertility", {}).get("level", "unknown"),
                "status": llm.get("soil_fertility", {}).get("analysis", "")
            }
        }
    
    def _extract_clustering(self, data: Dict) -> Dict:
        """Extract clustering/stress zone data."""
        clustering = data.get("clustering", {})
        stress = data.get("stress_detection", {})
        
        clusters = []
        for cluster in clustering.get("clusters", []):
            clusters.append({
                "cluster_id": cluster.get("id"),
                "num_patches": cluster.get("num_patches"),
                "percentage": cluster.get("percentage"),
                "stress_score_mean": cluster.get("stress_mean"),
                "dominant_location": cluster.get("location")
            })
        
        stressed_patches = []
        for patch in stress.get("stressed_patches", []):
            if patch.get("stress_score", 0) > 0.5:
                stressed_patches.append(patch)
        
        return {
            "clusters": clusters,
            "stressed_patches": stressed_patches,
            "overall_stress_score": stress.get("overall_stress", 0)
        }
    
    def _extract_anomalies(self, data: Dict) -> Dict:
        """Extract anomaly detection results."""
        anomalies = data.get("anomaly_detection", {})
        
        return {
            "total_detected": anomalies.get("total_anomalies", 0),
            "percentage_affected": anomalies.get("anomaly_percentage", 0),
            "high_priority": [
                a for a in anomalies.get("anomaly_patches", [])
                if a.get("stress_score", 0) > 0.7
            ]
        }
    
    def _extract_weather(self, data: Dict) -> Dict:
        """Extract weather data."""
        weather = data.get("weather_data", [])
        
        if not weather:
            return {}
        
        # Aggregate last 7 days
        recent = weather[:7] if len(weather) >= 7 else weather
        
        temps = [w.get("temp_max", 0) for w in recent if w.get("temp_max")]
        precip = sum(w.get("precipitation", 0) for w in recent)
        heat_days = sum(1 for w in recent if w.get("temp_max", 0) > 35)
        dry_days = sum(1 for w in recent if w.get("precipitation", 0) == 0)
        
        return {
            "recent_7d": {
                "avg_temp_max": round(sum(temps) / len(temps), 1) if temps else None,
                "heat_stress_days": heat_days,
                "total_precipitation_mm": round(precip, 1),
                "consecutive_dry_days": dry_days
            },
            "stress_indicators": {
                "heat_stress": heat_days >= 3,
                "drought_stress": dry_days >= 5 and precip < 10
            }
        }
    
    def _fetch_weather_openmeteo(self, center_lat: float, center_lon: float) -> Dict:
        """
        Fetch comprehensive weather data from Open-Meteo (free API).
        
        Returns 7-day historical + 7-day forecast with rolling statistics
        and actionable stress indicators.
        """
        try:
            response = requests.get(
                "https://api.open-meteo.com/v1/forecast",
                params={
                    "latitude": center_lat,
                    "longitude": center_lon,
                    "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum,"
                             "relative_humidity_2m_mean,wind_speed_10m_max,"
                             "et0_fao_evapotranspiration",
                    "past_days": 7,
                    "forecast_days": 7,
                    "timezone": "Asia/Kolkata"
                },
                timeout=30
            )
            
            if response.status_code == 200:
                return self._structure_weather_response(response.json())
            else:
                logger.warning(f"Open-Meteo returned status {response.status_code}")
                return {}
                
        except Exception as e:
            logger.warning(f"Weather fetch error: {e}")
            return {}
    
    def _structure_weather_response(self, data: Dict) -> Dict:
        """Structure weather API response into historical + forecast + stats."""
        daily = data.get("daily", {})
        dates = daily.get("time", [])
        
        if not dates:
            return {}
        
        # Split into historical (first 7) and forecast (last 7)
        historical = []
        forecast = []
        today_idx = min(7, len(dates))
        
        for i, date in enumerate(dates):
            entry = {
                "date": date,
                "temp_max": daily.get("temperature_2m_max", [None] * len(dates))[i],
                "temp_min": daily.get("temperature_2m_min", [None] * len(dates))[i],
                "precipitation": daily.get("precipitation_sum", [None] * len(dates))[i],
                "humidity": daily.get("relative_humidity_2m_mean", [None] * len(dates))[i],
                "wind": daily.get("wind_speed_10m_max", [None] * len(dates))[i],
                "et0": daily.get("et0_fao_evapotranspiration", [None] * len(dates))[i]
            }
            if i < today_idx:
                historical.append(entry)
            else:
                forecast.append(entry)
        
        return {
            "historical_7d": historical,
            "forecast_7d": forecast,
            "rolling_stats": self._compute_weather_rolling_stats(historical),
            "stress_indicators": self._detect_weather_stress_indicators(historical, forecast)
        }
    
    def _compute_weather_rolling_stats(self, data: List[Dict]) -> Dict:
        """Compute rolling weather statistics for the past 7 days."""
        temps = [d["temp_max"] for d in data if d.get("temp_max") is not None]
        precip = [d["precipitation"] for d in data if d.get("precipitation") is not None]
        humidity = [d["humidity"] for d in data if d.get("humidity") is not None]
        et0 = [d["et0"] for d in data if d.get("et0") is not None]
        
        return {
            "avg_temp_7d": round(sum(temps) / len(temps), 1) if temps else None,
            "max_temp_7d": max(temps) if temps else None,
            "min_temp_7d": min(temps) if temps else None,
            "total_precip_7d": round(sum(precip), 1) if precip else 0,
            "dry_days_count": sum(1 for p in precip if p == 0),
            "heat_stress_days": sum(1 for t in temps if t > 35),
            "avg_humidity_7d": round(sum(humidity) / len(humidity), 1) if humidity else None,
            "total_et0_7d": round(sum(et0), 1) if et0 else None
        }
    
    def _detect_weather_stress_indicators(self, hist: List[Dict], fore: List[Dict]) -> Dict:
        """Detect actionable weather stress indicators."""
        h_temps = [d["temp_max"] for d in hist if d.get("temp_max")]
        f_temps = [d["temp_max"] for d in fore if d.get("temp_max")]
        h_precip = sum((d.get("precipitation") or 0) for d in hist)
        f_precip = sum((d.get("precipitation") or 0) for d in fore)
        
        # Check if recent 3 days or upcoming 3 days have heat stress
        recent_3_heat = any(t > 38 for t in h_temps[-3:]) if len(h_temps) >= 3 else False
        upcoming_3_heat = any(t > 38 for t in f_temps[:3]) if len(f_temps) >= 3 else False
        
        return {
            "current_heat_stress": recent_3_heat,
            "predicted_heat_stress": upcoming_3_heat,
            "drought_risk": h_precip < 10 and f_precip < 5,
            "flood_risk": f_precip > 100,
            "suitable_for_irrigation": f_precip < 5 and max(f_temps[:3] or [30]) < 40,
            "suitable_for_spraying": f_precip < 2 and max(f_temps[:2] or [30]) < 35
        }

    def _compute_historical_trends(self, current_indices: Dict, 
                                    temporal_trends: Dict) -> Dict:
        """
        Compute historical trend metrics comparing current vs past data.
        
        Returns trend direction (improving/declining/stable) and change percentages.
        """
        trends = {"changes": {}}
        
        # Try to compute NDVI trends
        ndvi_history = temporal_trends.get("ndvi", [])
        current_ndvi = current_indices.get("ndvi")
        
        if current_ndvi and len(ndvi_history) >= 2:
            # Get value from 7 days ago if available
            week_ago_idx = min(6, len(ndvi_history) - 1)
            week_ago = ndvi_history[week_ago_idx].get("value", current_ndvi)
            
            change_7d = current_ndvi - week_ago
            trends["changes"]["ndvi_change_7d"] = round(change_7d, 4)
            trends["changes"]["ndvi_pct_change_7d"] = round((change_7d / week_ago * 100) if week_ago else 0, 1)
            
            # Classify trend
            if change_7d > 0.03:
                trends["ndvi_trend"] = "improving"
            elif change_7d < -0.03:
                trends["ndvi_trend"] = "declining"
            else:
                trends["ndvi_trend"] = "stable"
        
        # Try to compute SMI trends (soil moisture)
        smi_history = temporal_trends.get("smi", [])
        current_smi = current_indices.get("smi")
        
        if current_smi and len(smi_history) >= 2:
            week_ago_smi = smi_history[min(6, len(smi_history) - 1)].get("value", current_smi)
            change_smi = current_smi - week_ago_smi
            trends["changes"]["smi_change_7d"] = round(change_smi, 3)
            
            if change_smi > 0.05:
                trends["smi_trend"] = "wetter"
            elif change_smi < -0.05:
                trends["smi_trend"] = "drier"
            else:
                trends["smi_trend"] = "stable"
        
        # Generate summary
        summaries = []
        if trends.get("ndvi_trend"):
            pct = abs(trends["changes"].get("ndvi_pct_change_7d", 0))
            summaries.append(f"Vegetation {trends['ndvi_trend']} ({pct:.0f}% change)")
        if trends.get("smi_trend"):
            summaries.append(f"Soil {trends['smi_trend']}")
        
        trends["summary"] = "; ".join(summaries) if summaries else "Insufficient historical data"
        
        return trends

    def _identify_priority_zones(self, patches: List[Dict]) -> Dict:
        """
        Identify zones/patches that need the most attention based on stress scores.
        
        Returns top 3 priority zones with location and issue details.
        """
        if not patches:
            return {"priority_zones": [], "most_critical": None, "total_affected_area_pct": 0}
        
        # Sort patches by stress score (highest first)
        stressed = sorted(
            [p for p in patches if p.get("stress_score", 0) > 0.3],
            key=lambda p: p.get("stress_score", 0),
            reverse=True
        )
        
        priority_zones = []
        for patch in stressed[:3]:  # Top 3 stressed zones
            # Determine location description
            location = patch.get("location_description")
            if not location:
                # Try to infer from coordinates or patch_id
                patch_id = patch.get("patch_id", patch.get("id", "Unknown"))
                location = self._infer_location_from_patch(patch_id, patch)
            
            priority_zones.append({
                "zone_id": patch.get("patch_id", patch.get("id")),
                "location": location,
                "stress_score": round(patch.get("stress_score", 0), 2),
                "primary_issue": patch.get("predicted_issue", patch.get("issue", "stress detected")),
                "area_percentage": round(patch.get("area_pct", patch.get("area_percentage", 0)), 1),
                "recommended_action": patch.get("recommended_action", "monitor closely")
            })
        
        total_affected = sum(z["area_percentage"] for z in priority_zones)
        
        return {
            "priority_zones": priority_zones,
            "most_critical": priority_zones[0] if priority_zones else None,
            "total_affected_area_pct": round(total_affected, 1),
            "zones_count": len(priority_zones)
        }
    
    def _infer_location_from_patch(self, patch_id: str, patch: Dict) -> str:
        """Infer human-readable location from patch data."""
        # Common quadrant mappings
        quadrant_map = {
            "NE": "Northeast corner",
            "NW": "Northwest corner", 
            "SE": "Southeast corner",
            "SW": "Southwest corner",
            "N": "Northern section",
            "S": "Southern section",
            "E": "Eastern section",
            "W": "Western section",
            "C": "Central area"
        }
        
        # Try to extract quadrant from patch_id
        patch_str = str(patch_id).upper()
        for abbr, name in quadrant_map.items():
            if abbr in patch_str:
                return name
        
        # Fall back to numbered zone
        if isinstance(patch_id, int) or patch_str.isdigit():
            return f"Zone {patch_id}"
        
        return f"Zone {patch_str}"


    
    # =========================================================================
    # PRIORITY-BASED CONTEXT FORMATTING
    # =========================================================================
    
    def format_for_priority(self, context: Dict, intent: str) -> Dict[str, Dict]:
        """
        Format context into priority levels based on intent.
        
        Returns:
            {
                "priority_1": {...},  # Primary evidence
                "priority_2": {...},  # Supporting evidence
                "priority_3": {...},  # Causal factors
                "priority_4": {...}   # Validation
            }
        """
        veg = context.get("vegetation_indices", {})
        sar = context.get("sar_bands", {})
        soil = context.get("soil_indicators", {})
        weather = self._extract_weather(context)
        clustering = context.get("clustering", {})
        anomalies = context.get("anomalies", {})
        farmer = context.get("farmer_actions", {})
        previous = context.get("previous_analysis", {})
        
        # Default priority mapping
        priority_1 = {
            "NDVI": veg.get("NDVI"),
            "EVI": veg.get("EVI"),
            "NDRE": veg.get("NDRE"),
            "RECI": veg.get("RECI"),
            "temporal_trends": context.get("temporal_trends", {})
        }
        
        priority_2 = {
            "clustering": clustering,
            "anomalies": anomalies,
            "PSRI": veg.get("PSRI"),
            "PRI": veg.get("PRI")
        }
        
        priority_3 = {
            "weather": weather,
            "SMI": veg.get("SMI"),
            "soil_indicators": soil,
            "B05": context.get("sentinel2_bands", {}).get("B05"),
            "B08": context.get("sentinel2_bands", {}).get("B08")
        }
        
        priority_4 = {
            "SAR": sar,
            "previous_analysis": previous,
            "farmer_actions": farmer
        }
        
        # Adjust based on intent
        if intent == "water_stress":
            priority_1 = {
                "SMI": veg.get("SMI"),
                "NDWI": veg.get("NDWI"),
                "SAR": sar,
                "temporal_trends_SMI": context.get("temporal_trends", {}).get("SMI")
            }
            priority_2["weather"] = weather
        
        elif intent == "nutrient_status":
            priority_1 = {
                "NDRE": veg.get("NDRE"),
                "RECI": veg.get("RECI"),
                "MCARI": veg.get("MCARI"),
                "B05": context.get("sentinel2_bands", {}).get("B05"),
                "B06": context.get("sentinel2_bands", {}).get("B06")
            }
        
        elif intent == "pest_disease":
            priority_1 = {
                "anomalies": anomalies,
                "PSRI": veg.get("PSRI"),
                "PRI": veg.get("PRI"),
                "clustering_outliers": clustering.get("stressed_patches", [])
            }
        
        # Filter out None values
        priority_1 = {k: v for k, v in priority_1.items() if v is not None}
        priority_2 = {k: v for k, v in priority_2.items() if v is not None}
        priority_3 = {k: v for k, v in priority_3.items() if v is not None}
        priority_4 = {k: v for k, v in priority_4.items() if v is not None}
        
        return {
            "priority_1": priority_1,
            "priority_2": priority_2,
            "priority_3": priority_3,
            "priority_4": priority_4
        }
    
    def format_for_llm(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Format aggregated context for LLM consumption.
        Backwards compatible version.
        """
        return {
            "field_info": context.get("field_info", {}),
            "vegetation_indices": context.get("vegetation_indices", {}),
            "sar_bands": context.get("sar_bands", {}),
            "health_summary": context.get("health_summary", {}),
            "stress_analysis": {
                "stressed_patch_count": len(context.get("stressed_patches", [])),
                "high_stress_patches": [p for p in context.get("stressed_patches", []) 
                                        if p.get("stress_score", 0) > 0.7]
            },
            "weather": self._extract_weather(context),
            "soil_indicators": context.get("soil_indicators", {}),
            "previous_analysis": context.get("llm_analysis", {})
        }


    def build_ultra_compact_context(self, context: Dict) -> str:
        """
        Build ULTRA-COMPACT context for Fast Lane (1-Call).
        
        Strictly filters for:
        1. Primary Health Indices (NDVI, NDRE) + Interpretation
        2. Soil Moisture (SMI) + Interpretation
        3. Weather Summary + Alerts
        4. Interpretation Strings (Crucial for 1-shot)
        
        Excludes:
        - SAR data (Too verbose)
        - Historical trends (Unless critical)
        - Raw bands
        - Patch lists (Summary only)
        """
        lines = []
        
        # 1. Primary Indicators (Health)
        veg = context.get("vegetation_indices", {})
        health_parts = []
        for k in ["NDVI", "NDRE", "EVI"]:
            val = veg.get(k)
            if val and isinstance(val, dict):
                curr = val.get("current")
                interp = val.get("interpretation", "")
                if curr is not None:
                    health_parts.append(f"{k}:{curr:.2f}({interp})")
        
        if health_parts:
            lines.append(f"[HEALTH_SIGNALS] " + " | ".join(health_parts))
            
        # 2. Secondary Indicators (Water/Stress)
        water_parts = []
        for k in ["SMI", "NDWI"]:
            val = veg.get(k)
            if val and isinstance(val, dict):
                curr = val.get("current")
                interp = val.get("interpretation", "")
                if curr is not None:
                    water_parts.append(f"{k}:{curr:.2f}({interp})")
        
        if water_parts:
            lines.append(f"[WATER_SIGNALS] " + " | ".join(water_parts))
            
        # 3. Weather Snapshot (Current + Alert)
        weather = context.get("weather", {})
        if weather:
            curr = weather.get("current", {})
            lines.append(f"[WEATHER] {curr.get('temp', '?')}°C, Rain: {curr.get('precip', '?')}mm")
            
            # Critical Alerts Only
            alerts = []
            stress = weather.get("stress_indicators", {})
            if stress.get("drought_risk"): alerts.append("DROUGHT_RISK")
            if stress.get("current_heat_stress"): alerts.append("HEAT_STRESS")
            if alerts:
                lines.append(f"[ALERTS] " + ", ".join(alerts))
                
        # 4. Stress Pattern
        analysis = context.get("stress_analysis", {})
        pct = analysis.get("impaired_percentage", 0)
        if pct > 10:
            lines.append(f"[PATTERN] {pct:.0f}% of field affected. Widespread stress.")
            
        return "\n".join(lines)

    def build_deep_dive_context(self, context: Dict, stage: str = "hypothesis") -> str:
        """
        Build specialized context for Deep Dive stages.
        """
        lines = []
        
        # Common Data (Always needed)
        lines.append(self.build_ultra_compact_context(context))
        
        if stage == "hypothesis":
            # Add History + Trends for robust hypothesis generation
            trends = context.get("historical_trends", {})
            if trends:
                summary = trends.get("summary", "")
                lines.append(f"[HISTORY] {summary}")
                
        elif stage == "adversary":
            # Add SAR + Soil + Detailed Weather for contradiction checking
            # This is data that was HIDDEN in the Fast Lane
            sar = context.get("sar_bands", {})
            if sar:
                lines.append(f"[SAR_DATA] VV:{sar.get('vv', '?')} VH:{sar.get('vh', '?')} Structure:{sar.get('interpretation', 'stable')}")
            
            soil = context.get("soil_indicators", {})
            if soil:
                lines.append(f"[SOIL_LAB] Salinity:{soil.get('salinity', {}).get('level')} Organic:{soil.get('organic_matter', {}).get('level')}")
                
        elif stage == "judge":
            # Add Farmer Context + Constraints
            farmer = context.get("farmer_profile", {})
            actions = context.get("farmer_actions", {})
            
            if farmer:
                lines.append(f"[FARMER] Goal:{farmer.get('farming_goal')} Budget:{farmer.get('budget_level', 'medium')}")
            if actions:
                lines.append(f"[ACTIONS] Irrigated:{actions.get('days_since_irrigation')} days ago. Fertilized:{actions.get('days_since_fertilizer')} days ago.")
                
        return "\n".join(lines)


# =============================================================================
# QUICK FUNCTIONS
# =============================================================================

def fetch_field_context(
    coordinates: Dict[str, Any],
    crop_type: str = "Wheat",
    area_acres: float = 1.0,
    fetch_satellite: bool = True,
    farmer_context: Optional[Dict] = None
) -> Dict[str, Any]:
    """
    Quick function to fetch and format field context.
    
    Args:
        coordinates: {"center_lat": float, "center_lon": float, "bbox": [...]}
        crop_type: Crop type string
        area_acres: Field size
        fetch_satellite: Whether to fetch from HF APIs
        farmer_context: Optional farmer data
    """
    aggregator = ContextAggregator()
    
    if fetch_satellite:
        raw_context = aggregator.fetch_full_context(
            coordinates=coordinates,
            crop_type=crop_type,
            area_acres=area_acres,
            farmer_context=farmer_context
        )
        return aggregator.format_for_llm(raw_context)
    else:
        return {
            "field_info": {
                "crop_type": crop_type,
                "area_acres": area_acres,
                "coordinates": coordinates
            }
        }


def fetch_priority_context(
    coordinates: Dict[str, Any],
    crop_type: str,
    area_acres: float,
    intent: str,
    farmer_context: Optional[Dict] = None
) -> Dict[str, Dict]:
    """
    Fetch satellite context and organize by priority for intent.
    
    Returns:
        {
            "priority_1": {...},
            "priority_2": {...},
            "priority_3": {...},
            "priority_4": {...}
        }
    """
    aggregator = ContextAggregator()
    
    raw_context = aggregator.fetch_full_context(
        coordinates=coordinates,
        crop_type=crop_type,
        area_acres=area_acres,
        farmer_context=farmer_context
    )
    
    return aggregator.format_for_priority(raw_context, intent)
