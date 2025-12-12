"""
LLM Integration for Vegetation Indices Analysis
================================================

This module integrates with Groq API to analyze vegetation indices
and provide comprehensive soil and crop insights.
"""

import os
import json
import numpy as np
from typing import Dict, Any, List, Optional

# Import from centralized Groq client
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from groq_client import call_groq, call_gemini_with_fallback

def prepare_indices_context(summary_report: Dict, crop_type: str, farmer_context: Dict, 
                           temporal_stats: Dict = None) -> str:
    """
    Prepare a comprehensive context string for the LLM including temporal statistics.
    
    Args:
        summary_report: Dictionary with all indices data
        crop_type: Type of crop being analyzed
        farmer_context: Farmer profile information
        temporal_stats: Dictionary with temporal statistics (optional)
        
    Returns:
        Formatted context string
    """
    context = f"""
CROP MONITORING ANALYSIS REQUEST

CROP INFORMATION:
- Crop Type: {crop_type}
- Analysis Period: {summary_report['dates'][0]} to {summary_report['dates'][-1]}
- Number of Images Analyzed: {summary_report['num_images']}

FARMER CONTEXT:
- Role: {farmer_context.get('role', 'Unknown')}
- Experience: {farmer_context.get('years_farming', 'Unknown')} years
- Irrigation Method: {farmer_context.get('irrigation_method', 'Unknown')}
- Farming Goal: {farmer_context.get('farming_goal', 'Unknown')}

VEGETATION INDICES DATA (ALL 13 INDICES):
"""
    
    for index_name, stats in summary_report['indices'].items():
        context += f"\n{index_name}:"
        context += f"\n  - Latest Mean Value: {stats['latest']['mean']:.4f}"
        context += f"\n  - Maximum in Field: {stats['max_in_field']:.4f}"
        context += f"\n  - Minimum in Field: {stats['min_in_field']:.4f}"
        context += f"\n  - Temporal Change (Latest - Oldest): {stats['change']:+.4f}"
        context += f"\n  - Temporal Trend (All Values): {stats['mean_values_over_time']}"
    
    
    # Add temporal statistics if provided
    if temporal_stats:
        context += "\n\nTEMPORAL STATISTICS (FEATURE ENGINEERING):\n"
        for index_name, t_stats in temporal_stats.items():
            context += f"\n{index_name} Temporal Features:"
            
            # Mean and std over time
            mean_spatial = float(np.nanmean(t_stats['mean_over_time']))
            std_spatial = float(np.nanmean(t_stats['std_over_time']))
            context += f"\n  - Spatial Mean (averaged over time): {mean_spatial:.4f}"
            context += f"\n  - Spatial Std (averaged over time): {std_spatial:.4f}"
            
            # Max and min over time
            max_val = float(np.nanmax(t_stats['max_over_time']))
            min_val = float(np.nanmin(t_stats['min_over_time']))
            range_val = float(np.nanmean(t_stats['range']))
            context += f"\n  - Maximum Value Over Time: {max_val:.4f}"
            context += f"\n  - Minimum Value Over Time: {min_val:.4f}"
            context += f"\n  - Average Range (Max-Min): {range_val:.4f}"
            
            # Temporal trend
            trend_mean = float(np.nanmean(t_stats['temporal_trend']))
            context += f"\n  - Average Temporal Trend: {trend_mean:+.4f}"
            
            # Rolling average if available
            if 'rolling_avg_3' in t_stats:
                latest_rolling = float(np.nanmean(t_stats['rolling_avg_3'][-1]))
                context += f"\n  - Latest Rolling Average (3-period): {latest_rolling:.4f}"
    
    return context

def format_stress_context(stress_context: Dict) -> str:
    """
    Format stress detection results for LLM prompt.
    
    Args:
        stress_context: Dictionary with stress detection results
        
    Returns:
        Formatted string with stress patterns, clusters, and anomalies
    """
    if not stress_context:
        return ""
        
    c = "\nDEEP LEARNING STRESS DETECTION RESULTS:\n"
    c += "=======================================\n"
    
    # Field Statistics
    fs = stress_context.get('field_statistics', {})
    c += f"Overall Field Stress Score: {fs.get('overall_stress', {}).get('mean', 0):.3f} (0=Healthy, 1=Severe Stress)\n"
    c += f"Stress Category Distribution: {fs.get('stress_distribution', {})}\n"
    
    # Cluster Statistics (Patterns)
    c += "\nIDENTIFIED CLUSTERING PATTERNS (SPATIAL-TEMPORAL BEHAVIOR):\n"
    for cluster in stress_context.get('cluster_statistics', []):
        c += f"  * Cluster {cluster['cluster_id']} ({cluster['percentage']:.1f}% of field):\n"
        c += f"    - Average Stress Score: {cluster['stress_score']['mean']:.3f}\n"
        c += f"    - Stress Variability (Std): {cluster['stress_score']['std']:.3f}\n"
        # Add key band stats if available to explain *why* it's a cluster
        if 'band_statistics' in cluster:
            c += "    - Key Spectral Characteristics:\n"
            # Just show a few key bands to keep it concise
            for band in ['B04', 'B08', 'B11']: # Red, NIR, SWIR
                if band in cluster['band_statistics']:
                    val = cluster['band_statistics'][band]['mean']
                    c += f"      {band}: {val:.4f}\n"
        
        # Add temporal trends if available
        if 'temporal_trends' in cluster:
            c += "    - Temporal Trends (Change over analysis period):\n"
            for band in ['B04', 'B08', 'B11']: # Red, NIR, SWIR
                if band in cluster['temporal_trends']:
                    trend = cluster['temporal_trends'][band]
                    c += f"      {band}: {trend['trend_direction']} ({trend['change']:+.4f})\n"

    # Anomaly Information
    anom = stress_context.get('anomaly_information', {})
    c += f"\nANOMALY DETECTION (UNUSUAL PATTERNS):\n"
    c += f"- Total Anomalies Detected: {anom.get('total_anomalies', 0)} patches ({anom.get('anomaly_percentage', 0):.1f}% of field)\n"
    if anom.get('anomaly_patches'):
        c += "- Sample Anomalies:\n"
        for p in anom['anomaly_patches'][:3]:
            c += f"  * Patch at {p['coordinates']}: Stress={p['stress_score']:.3f}, Category={p['stress_category']}\n"
            
    return c

def analyze_with_llm(summary_report: Dict, crop_type: str, farmer_context: Dict, 
                     center_lat: float, center_lon: float, field_size_hectares: float,
                     temporal_stats: Dict = None, stress_context: Dict = None) -> Dict[str, Any]:
    """
    Analyze vegetation indices using Gemini LLM and extract soil insights.
    
    Args:
        summary_report: Dictionary with all indices data
        crop_type: Type of crop
        farmer_context: Farmer profile information
        center_lat: Latitude
        center_lon: Longitude
        field_size_hectares: Field size
        temporal_stats: Dictionary with temporal statistics
        stress_context: Dictionary with stress detection results (clustering, anomalies)
    
    Returns:
        Dictionary with structured LLM analysis results
    """
    # Prepare context with temporal statistics
    indices_context = prepare_indices_context(summary_report, crop_type, farmer_context, temporal_stats)
    
    # Prepare stress context
    stress_text = format_stress_context(stress_context)
    
    # Create prompt for LLM
    # Using concatenation to avoid potential f-string parsing issues with long multi-line strings
    prompt = f"{indices_context}\n\n{stress_text}\n\n"
    prompt += "FIELD METADATA:\n"
    # Add location details
    prompt += f"- Location: Latitude {center_lat:.4f}, Longitude {center_lon:.4f}\n"
    prompt += f"- Field Size: {field_size_hectares:.2f} hectares\n\n"
    
    prompt += """Based on the vegetation indices data AND the deep learning stress detection results above, 
provide a comprehensive analysis.

Use the cluster patterns to identify distinct zones in the field.
Use the anomaly detection results to pinpoint specific problem areas.
Analyze the temporal trends in each cluster to determine if stress is worsening or recovering.
Combine the spectral indices (NDVI, NDWI, etc.) with the stress scores to explain the *cause* of stress.

You MUST respond with a valid JSON object (no markdown, no code blocks) with EXACTLY this structure:

{
  "soil_moisture": {
    "level": "Low" or "Moderate" or "High",
    "maximum_value": <float>,
    "minimum_value": <float>,
    "analysis": "Analyse mainly SMI patterns,spatial and temporal and variation,then check all other information along with the context given to give four words,not necessarily full sentences,but capture the sense which are very impactful,very simple to understand about the current soil moisture content of the overall field"
  },
  "soil_salinity": {
    "level": "Low" or "Moderate" or "High",
    "analysis": "Analyse mainly NDSI patterns,spatial and temporal and variation,then check all other information along with the context given to give four words,not necessarily full sentences,but capture the sense which are very impactful,very simple to understand about the current soil salinity of the overall field"
  },
  "organic_matter": {
    "level": "Low" or "Moderate" or "High",
    "analysis": "Analyse mainly SOMI patterns,spatial and temporal and variation,then check all other information along with the context given to give four words,not necessarily full sentences,but capture the sense which are very impactful,very simple to understand about the current soil organic matter content of the overall field"
  },
  "soil_fertility": {
    "level": "Low" or "Moderate" or "High",
    "analysis": "Analyse mainly SFI patterns,spatial and temporal and variation,then check all other information along with the context given to give four words,not necessarily full sentences,but capture the sense which are very impactful,very simple to understand about the current soil fertility of the overall field"
  },
  "Pest Rsk": {
    "level": "Low" or "Moderate" or "High",
    "analysis": "Analyse field patterns,temporal and spatial health variations very meticulously,catch the pattern and use the indices as additional confirmation to give accurate pest risk diseases and give 4 words not necessarily connected sentences,but capture the sense which are very impactful,very simple to understand about current pest risk or its spreading pattern"
  },
  "Nutrient Stress": {
    "level": "Low" or "Moderate" or "High",
    "analysis":"Analyse field patterns,temporal and spatial health variations very meticulously,catch the pattern and use NDRE,NDVI,MCARI,OSAVI as primary indices whose trends both spatial and temporal should be closely analysed and four words not neccesarily connected sentences,but capture the sense which are very impactful,very simple to understand about current nutrient stress"
  },
  "Disease Risk": {
    "level": "Low" or "Moderate" or "High",
    "analysis": "Analyse field patterns,temporal and spatial health variations very meticulously,catch the pattern be closely analysed and four words not neccesarily connected sentences,but capture the sense which are very impactful,very simple to understand about current disease rsik of the entire field,preferably a possible attacking agent/pest name"
  },
  "Stress Zone": {
    "level": "Low" or "Moderate" or "Alert",
    "analysis": "Analyse field patterns,temporal and spatial health variations very meticulously,catch the pattern be closely analysed and four words not neccesarily connected sentences,but capture the sense which are very impactful,very simple to understand about current stress zones in the entire field,the location,intensity,duration of stress or stress spread pattern in the field "
  },
  "overall_health": {
    "status": "poor" or "fair" or "good" or "excellent",
    "key_concerns": ["concern1", "concern2"],
    "recommendations": ["recommendation1", "recommendation2"]
  }
}

IMPORTANT GUIDELINES:
- For soil_moisture.maximum_value and minimum_value, use the SMI index values from the data
- For soil_salinity.trend, provide EXACTLY four words describing the trend based on SASI values
- For organic_matter.status, provide EXACTLY four words based on SOMI index values
- For soil_fertility.status, provide EXACTLY four words (not a sentence) about soil health based on SFI values
- For vegetation_stress.status, provide EXACTLY four words based on NDVI, EVI, NDRE temporal patterns
- For photosynthetic_stress.status, provide EXACTLY four words based on PRI, PSRI, RECI values
- For hotspot_detection.description, provide LESS THAN 6 words about stress direction and intensity
- For moisture_zones.description, provide NOT MORE THAN 6 words about moisture variation and trend
- Use spatial statistics (max, min, range) to identify hotspots and zones
- Consider temporal trends to detect spreading patterns
- Base your analysis on the actual index values provided
- Provide actionable insights relevant to the farmer's context

Return ONLY the JSON object, no additional text.
"""
    
    # Get LLM response using fallback system
    response_text = call_gemini_with_fallback(prompt).strip()
    
    # Remove markdown code blocks if present
    if response_text.startswith("```"):
        lines = response_text.split("\n")
        response_text = "\n".join(lines[1:-1])
    if response_text.startswith("json"):
        response_text = response_text[4:].strip()
    
    # Parse JSON response
    try:
        analysis = json.loads(response_text)
        
        # Normalize keys to snake_case for frontend consistency
        key_mapping = {
            'Pest Rsk': 'pest_risk',
            'Pest Risk': 'pest_risk',
            'Disease Risk': 'disease_risk',
            'Nutrient Stress': 'nutrient_stress',
            'Stress Zone': 'stress_zone',
        }
        
        for old_key, new_key in key_mapping.items():
            if old_key in analysis:
                analysis[new_key] = analysis.pop(old_key)
        
        # Ensure overall scores are always present
        if 'overall_soil_health' not in analysis:
            # Calculate from soil components
            score = 0
            count = 0
            for key in ['soil_moisture', 'soil_salinity', 'organic_matter', 'soil_fertility']:
                if key in analysis and 'level' in analysis[key]:
                    level = analysis[key]['level'].lower()
                    if level == 'high' or level == 'good':
                        score += 0.8
                    elif level == 'moderate':
                        score += 0.5
                    else:
                        score += 0.2
                    count += 1
            analysis['overall_soil_health'] = score / count if count > 0 else 0.5
        
        if 'overall_biorisk' not in analysis:
            # Calculate from bio components
            score = 0
            count = 0
            for key in ['pest_risk', 'disease_risk', 'nutrient_stress', 'stress_zone']:
                if key in analysis and 'level' in analysis[key]:
                    level = analysis[key]['level'].lower()
                    if level == 'high' or level == 'alert':
                        score += 0.8
                    elif level == 'moderate':
                        score += 0.5
                    else:
                        score += 0.2
                    count += 1
            analysis['overall_biorisk'] = score / count if count > 0 else 0.3
        
        return analysis
    except json.JSONDecodeError as e:
        print(f"Error parsing LLM response: {e}")
        print(f"Response text: {response_text}")
        # Return fallback structure
        return {
            "soil_moisture": {
                "level": "Moderate",
                "maximum_value": summary_report['indices']['SMI']['max_in_field'],
                "minimum_value": summary_report['indices']['SMI']['min_in_field'],
                "analysis": "Unable to parse LLM response"
            },
            "soil_salinity": {
                "level": "Moderate",
                "analysis": "Unable to parse LLM response"
            },
            "organic_matter": {
                "level": "Moderate",
                "analysis": "Unable to parse LLM response"
            },
            "soil_fertility": {
                "level": "Moderate",
                "analysis": "Unable to parse LLM response"
            },
            "pest_risk": {
                "level": "Moderate",
                "analysis": "Unable to parse LLM response"
            },
            "disease_risk": {
                "level": "Moderate",
                "analysis": "Unable to parse LLM response"
            },
            "nutrient_stress": {
                "level": "Moderate",
                "analysis": "Unable to parse LLM response"
            },
            "stress_zone": {
                "level": "Moderate",
                "analysis": "Unable to parse LLM response"
            },
            "overall_health": {
                "status": "fair",
                "key_concerns": ["Analysis unavailable"],
                "recommendations": ["Please review indices manually"]
            },
            "overall_biorisk": 0.5,
            "overall_soil_health": 0.5
        }

def format_llm_output(analysis: Dict) -> str:
    """
    Format LLM analysis into a readable report.
    
    Args:
        analysis: Dictionary with LLM analysis results
        
    Returns:
        Formatted string report
    """
    report = """
+================================================================+
|              LLM ANALYSIS - SOIL & CROP INSIGHTS               |
+================================================================+

SOIL MOISTURE ANALYSIS:
----------------------------------------------------------------
"""
    
    sm = analysis['soil_moisture']
    report += f"  Level: {sm['level'].upper()}\n"
    report += f"  Maximum Value: {sm['maximum_value']:.4f}\n"
    report += f"  Minimum Value: {sm['minimum_value']:.4f}\n"
    report += f"  Analysis: {sm['analysis']}\n"
    
    report += """
SOIL SALINITY ANALYSIS:
----------------------------------------------------------------
"""
    
    ss = analysis['soil_salinity']
    report += f"  Level: {ss['level'].upper()}\n"
    report += f"  Analysis: {ss['analysis']}\n"
    
    report += """
ORGANIC MATTER ANALYSIS:
----------------------------------------------------------------
"""
    
    om = analysis['organic_matter']
    report += f"  Level: {om['level'].upper()}\n"
    report += f"  Analysis: {om['analysis']}\n"
    
    report += """
SOIL FERTILITY ANALYSIS:
----------------------------------------------------------------
"""
    
    sf = analysis['soil_fertility']
    report += f"  Level: {sf['level'].upper()}\n"
    report += f"  Analysis: {sf['analysis']}\n"
    

    
    report += """
PEST RISK ANALYSIS:
----------------------------------------------------------------
"""
    
    pr = analysis.get('pest_risk', {'level': 'unknown', 'analysis': 'No data'})
    report += f"  Level: {pr['level'].upper()}\n"
    report += f"  Analysis: {pr['analysis']}\n"
    
    report += """
DISEASE RISK ANALYSIS:
----------------------------------------------------------------
"""
    
    dr = analysis.get('disease_risk', {'level': 'unknown', 'analysis': 'No data'})
    report += f"  Level: {dr['level'].upper()}\n"
    report += f"  Analysis: {dr['analysis']}\n"
    
    report += """
NUTRIENT STRESS ANALYSIS:
----------------------------------------------------------------
"""
    
    ns = analysis.get('nutrient_stress', {'level': 'unknown', 'analysis': 'No data'})
    report += f"  Level: {ns['level'].upper()}\n"
    report += f"  Analysis: {ns['analysis']}\n"

    report += """
STRESS ZONE ANALYSIS:
----------------------------------------------------------------
"""
    
    sz = analysis.get('stress_zone', {'level': 'unknown', 'analysis': 'No data'})
    report += f"  Level: {sz['level'].upper()}\n"
    report += f"  Analysis: {sz['analysis']}\n"
    
    report += """
OVERALL CROP HEALTH:
----------------------------------------------------------------
"""
    
    oh = analysis['overall_health']
    report += f"  Status: {oh['status'].upper()}\n"
    report += f"\n  Key Concerns:\n"
    for concern in oh['key_concerns']:
        report += f"    • {concern}\n"
    report += f"\n  Recommendations:\n"
    for rec in oh['recommendations']:
        report += f"    • {rec}\n"
    
    report += "\n" + "=" * 64 + "\n"
    
    return report
