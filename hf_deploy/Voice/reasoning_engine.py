"""
Multi-Stage Reasoning Engine for Agricultural Chatbot
======================================================
Implements the full spec: Claim → Validate → Contradict → Confirm pipeline
with priority-based context selection and evidence tracking.
"""

import json
import logging
from typing import Dict, List, Any, Optional, Tuple, Callable
from dataclasses import dataclass, field

from intent_classifier import IntentClassifier
from priority_mapper import PriorityContextMapper
from prompts import (
    SYSTEM_PROMPT, CLAIM_PROMPT, VALIDATE_PROMPT, 
    CONTRADICT_PROMPT, CONFIRM_PROMPT, RESPONSE_PROMPT,
    format_stage_prompt, build_context_prompt, generate_followup_questions,
    # Compact prompts for token reduction
    COMPACT_CLAIM_PROMPT, COMPACT_VALIDATE_PROMPT, COMPACT_CONTRADICT_PROMPT,
    COMPACT_CONFIRM_PROMPT, COMPACT_RESPONSE_PROMPT,
    build_compact_context, get_compact_prompt, format_minimal_diagnosis
)

logger = logging.getLogger("ReasoningEngine")

# Toggle compact prompts to reduce token usage (saves ~50% tokens)
USE_COMPACT_PROMPTS = True


# =============================================================================
# DATA CLASSES
# =============================================================================

@dataclass
class StageResult:
    """Result from a single reasoning stage."""
    stage: str
    output: Dict[str, Any]
    context_used: List[str]
    confidence: float
    raw_response: str = ""


@dataclass
class ReasoningResult:
    """Complete reasoning chain result."""
    claim: StageResult
    validation: StageResult
    contradiction: StageResult
    confirmation: StageResult
    final_diagnosis: str
    final_confidence: float
    causal_chain: str
    root_cause: str
    symptoms: List[str]
    recommendation: str
    evidence_summary: Dict[str, List[str]]


# =============================================================================
# REASONING ENGINE
# =============================================================================

class ReasoningEngine:
    """
    Multi-stage reasoning engine for agricultural chatbot.
    
    Following the spec:
    - Does NOT ingest all context at once
    - Uses priority-based context selection per intent
    - Actively seeks contradictions in Stage C
    - Tracks evidence chain for transparency
    """
    
    def __init__(self, llm_caller: Callable[[str], str]):
        """
        Args:
            llm_caller: Function that takes (prompt: str) -> str
        """
        self.llm = llm_caller
        self.intent_classifier = IntentClassifier()
        self.priority_mapper = PriorityContextMapper()
    
    def process_query(
        self, 
        query: str, 
        context: Optional[Dict[str, Any]] = None
    ) -> Tuple[str, Dict[str, Any]]:
        """
        Process user query through full reasoning pipeline.
        
        Returns:
            (response_text, reasoning_trace)
        """
        logger.info(f"Processing query: {query[:50]}...")
        
        # Stage 1: Classify intent
        intent = self.intent_classifier.classify(query)
        logger.info(f"Intent: {intent['primary_intent']} ({intent['confidence']})")
        
        # Stage 2: Get prioritized context (NOT all context at once!)
        staged_context = self.priority_mapper.build_staged_context(
            intent=intent["primary_intent"],
            full_context=context or {}
        )
        
        # Stage 3: Multi-stage reasoning
        reasoning_result = self._reason(query, intent, staged_context)
        
        # Stage 4: Generate response (pass full context for persona/weather/zone)
        response = self._generate_response(query, reasoning_result, context)
        
        # Stage 5: Generate followups
        followups = generate_followup_questions(
            intent["primary_intent"],
            reasoning_result.final_diagnosis
        )
        
        # Build complete trace
        trace = self._build_trace(intent, reasoning_result, staged_context, followups)
        
        return response, trace
    
    def _reason(
        self, 
        query: str, 
        intent: Dict, 
        staged_context: Dict
    ) -> ReasoningResult:
        """Execute 4-stage reasoning pipeline as per spec."""
        
        # Stage A: Initial Claim (Priority 1 context only)
        logger.info("Stage A: Making initial claim...")
        claim = self._stage_claim(query, staged_context["claim_context"])
        
        # Stage B: Validate (Add Priority 2 context)
        logger.info(f"Stage B: Validating hypothesis '{claim.output.get('hypothesis')}'...")
        validation = self._stage_validate(
            hypothesis=claim.output.get("hypothesis", "unknown"),
            confidence=claim.confidence,
            context=staged_context["validate_context"]
        )
        
        # Stage C: Contradict (Priority 3 - actively seek alternatives)
        current_hypothesis = validation.output.get("hypothesis", 
                                                   claim.output.get("hypothesis", "unknown"))
        logger.info(f"Stage C: Seeking contradictions to '{current_hypothesis}'...")
        contradiction = self._stage_contradict(
            hypothesis=current_hypothesis,
            confidence=validation.confidence,
            context=staged_context["contradict_context"]
        )
        
        # Stage D: Confirm (Priority 4 - final decision)
        logger.info("Stage D: Final confirmation...")
        confirmation = self._stage_confirm(
            hypothesis_1=current_hypothesis,
            conf_1=validation.confidence,
            hypothesis_2=contradiction.output.get("alternative_hypothesis", "none"),
            conf_2=contradiction.output.get("alternative_confidence", 0),
            context=staged_context["confirm_context"]
        )
        
        return ReasoningResult(
            claim=claim,
            validation=validation,
            contradiction=contradiction,
            confirmation=confirmation,
            final_diagnosis=confirmation.output.get("final_diagnosis", "Undetermined"),
            final_confidence=confirmation.confidence,
            causal_chain=confirmation.output.get("causal_chain", ""),
            root_cause=confirmation.output.get("root_cause", "unknown"),
            symptoms=confirmation.output.get("symptoms", []),
            recommendation=confirmation.output.get("recommendation", ""),
            evidence_summary={
                "primary": claim.context_used,
                "supporting": validation.context_used,
                "alternative": contradiction.context_used,
                "validation": confirmation.context_used,
                "supporting_evidence": confirmation.output.get("evidence_summary", {}).get("supporting", []),
                "contradicting_evidence": confirmation.output.get("evidence_summary", {}).get("contradicting", []),
                "inconclusive_evidence": confirmation.output.get("evidence_summary", {}).get("inconclusive", [])
            }
        )
    
    def _stage_claim(self, query: str, context: Dict) -> StageResult:
        """Stage 3A: Make initial claim using Priority 1 context only."""
        if USE_COMPACT_PROMPTS:
            compact_ctx = build_compact_context(context) if isinstance(context, dict) else str(context)
            prompt = COMPACT_CLAIM_PROMPT.format(query=query, context=compact_ctx)
        else:
            prompt = format_stage_prompt(
                CLAIM_PROMPT,
                query=query,
                priority_1_context=context
            )
        
        full_prompt = f"{SYSTEM_PROMPT}\n\n{prompt}" if not USE_COMPACT_PROMPTS else prompt
        response = self.llm(full_prompt)
        
        output = self._parse_json_safe(response, {
            "initial_claim": response[:200] if response else "No analysis available",
            "hypothesis": "general_issue",
            "evidence_cited": list(context.keys()),
            "confidence": 0.5,
            "uncertainties": ["Limited data available"]
        })
        
        return StageResult(
            stage="claim",
            output=output,
            context_used=list(context.keys()),
            confidence=output.get("confidence", 0.5),
            raw_response=response
        )
    
    def _stage_validate(
        self, 
        hypothesis: str, 
        confidence: float, 
        context: Dict
    ) -> StageResult:
        """Stage 3B: Validate hypothesis using Priority 2 context."""
        if USE_COMPACT_PROMPTS:
            compact_ctx = build_compact_context(context) if isinstance(context, dict) else str(context)
            prompt = COMPACT_VALIDATE_PROMPT.format(
                previous_hypothesis=hypothesis,
                previous_confidence=confidence,
                priority_2_context=compact_ctx
            )
        else:
            prompt = format_stage_prompt(
                VALIDATE_PROMPT,
                previous_hypothesis=hypothesis,
                previous_confidence=confidence,
                priority_2_context=context
            )
        
        full_prompt = f"{SYSTEM_PROMPT}\n\n{prompt}" if not USE_COMPACT_PROMPTS else prompt
        response = self.llm(full_prompt)
        
        output = self._parse_json_safe(response, {
            "validation_result": "neutral",
            "confidence_updated": confidence,
            "spatial_notes": "Unable to determine spatial distribution",
            "new_evidence_summary": ""
        })
        
        # Carry forward hypothesis
        output["hypothesis"] = hypothesis
        
        return StageResult(
            stage="validate",
            output=output,
            context_used=list(context.keys()),
            confidence=output.get("confidence_updated", confidence),
            raw_response=response
        )
    
    def _stage_contradict(
        self, 
        hypothesis: str, 
        confidence: float, 
        context: Dict
    ) -> StageResult:
        """Stage 3C: Actively seek contradictions using Priority 3 context."""
        if USE_COMPACT_PROMPTS:
            compact_ctx = build_compact_context(context) if isinstance(context, dict) else str(context)
            prompt = COMPACT_CONTRADICT_PROMPT.format(
                hypothesis=hypothesis,
                confidence=confidence,
                priority_3_context=compact_ctx
            )
        else:
            prompt = format_stage_prompt(
                CONTRADICT_PROMPT,
                hypothesis=hypothesis,
                confidence=confidence,
                priority_3_context=context
            )
        
        full_prompt = f"{SYSTEM_PROMPT}\n\n{prompt}" if not USE_COMPACT_PROMPTS else prompt
        response = self.llm(full_prompt)
        
        output = self._parse_json_safe(response, {
            "contradiction_found": False,
            "contradicting_evidence": [],
            "alternative_hypothesis": "none",
            "alternative_confidence": 0.0,
            "reasoning": "No strong contradicting evidence found"
        })
        
        return StageResult(
            stage="contradict",
            output=output,
            context_used=list(context.keys()),
            confidence=output.get("alternative_confidence", 0.0),
            raw_response=response
        )
    
    def _stage_confirm(
        self,
        hypothesis_1: str,
        conf_1: float,
        hypothesis_2: str,
        conf_2: float,
        context: Dict
    ) -> StageResult:
        """Stage 3D: Final confirmation using Priority 4 context."""
        if USE_COMPACT_PROMPTS:
            compact_ctx = build_compact_context(context) if isinstance(context, dict) else str(context)
            prompt = COMPACT_CONFIRM_PROMPT.format(
                hypothesis_1=hypothesis_1,
                conf_1=conf_1,
                hypothesis_2=hypothesis_2 if hypothesis_2 != "none" else "no_alt",
                conf_2=conf_2,
                priority_4_context=compact_ctx
            )
        else:
            prompt = format_stage_prompt(
                CONFIRM_PROMPT,
                hypothesis_1=hypothesis_1,
                conf_1=conf_1,
                hypothesis_2=hypothesis_2 if hypothesis_2 != "none" else "no_alternative",
                conf_2=conf_2,
                priority_4_context=context
            )
        
        full_prompt = f"{SYSTEM_PROMPT}\n\n{prompt}" if not USE_COMPACT_PROMPTS else prompt
        response = self.llm(full_prompt)
        
        # Pick the more confident hypothesis as default
        default_diagnosis = hypothesis_1 if conf_1 >= conf_2 else hypothesis_2
        default_conf = max(conf_1, conf_2)
        
        output = self._parse_json_safe(response, {
            "final_diagnosis": default_diagnosis,
            "confidence": default_conf,
            "causal_chain": f"{default_diagnosis} leads to observed symptoms",
            "root_cause": default_diagnosis,
            "symptoms": [],
            "evidence_summary": {
                "supporting": list(context.keys()),
                "contradicting": [],
                "inconclusive": []
            },
            "recommendation": "Further investigation recommended based on available data"
        })
        
        return StageResult(
            stage="confirm",
            output=output,
            context_used=list(context.keys()),
            confidence=output.get("confidence", default_conf),
            raw_response=response
        )
    
    def _generate_response(self, query: str, result: ReasoningResult, 
                            context: Dict = None) -> str:
        """Generate final user-facing response with persona and context."""
        diagnosis_data = {
            "diagnosis": result.final_diagnosis,
            "confidence": result.final_confidence,
            "causal_chain": result.causal_chain,
            "root_cause": result.root_cause,
            "symptoms": result.symptoms,
            "recommendation": result.recommendation
        }
        
        # Extract persona instructions
        persona = context.get("persona", {}) if context else {}
        persona_instructions = persona.get("instructions", "Provide clear, helpful farming advice.")
        
        # Conversation history disabled to reduce token usage
        history_text = ""
        
        # Format zone context
        zone_data = context.get("zone_analysis", {}) if context else {}
        if zone_data and zone_data.get("priority_zones"):
            zones = zone_data["priority_zones"]
            zone_text = "PRIORITY ZONES:\n"
            for i, z in enumerate(zones[:3], 1):
                zone_text += f"  {i}. {z.get('location', 'Zone')} - Stress: {z.get('stress_score', 0):.0%}\n"
        else:
            zone_text = "No zone-specific data available."
        
        # Format trend context
        trend_data = context.get("historical_trends", {}) if context else {}
        if trend_data.get("summary"):
            trend_text = trend_data["summary"]
        else:
            trend_text = "No historical trend data available."
        
        # Format weather context
        weather = context.get("weather", {}) if context else {}
        if weather:
            from prompts import format_weather_context
            weather_text = format_weather_context(weather)
        else:
            weather_text = "No weather data available."
        
        prompt = format_stage_prompt(
            RESPONSE_PROMPT,
            query=query,
            diagnosis=json.dumps(diagnosis_data, indent=2),
            evidence=json.dumps(result.evidence_summary, indent=2),
            persona_instructions=persona_instructions,
            conversation_history=history_text,
            zone_context=zone_text,
            trend_context=trend_text,
            weather_context=weather_text
        )
        
        full_prompt = f"{SYSTEM_PROMPT}\n\n{prompt}"
        response = self.llm(full_prompt)
        
        return response
    
    def _build_trace(
        self, 
        intent: Dict, 
        result: ReasoningResult,
        staged_context: Dict,
        followups: List[str]
    ) -> Dict[str, Any]:
        """Build reasoning trace for transparency as per spec."""
        return {
            "intent_detected": intent["primary_intent"],
            "intent_confidence": intent["confidence"],
            "sub_intents": intent["sub_intents"],
            "stages": {
                "claim": {
                    "hypothesis": result.claim.output.get("hypothesis"),
                    "initial_claim": result.claim.output.get("initial_claim"),
                    "confidence": result.claim.confidence,
                    "context_used": result.claim.context_used,
                    "evidence_cited": result.claim.output.get("evidence_cited", [])
                },
                "validation": {
                    "result": result.validation.output.get("validation_result"),
                    "confidence": result.validation.confidence,
                    "spatial_notes": result.validation.output.get("spatial_notes"),
                    "context_used": result.validation.context_used
                },
                "contradiction": {
                    "found": result.contradiction.output.get("contradiction_found"),
                    "alternative": result.contradiction.output.get("alternative_hypothesis"),
                    "alternative_confidence": result.contradiction.output.get("alternative_confidence"),
                    "reasoning": result.contradiction.output.get("reasoning"),
                    "context_used": result.contradiction.context_used
                },
                "confirmation": {
                    "final": result.final_diagnosis,
                    "confidence": result.final_confidence,
                    "root_cause": result.root_cause,
                    "causal_chain": result.causal_chain,
                    "context_used": result.confirmation.context_used
                }
            },
            "causal_chain": result.causal_chain,
            "root_cause": result.root_cause,
            "symptoms": result.symptoms,
            "evidence_summary": result.evidence_summary,
            "context_priority_used": {
                "priority_1": list(staged_context.get("claim_context", {}).keys()),
                "priority_2": list(staged_context.get("validate_context", {}).keys()),
                "priority_3": list(staged_context.get("contradict_context", {}).keys()),
                "priority_4": list(staged_context.get("confirm_context", {}).keys())
            },
            "suggested_followups": followups
        }
    
    def _parse_json_safe(self, text: str, default: Dict) -> Dict:
        """Safely extract and parse JSON from LLM response."""
        if not text:
            return default
        
        text = text.strip()
        
        # Look for JSON code block
        if "```json" in text:
            start = text.find("```json") + 7
            end = text.find("```", start)
            if end > start:
                text = text[start:end].strip()
        elif "```" in text:
            start = text.find("```") + 3
            end = text.find("```", start)
            if end > start:
                text = text[start:end].strip()
        
        # Find JSON object
        start = text.find("{")
        end = text.rfind("}") + 1
        
        if start >= 0 and end > start:
            try:
                return json.loads(text[start:end])
            except json.JSONDecodeError as e:
                logger.warning(f"JSON parse error: {e}")
        
        return default


# =============================================================================
# SIMPLE REASONING (Fallback)
# =============================================================================

def simple_reason(query: str, context: Dict, llm_caller: Callable) -> str:
    """Simplified single-stage reasoning for when full pipeline isn't needed."""
    context_str = build_context_prompt(context) if context else "No specific field data available."
    
    prompt = f"""{SYSTEM_PROMPT}

User Query: {query}

Available Context:
{context_str}

Provide a helpful, actionable response. If specific data is available, cite it.
If not, provide general guidance based on the query.

Use this format:
1. Direct answer to the question
2. Key observations from data (if available)
3. Practical recommendations
4. What to monitor or check next"""
    
    return llm_caller(prompt)
