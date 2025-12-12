"""
AGROW Agricultural Chatbot Service - Hybrid Architecture v3
=============================================================
AI-powered agricultural advisor with:
- Hybrid Routing (Fast Lane vs Deep Dive)
- Fast Lane: 1-call for simple queries (<2s latency)
- Deep Dive: 3-call for complex diagnosis (Hypothesis → Adversary → Judge)
- Comprehensive satellite context from SAR, Sentinel-2, Weather
"""

import os
import json
import logging
import uuid
import requests
from datetime import datetime
from typing import Optional, List, Dict, Any
import traceback

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import asyncio
from groq import Groq

from supabase_client import SupabaseClient
from reasoning_engine import ReasoningEngine
from context_aggregator import ContextAggregator
from prompts import create_user_persona, PERSONA_DEFINITIONS

# ============================================================================
# LOGGING
# ============================================================================
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger("ChatbotService")

print("=" * 50)
print(f"===== AGROW Chatbot v3.0 (Hybrid) - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} =====")
print("=" * 50)

# ============================================================================
# GROQ SETUP 
# ============================================================================
from groq_client import GROQ_API_KEYS, GROQ_MODEL

logger.info(f"Loaded {len(GROQ_API_KEYS)} Groq API keys")

# Global key index for round-robin
current_key_idx = 0

def get_llm_caller():
    """Create LLM caller function with key rotation."""
    global current_key_idx
    
    def call_llm(prompt: str) -> str:
        global current_key_idx
        last_error = None
        
        for attempt in range(len(GROQ_API_KEYS)):
            key_idx = (current_key_idx + attempt) % len(GROQ_API_KEYS)
            try:
                client = Groq(api_key=GROQ_API_KEYS[key_idx])
                response = client.chat.completions.create(
                    messages=[{"role": "user", "content": prompt}],
                    model=GROQ_MODEL,
                    temperature=0.7,
                    max_tokens=4096,
                )
                # Rotate to next key for next call
                current_key_idx = (key_idx + 1) % len(GROQ_API_KEYS)
                return response.choices[0].message.content
            except Exception as e:
                last_error = e
                logger.warning(f"Key {key_idx+1} failed: {str(e)[:50]}")
                continue
        
        raise Exception(f"All {len(GROQ_API_KEYS)} keys failed. Last: {last_error}")
    
    return call_llm

# Initialize components
supabase = SupabaseClient()
aggregator = ContextAggregator()
reasoning_engine = ReasoningEngine(llm_caller=get_llm_caller())

# ============================================================================
# FASTAPI
# ============================================================================
app = FastAPI(
    title="AGROW Chatbot Service",
    description="AI agricultural advisor with Hybrid Reasoning (Fast Lane + Deep Dive)",
    version="3.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# REQUEST/RESPONSE MODELS
# ============================================================================
class ChatRequest(BaseModel):
    session_id: str
    message: str
    user_id: Optional[str] = None
    field_id: Optional[str] = None

class ChatResponse(BaseModel):
    response: str
    session_id: str
    message_id: str
    context_used: List[str]
    routing_mode: str  # NEW: "FAST_LANE" or "DEEP_DIVE"
    timestamp: str

class SessionRequest(BaseModel):
    user_id: str
    title: Optional[str] = None

class SessionResponse(BaseModel):
    session_id: str
    title: str
    created_at: str

# ============================================================================
# FETCH FIELD & PROFILE DATA FROM SUPABASE
# ============================================================================
def fetch_field_data(user_id: str, field_id: Optional[str] = None) -> Optional[Dict]:
    """Fetch field data from Supabase coordinates_quad."""
    try:
        if field_id:
            query = supabase.client.table("coordinates_quad").select("*").eq("id", field_id).limit(1).execute()
        else:
            query = supabase.client.table("coordinates_quad").select("*").eq("user_id", user_id).limit(1).execute()
        
        if query.data and len(query.data) > 0:
            field = query.data[0]
            lats = [field.get(f"lat{i}", 0) for i in range(1, 5)]
            lons = [field.get(f"lon{i}", 0) for i in range(1, 5)]
            return {
                "id": field.get("id"),
                "name": field.get("name", "My Field"),
                "crop_type": field.get("crop_type", "Wheat"),
                "area_acres": field.get("area_acres", 1.0),
                "center_lat": sum(lats) / 4,
                "center_lon": sum(lons) / 4,
                "bbox": [min(lons), min(lats), max(lons), max(lats)]
            }
    except Exception as e:
        logger.error(f"Error fetching field data: {e}")
    return None


def fetch_user_profile(user_id: str) -> Dict:
    """Fetch user profile and questionnaire from Supabase."""
    try:
        query = supabase.client.table("user_profiles").select(
            "full_name, address, questionnaire_data"
        ).eq("user_id", user_id).limit(1).execute()
        
        if query.data and len(query.data) > 0:
            profile = query.data[0]
            return {
                "full_name": profile.get("full_name", ""),
                "address": profile.get("address", ""),
                "questionnaire_data": profile.get("questionnaire_data", {}) or {}
            }
    except Exception as e:
        logger.error(f"Error fetching user profile: {e}")
    return {"full_name": "", "address": "", "questionnaire_data": {}}


# ============================================================================
# BUILD CONTEXT FOR REASONING ENGINE
# ============================================================================
def build_context_for_reasoning(user_id: str, field_id: Optional[str] = None) -> Dict:
    """Build context dict for reasoning engine using Supabase + APIs."""
    context = {"fetch_timestamp": datetime.now().isoformat()}
    
    # 1. Field data
    field = fetch_field_data(user_id, field_id)
    if not field:
        logger.warning("No field data found")
        return context
    
    context["field_info"] = {
        "name": field["name"],
        "crop_type": field["crop_type"],
        "area_acres": field["area_acres"]
    }
    
    # 2. Profile + Persona
    profile = fetch_user_profile(user_id)
    persona = create_user_persona(profile)
    context["persona"] = persona
    
    # 3. Fetch satellite data via aggregator
    coordinates = {
        "center_lat": field["center_lat"],
        "center_lon": field["center_lon"],
        "bbox": field["bbox"]
    }
    
    farmer_context = {
        "profile": persona,
        "actions": {}
    }
    
    try:
        satellite_context = aggregator.fetch_full_context(
            coordinates=coordinates,
            crop_type=field["crop_type"],
            area_acres=field["area_acres"],
            farmer_context=farmer_context
        )
        context.update(satellite_context)
        logger.info(f"Context built with keys: {list(context.keys())}")
    except Exception as e:
        logger.error(f"Error fetching satellite context: {e}")
    
    return context


# ============================================================================
# GENERATE RESPONSE USING HYBRID REASONING
# ============================================================================
def generate_response(user_message: str, history: List[Dict], context: Dict) -> tuple[str, List[str], str]:
    """Generate AI response using Hybrid Reasoning Engine."""
    try:
        response_text, trace = reasoning_engine.process_query(
            query=user_message,
            context=context
        )
        
        routing_mode = trace.get("routing_mode", "UNKNOWN")
        
        # Extract context_used safely (can be list or dict)
        priority_1 = trace.get("context_priority_used", {}).get("priority_1", [])
        if isinstance(priority_1, dict):
            context_used = list(priority_1.keys())
        elif isinstance(priority_1, list):
            context_used = priority_1
        else:
            context_used = []
        
        logger.info(f"[Hybrid] Mode: {routing_mode}, Diagnosis: {str(trace.get('stages', {}).get('confirmation', {}).get('final', 'N/A'))[:50]}")
        
        return response_text, context_used, routing_mode
        
    except Exception as e:
        logger.error(f"Reasoning error: {e}")
        traceback.print_exc()
        return "I apologize, but I encountered an error. Please try again.", [], "ERROR"


# ============================================================================
# API ENDPOINTS
# ============================================================================
@app.get("/")
async def root():
    return {
        "service": "AGROW Chatbot Service",
        "version": "3.0.0",
        "architecture": "Hybrid (Fast Lane + Deep Dive)",
        "features": ["hybrid_routing", "3_stage_reasoning", "persona_based"]
    }

@app.get("/health")
async def health():
    return {"status": "healthy", "groq_keys": len(GROQ_API_KEYS), "version": "3.0.0"}


@app.post("/session/new", response_model=SessionResponse)
async def create_session(request: SessionRequest):
    logger.info(f"Creating session for user: {request.user_id}")
    try:
        session = supabase.create_session(
            user_id=request.user_id,
            title=request.title or "New Conversation"
        )
        return SessionResponse(
            session_id=session["id"],
            title=session["title"],
            created_at=session["created_at"]
        )
    except Exception as e:
        logger.error(f"Failed to create session: {e}")
        raise HTTPException(500, str(e))


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    logger.info(f"Chat request - Session: {request.session_id}, Mode: Hybrid")
    
    try:
        history = supabase.get_messages(request.session_id)
        
        supabase.add_message(
            session_id=request.session_id,
            role="user",
            content=request.message
        )
        
        # Build context and generate response
        context = {}
        if request.user_id:
            context = build_context_for_reasoning(request.user_id, request.field_id)
        
        response_text, context_used, routing_mode = generate_response(
            request.message, history, context
        )
        
        assistant_msg_id = supabase.add_message(
            session_id=request.session_id,
            role="assistant",
            content=response_text,
            context_used=context_used
        )
        
        supabase.update_session_timestamp(request.session_id)
        
        return ChatResponse(
            response=response_text,
            session_id=request.session_id,
            message_id=assistant_msg_id,
            context_used=context_used,
            routing_mode=routing_mode,
            timestamp=datetime.now().isoformat()
        )
        
    except Exception as e:
        logger.error(f"Chat error: {e}")
        traceback.print_exc()
        raise HTTPException(500, str(e))


@app.post("/chat/stream")
async def chat_stream(request: ChatRequest):
    logger.info(f"Stream chat - Session: {request.session_id}")
    
    try:
        history = supabase.get_messages(request.session_id)
        
        supabase.add_message(
            session_id=request.session_id,
            role="user",
            content=request.message
        )
        
        context = {}
        if request.user_id:
            context = build_context_for_reasoning(request.user_id, request.field_id)
        
        response_text, context_used, routing_mode = generate_response(
            request.message, history, context
        )
        
        assistant_msg_id = supabase.add_message(
            session_id=request.session_id,
            role="assistant",
            content=response_text,
            context_used=context_used
        )
        
        supabase.update_session_timestamp(request.session_id)
        
        async def stream_response():
            yield f"data: {json.dumps({'type': 'metadata', 'session_id': request.session_id, 'message_id': assistant_msg_id, 'routing_mode': routing_mode})}\n\n"
            
            for i in range(0, len(response_text), 15):
                yield f"data: {json.dumps({'type': 'chunk', 'text': response_text[i:i+15]})}\n\n"
                await asyncio.sleep(0.03)
            
            yield f"data: {json.dumps({'type': 'done', 'full_text': response_text})}\n\n"
        
        return StreamingResponse(stream_response(), media_type="text/event-stream")
        
    except Exception as e:
        logger.error(f"Stream error: {e}")
        raise HTTPException(500, str(e))


@app.get("/context/{user_id}")
async def get_context(user_id: str, field_id: Optional[str] = None):
    """Debug endpoint - returns full context JSON."""
    return build_context_for_reasoning(user_id, field_id)


@app.get("/session/{session_id}/history")
async def get_history(session_id: str):
    try:
        messages = supabase.get_messages(session_id)
        return {"session_id": session_id, "messages": messages}
    except Exception as e:
        raise HTTPException(500, str(e))


@app.get("/sessions/{user_id}")
async def list_sessions(user_id: str):
    try:
        sessions = supabase.get_user_sessions(user_id)
        return {"user_id": user_id, "sessions": sessions, "count": len(sessions)}
    except Exception as e:
        raise HTTPException(500, str(e))


@app.delete("/session/{session_id}")
async def delete_session(session_id: str):
    try:
        supabase.delete_session(session_id)
        return {"status": "deleted", "session_id": session_id}
    except Exception as e:
        raise HTTPException(500, str(e))


if __name__ == "__main__":
    import uvicorn
    logger.info("Starting AGROW Chatbot Service v3.0 (Hybrid Architecture)")
    uvicorn.run(app, host="0.0.0.0", port=7860)
