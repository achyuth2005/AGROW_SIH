"""
Intent Classifier for Agricultural Chatbot
==========================================
Detects user intent with sub-intents for priority context selection.
Matching Developer Specification categories.
"""

from typing import Dict, List, Tuple
import re

# =============================================================================
# INTENT PATTERNS - Based on Developer Spec
# =============================================================================

INTENT_PATTERNS = {
    "vegetation_health": {
        "keywords": [
            "yellow", "yellowing", "brown", "browning", "dying", "wilting", 
            "healthy", "health", "crop health", "plant health", "leaf", "leaves",
            "chlorophyll", "green", "greenness", "stunted", "weak", "pale",
            "ndvi", "evi", "vegetation", "biomass", "vigor", "canopy"
        ],
        "phrases": [
            "why is my crop", "is my crop healthy", "crop looks", 
            "plants look", "leaves turning", "plant dying"
        ],
        "sub_intents": ["chlorophyll_issue", "nutrient_deficiency", "general_health"],
        "priority": 1
    },
    
    "water_stress": {
        "keywords": [
            "water", "irrigation", "irrigate", "dry", "drought", "moisture",
            "thirsty", "watering", "rain", "wet", "smi", "ndwi", "soil moisture",
            "dehydrated", "wilt", "drooping", "crispy", "parched"
        ],
        "phrases": [
            "need water", "should i water", "need irrigation", "drought stress",
            "when to irrigate", "soil is dry", "field is dry"
        ],
        "sub_intents": ["drought_stress", "overwatering", "irrigation_timing"],
        "priority": 2
    },
    
    "nutrient_status": {
        "keywords": [
            "fertilizer", "nutrient", "nitrogen", "phosphorus", "potassium",
            "npk", "deficiency", "feeding", "feed", "ndre", "reci", "mcari",
            "urea", "dap", "mop", "manure", "compost", "micronutrient"
        ],
        "phrases": [
            "need fertilizer", "nutrient deficiency", "should i fertilize",
            "lacking nutrients", "nitrogen deficiency", "fertilizer amount"
        ],
        "sub_intents": ["nitrogen_deficiency", "nutrient_excess", "fertilizer_timing"],
        "priority": 3
    },
    
    "pest_disease": {
        "keywords": [
            "pest", "disease", "insect", "bug", "infection", "fungus",
            "blight", "rot", "spots", "holes", "eating", "aphid", "borer",
            "rust", "mildew", "virus", "bacteria", "infestation", "damage"
        ],
        "phrases": [
            "pest attack", "disease problem", "insect damage", "fungal infection",
            "what is eating", "spots on leaves", "pest risk"
        ],
        "sub_intents": ["pest_damage", "fungal_disease", "bacterial_issue", "viral_disease"],
        "priority": 4
    },
    
    "zone_specific": {
        "keywords": [
            "area", "zone", "patch", "section", "part", "corner", "side",
            "northeast", "northwest", "southeast", "southwest", "north", "south",
            "east", "west", "center", "edge", "boundary", "specific"
        ],
        "phrases": [
            "which area", "which zone", "which part", "where is the problem",
            "affected area", "problem zone", "specific area"
        ],
        "sub_intents": ["zone_diagnosis", "zone_comparison", "spatial_query"],
        "priority": 5
    },
    
    "forecast_query": {
        "keywords": [
            "forecast", "predict", "prediction", "future", "next week", "tomorrow",
            "will", "expect", "trend", "coming days", "upcoming", "projection",
            "growth", "yield", "estimate", "outlook"
        ],
        "phrases": [
            "what will happen", "next week", "in the future", "will my crop",
            "expected yield", "growth forecast", "weather forecast"
        ],
        "sub_intents": ["growth_forecast", "stress_prediction", "weather_impact", "yield_forecast"],
        "priority": 6
    },
    
    "action_recommendation": {
        "keywords": [
            "what should", "how to", "fix", "solve", "recommend", "advice",
            "help", "do", "action", "steps", "treatment", "remedy", "solution",
            "best practice", "suggestion", "improve"
        ],
        "phrases": [
            "what should i do", "how do i fix", "how to solve", "recommend",
            "give me advice", "best action", "immediate action"
        ],
        "sub_intents": ["immediate_action", "long_term_plan", "preventive_action"],
        "priority": 7
    },
    
    "comparison": {
        "keywords": [
            "compare", "comparison", "better", "worse", "change", "changed", 
            "difference", "last week", "before", "improvement", "decline",
            "progress", "regression", "historical", "trend"
        ],
        "phrases": [
            "compared to", "better than", "worse than", "has it improved",
            "how has it changed", "over time", "last month"
        ],
        "sub_intents": ["temporal_comparison", "zone_comparison", "historical_analysis"],
        "priority": 8
    },
    
    "field_comparison": {
        "keywords": [
            "compare", "comparison", "versus", " vs ", "other field", "another field",
            "between fields", "both fields", "which field", "differ", "different field",
            "my other", "second field", "first field"
        ],
        "phrases": [
            "compare with", "compared to my", "how does my * compare", "between my fields",
            "which field is better", "difference between", "compare * and *",
            "other farm", "other farmland", "another farm"
        ],
        "sub_intents": ["multi_field_analysis", "field_ranking", "relative_health"],
        "priority": 2
    },
    
    "general_query": {
        "keywords": [
            "what", "how", "why", "tell", "about", "explain", "hello", "hi",
            "information", "details", "overview", "status", "summary"
        ],
        "phrases": [
            "tell me about", "what is", "how does", "explain"
        ],
        "sub_intents": ["general_info"],
        "priority": 9
    }
}

# Hindi/regional language keywords (common agricultural terms)
REGIONAL_KEYWORDS = {
    "vegetation_health": ["पीला", "पत्ते", "सूखा", "मुरझाना"],
    "water_stress": ["पानी", "सिंचाई", "सूखा"],
    "nutrient_status": ["खाद", "यूरिया", "उर्वरक"],
    "pest_disease": ["कीट", "रोग", "कीड़ा"]
}


# =============================================================================
# INTENT CLASSIFIER
# =============================================================================

class IntentClassifier:
    """
    Classifies user queries into agricultural intent categories.
    Uses keyword matching, phrase matching, and confidence scoring.
    """
    
    def __init__(self):
        self.patterns = INTENT_PATTERNS
        self.regional = REGIONAL_KEYWORDS
    
    def classify(self, query: str) -> Dict:
        """
        Classify the intent of a user query.
        
        Returns:
            {
                "primary_intent": str,
                "sub_intents": List[str],
                "confidence": float (0.0-1.0),
                "matched_keywords": List[str],
                "all_intents": List[Tuple[str, float]]  # All detected intents with scores
            }
        """
        query_lower = query.lower()
        intent_scores = {}
        matched_keywords = {}
        
        # Score each intent
        for intent, config in self.patterns.items():
            score, matches = self._score_intent(query_lower, config)
            
            # Also check regional keywords
            if intent in self.regional:
                for kw in self.regional[intent]:
                    if kw in query:
                        score += 0.3
                        matches.append(kw)
            
            if score > 0:
                intent_scores[intent] = min(score, 1.0)
                matched_keywords[intent] = matches
        
        if not intent_scores:
            return self._default_response()
        
        # Sort intents by score
        sorted_intents = sorted(intent_scores.items(), key=lambda x: x[1], reverse=True)
        primary_intent = sorted_intents[0][0]
        confidence = sorted_intents[0][1]
        
        # Get sub-intents
        sub_intents = self._detect_sub_intents(query_lower, primary_intent)
        
        return {
            "primary_intent": primary_intent,
            "sub_intents": sub_intents,
            "confidence": round(confidence, 2),
            "matched_keywords": matched_keywords.get(primary_intent, []),
            "all_intents": [(intent, round(score, 2)) for intent, score in sorted_intents[:3]]
        }
    
    def _score_intent(self, query: str, config: Dict) -> Tuple[float, List[str]]:
        """Calculate score for a single intent."""
        score = 0.0
        matches = []
        
        keywords = config.get("keywords", [])
        phrases = config.get("phrases", [])
        
        # Check keyword matches
        for kw in keywords:
            if kw in query:
                score += 0.15
                matches.append(kw)
                # Bonus for exact word match (not substring)
                if re.search(rf'\b{re.escape(kw)}\b', query):
                    score += 0.05
        
        # Check phrase matches (higher score)
        for phrase in phrases:
            if phrase in query:
                score += 0.35
                matches.append(phrase)
        
        # Boost for multiple matches
        if len(matches) >= 3:
            score += 0.1
        
        return score, matches
    
    def _detect_sub_intents(self, query: str, primary_intent: str) -> List[str]:
        """Detect more specific sub-intents within the primary intent."""
        sub_intents = []
        config = self.patterns.get(primary_intent, {})
        
        # Add base sub-intent
        if config.get("sub_intents"):
            sub_intents.append(config["sub_intents"][0])
        
        # Detect question type
        if "why" in query:
            sub_intents.append("causal_analysis")
        if "how much" in query or "how many" in query or "quantity" in query:
            sub_intents.append("quantitative")
        if "when" in query:
            sub_intents.append("temporal")
        if "where" in query:
            sub_intents.append("spatial")
        if "should" in query or "recommend" in query:
            sub_intents.append("recommendation_needed")
        if "urgent" in query or "immediately" in query or "emergency" in query:
            sub_intents.append("urgent")
        
        return sub_intents if sub_intents else ["general"]
    
    def extract_field_names(self, query: str, available_fields: List[str]) -> List[str]:
        """
        Extract field names mentioned in the query.
        
        This enables dynamic field comparison - when a user mentions
        another field name, we can fetch data for that field and compare.
        
        Args:
            query: User's message
            available_fields: List of user's registered field names
            
        Returns:
            List of detected field names (in order of appearance)
        """
        if not available_fields:
            return []
        
        query_lower = query.lower()
        detected = []
        
        # Check each registered field name
        for field_name in available_fields:
            if not field_name:
                continue
            # Check if field name appears in query (case-insensitive)
            if field_name.lower() in query_lower:
                detected.append(field_name)
        
        # Also check for ordinal patterns like "field 1", "field 2", "first field"
        ordinal_map = {
            "first": 0, "1st": 0, "field 1": 0, "field one": 0,
            "second": 1, "2nd": 1, "field 2": 1, "field two": 1,
            "third": 2, "3rd": 2, "field 3": 2, "field three": 2
        }
        
        for pattern, idx in ordinal_map.items():
            if pattern in query_lower and idx < len(available_fields):
                field = available_fields[idx]
                if field not in detected:
                    detected.append(field)
        
        return detected
    
    def is_field_comparison_query(self, query: str, available_fields: List[str]) -> bool:
        """
        Check if the query is asking to compare multiple fields.
        
        Returns True if:
        1. Multiple field names are mentioned, OR
        2. Comparison keywords + at least one field name
        """
        intent = self.classify(query)
        mentioned_fields = self.extract_field_names(query, available_fields)
        
        # Multiple fields mentioned
        if len(mentioned_fields) >= 2:
            return True
        
        # Comparison intent + at least one field mentioned
        if intent["primary_intent"] in ["field_comparison", "comparison"]:
            if len(mentioned_fields) >= 1:
                return True
            # Check for phrases like "other field", "another farm"
            comparison_phrases = ["other field", "another field", "other farm", "another farm", 
                                  "my other", "between fields"]
            query_lower = query.lower()
            for phrase in comparison_phrases:
                if phrase in query_lower:
                    return True
        
        return False
    
    def _default_response(self) -> Dict:
        """Return default classification for unrecognized queries."""
        return {
            "primary_intent": "general_query",
            "sub_intents": ["general_info"],
            "confidence": 0.4,
            "matched_keywords": [],
            "all_intents": [("general_query", 0.4)]
        }
    
    def get_priority_for_intent(self, intent: str) -> int:
        """Get priority number for an intent."""
        return self.patterns.get(intent, {}).get("priority", 9)
