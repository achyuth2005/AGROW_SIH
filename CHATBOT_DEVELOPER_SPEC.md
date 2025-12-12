# Intelligent Agricultural Chatbot - Developer Specification

> **Architecture**: Priority-based Context Selection with Multi-Stage Reasoning

---

## Core Principle

**The chatbot does NOT ingest all context at once.**

Instead, it follows a 4-stage reasoning pipeline:

```
User Query → Intent Detection → Priority Context Selection → 
Multi-Stage Reasoning (Claim → Validate → Contradict → Confirm) → Response
```

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              FLUTTER APP                                    │
│                         User sends: "Why is my crop yellowing?"             │
└─────────────────────────────────────────┬───────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         STAGE 1: INTENT CLASSIFIER                          │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  Query: "Why is my crop yellowing?"                                    │ │
│  │                                                                         │ │
│  │  Detected Intent: vegetation_health_diagnosis                          │ │
│  │  Sub-intents: [chlorophyll_issue, nutrient_deficiency, water_stress]  │ │
│  │  Confidence: 0.92                                                       │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────┬───────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STAGE 2: PRIORITY CONTEXT SELECTOR                       │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  Based on intent "vegetation_health_diagnosis":                        │ │
│  │                                                                         │ │
│  │  PRIORITY 1 (Primary Evidence):                                        │ │
│  │    - vegetation_indices.NDVI                                           │ │
│  │    - vegetation_indices.NDRE (chlorophyll)                             │ │
│  │    - vegetation_indices.RECI (chlorophyll)                             │ │
│  │    - temporal_trends.NDVI.trend                                        │ │
│  │                                                                         │ │
│  │  PRIORITY 2 (Supporting Evidence):                                     │ │
│  │    - vegetation_indices.EVI                                            │ │
│  │    - clustering.stressed_clusters                                      │ │
│  │    - anomaly_detection.anomaly_patches                                 │ │
│  │                                                                         │ │
│  │  PRIORITY 3 (Causal Factors):                                          │ │
│  │    - weather_data.temperature_stress                                   │ │
│  │    - vegetation_indices.SMI (soil moisture)                            │ │
│  │    - sentinel2_bands.B05 (red edge)                                    │ │
│  │                                                                         │ │
│  │  PRIORITY 4 (Validation/Contradiction):                                │ │
│  │    - sar_bands.VV (soil moisture proxy)                                │ │
│  │    - llm_analysis.previous_diagnosis                                   │ │
│  │    - farmer_profile.recent_actions                                     │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────┬───────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STAGE 3: MULTI-STAGE REASONING                           │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  STEP 3A: INITIAL CLAIM (Using Priority 1 context only)             │   │
│  │  ────────────────────────────────────────────────────────────────   │   │
│  │  LLM Input: {                                                        │   │
│  │    "query": "Why is my crop yellowing?",                             │   │
│  │    "context": {                                                      │   │
│  │      "NDVI": {"current": 0.45, "trend": "declining", "change": -0.12},│  │
│  │      "NDRE": {"current": 0.32, "interpretation": "low_chlorophyll"}, │   │
│  │      "RECI": {"current": 1.4, "interpretation": "chlorophyll_stress"}│   │
│  │    }                                                                 │   │
│  │  }                                                                   │   │
│  │                                                                      │   │
│  │  LLM Output: {                                                       │   │
│  │    "initial_claim": "Yellowing appears to be caused by chlorophyll  │   │
│  │                      deficiency, indicated by low NDRE (0.32) and    │   │
│  │                      declining NDVI trend (-0.12)",                  │   │
│  │    "confidence": 0.72,                                               │   │
│  │    "hypothesis": "chlorophyll_deficiency"                            │   │
│  │  }                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                          │                                  │
│                                          ▼                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  STEP 3B: VALIDATE (Add Priority 2 context)                         │   │
│  │  ────────────────────────────────────────────────────────────────   │   │
│  │  LLM Input: {                                                        │   │
│  │    "previous_claim": "chlorophyll_deficiency",                       │   │
│  │    "supporting_context": {                                           │   │
│  │      "EVI": {"current": 0.38, "confirms": true},                     │   │
│  │      "stress_clusters": [{"id": 2, "patches": 12, "stress": 0.68}],  │   │
│  │      "anomalies": [{"patch": 5, "type": "spectral_anomaly"}]         │   │
│  │    }                                                                 │   │
│  │  }                                                                   │   │
│  │                                                                      │   │
│  │  LLM Output: {                                                       │   │
│  │    "validation": "CONFIRMED - EVI also low, 12 patches in stress    │   │
│  │                   cluster align with chlorophyll deficiency pattern",│   │
│  │    "confidence_updated": 0.81,                                       │   │
│  │    "spatial_notes": "Concentrated in northeast quadrant"             │   │
│  │  }                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                          │                                  │
│                                          ▼                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  STEP 3C: CONTRADICT (Add Priority 3 - seek alternative causes)    │   │
│  │  ────────────────────────────────────────────────────────────────   │   │
│  │  LLM Input: {                                                        │   │
│  │    "current_hypothesis": "chlorophyll_deficiency",                   │   │
│  │    "alternative_factors": {                                          │   │
│  │      "weather": {"temp_max": 38, "heat_stress_days": 5},             │   │
│  │      "SMI": {"current": 0.18, "interpretation": "moisture_deficit"}, │   │
│  │      "B05_RedEdge": {"trend": "declining"}                           │   │
│  │    },                                                                │   │
│  │    "task": "Find evidence that CONTRADICTS chlorophyll deficiency   │   │
│  │             and suggests alternative cause"                          │   │
│  │  }                                                                   │   │
│  │                                                                      │   │
│  │  LLM Output: {                                                       │   │
│  │    "contradiction_found": true,                                      │   │
│  │    "alternative_hypothesis": "water_stress",                         │   │
│  │    "reasoning": "Low SMI (0.18) and 5 consecutive heat stress days  │   │
│  │                  suggest water stress as ROOT CAUSE. Chlorophyll    │   │
│  │                  deficiency may be SYMPTOM, not cause.",             │   │
│  │    "evidence_strength": 0.76                                         │   │
│  │  }                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                          │                                  │
│                                          ▼                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  STEP 3D: CONFIRM (Add Priority 4 - final validation)              │   │
│  │  ────────────────────────────────────────────────────────────────   │   │
│  │  LLM Input: {                                                        │   │
│  │    "competing_hypotheses": [                                         │   │
│  │      {"hypothesis": "chlorophyll_deficiency", "conf": 0.81},         │   │
│  │      {"hypothesis": "water_stress", "conf": 0.76}                    │   │
│  │    ],                                                                │   │
│  │    "validation_context": {                                           │   │
│  │      "SAR_VV": {"trend": "increasing", "note": "drier soil"},        │   │
│  │      "previous_llm_analysis": {"diagnosis": "moisture_declining"},   │   │
│  │      "farmer_actions": {"last_irrigation": "8 days ago"}             │   │
│  │    },                                                                │   │
│  │    "task": "Determine final diagnosis with confidence"               │   │
│  │  }                                                                   │   │
│  │                                                                      │   │
│  │  LLM Output: {                                                       │   │
│  │    "final_diagnosis": "water_stress_induced_chlorophyll_decline",    │   │
│  │    "confidence": 0.89,                                               │   │
│  │    "causal_chain": "Heat stress (5 days) + No irrigation (8 days)   │   │
│  │                     → Soil moisture deficit (SMI 0.18) →             │   │
│  │                     Chlorophyll degradation (NDRE 0.32) →            │   │
│  │                     Visible yellowing",                               │   │
│  │    "evidence_used": ["SMI", "weather", "SAR_VV", "farmer_actions"],  │   │
│  │    "contradicted": ["pure_nutrient_deficiency"]                      │   │
│  │  }                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────┬───────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STAGE 4: RESPONSE GENERATION                             │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  Final Response to User:                                               │ │
│  │                                                                         │ │
│  │  "Your crop is yellowing due to **water stress**, not a nutrient      │ │
│  │   problem. Here's how I determined this:                               │ │
│  │                                                                         │ │
│  │   📊 **Evidence**:                                                     │ │
│  │   - Soil Moisture Index is critically low (0.18)                       │ │
│  │   - Last irrigation was 8 days ago                                     │ │
│  │   - 5 consecutive days above 38°C                                      │ │
│  │   - SAR data confirms drying trend                                     │ │
│  │                                                                         │ │
│  │   🔬 **What's happening**:                                             │ │
│  │   Heat + drought → soil drying → plant can't uptake nutrients →       │ │
│  │   chlorophyll breaks down → leaves turn yellow                         │ │
│  │                                                                         │ │
│  │   ✅ **Recommendation**: Irrigate immediately, especially the         │ │
│  │   northeast sector where stress is highest."                           │ │
│  │                                                                         │ │
│  │  reasoning_trace: {...}  // Full reasoning chain for debugging        │ │
│  │  confidence: 0.89                                                      │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Intent-to-Context Priority Mapping

### Intent Classification Categories

| Intent Category | Example Queries |
|:---|:---|
| `vegetation_health` | "Why is my crop yellowing?", "Is my crop healthy?" |
| `water_stress` | "Does my field need water?", "Is there drought stress?" |
| `nutrient_status` | "Do I need fertilizer?", "Is there nitrogen deficiency?" |
| `pest_disease` | "Could this be a disease?", "Are there pest issues?" |
| `forecast_query` | "What will happen next week?", "How will my crop grow?" |
| `zone_specific` | "What's wrong in the northeast?", "Which area needs attention?" |
| `action_recommendation` | "What should I do?", "How do I fix this?" |
| `comparison` | "Is this better than last week?", "How has it changed?" |

### Priority Context Matrix

```json
{
  "intent_context_priorities": {
    
    "vegetation_health": {
      "priority_1": ["NDVI", "EVI", "NDRE", "RECI", "temporal_trends.NDVI"],
      "priority_2": ["clustering.stressed_patches", "anomalies", "PSRI"],
      "priority_3": ["weather.temperature", "SMI", "B05", "B08"],
      "priority_4": ["SAR.VV", "previous_llm", "farmer_actions"]
    },
    
    "water_stress": {
      "priority_1": ["SMI", "NDWI", "SAR.VV", "SAR.VH"],
      "priority_2": ["temporal_trends.SMI", "weather.precipitation", "weather.evapotranspiration"],
      "priority_3": ["NDVI", "clustering.moisture_clusters", "B11", "B12"],
      "priority_4": ["farmer_actions.irrigation", "forecast.rain", "previous_llm"]
    },
    
    "nutrient_status": {
      "priority_1": ["NDRE", "RECI", "MCARI", "B05", "B06", "B07"],
      "priority_2": ["NDVI", "EVI", "temporal_trends.NDRE"],
      "priority_3": ["SOMI", "SFI", "clustering.nutrient_clusters"],
      "priority_4": ["farmer_actions.fertilizer", "weather", "previous_llm"]
    },
    
    "pest_disease": {
      "priority_1": ["anomalies", "PSRI", "PRI", "spatial_patterns.hotspots"],
      "priority_2": ["NDVI", "temporal_trends.sudden_changes", "clustering.outliers"],
      "priority_3": ["weather.humidity", "B04", "B05"],
      "priority_4": ["farmer_actions.spraying", "previous_llm", "historical_issues"]
    },
    
    "zone_specific": {
      "priority_1": ["clustering.zone_stats", "patch_assignments", "spatial_embeddings"],
      "priority_2": ["anomalies.in_zone", "all_indices.zone_values"],
      "priority_3": ["temporal_trends.zone_specific"],
      "priority_4": ["previous_llm.zone_notes", "farmer_actions.zone_specific"]
    },
    
    "forecast_query": {
      "priority_1": ["forecast.predictions", "temporal_trends.all", "weather.forecast"],
      "priority_2": ["NDVI", "SMI", "current_stress_level"],
      "priority_3": ["historical_patterns", "growth_stage"],
      "priority_4": ["farmer_actions.planned", "previous_llm"]
    }
  }
}
```

---

## Context Data Structures

### Priority 1: Primary Evidence

```json
{
  "vegetation_indices": {
    "NDVI": {
      "current": 0.45,
      "trend_7d": -0.08,
      "trend_30d": -0.15,
      "zone_values": {
        "northwest": 0.52,
        "northeast": 0.31,
        "southwest": 0.48,
        "southeast": 0.51
      },
      "interpretation": "declining_vegetation_health"
    },
    "NDRE": {
      "current": 0.32,
      "healthy_threshold": 0.45,
      "interpretation": "chlorophyll_stress"
    },
    "RECI": {
      "current": 1.4,
      "healthy_range": [2.0, 4.0],
      "interpretation": "low_chlorophyll_content"
    }
  }
}
```

### Priority 2: Supporting Evidence

```json
{
  "clustering": {
    "cluster_2_stressed": {
      "num_patches": 12,
      "percentage": 18.75,
      "avg_stress_score": 0.68,
      "dominant_location": "northeast",
      "spectral_signature": {
        "NDVI_mean": 0.38,
        "NDRE_mean": 0.28,
        "SMI_mean": 0.15
      }
    }
  },
  "anomalies": {
    "detected": 7,
    "high_priority": [
      {
        "patch_id": 5,
        "location": "northeast",
        "anomaly_type": "spectral_outlier",
        "stress_score": 0.91
      }
    ]
  }
}
```

### Priority 3: Causal Factors

```json
{
  "weather": {
    "recent_7d": {
      "avg_temp_max": 36.5,
      "heat_stress_days": 5,
      "total_precipitation_mm": 0,
      "avg_humidity": 35
    },
    "stress_indicators": {
      "heat_stress": true,
      "drought_stress": true,
      "consecutive_dry_days": 12
    }
  },
  "soil_indicators": {
    "SMI": {
      "current": 0.18,
      "critical_threshold": 0.20,
      "status": "critical_deficit"
    }
  }
}
```

### Priority 4: Validation Context

```json
{
  "sar_validation": {
    "VV": {
      "current_db": -10.2,
      "trend": "increasing",
      "interpretation": "soil_drying"
    }
  },
  "previous_analysis": {
    "date": "2024-03-10",
    "diagnosis": "early_moisture_stress",
    "recommendation": "increase_irrigation"
  },
  "farmer_actions": {
    "last_irrigation": "2024-03-08",
    "days_since_irrigation": 8,
    "last_fertilizer": "2024-02-15",
    "notes": []
  }
}
```

---

## Reasoning Engine Implementation

### Python Class Structure

```python
class ReasoningEngine:
    """
    Multi-stage reasoning engine for agricultural chatbot.
    Does NOT ingest all context - uses priority-based selection.
    """
    
    def __init__(self, llm_client, context_store):
        self.llm = llm_client
        self.context = context_store
        self.intent_classifier = IntentClassifier()
        self.priority_mapper = PriorityContextMapper()
    
    async def process_query(self, user_query: str, session_id: str) -> Response:
        # Stage 1: Classify intent
        intent = self.intent_classifier.classify(user_query)
        
        # Stage 2: Get prioritized context (NOT all context)
        priority_context = self.priority_mapper.get_context(
            intent=intent,
            context_store=self.context
        )
        
        # Stage 3: Multi-stage reasoning
        reasoning_result = await self.reason(
            query=user_query,
            intent=intent,
            priority_context=priority_context
        )
        
        # Stage 4: Generate response
        response = self.generate_response(reasoning_result)
        
        return response
    
    async def reason(self, query, intent, priority_context):
        """4-step reasoning: Claim → Validate → Contradict → Confirm"""
        
        # Step A: Initial claim using Priority 1 only
        claim = await self.llm.generate(
            system_prompt=CLAIM_PROMPT,
            context=priority_context['priority_1'],
            query=query
        )
        
        # Step B: Validate using Priority 2
        validation = await self.llm.generate(
            system_prompt=VALIDATE_PROMPT,
            previous_claim=claim,
            context=priority_context['priority_2']
        )
        
        # Step C: Seek contradictions using Priority 3
        contradiction = await self.llm.generate(
            system_prompt=CONTRADICT_PROMPT,
            current_hypothesis=validation.hypothesis,
            context=priority_context['priority_3']
        )
        
        # Step D: Final confirmation using Priority 4
        final = await self.llm.generate(
            system_prompt=CONFIRM_PROMPT,
            hypotheses=[validation.hypothesis, contradiction.alternative],
            context=priority_context['priority_4']
        )
        
        return ReasoningResult(
            claim=claim,
            validation=validation,
            contradiction=contradiction,
            final=final,
            confidence=final.confidence,
            evidence_chain=self.build_evidence_chain(...)
        )
```

---

## LLM Prompts for Each Reasoning Stage

### Stage 3A: CLAIM Prompt

```
You are analyzing agricultural satellite data to diagnose crop issues.

USER QUERY: {query}

AVAILABLE EVIDENCE (Primary indicators only):
{priority_1_context}

Based ONLY on this primary evidence:
1. State your initial hypothesis about what's happening
2. Cite specific values that support your hypothesis
3. Rate your confidence (0.0 to 1.0)

Respond in JSON:
{
  "initial_claim": "...",
  "hypothesis": "single_word_label",
  "evidence_cited": ["index1: value", "index2: value"],
  "confidence": 0.X,
  "uncertainties": ["what you're unsure about"]
}
```

### Stage 3B: VALIDATE Prompt

```
You previously hypothesized: {previous_hypothesis}
Confidence: {previous_confidence}

ADDITIONAL SUPPORTING EVIDENCE:
{priority_2_context}

Does this new evidence:
1. CONFIRM your hypothesis? (increases confidence)
2. WEAKEN your hypothesis? (decreases confidence)
3. Add SPATIAL context? (where is the issue?)

Respond in JSON:
{
  "validation_result": "confirmed|weakened|neutral",
  "confidence_updated": 0.X,
  "spatial_notes": "where specifically",
  "new_evidence_summary": "..."
}
```

### Stage 3C: CONTRADICT Prompt

```
CURRENT HYPOTHESIS: {hypothesis} (confidence: {confidence})

YOUR TASK: Actively look for evidence that CONTRADICTS this hypothesis.

ALTERNATIVE CAUSAL FACTORS TO CONSIDER:
{priority_3_context}

Questions to answer:
1. Could something ELSE explain the symptoms?
2. Is there evidence that contradicts the current hypothesis?
3. What's the alternative explanation?

Respond in JSON:
{
  "contradiction_found": true|false,
  "contradicting_evidence": ["..."],
  "alternative_hypothesis": "...",
  "alternative_confidence": 0.X,
  "reasoning": "why alternative might be correct"
}
```

### Stage 3D: CONFIRM Prompt

```
COMPETING HYPOTHESES:
1. {hypothesis_1} (confidence: {conf_1})
2. {hypothesis_2} (confidence: {conf_2})

FINAL VALIDATION DATA:
{priority_4_context}

Determine the FINAL diagnosis by:
1. Weighing evidence for each hypothesis
2. Considering farmer's recent actions
3. Checking consistency with previous analyses
4. Identifying the ROOT CAUSE vs symptoms

Respond in JSON:
{
  "final_diagnosis": "...",
  "confidence": 0.X,
  "causal_chain": "A → B → C → symptom",
  "root_cause": "...",
  "symptoms": ["..."],
  "evidence_summary": {
    "supporting": ["..."],
    "contradicting": ["..."],
    "inconclusive": ["..."]
  },
  "recommendation": "what to do"
}
```

---

## API Response Structure

```json
{
  "response": {
    "message": "Your crop is yellowing due to water stress...",
    "confidence": 0.89,
    "diagnosis": "water_stress_induced_chlorophyll_decline"
  },
  
  "reasoning_trace": {
    "intent_detected": "vegetation_health",
    "stages": {
      "claim": {
        "hypothesis": "chlorophyll_deficiency",
        "confidence": 0.72,
        "context_used": ["NDVI", "NDRE", "RECI"]
      },
      "validation": {
        "result": "confirmed",
        "confidence": 0.81,
        "context_used": ["EVI", "clustering"]
      },
      "contradiction": {
        "found": true,
        "alternative": "water_stress",
        "confidence": 0.76,
        "context_used": ["weather", "SMI"]
      },
      "confirmation": {
        "final": "water_stress_root_cause",
        "confidence": 0.89,
        "context_used": ["SAR_VV", "farmer_actions"]
      }
    }
  },
  
  "context_priority_used": {
    "priority_1": ["NDVI", "NDRE", "RECI"],
    "priority_2": ["EVI", "clustering"],
    "priority_3": ["weather", "SMI"],
    "priority_4": ["SAR_VV", "farmer_actions"]
  },
  
  "suggested_followups": [
    "How much should I irrigate?",
    "Which area is most affected?",
    "Will rain help this week?"
  ]
}
```

---

## Implementation Files

```
chatbot/
├── api.py                    # FastAPI endpoints
├── reasoning_engine.py       # Multi-stage reasoning logic
├── intent_classifier.py      # Query intent detection
├── priority_mapper.py        # Intent → Context priority mapping
├── prompts.py               # LLM prompts for each stage
├── context_aggregator.py    # Fetches context from pipelines
├── models.py                # Pydantic schemas
├── supabase_client.py       # Session/history storage
├── requirements.txt
└── Dockerfile
```

---

## Key Design Principles

| Principle | Implementation |
|:---|:---|
| **Selective Context** | Only fetch context relevant to detected intent |
| **Priority Ordering** | Most diagnostic data first, validation data last |
| **Active Contradiction** | Explicitly prompt LLM to find alternative explanations |
| **Evidence Chain** | Track which data supports/contradicts each conclusion |
| **Confidence Scoring** | Update confidence at each reasoning stage |
| **Transparency** | Return full reasoning trace for debugging |

---

## Sentinel-2 Bands (13) + SAR (2) Reference

| Band | Priority Uses |
|:---|:---|
| B02 (Blue) | Water quality, atmospheric |
| B03 (Green) | Chlorophyll peak, NDWI |
| B04 (Red) | Chlorophyll absorption, stress |
| B05 (Red Edge 1) | Early stress detection |
| B06 (Red Edge 2) | Chlorophyll content |
| B07 (Red Edge 3) | LAI, biomass |
| B08 (NIR) | NDVI, vegetation health |
| B8A (NIR Narrow) | Water vapor reference |
| B09 (Water Vapor) | Atmospheric |
| B11 (SWIR 1) | Moisture, SMI |
| B12 (SWIR 2) | Soil/dry matter |
| SCL | Cloud/shadow mask |
| VV (SAR) | Soil moisture, structure |
| VH (SAR) | Vegetation volume/biomass |

---

## Summary: What Makes This Different

1. **NOT all context ingested** - Only priority-relevant data
2. **Intent-driven retrieval** - Query determines context selection
3. **4-stage reasoning** - Claim → Validate → Contradict → Confirm
4. **Active contradiction** - LLM explicitly seeks alternative explanations
5. **Confidence tracking** - Updated at each stage
6. **Evidence transparency** - Full reasoning trace returned
7. **Causal chain** - Distinguishes root cause from symptoms

---

*Specification Version: 2.0 - Priority Reasoning Architecture*  
*Last Updated: 2024-12-06*
