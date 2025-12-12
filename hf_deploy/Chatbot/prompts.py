"""
LLM Prompts for Multi-Stage Reasoning
======================================
Prompts for each stage: Claim → Validate → Contradict → Confirm
Following the Developer Specification exactly.
"""

from typing import Dict, List, Any, Optional

# =============================================================================
# PERSONA SYSTEM - Tailored Responses Based on User Profile
# =============================================================================

# Granular persona definitions based on role, experience, and context
PERSONA_DEFINITIONS = {
    "new_farmer_basic_tech": {
        "description": "New farmer (0-3 years), limited smartphone familiarity",
        "style": "Very simple, step-by-step guidance. NO NUMBERS OR INDICES.",
        "format": "Short bullet points, numbered steps. Use terms like 'Low', 'High', 'Good', 'Bad'.",
        "focus": "Immediate actions. Explain strictly based on their irrigation method.",
        "tone": "Warm, patient, encouraging, supportive",
        "recommendations": "Simple low-cost solutions. Tailor to their specific farming technique."
    },
    "new_farmer_tech_savvy": {
        "description": "New farmer (0-3 years), comfortable with technology",
        "style": "Clear explanations without complex numbers. NO RAW INDICES.",
        "format": "Use 'High'/'Moderate'/'Low' for status. Visual cues.",
        "focus": "Learning-oriented. Explain 'why' using their specific crop context.",
        "tone": "Friendly, educational, encouraging.",
        "recommendations": "Modern approaches. Consider their specific irrigation setup."
    },
    "experienced_farmer_traditional": {
        "description": "Experienced farmer (5+ years), prefers traditional methods",
        "style": "Practical. NO RAW DATA/NUMBERS. Use traditional terms.",
        "format": "Direct recommendations. Use 'Adequate', 'Stressed', 'Severe'.",
        "focus": "Risk assessment. Relate to their traditional techniques.",
        "tone": "Respectful of expertise, peer-to-peer.",
        "recommendations": "Proven methods first. Match their existing irrigation habits."
    },
    "experienced_farmer_innovative": {
        "description": "Experienced farmer (5+ years), open to modern methods",
        "style": "Practical but simplified metrics. NO COMPLEX DECIMALS.",
        "format": "Use 'High Efficiency' vs 'Low'.",
        "focus": "Efficiency. Optimize their specific machinery/irrigation inputs.",
        "tone": "Professional, partner-like.",
        "recommendations": "Innovation welcomed. Precision approaches for their equipment."
    },
    "commercial_farmer": {
        "description": "Commercial farming focus, business-oriented",
        "style": "Business-focused. Summary stats only (High/Low risks).",
        "format": "Clear priorities. Zone breakdowns by 'Severity' (not index).",
        "focus": "ROI and scalable solutions for their infrastructure.",
        "tone": "Professional, efficient, results-oriented",
        "recommendations": "Commercial-grade solutions tailored to their scale/inputs."
    },
    "agricultural_officer": {
        "description": "Extension officer or field advisor",
        "style": "Professional summary. Minimal raw numbers, focus on status.",
        "format": "Zone-wise 'Affected' vs 'Healthy'. trend direction.",
        "focus": "Regional patterns. Farmer communication tips.",
        "tone": "Formal, shareable insights",
        "recommendations": "Scalable solutions for the region's common techniques."
    },
    "agronomist_researcher": {
        "description": "Technical researcher or scientist",
        "style": "Full technical precision. HEAVY USE OF NUMERICAL DATA & INDICES.",
        "format": "Tables with exact NDVI/NDRE values. Statistical confidence intervals.",
        "focus": "Causal mechanisms, data quality, methodology.",
        "tone": "Scientific, analytical, evidence-driven",
        "recommendations": "Experimental approaches. Cite specific spectral bands/thresholds."
    }
}

# Questionnaire key mappings
EXPERIENCE_MAP = {
    "Less than 2 years": 1,
    "2 - 5 years": 3,
    "5 - 10 years": 7,
    "More than 10 years": 15
}

TECH_COMFORT_MAP = {
    "I don't know how to use them": "basic",
    "I need help using them": "basic",
    "I can use basic features (calls, WhatsApp, YouTube)": "moderate",
    "I am very comfortable using apps": "advanced"
}

INNOVATION_MAP = {
    "I prefer traditional methods": "traditional",
    "I try new methods occasionally": "moderate",
    "I regularly adopt modern/innovative methods": "innovative"
}

FARMING_GOAL_MAP = {
    "Food for family consumption": "subsistence",
    "Earn Income / Livelihood": "income",
    "Sell Commercially / Business": "commercial",
    "Other": "custom"
}


def create_user_persona(user_profile: Dict, all_fields: List = None) -> Dict:
    """
    Create a comprehensive user persona from questionnaire data.
    
    Uses all available context: role, experience, smartphone familiarity,
    innovation attitude, farming goals, irrigation methods, mechanization,
    and cropping frequency to tailor responses appropriately.
    
    Args:
        user_profile: User profile dict with 'questionnaire_data' key
        all_fields: List of user's field info dicts
        
    Returns:
        Persona dict with instructions for response generation
    """
    questionnaire = user_profile.get("questionnaire_data", {}) if user_profile else {}
    
    # Extract all questionnaire answers
    role = questionnaire.get("role", "Farmer")
    age_group = questionnaire.get("age_group", "31 - 45")
    farming_exp = questionnaire.get("farming_experience", "2 - 5 years")
    smartphone = questionnaire.get("smartphone_familiarity", "I can use basic features (calls, WhatsApp, YouTube)")
    innovation = questionnaire.get("innovation_attitude", "I try new methods occasionally")
    farming_goal = questionnaire.get("farming_goal", "Earn Income / Livelihood")
    irrigation = questionnaire.get("irrigation_source", "Tube well / Borewell")
    mechanization = questionnaire.get("mechanization_level", "with both by hand and machines")
    cropping_freq = questionnaire.get("cropping_frequency", "2 crops per year")
    
    # Map to numeric and categorical values
    years_experience = EXPERIENCE_MAP.get(farming_exp, 3)
    tech_level = TECH_COMFORT_MAP.get(smartphone, "moderate")
    innovation_level = INNOVATION_MAP.get(innovation, "moderate")
    goal_type = FARMING_GOAL_MAP.get(farming_goal, "income")
    
    # Determine persona type based on combined factors
    if role == "Agro-tech Researcher":
        persona_type = "agronomist_researcher"
    elif role in ["Extension Officer", "Agricultural Officer"]:
        persona_type = "agricultural_officer"
    elif goal_type == "commercial":
        persona_type = "commercial_farmer"
    elif years_experience <= 3:
        if tech_level == "advanced":
            persona_type = "new_farmer_tech_savvy"
        else:
            persona_type = "new_farmer_basic_tech"
    else:
        if innovation_level == "innovative":
            persona_type = "experienced_farmer_innovative"
        else:
            persona_type = "experienced_farmer_traditional"
    
    persona_def = PERSONA_DEFINITIONS.get(persona_type, PERSONA_DEFINITIONS["experienced_farmer_traditional"])
    
    # Build context-aware persona instructions
    persona_instructions = f"""
USER PERSONA: {persona_def['description']}

COMMUNICATION STYLE: {persona_def['style']}
RESPONSE FORMAT: {persona_def['format']}
PRIMARY FOCUS: {persona_def['focus']}
TONE: {persona_def['tone']}
RECOMMENDATION STYLE: {persona_def['recommendations']}

USER CONTEXT FOR TAILORING:
- Farming Experience: {farming_exp} ({years_experience} years)
- Technology Comfort: {smartphone}
- Innovation Attitude: {innovation}
- Farming Goal: {farming_goal}
- Irrigation Method: {irrigation}
- Mechanization: {mechanization}
- Cropping Frequency: {cropping_freq}

TAILORING GUIDELINES:
1. Match recommendations to their IRRIGATION method ({irrigation}):
   - For "Rain only": Focus on rainwater harvesting, moisture conservation
   - For "Drip/Sprinkler": Can suggest precise application rates
   - For "Tube well": Consider water table sustainability
   
2. Match recommendations to their MECHANIZATION level ({mechanization}):
   - For "by hand": Suggest labor-manageable solutions
   - For "with machines": Can suggest mechanized interventions
   
3. Align with their FARMING GOAL ({farming_goal}):
   - Subsistence: Prioritize food security, low-cost solutions
   - Income: Balance cost and yield improvements
   - Commercial: Focus on ROI, market timing, quality

4. Respect their INNOVATION preference ({innovation}):
   - Traditional: Lead with proven methods, new tech as optional
   - Innovative: Can suggest modern precision approaches

IMPORTANT: Generate a response that this specific user will find most helpful and actionable.
"""

    return {
        "type": persona_type,
        "experience_years": years_experience,
        "tech_level": tech_level,
        "innovation_level": innovation_level,
        "goal_type": goal_type,
        "irrigation_method": irrigation,
        "mechanization": mechanization,
        "cropping_frequency": cropping_freq,
        "all_fields": [f.get("name") for f in (all_fields or [])],
        "instructions": persona_instructions,
        "raw_questionnaire": questionnaire
    }



# =============================================================================
# SYSTEM PROMPT (Base context)
# =============================================================================

SYSTEM_PROMPT = """You are AGROW AI, a dedicated PERSONAL agricultural advisor for Indian farmers. 
Your goal is to be a trusted partner in their farming journey, not just a data analyzer.

LANGUAGE RULE (CRITICAL):
- ALWAYS respond in the SAME LANGUAGE as the user's query.
- If the user writes in Hindi, respond ENTIRELY in Hindi.
- If the user writes in English, respond in English.
- If the user writes in Hinglish (mixed), respond in Hinglish.
- This applies to ALL responses including technical terms.

SPECIALIZATIONS:
- Satellite imagery interpretation (Sentinel-1 SAR, Sentinel-2 optical bands)
- Vegetation indices analysis (NDVI, NDRE, EVI, SMI, PSRI, PRI, MCARI, etc.)
- Crop stress diagnosis (water stress, nutrient deficiency, pest/disease)
- Climate-smart farming recommendations
- Regional crop knowledge (wheat, rice, cotton, sugarcane, pulses, mustard, etc.)

COMMUNICATION STYLE:
- Use a PERSONAL, RELATABLE tone. Use "I", "We", and refer to "Your field".
- Avoid neutral, robotic assertions. Show empathy and understanding.
- Use simple, practical language farmers understand.
- Cite specific values but explain what they mean for *their* specific field.
- Distinguish ROOT CAUSE from SYMPTOMS.
- Give actionable, prioritized recommendations.
- Reference local conditions and seasonal context.

ANALYSIS APPROACH:
- Always consider multiple hypotheses before concluding.
- Seek contradicting evidence actively.
- Build causal chains: Event A → Effect B → Symptom C.
- Confidence scores reflect evidence strength.

When you lack specific data, acknowledge it honestly and provide general guidance based on described symptoms."""

# =============================================================================
# STAGE 3A: CLAIM PROMPT - Initial Hypothesis
# =============================================================================

CLAIM_PROMPT = """You are analyzing agricultural satellite data to diagnose crop issues.

USER QUERY: {query}

AVAILABLE EVIDENCE (Priority 1 - Primary indicators only):
{priority_1_context}

Based ONLY on this primary evidence:
1. State your initial hypothesis about what's happening
2. Cite specific values that support your hypothesis
3. Rate your confidence (0.0 to 1.0)
4. List what you're unsure about

Respond in JSON format ONLY:
{{
    "initial_claim": "Your hypothesis in 1-2 sentences describing what's likely happening",
    "hypothesis": "single_word_label (e.g., chlorophyll_deficiency, water_stress, nutrient_issue)",
    "evidence_cited": ["NDVI: 0.45", "NDRE: 0.32", "trend: declining"],
    "confidence": 0.72,
    "uncertainties": ["cannot determine spatial distribution", "need weather data"]
}}

Return ONLY the JSON object, no additional text."""

# =============================================================================
# STAGE 3B: VALIDATE PROMPT - Confirm with Supporting Evidence
# =============================================================================

VALIDATE_PROMPT = """You previously hypothesized: {previous_hypothesis}
Initial confidence: {previous_confidence}

ADDITIONAL SUPPORTING EVIDENCE (Priority 2):
{priority_2_context}

Analyze this new evidence and determine:
1. Does it CONFIRM your hypothesis? (increases confidence)
2. Does it WEAKEN your hypothesis? (decreases confidence)
3. Does it add SPATIAL context? (where is the issue concentrated?)

Respond in JSON format ONLY:
{{
    "validation_result": "confirmed|weakened|neutral",
    "confidence_updated": 0.81,
    "spatial_notes": "Stress concentrated in northeast quadrant, 12 patches affected",
    "new_evidence_summary": "EVI also low (0.38), clustering shows 18.75% field under stress"
}}

Return ONLY the JSON object, no additional text."""

# =============================================================================
# STAGE 3C: CONTRADICT PROMPT - Seek Alternative Explanations
# =============================================================================

CONTRADICT_PROMPT = """CURRENT HYPOTHESIS: {hypothesis} (confidence: {confidence})

YOUR CRITICAL TASK: Actively look for evidence that CONTRADICTS this hypothesis.
Do NOT confirm - seek alternative explanations!

ALTERNATIVE CAUSAL FACTORS TO CONSIDER (Priority 3):
{priority_3_context}

Questions to answer:
1. Could something ELSE explain the observed symptoms?
2. Is there evidence that CONTRADICTS the current hypothesis?
3. What's the strongest alternative explanation?
4. Could the current hypothesis be a SYMPTOM of a deeper ROOT CAUSE?

Respond in JSON format ONLY:
{{
    "contradiction_found": true,
    "contradicting_evidence": ["SMI critically low (0.18)", "5 consecutive heat stress days"],
    "alternative_hypothesis": "water_stress",
    "alternative_confidence": 0.76,
    "reasoning": "Low SMI and heat stress suggest water deficit as ROOT CAUSE. The chlorophyll deficiency may be a SYMPTOM of water stress, not the primary issue."
}}

Return ONLY the JSON object, no additional text."""

# =============================================================================
# STAGE 3D: CONFIRM PROMPT - Final Diagnosis
# =============================================================================

CONFIRM_PROMPT = """COMPETING HYPOTHESES:
1. {hypothesis_1} (confidence: {conf_1})
2. {hypothesis_2} (confidence: {conf_2})

FINAL VALIDATION DATA (Priority 4):
{priority_4_context}

Determine the FINAL diagnosis by:
1. Weighing evidence for EACH hypothesis against this validation data
2. Considering farmer's recent actions and their impact
3. Checking consistency with any previous analyses
4. Identifying the ROOT CAUSE vs symptoms
5. Building a causal chain explaining how events led to current state

Respond in JSON format ONLY:
{{
    "final_diagnosis": "water_stress_induced_chlorophyll_decline",
    "confidence": 0.89,
    "causal_chain": "Heat stress (5 days >38°C) + No irrigation (8 days) → Soil moisture deficit (SMI 0.18) → Plant water stress → Reduced nutrient uptake → Chlorophyll degradation (NDRE 0.32) → Visible yellowing",
    "root_cause": "water_stress",
    "symptoms": ["chlorophyll_decline", "yellowing_leaves", "low_NDRE"],
    "evidence_summary": {{
        "supporting": ["SAR VV increasing (drier soil)", "last irrigation 8 days ago"],
        "contradicting": ["no pest/disease indicators"],
        "inconclusive": ["nitrogen status unclear without fertilizer history"]
    }},
    "recommendation": "Irrigate immediately, prioritizing northeast sector where stress is highest. Consider light foliar feeding once moisture is restored."
}}

Return ONLY the JSON object, no additional text."""

# =============================================================================
# RESPONSE GENERATION PROMPT
# =============================================================================

RESPONSE_PROMPT = """
{persona_instructions}

CONVERSATION HISTORY (for follow-up awareness):
{conversation_history}

Based on the diagnostic analysis, generate a COMPREHENSIVE and DETAILED response.
The user wants a full explanation, not just a summary.

USER QUERY: {query}

DIAGNOSIS: {diagnosis}

EVIDENCE: {evidence}

WEATHER: {weather_context}

ZONE ANALYSIS:
{zone_context}

HISTORICAL TRENDS:
{trend_context}

---------------------------------------------------------------
CRITICAL: RESPONSE STRUCTURE (MUST FOLLOW THIS EXACT FORMAT)
---------------------------------------------------------------

**DIAGNOSIS & STATUS**
* Clearly state the primary issue identified (or confirmation of health).
* Mention the severity level (Mild/Moderate/Severe) based on the data.
* State the confidence level in this diagnosis.

**DETAILED REASONING**
* Explain *WHY* this is the diagnosis, connecting the dots between different data points.
* Cite specific metrics (NDVI, SMI, NDRE) and explain what they mean in this context.
* Explicitly mention if the 3-stage analysis (Hypothesis -> Adversary -> Judge) ruled out other causes.
* Reference historical trends or weather patterns that support this conclusion.

**FUTURE RISKS**
* Explain what will happen if this issue is ignored for 3-5 days.
* Mention potential yield impact or long-term damage.
* Flag any upcoming weather risks (e.g., "Forecast rain might worsen fungal spread").

**RECOMMENDATIONS**
* **Immediate Action**: What needs to be done TODAY? (be specific: amounts, methods).
* **Follow-up**: What to check in 3 days.
* **Long-term**: Preventative measures for next season.

**NEXT STEPS**
* End with a specific question to keep the conversation going.
* Examples: 
  * "Should I help you calculate the fertilizer dosage?"
  * "Would you like to analyze the historical trends for this field?"
  * "Shall I monitor this area for you over the next week?"

---------------------------------------------------------------
GUIDELINES:
* LANGUAGE: Respond in the SAME language as the user's query (Hindi→Hindi, English→English, Hinglish→Hinglish).
* NO EMOJIS in the output.
* Use asterisk (*) for bullet points, do NOT use hyphens (-).
* Bold the section headings.
* Tone: Professional, authoritative, but helpful (Agro-Expert).
* Length: Comprehensive (300-500 words is acceptable for Deep Dive).
"""


# =============================================================================
# CONFIDENCE-BASED RESPONSE PROMPTS
# =============================================================================

LOW_CONFIDENCE_PROMPT = """
{persona_instructions}

I need more information to give you a confident answer.

WHAT I CAN SEE:
{available_evidence}

WHAT'S UNCLEAR:
{missing_info}

**Before I can help accurately, please tell me:**
{clarifying_questions}

Once you provide this information, I can give you specific recommendations.
"""

MEDIUM_CONFIDENCE_PROMPT = """
{persona_instructions}

USER QUERY: {query}

Based on available data, here's my analysis (with some uncertainty):

{diagnosis}

⚠️ **Note:** My confidence is moderate because:
{uncertainty_reasons}

**Recommended action:**
{recommendation}

**To be more certain, it would help to know:**
{additional_info_needed}
"""

# =============================================================================
# ZONE-SPECIFIC CONTEXT BUILDER
# =============================================================================

def format_zone_context(zone_data: dict) -> str:
    """Format zone/patch data into readable context for LLM."""
    if not zone_data or not zone_data.get("priority_zones"):
        return "No zone-specific data available."
    
    lines = []
    zones = zone_data.get("priority_zones", [])
    
    if zones:
        lines.append("PRIORITY ZONES (highest stress first):")
        for i, zone in enumerate(zones[:3], 1):
            lines.append(f"  {i}. {zone.get('location', 'Zone')} - "
                        f"Stress: {zone.get('stress_score', 0):.0%}, "
                        f"Issue: {zone.get('primary_issue', 'unknown')}, "
                        f"Area: {zone.get('area_percentage', 0):.1f}%")
    
    most_critical = zone_data.get("most_critical")
    if most_critical:
        lines.append(f"\n⚠️ MOST CRITICAL: {most_critical.get('location', 'Zone')} "
                    f"needs immediate attention")
    
    return "\n".join(lines) if lines else "No zone-specific data available."


def format_trend_context(trend_data: dict) -> str:
    """Format historical trend data into readable context for LLM."""
    if not trend_data:
        return "No historical trend data available."
    
    lines = []
    changes = trend_data.get("changes", {})
    
    if changes.get("ndvi_change_7d") is not None:
        change = changes["ndvi_change_7d"]
        direction = "↑" if change > 0 else "↓" if change < 0 else "→"
        lines.append(f"NDVI Change (7 days): {direction} {abs(change):.3f} "
                    f"({trend_data.get('ndvi_trend', 'unknown')})")
    
    if changes.get("smi_change_7d") is not None:
        change = changes["smi_change_7d"]
        direction = "↑" if change > 0 else "↓" if change < 0 else "→"
        lines.append(f"Soil Moisture Change: {direction} {abs(change):.2f}")
    
    summary = trend_data.get("summary")
    if summary:
        lines.append(f"Summary: {summary}")
    
    return "\n".join(lines) if lines else "No historical trend data available."


def format_conversation_history(history: list) -> str:
    """Format conversation history for context injection."""
    if not history:
        return "This is the first message in the conversation."
    
    lines = ["Recent conversation:"]
    for turn in history[-3:]:  # Last 3 turns
        role = turn.get("role", "unknown")
        content = turn.get("content", "")[:150]  # Truncate long messages
        if role == "user":
            lines.append(f"  User: {content}")
        else:
            # For assistant, show diagnosis summary if available
            diagnosis = turn.get("diagnosis", content[:100])
            lines.append(f"  Assistant: {diagnosis}")
    
    return "\n".join(lines)


# =============================================================================
# FOLLOWUP GENERATION PROMPT
# =============================================================================

FOLLOWUP_PROMPT = """Based on this conversation:

USER QUERY: {query}
DIAGNOSIS: {diagnosis}
INTENT: {intent}

Generate 3 relevant follow-up questions the farmer might want to ask next.

Rules:
- Make them specific to the diagnosis and context
- Include at least one spatial question ("Which area...")
- Include at least one action question ("How do I...")
- Keep them short and natural-sounding

Respond as a JSON list:
["Question 1?", "Question 2?", "Question 3?"]"""

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def build_context_prompt(context: dict) -> str:
    """Convert context dict to readable string for LLM."""
    if not context:
        return "No specific data available."
    
    lines = []
    for key, value in context.items():
        if value is None:
            continue
        if isinstance(value, dict):
            lines.append(f"**{key}**:")
            for k, v in value.items():
                if v is not None:
                    if isinstance(v, float):
                        lines.append(f"  - {k}: {v:.4f}")
                    else:
                        lines.append(f"  - {k}: {v}")
        elif isinstance(value, list):
            if len(value) > 0:
                lines.append(f"**{key}**: {value}")
        else:
            if isinstance(value, float):
                lines.append(f"**{key}**: {value:.4f}")
            else:
                lines.append(f"**{key}**: {value}")
    
    return "\n".join(lines) if lines else "No specific data available."


def format_stage_prompt(template: str, **kwargs) -> str:
    """Format a stage prompt with provided values."""
    # Convert context dicts to strings
    formatted_kwargs = {}
    for key, value in kwargs.items():
        if isinstance(value, dict):
            formatted_kwargs[key] = build_context_prompt(value)
        else:
            formatted_kwargs[key] = value
    
    return template.format(**formatted_kwargs)


def generate_followup_questions(intent: str, diagnosis: str) -> list:
    """Generate suggested followup questions based on intent and diagnosis."""
    followup_templates = {
        "vegetation_health": [
            "Which part of my field is most affected?",
            "How much water/fertilizer should I apply?",
            "Will this damage spread if I don't act now?"
        ],
        "water_stress": [
            "How much should I irrigate?",
            "Is rain expected this week?",
            "Which zone needs water most urgently?"
        ],
        "nutrient_status": [
            "Which fertilizer should I use?",
            "How much fertilizer per acre?",
            "When is the best time to apply?"
        ],
        "pest_disease": [
            "What pesticide should I use?",
            "How fast is this spreading?",
            "Should I quarantine the affected area?"
        ],
        "forecast_query": [
            "What should I prepare for?",
            "How will weather affect my crop next week?",
            "When is the best time to harvest?"
        ],
        "action_recommendation": [
            "How soon should I act?",
            "What's the most cost-effective solution?",
            "Can I wait for rain instead of irrigating?"
        ]
    }
    
    return followup_templates.get(intent, [
        "What should I do next?",
        "Is my crop at risk?",
        "How can I prevent this in the future?"
    ])


# =============================================================================
# FIELD COMPARISON PROMPT
# =============================================================================

COMPARISON_RESPONSE_PROMPT = """
{persona_instructions}

The user is asking to compare multiple fields. Analyze the data below and provide a comparative assessment.

FIELDS BEING COMPARED:
{comparison_data}

WEATHER CONTEXT (shared for all fields):
{weather_context}

Generate a comparative response that:
1. Creates a clear side-by-side summary of key health metrics for each field
2. Explicitly states which field is performing BETTER and which needs MORE ATTENTION
3. Identifies the KEY DIFFERENCES between fields and potential CAUSES
4. Provides FIELD-SPECIFIC recommendations (different actions per field)
5. Uses the weather forecast to suggest optimal timing for interventions
6. Matches the user's persona communication style

COMPARISON FORMAT:
- Start with a quick overview (which field needs priority)
- Use a structured comparison (Field A vs Field B)
- End with specific action items per field

Respond in natural language but use clear structure (headers, bullets) for easy comparison."""


def format_weather_context(weather_data: dict) -> str:
    """Format weather data into readable context for LLM."""
    if not weather_data:
        return "No weather data available."
    
    lines = []
    
    # Historical summary
    hist = weather_data.get("rolling_stats", {})
    if hist:
        lines.append("PAST 7 DAYS:")
        if hist.get("avg_temp_7d"):
            lines.append(f"  - Average Max Temp: {hist['avg_temp_7d']}°C")
        if hist.get("total_precip_7d") is not None:
            lines.append(f"  - Total Rainfall: {hist['total_precip_7d']} mm")
        if hist.get("dry_days_count") is not None:
            lines.append(f"  - Dry Days: {hist['dry_days_count']}")
        if hist.get("heat_stress_days") is not None:
            lines.append(f"  - Heat Stress Days (>35°C): {hist['heat_stress_days']}")
    
    # Forecast summary
    forecast = weather_data.get("forecast_7d", [])
    if forecast:
        lines.append("\nNEXT 7 DAYS FORECAST:")
        for day in forecast[:3]:  # First 3 days
            lines.append(f"  - {day.get('date', 'N/A')}: {day.get('temp_max', 'N/A')}°C, Rain: {day.get('precipitation', 0)}mm")
    
    # Stress indicators
    stress = weather_data.get("stress_indicators", {})
    if stress:
        lines.append("\nWEATHER STRESS INDICATORS:")
        if stress.get("current_heat_stress"):
            lines.append("  ⚠️ Current heat stress detected")
        if stress.get("predicted_heat_stress"):
            lines.append("  ⚠️ Heat stress predicted in next 3 days")
        if stress.get("drought_risk"):
            lines.append("  ⚠️ Drought risk - low recent and forecast rainfall")
        if stress.get("suitable_for_irrigation"):
            lines.append("  ✅ Good conditions for irrigation")
        if stress.get("suitable_for_spraying"):
            lines.append("  ✅ Good conditions for pesticide/fertilizer application")
    
    return "\n".join(lines) if lines else "Weather data not available."


# =============================================================================
# COMPACT CONTEXT BUILDER - Reduces Token Usage by ~50%
# =============================================================================

def build_compact_context(context: Dict) -> str:
    """
    Build a compressed context string using abbreviations and key-value format.
    Captures ALL essential data in ~50% fewer tokens.
    
    Format: KEY:value pairs, one per line, grouped by category.
    """
    lines = []
    
    # --- Field Info (compact) ---
    field = context.get("field_info", {})
    if field:
        lines.append(f"[FIELD] {field.get('name','?')} | {field.get('crop_type','?')} | {field.get('area_acres',0):.1f}ac")
    
    # --- ALL Vegetation Indices (compact key:value format) ---
    veg = context.get("vegetation_indices", {})
    if veg:
        # Primary indices (most important)
        primary = []
        for k in ["ndvi", "evi", "ndre", "smi", "ndwi"]:
            val = veg.get(k) or veg.get(k.upper())
            if val is not None:
                try:
                    primary.append(f"{k.upper()}:{float(val):.2f}")
                except (ValueError, TypeError):
                    pass
        if primary:
            lines.append(f"[VEG1] " + " | ".join(primary))
        
        # Secondary indices (stress/health indicators)
        secondary = []
        for k in ["psri", "pri", "mcari", "osavi", "reci"]:
            val = veg.get(k) or veg.get(k.upper())
            if val is not None:
                try:
                    secondary.append(f"{k.upper()}:{float(val):.2f}")
                except (ValueError, TypeError):
                    pass
        if secondary:
            lines.append(f"[VEG2] " + " | ".join(secondary))
        
        # Soil indices
        soil_idx = []
        for k in ["sasi", "somi", "sfi"]:
            val = veg.get(k) or veg.get(k.upper())
            if val is not None:
                try:
                    soil_idx.append(f"{k.upper()}:{float(val):.2f}")
                except (ValueError, TypeError):
                    pass
        if soil_idx:
            lines.append(f"[SOIL_IDX] " + " | ".join(soil_idx))
    
    # --- Health Summary (single line) ---
    health = context.get("health_summary", {})
    if health:
        score = health.get("overall_stress", health.get("stress_score", health.get("average_stress_score", 0)))
        status = health.get("status", health.get("crop_health", "unknown"))
        conf = health.get("confidence_score", health.get("confidence", 0))
        try:
            lines.append(f"[HEALTH] score:{float(score):.2f} status:{status} conf:{float(conf):.2f}")
        except (ValueError, TypeError):
            lines.append(f"[HEALTH] status:{status}")
    
    # --- Stressed Patches (count + top 5) ---
    patches = context.get("stressed_patches", [])
    if patches:
        lines.append(f"[STRESS] {len(patches)} patches")
        for p in patches[:5]:  # Top 5 patches
            pid = p.get('patch_id', p.get('id', '?'))
            score = p.get('stress_score', p.get('score', 0))
            try:
                lines.append(f"  P{pid}:{float(score):.2f}")
            except (ValueError, TypeError):
                lines.append(f"  P{pid}")
    
    # --- Clustering Data (critical for zone analysis) ---
    stress_analysis = context.get("stress_analysis", {})
    clusters = stress_analysis.get("cluster_statistics", [])
    if clusters:
        lines.append(f"[CLUSTERS] {len(clusters)} zones")
        for c in clusters[:3]:  # Top 3 clusters
            cid = c.get('cluster_id', '?')
            pct = c.get('percentage', 0)
            stress = c.get('stress_score', {}).get('mean', 0) if isinstance(c.get('stress_score'), dict) else 0
            lines.append(f"  C{cid}:{pct:.1f}% stress:{stress:.2f}")
    
    # --- SAR Bands (compact) ---
    sar = context.get("sar_bands", {})
    if sar:
        sar_parts = []
        for k in ["vv", "vh", "ratio", "VV", "VH"]:
            if k.lower() in sar or k in sar:
                val = sar.get(k.lower()) or sar.get(k)
                if val is not None:
                    try:
                        sar_parts.append(f"{k.upper()}:{float(val):.2f}")
                    except (ValueError, TypeError):
                        pass
        if sar_parts:
            lines.append(f"[SAR] " + " | ".join(sar_parts[:3]))
    
    # --- Weather (compressed with forecast) ---
    weather = context.get("weather", {})
    if weather:
        current = weather.get("current", {})
        if current:
            lines.append(f"[WX] T:{current.get('temp',0):.0f}°C H:{current.get('humidity',0):.0f}% Rain:{current.get('precip',0):.0f}mm")
        
        # Add 3-day forecast summary
        forecast = weather.get("forecast_7d", weather.get("forecast", []))
        if forecast and len(forecast) > 0:
            rain_days = sum(1 for d in forecast[:3] if d.get('precipitation', 0) > 5)
            max_temp = max((d.get('temp_max', 0) for d in forecast[:3]), default=0)
            lines.append(f"[FORECAST] 3d_rain_days:{rain_days} max_T:{max_temp:.0f}°C")
        
        # Weather alerts
        stress = weather.get("stress_indicators", {})
        flags = []
        if stress.get("current_heat_stress"): flags.append("HEAT")
        if stress.get("predicted_heat_stress"): flags.append("HEAT_RISK")
        if stress.get("drought_risk"): flags.append("DROUGHT")
        if stress.get("suitable_for_irrigation"): flags.append("OK_IRRIG")
        if stress.get("suitable_for_spraying"): flags.append("OK_SPRAY")
        if flags:
            lines.append(f"[WX_ALERT] " + ",".join(flags))
    
    # --- Soil Indicators (compact) ---
    soil = context.get("soil_indicators", {})
    if soil:
        soil_parts = []
        for k in ["moisture", "salinity", "fertility", "organic"]:
            if k in soil and soil[k]:
                level = soil[k].get("level", "") if isinstance(soil[k], dict) else soil[k]
                soil_parts.append(f"{k[:4]}:{level}")
        if soil_parts:
            lines.append(f"[SOIL] " + " | ".join(soil_parts))
    
    # --- Historical Trends (more detail) ---
    trends = context.get("historical_trends", {})
    if trends:
        summary = trends.get("summary", "")
        if summary:
            lines.append(f"[TREND] {summary[:120]}")
        # Add specific trend data
        ndvi_trend = trends.get("ndvi_change") or trends.get("NDVI_change")
        smi_trend = trends.get("smi_change") or trends.get("SMI_change")
        if ndvi_trend or smi_trend:
            parts = []
            if ndvi_trend: parts.append(f"NDVI:{ndvi_trend:+.2f}")
            if smi_trend: parts.append(f"SMI:{smi_trend:+.2f}")
            if parts:
                lines.append(f"[TREND_DATA] " + " ".join(parts))
    
    # --- Zone Analysis (all critical zones) ---
    zones = context.get("zone_analysis", {})
    if zones:
        priority_zones = zones.get("priority_zones", [])
        if priority_zones:
            lines.append(f"[ZONES] {len(priority_zones)} priority areas")
            for z in priority_zones[:3]:
                loc = z.get('location', '?')
                score = z.get('stress_score', 0)
                lines.append(f"  {loc}: stress:{score:.2f}")
        elif zones.get("most_critical"):
            mc = zones["most_critical"]
            lines.append(f"[ZONE_ALERT] {mc.get('location','?')} stress:{mc.get('stress_score',0):.2f}")
    
    # --- Previous Analysis (LLM insights from satellite) ---
    prev = context.get("previous_analysis", {})
    if prev:
        rec = prev.get("recommendation", prev.get("recommendations", ""))
        if rec:
            rec_text = rec[0] if isinstance(rec, list) else str(rec)
            lines.append(f"[PREV_REC] {rec_text[:80]}")
        
        concerns = prev.get("key_concerns", [])
        if concerns and isinstance(concerns, list):
            lines.append(f"[CONCERNS] " + ", ".join(str(c)[:30] for c in concerns[:3]))
    
    return "\n".join(lines) if lines else "No data"



# =============================================================================
# COMPRESSED STAGE PROMPTS - Reduce Token Usage
# =============================================================================

COMPACT_CLAIM_PROMPT = """Q:{query}
DATA:
{context}

Hypothesize. JSON only:
{{"claim":"diagnosis","hyp":"label","evidence":["val1","val2"],"conf":0.7,"unsure":["x"]}}"""

COMPACT_VALIDATE_PROMPT = """HYP:{previous_hypothesis} conf:{previous_confidence}
DATA:{priority_2_context}

Validate. JSON:
{{"result":"confirmed|weakened","conf":0.8,"spatial":"where","new_ev":"summary"}}"""

COMPACT_CONTRADICT_PROMPT = """HYP:{hypothesis} conf:{confidence}
ALT FACTORS:{priority_3_context}

Seek contradictions. JSON:
{{"contra_found":true,"contra_ev":["x"],"alt_hyp":"y","alt_conf":0.7,"reason":"z"}}"""

COMPACT_CONFIRM_PROMPT = """H1:{hypothesis_1} c:{conf_1}
H2:{hypothesis_2} c:{conf_2}
FINAL:{priority_4_context}

Decide. JSON:
{{"diag":"final","conf":0.85,"chain":"A→B→C","root":"cause","symptoms":["x"],"rec":"action"}}"""

COMPACT_RESPONSE_PROMPT = """{persona_instructions}

Q:{query}
DIAG:{diagnosis}
{weather_context}
{zone_context}

STRUCTURE:
1.ANSWER(2-3 sent): direct answer + key data
2.ACTION(1): what to do + when

Keep <100 words."""


def get_compact_prompt(stage: str) -> str:
    """Get the compact version of a stage prompt."""
    prompts = {
        "claim": COMPACT_CLAIM_PROMPT,
        "validate": COMPACT_VALIDATE_PROMPT,
        "contradict": COMPACT_CONTRADICT_PROMPT,
        "confirm": COMPACT_CONFIRM_PROMPT,
        "response": COMPACT_RESPONSE_PROMPT
    }
    return prompts.get(stage, "")


def format_minimal_diagnosis(result) -> str:
    """Format diagnosis in minimal tokens."""
    if isinstance(result, dict):
        return f"diag:{result.get('final_diagnosis','')} conf:{result.get('final_confidence',0):.2f} cause:{result.get('root_cause','?')}"

# =============================================================================
# HYBRID ARCHITECTURE PROMPTS
# =============================================================================

FAST_LANE_PROMPT = """You are Agrow-AI. 
TASK: Answer the user's question and diagnose any crop issues based on the provided context.
PRIORITY: SPEED & ACCURACY.

USER QUESTION:
{query}

CONTEXT:
{context}

INSTRUCTIONS:
1. [Hypothesis]: Briefly state what the primary signals (NDVI, NDRE, etc.) suggest.
2. [Check]: Verify if supporting data (Moisture, Weather) aligns or contradicts.
3. [Diagnosis]: State the final conclusion that ANSWERS THE USER'S QUESTION.
4. [Action]: One specific corrective action.

OUTPUT JSON ONLY:
{{
    "reasoning_trace": "Hypothesis... Check... Conclusion...",
    "diagnosis": "Final Diagnosis",
    "confidence": 0.0-1.0,
    "action": "Corrective Action"
}}
"""

DEEP_DIVE_HYPOTHESIS_PROMPT = """You are Agrow-AI, conducting a DEEP DIVE diagnosis.
STAGE A: HYPOTHESIS GENERATION

USER QUESTION:
{query}

CONTEXT:
{context}

TASK:
Identify top 3 possible causes that could answer the user's question. Do not conclude yet.
Think broadly (Nutrients, Pests, Water, Soil, Disease).

OUTPUT JSON ONLY:
{{
    "hypotheses": [
        {{"cause": "Cause 1", "likelihood": "High/Med", "reason": "why"}},
        {{"cause": "Cause 2", "likelihood": "High/Med", "reason": "why"}},
        {{"cause": "Cause 3", "likelihood": "High/Med", "reason": "why"}}
    ]
}}
"""

DEEP_DIVE_ADVERSARY_PROMPT = """You are Agrow-AI.
STAGE B: ADVERSARIAL CHECK

USER QUESTION:
{query}

HYPOTHESES:
{hypotheses}

NEW EVIDENCE (Adversarial Data):
{context}

TASK:
Actively try to DISPROVE each hypothesis using the new evidence (SAR, Soil, Pests).
If evidence contradicts a hypothesis, mark it as INVALID.
Remember to focus on answering the user's question.

OUTPUT JSON ONLY:
{{
    "analysis": [
        {{"cause": "Cause 1", "status": "Valid/Invalid", "reason": "Support/Contradiction from new evidence"}},
        ...
    ],
    "surviving_hypothesis": "The strongest remaining cause",
    "confidence": 0.0-1.0
}}
"""

DEEP_DIVE_JUDGE_PROMPT = """You are Agrow-AI.
STAGE C: FINAL VERDICT

USER QUESTION:
{query}

WINNING HYPOTHESIS:
{hypothesis}

CONSTRAINTS & HISTORY:
{context}

TASK:
Provide the final diagnostic report and a detailed action plan that DIRECTLY ANSWERS the user's question.
Consider farmer constraints (budget, machinery) and historical trends.

OUTPUT JSON ONLY:
{{
    "final_diagnosis": "Diagnosis",
    "root_cause": "Root Cause",
    "detailed_reasoning": "Explanation of why this is the verdict",
    "action_plan": {{
        "immediate": "Action 1",
        "long_term": "Action 2"
    }}
}}
"""

