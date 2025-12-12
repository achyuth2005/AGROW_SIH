"""
============================================================================
FILE: gemini_llm_integration.py
============================================================================
PURPOSE: Integrates Large Language Model (LLM) AI for intelligent crop health
         analysis. Takes raw SAR statistics and weather data, then uses an AI
         model to generate human-readable insights and recommendations.

WHAT THIS FILE DOES:
    1. Prepares analysis statistics (field-wide and stress zones)
    2. Builds a detailed prompt with all context
    3. Calls the Groq LLM API (running Llama 3.3 70B model)
    4. Parses the AI's JSON response
    5. Returns structured health assessments (greenness, nitrogen, biomass, etc.)

WHY USE AN LLM?
    Raw SAR data (VV, VH backscatter values in dB) is meaningless to farmers.
    The LLM translates technical data into actionable insights like:
    "Your crop shows signs of nitrogen deficiency. Consider applying urea."

API KEY ROTATION:
    The file maintains a pool of 21 Groq API keys with automatic fallback.
    If one key hits rate limits, it automatically tries the next one.
    This ensures high availability even under heavy load.

OUTPUT FORMAT:
    The LLM returns structured JSON with:
    - greenness_status/level: Vegetation color health
    - nitrogen_status/level: Nutrient content
    - biomass_status/level: Plant mass/growth
    - heat_stress_status/level: Temperature stress
    - overall_crop_health: Summary sentence

DEPENDENCIES:
    - groq: Python client for Groq API
    - json: JSON parsing
    - dotenv: Environment variable loading
============================================================================
"""

# Groq Python client - for calling the Llama LLM
from groq import Groq

# Standard library imports
import json  # For parsing LLM's JSON response
import os    # For environment variables
import time  # For timing/delays (if needed)

# Load environment variables from .env file
from dotenv import load_dotenv
load_dotenv()


# =============================================================================
# API CONFIGURATION
# =============================================================================
# Pool of Groq API keys for high availability.
# If one key gets rate-limited (429 error), we try the next one.
# This is crucial for production reliability.

GROQ_API_KEYS = [
    # Original keys (batch 1)
    "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",
    "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",
    "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",
    "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",
    "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",
    "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",
    "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",
    "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",
    "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",
    # Keys added 2025-12-09 (batch 2)
    "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",
    "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",
    "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",
    "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",
    "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",
    "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",
    "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",
    "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",
    "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",
    # Keys added 2025-12-09 (batch 3)
    "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",
    "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",
    "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",
]

# The LLM model to use - Llama 3.3 70B is one of the most capable open models
# "versatile" variant is optimized for general tasks including structured output
GROQ_MODEL = "llama-3.3-70b-versatile"

print(f"[GroqClient] Initialized with {len(GROQ_API_KEYS)} API keys")


# =============================================================================
# MAIN LLM FUNCTION
# =============================================================================

def call_gemini_llm_structured(
    crop_type,              # What crop is being analyzed ("wheat", "rice", etc.)
    nearest_date,           # Date of the satellite image
    center_lat,             # Field center latitude
    center_lon,             # Field center longitude
    field_size_hectares,    # Calculated field size
    weather_summary,        # Formatted weather data string
    farmer_context,         # Dictionary with farmer profile info
    total_patches,          # Total number of analysis patches
    stressed_patches_count, # How many patches show stress
    stress_percentage,      # Percentage of field under stress
    patch_size_m,           # Size of each patch in meters
    field_wide_stats,       # Average stats across entire field
    stress_zone_stats       # Stats specifically for stressed areas
):
    """
    Call the LLM (Groq/Llama) with agricultural context and get structured output.
    
    THE PROMPT ENGINEERING APPROACH:
    ---------------------------------
    1. CONTEXT SETTING: Tell the LLM it's an "expert agricultural AI"
    2. DATA PRESENTATION: Provide all statistics in a clear, labeled format
    3. INTERPRETATION GUIDE: Explain what the SAR values mean
    4. STRICT OUTPUT FORMAT: Request JSON with exact key names
    5. REASONING GUIDELINES: Tell the LLM how to interpret the data
    
    WHY STRUCTURED OUTPUT?
    ----------------------
    We need predictable JSON output so the mobile app can parse it.
    The prompt explicitly requests specific keys and value formats.
    
    PARAMETERS:
    -----------
    See parameter list above - all field analysis data and context
    
    RETURNS:
    --------
    dict with keys:
        - greenness_status: 4-word summary of vegetation greenness
        - greenness_level: "high", "moderate", or "low"
        - nitrogen_status: 4-word summary of nitrogen content
        - nitrogen_level: "high", "moderate", or "low"
        - biomass_status: 4-word summary of plant biomass
        - biomass_level: "high", "moderate", or "low"
        - heat_stress_status: 4-word summary of heat stress
        - heat_stress_level: "high", "moderate", or "low"
        - overall_crop_health: Full sentence summarizing field health
        - crop_phenology_state: Single word for growth stage
    """
    
    # =========================================================================
    # BUILD THE PROMPT
    # =========================================================================
    # The prompt is carefully engineered to:
    # 1. Establish the AI's role as an agricultural expert
    # 2. Present all data in a structured, easy-to-parse format
    # 3. Provide interpretation guidelines for SAR data
    # 4. Request a specific JSON output format
    
    prompt = f"""
You are an expert agricultural AI analyzing SAR (Synthetic Aperture Radar) satellite data for crop health assessment.

FIELD-WIDE STATISTICS (All {total_patches} patches):
- VV Backscatter Mean: {field_wide_stats['vv_mean']:.2f} dB (Std: {field_wide_stats['vv_std']:.2f})
- VH Backscatter Mean: {field_wide_stats['vh_mean']:.2f} dB (Std: {field_wide_stats['vh_std']:.2f})
- VV/VH Ratio Mean: {field_wide_stats['ratio_mean']:.2f} dB (Std: {field_wide_stats['ratio_std']:.2f})
- Patch Size: {patch_size_m}m x {patch_size_m}m each

STRESS ZONE STATISTICS ({stressed_patches_count} stressed patches = {stress_percentage:.1f}% of field):
- VV Backscatter Mean: {stress_zone_stats['vv_mean']:.2f} dB (Std: {stress_zone_stats['vv_std']:.2f})
- VH Backscatter Mean: {stress_zone_stats['vh_mean']:.2f} dB (Std: {stress_zone_stats['vh_std']:.2f})
- VV/VH Ratio Mean: {stress_zone_stats['ratio_mean']:.2f} dB (Std: {stress_zone_stats['ratio_std']:.2f})

{weather_summary}

INTERPRETATION GUIDE FOR SAR DATA:
- VV Backscatter: Sensitive to crop structure and biomass (higher = more biomass)
- VH Backscatter: Sensitive to vegetation volume and moisture (higher = healthier vegetation)
- VV/VH Ratio: Indicator of crop type and growth stage (higher = more mature/dense vegetation)

TASK:
Based on the SAR data, weather conditions, and comparison between field-wide and stress-zone statistics, provide a structured crop health assessment.

CRITICAL: You MUST respond with ONLY a valid JSON object (no markdown, no code blocks, no extra text) in this EXACT format:

{{
  "greenness_status": "four words summarizing the exact greenness status of the entire field,it should be very impactful easy to understand,not a full connected sentence",
  "greenness_level": "high" or "moderate" or "low",
  "nitrogen_status": "four words summarizing the exact nitrogen content of soil of the entire field,it should be very impactful easy to understand,not a full connected sentence",
  "nitrogen_level": "high" or "moderate" or "low",
  "biomass_status": "four words summarizing the biomass content of the entire field,it should be very impactful easy to understand,not a full connected sentence",
  "biomass_level": "high" or "moderate" or "low",
  "heat_stress_status": "four words summarizing the exact heat stress of the entire field from weather data provided,it should be very impactful easy to understand,not a full connected sentence",
  "heat_stress_level": "high" or "moderate" or "low",
  "overall_crop_health": "a full sentence summarizing the overall health status of the entire field,it should be very impactful easy to understand",
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

    # Log the prompt for debugging
    print("\n" + "="*80)
    print("LLM INPUT PROMPT")
    print("="*80)
    print(prompt)
    print("="*80 + "\n")

    # =========================================================================
    # API KEY ROTATION WITH FALLBACK
    # =========================================================================
    # Try each API key in order. If one fails (rate limit, error), try the next.
    # This provides high availability under heavy load.
    
    last_error = None
    for key_idx, api_key in enumerate(GROQ_API_KEYS):
        try:
            # Log which key we're trying
            print(f"[Groq] Trying API key {key_idx+1}/{len(GROQ_API_KEYS)} with model {GROQ_MODEL}...")
            
            # Create Groq client with this API key
            groq_client = Groq(api_key=api_key)
            
            # Make the API call
            chat_completion = groq_client.chat.completions.create(
                messages=[
                    {
                        # System message sets the AI's role/behavior
                        "role": "system",
                        "content": "You are an expert agricultural AI analyst. Always respond with valid JSON only, no markdown code blocks."
                    },
                    {
                        # User message contains our detailed prompt
                        "role": "user",
                        "content": prompt
                    }
                ],
                model=GROQ_MODEL,
                temperature=0.7,  # Some creativity, but mostly consistent
                max_tokens=2048,  # Enough tokens for detailed response
            )
            
            # Extract the text response
            response_text = chat_completion.choices[0].message.content.strip()
            print(f"[Groq] Success with key {key_idx+1}! Response length: {len(response_text)} chars")
            
            # -----------------------------------------------------------------
            # CLEAN UP THE RESPONSE
            # -----------------------------------------------------------------
            # Sometimes the LLM adds markdown code blocks despite instructions.
            # We strip them out to get pure JSON.
            if response_text.startswith('```'):
                response_text = response_text.split('```')[1]
                if response_text.startswith('json'):
                    response_text = response_text[4:]  # Remove "json" label
                response_text = response_text.strip()
            
            # Parse the JSON response
            result = json.loads(response_text)
            
            # -----------------------------------------------------------------
            # VALIDATE THE RESPONSE
            # -----------------------------------------------------------------
            # Ensure all required keys are present
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
            
            # Validate that level values are one of the expected options
            valid_levels = ['high', 'moderate', 'low']
            level_keys = ['greenness_level', 'nitrogen_level', 'biomass_level', 'heat_stress_level']
            for key in level_keys:
                if result[key].lower() not in valid_levels:
                    result[key] = 'moderate'  # Default to moderate if invalid
            
            # Log the successful output
            print("\n" + "="*50)
            print("[INFO] GROQ LLM OUTPUT")
            print("="*50)
            print("Documentation: This JSON object contains the structured health assessment from the LLM.")
            print("-" * 50)
            print(json.dumps(result, indent=2))
            print("="*50 + "\n")

            return result
            
        except json.JSONDecodeError as e:
            # LLM returned invalid JSON - try next key
            print(f"[Groq] Key {key_idx+1} - Error parsing JSON: {e}")
            last_error = e
            continue
            
        except Exception as e:
            # Other error (network, rate limit, etc.)
            error_str = str(e)
            print(f"[Groq] Key {key_idx+1} failed: {error_str[:100]}")
            
            # Check for rate limiting (HTTP 429)
            if "rate_limit" in error_str.lower() or "429" in error_str:
                print(f"[Groq] Rate limited. Switching to next key...")
                continue
            
            last_error = e
            continue
    
    # =========================================================================
    # ALL KEYS FAILED - RETURN FALLBACK
    # =========================================================================
    # If we've exhausted all API keys, return a generic response
    # so the app doesn't crash. The user will see "Unable to assess".
    
    print(f"[Groq] All {len(GROQ_API_KEYS)} API keys failed. Last error: {last_error}")
    
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


# =============================================================================
# DATA PREPARATION FUNCTION
# =============================================================================

def prepare_llm_input(features, stressed_indices, patches, df_weather, CROP_TYPE, 
                      nearest_date, center_lat, center_lon, PATCH_SIZE, RESOLUTION, 
                      FARMER_CONTEXT):
    """
    Prepares all statistics needed for the LLM and calls it.
    
    This function:
    1. Calculates field-wide statistics (averages across all patches)
    2. Calculates stress-zone statistics (averages for stressed patches only)
    3. Formats weather data into a readable summary
    4. Calls the LLM with all this context
    
    PARAMETERS:
    -----------
    features : pandas.DataFrame
        Statistical features for each patch (vv_mean, vh_mean, etc.)
    
    stressed_indices : numpy.array
        Indices of patches identified as "stressed" by anomaly detection
    
    patches : numpy.array
        The actual patch data (not used here, but for size calculation)
    
    df_weather : pandas.DataFrame
        Weather data for the past 7 days
    
    CROP_TYPE : str
        Type of crop being analyzed
    
    nearest_date : str
        Date of the satellite image used
    
    center_lat, center_lon : float
        Center coordinates of the field
    
    PATCH_SIZE : int
        Size of each patch in pixels
    
    RESOLUTION : int
        Resolution in meters per pixel
    
    FARMER_CONTEXT : dict
        Information about the farmer (role, experience, methods)
    
    RETURNS:
    --------
    tuple of (llm_result, field_wide_stats, stress_zone_stats)
    """
    
    # =========================================================================
    # CALCULATE FIELD-WIDE STATISTICS
    # =========================================================================
    # These are the average values across ALL patches in the field.
    # They represent the "baseline" for comparison.
    
    field_wide_stats = {
        'vv_mean': features['vv_mean'].mean(),    # Average VV backscatter
        'vv_std': features['vv_mean'].std(),      # Variation in VV
        'vh_mean': features['vh_mean'].mean(),    # Average VH backscatter
        'vh_std': features['vh_mean'].std(),      # Variation in VH
        'ratio_mean': features['ratio_mean'].mean(),  # Average VV/VH ratio
        'ratio_std': features['ratio_mean'].std()     # Variation in ratio
    }
    
    # =========================================================================
    # CALCULATE STRESS ZONE STATISTICS
    # =========================================================================
    # These are the average values for patches flagged as "stressed".
    # Comparing these to field-wide stats reveals what's wrong.
    
    if len(stressed_indices) > 0:
        # Extract only the stressed patches
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
        # No stressed patches - use field-wide stats
        stress_zone_stats = field_wide_stats.copy()
    
    # =========================================================================
    # FORMAT WEATHER SUMMARY
    # =========================================================================
    # Create a human-readable summary of weather conditions.
    
    if not df_weather.empty:
        weather_summary = f"""
WEATHER CONDITIONS (Last 7 days):
- Average Temperature: {df_weather['temp_mean'].mean():.1f}°C (Min: {df_weather['temp_min'].min():.1f}°C, Max: {df_weather['temp_max'].max():.1f}°C)
- Total Precipitation: {df_weather['precipitation'].sum():.1f} mm
- Average Wind Speed: {df_weather['wind_speed'].mean():.1f} km/h
- Total Evapotranspiration: {df_weather['evapotranspiration'].sum():.1f} mm
- Average Humidity: {df_weather['humidity'].mean():.1f}%
- Max UV Index: {df_weather['uv_index'].max():.1f}
"""
    else:
        weather_summary = "WEATHER CONDITIONS: Data not available"
    
    # =========================================================================
    # CALCULATE DERIVED METRICS
    # =========================================================================
    
    # Estimate field size in hectares
    # Formula: patches × (patch_pixels × resolution)² / 10000 (m² to hectares)
    field_size_hectares = len(patches) * (PATCH_SIZE * RESOLUTION) ** 2 / 10000
    
    # Percentage of field showing stress
    stress_percentage = (len(stressed_indices) / len(patches)) * 100
    
    # =========================================================================
    # CALL THE LLM
    # =========================================================================
    
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
    
    # Return all calculated data for potential logging/debugging
    return result, field_wide_stats, stress_zone_stats
