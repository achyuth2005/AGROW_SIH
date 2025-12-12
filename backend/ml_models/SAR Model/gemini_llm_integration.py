"""
Gemini LLM Integration for SAR Crop Analysis
Provides structured output for greenness, nitrogen, biomass, and heat stress
"""

import google.generativeai as genai
import json
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configure Gemini API
# Read API key from environment variable
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

if not GEMINI_API_KEY:
    # Fallback for local testing if needed, but warn
    print("Warning: GEMINI_API_KEY environment variable not set.")
    # You can optionally raise an error here if you want to enforce it
    # raise ValueError("GEMINI_API_KEY environment variable not set")

# Configure with explicit API settings
if GEMINI_API_KEY:
    genai.configure(
        api_key=GEMINI_API_KEY,
        transport='rest'  # Use REST transport for better compatibility
    )

def call_gemini_llm_structured(
    crop_type,
    nearest_date,
    center_lat,
    center_lon,
    field_size_hectares,
    weather_summary,
    farmer_context,
    total_patches,
    stressed_patches_count,
    stress_percentage,
    patch_size_m,
    field_wide_stats,
    stress_zone_stats
):
    """
    Call Gemini API with structured output format.
    
    Returns:
        dict with keys: greenness_status, greenness_level, nitrogen_status, nitrogen_level,
                       biomass_status, biomass_level, heat_stress_status, heat_stress_level,
                       overall_crop_health
    """
    
    # Prepare comprehensive prompt with field-wide and stress-zone data
    prompt = f"""
You are an expert agricultural AI analyzing SAR (Synthetic Aperture Radar) satellite data for crop health assessment.

CROP INFORMATION:
- Crop Type: {crop_type}
- Analysis Date: {nearest_date}
- Location: Lat {center_lat:.4f}, Lon {center_lon:.4f}
- Field Size: {field_size_hectares:.2f} hectares

FARMER PROFILE:
- Role: {farmer_context['role']}
- Experience: {farmer_context['years_farming']} years
- Irrigation Method: {farmer_context['irrigation_method']}
- Farming Goal: {farmer_context['farming_goal']}

{weather_summary}

SAR ANALYSIS RESULTS:
===================

FIELD-WIDE STATISTICS (All {total_patches} patches):
- VV Backscatter Mean: {field_wide_stats['vv_mean']:.2f} dB (Std: {field_wide_stats['vv_std']:.2f})
- VH Backscatter Mean: {field_wide_stats['vh_mean']:.2f} dB (Std: {field_wide_stats['vh_std']:.2f})
- VV/VH Ratio Mean: {field_wide_stats['ratio_mean']:.2f} dB (Std: {field_wide_stats['ratio_std']:.2f})
- Patch Size: {patch_size_m}m x {patch_size_m}m each

STRESS ZONE STATISTICS ({stressed_patches_count} stressed patches = {stress_percentage:.1f}% of field):
- VV Backscatter Mean: {stress_zone_stats['vv_mean']:.2f} dB (Std: {stress_zone_stats['vv_std']:.2f})
- VH Backscatter Mean: {stress_zone_stats['vh_mean']:.2f} dB (Std: {stress_zone_stats['vh_std']:.2f})
- VV/VH Ratio Mean: {stress_zone_stats['ratio_mean']:.2f} dB (Std: {stress_zone_stats['ratio_std']:.2f})

INTERPRETATION GUIDE FOR SAR DATA:
- VV Backscatter: Sensitive to crop structure and biomass (higher = more biomass)
- VH Backscatter: Sensitive to vegetation volume and moisture (higher = healthier vegetation)
- VV/VH Ratio: Indicator of crop type and growth stage (higher = more mature/dense vegetation)

TASK:
Based on the SAR data, weather conditions, and comparison between field-wide and stress-zone statistics, provide a structured crop health assessment.

CRITICAL: You MUST respond with ONLY a valid JSON object (no markdown, no code blocks, no extra text) in this EXACT format:

{{
  "greenness_status": "one to five phrases about field greenness with respect to available data",
  "greenness_level": "high" or "moderate" or "low",
  "nitrogen_status": "one to five phrases about nitrogen level in soil with respect to available data",
  "nitrogen_level": "high" or "moderate" or "low",
  "biomass_status": "one to five phrases about biomass with respect to available data",
  "biomass_level": "high" or "moderate" or "low",
  "heat_stress_status": "one to five phrases about heat stress with respect to available data",
  "heat_stress_level": "high" or "moderate" or "low",
  "overall_crop_health": "one to five phrases about overall crop health with respect to available data",
  "crop_phenology_state": "the current phenological state of crop in a single word by analysing all the data given"
}}

IMPORTANT REASONING GUIDELINES:
1. Compare stress zone stats vs field-wide stats to identify deficiencies
2. Lower VH backscatter in stress zones indicates reduced vegetation vigor (greenness)
3. Lower VV/VH ratio suggests reduced biomass/nitrogen
4. Consider weather data (temperature, precipitation) for heat stress assessment
5. Use farmer's irrigation method and experience level in your assessment

Respond with ONLY the JSON object, nothing else.
"""

    try:
        # Use gemini-flash-latest which is explicitly listed in the available models
        model = genai.GenerativeModel('gemini-flash-latest')
        
        # Configure generation settings for JSON output
        generation_config = {
            'temperature': 0.7,
            'top_p': 0.95,
            'top_k': 40,
            'max_output_tokens': 2048,
        }
        
        response = model.generate_content(
            prompt,
            generation_config=generation_config
        )
        
        # Extract JSON from response
        response_text = response.text.strip()
        
        # Remove markdown code blocks if present
        if response_text.startswith('```'):
            response_text = response_text.split('```')[1]
            if response_text.startswith('json'):
                response_text = response_text[4:]
            response_text = response_text.strip()
        
        # Parse JSON
        result = json.loads(response_text)
        
        # Validate required keys
        required_keys = [
            'greenness_status', 'greenness_level',
            'nitrogen_status', 'nitrogen_level',
            'biomass_status', 'biomass_level',
            'heat_stress_status', 'heat_stress_level',
            'overall_crop_health'
        ]
        
        for key in required_keys:
            if key not in result:
                raise ValueError(f"Missing required key: {key}")
        
        # Validate level values
        valid_levels = ['high', 'moderate', 'low']
        level_keys = ['greenness_level', 'nitrogen_level', 'biomass_level', 'heat_stress_level']
        for key in level_keys:
            if result[key].lower() not in valid_levels:
                result[key] = 'moderate'  # Default to moderate if invalid
        
        return result
        
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON from Gemini response: {e}")
        print(f"Response text: {response_text}")
        # Return fallback structure
        return {
            "greenness_status": "Unable to assess - API response error",
            "greenness_level": "moderate",
            "nitrogen_status": "Unable to assess - API response error",
            "nitrogen_level": "moderate",
            "biomass_status": "Unable to assess - API response error",
            "biomass_level": "moderate",
            "heat_stress_status": "Unable to assess - API response error",
            "heat_stress_level": "moderate",
            "overall_crop_health": f"Analysis completed for {total_patches} patches with {stress_percentage:.1f}% showing stress indicators. Manual review recommended due to API parsing error."
        }
    
    except Exception as e:
        print(f"Error calling Gemini API: {e}")
        # Return fallback structure
        return {
            "greenness_status": "Unable to assess - API error",
            "greenness_level": "moderate",
            "nitrogen_status": "Unable to assess - API error",
            "nitrogen_level": "moderate",
            "biomass_status": "Unable to assess - API error",
            "biomass_level": "moderate",
            "heat_stress_status": "Unable to assess - API error",
            "heat_stress_level": "moderate",
            "overall_crop_health": f"Analysis completed for {total_patches} patches with {stress_percentage:.1f}% showing stress indicators. Manual review recommended due to API error."
        }


# Example usage function
def prepare_llm_input(features, stressed_indices, patches, df_weather, CROP_TYPE, nearest_date, 
                      center_lat, center_lon, PATCH_SIZE, RESOLUTION, FARMER_CONTEXT):
    """
    Prepare all necessary statistics for LLM input.
    """
    # Field-wide statistics
    field_wide_stats = {
        'vv_mean': features['vv_mean'].mean(),
        'vv_std': features['vv_mean'].std(),
        'vh_mean': features['vh_mean'].mean(),
        'vh_std': features['vh_mean'].std(),
        'ratio_mean': features['ratio_mean'].mean(),
        'ratio_std': features['ratio_mean'].std()
    }
    
    # Stress zone statistics
    if len(stressed_indices) > 0:
        stress_features = features.iloc[stressed_indices]
        stress_zone_stats = {
            'vv_mean': stress_features['vv_mean'].mean(),
            'vv_std': stress_features['vv_mean'].std(),
            'vh_mean': stress_features['vh_mean'].mean(),
            'vh_std': stress_features['vh_mean'].std(),
            'ratio_mean': stress_features['ratio_mean'].mean(),
            'ratio_std': stress_features['ratio_mean'].std()
        }
    else:
        stress_zone_stats = field_wide_stats.copy()
    
    # Weather summary
    if not df_weather.empty:
        weather_summary = f"""
WEATHER CONDITIONS (Last 7 days):
- Average Temperature: {df_weather['temp_mean'].mean():.1f}°C (Min: {df_weather['temp_min'].min():.1f}°C, Max: {df_weather['temp_max'].max():.1f}°C)
- Total Precipitation: {df_weather['precipitation'].sum():.1f} mm
- Average Wind Speed: {df_weather['wind_speed'].mean():.1f} km/h
- Total Evapotranspiration: {df_weather['evapotranspiration'].sum():.1f} mm
"""
    else:
        weather_summary = "WEATHER CONDITIONS: Data not available"
    
    # Calculate field size
    field_size_hectares = len(patches) * (PATCH_SIZE * RESOLUTION) ** 2 / 10000
    stress_percentage = (len(stressed_indices) / len(patches)) * 100
    
    # Call LLM
    result = call_gemini_llm_structured(
        crop_type=CROP_TYPE,
        nearest_date=nearest_date,
        center_lat=center_lat,
        center_lon=center_lon,
        field_size_hectares=field_size_hectares,
        weather_summary=weather_summary,
        farmer_context=FARMER_CONTEXT,
        total_patches=len(patches),
        stressed_patches_count=len(stressed_indices),
        stress_percentage=stress_percentage,
        patch_size_m=PATCH_SIZE * RESOLUTION,
        field_wide_stats=field_wide_stats,
        stress_zone_stats=stress_zone_stats
    )
    
    return result, field_wide_stats, stress_zone_stats
