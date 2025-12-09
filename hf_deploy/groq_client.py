"""
AGROW Centralized Groq Client
=============================
Shared LLM client with key rotation and fallback for all AGROW backend services.

Features:
- Centralized API key pool (15 keys)
- Automatic key rotation on rate limits (429)
- Exponential backoff per key
- Detailed logging for debugging
"""

import time
import logging
from typing import Optional

# ============================================================================
# LOGGING
# ============================================================================
logger = logging.getLogger("GroqClient")

# ============================================================================
# GROQ API CONFIGURATION
# ============================================================================

# Full pool of Groq API keys for rotation
GROQ_API_KEYS = [
    # Original keys
    "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",
    "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",
    "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",
    "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",
    "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",
    "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",
    "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",
    "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",
    "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",
    # New keys (added 2025-12-09)
    "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",
    "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",
    "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",
    "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",
    "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",
    "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",
]

GROQ_MODEL = "llama-3.3-70b-versatile"

logger.info(f"[GroqClient] Initialized with {len(GROQ_API_KEYS)} API keys")


def call_groq(
    prompt: str,
    system_prompt: str = "You are an expert agricultural AI analyst. Always respond with valid JSON only, no markdown code blocks.",
    max_tokens: int = 2048,
    temperature: float = 0.7,
) -> str:
    """
    Call Groq API with automatic key rotation and fallback.
    
    Args:
        prompt: User prompt to send
        system_prompt: System message for the LLM
        max_tokens: Maximum tokens in response
        temperature: Sampling temperature
        
    Returns:
        Response text from the LLM
        
    Raises:
        ValueError: If all API keys fail
    """
    from groq import Groq
    
    if not GROQ_API_KEYS:
        raise ValueError("No GROQ_API_KEYS configured")
    
    max_attempts_per_key = 3
    base_backoff = 1.0
    last_error = None
    
    # Iterate through all available keys
    for key_idx, api_key in enumerate(GROQ_API_KEYS):
        try:
            client = Groq(api_key=api_key)
            logger.info(f"[GroqClient] Trying key {key_idx+1}/{len(GROQ_API_KEYS)}")
            
            # Retry logic per key (for network/timeout issues)
            for attempt in range(1, max_attempts_per_key + 1):
                try:
                    chat_completion = client.chat.completions.create(
                        messages=[
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": prompt}
                        ],
                        model=GROQ_MODEL,
                        temperature=temperature,
                        max_tokens=max_tokens,
                    )
                    
                    response_text = chat_completion.choices[0].message.content
                    logger.info(f"[GroqClient] Success with key {key_idx+1}! Response: {len(response_text)} chars")
                    return response_text
                    
                except Exception as e:
                    error_str = str(e)
                    logger.warning(f"[GroqClient] Key {key_idx+1} attempt {attempt} failed: {error_str[:100]}")
                    
                    # Rate limit (429) - immediately switch to next key
                    if "rate_limit" in error_str.lower() or "429" in error_str:
                        logger.info(f"[GroqClient] Rate limited. Switching to next key...")
                        break
                    
                    # Other errors - backoff and retry same key
                    if attempt < max_attempts_per_key:
                        wait = base_backoff * (2 ** (attempt - 1))
                        logger.info(f"[GroqClient] Backing off {wait}s...")
                        time.sleep(wait)
                    else:
                        # Move to next key
                        raise e
                        
        except Exception as e:
            last_error = str(e)
            logger.warning(f"[GroqClient] Key {key_idx+1} failed completely: {str(e)[:100]}")
            continue
    
    raise ValueError(f"All {len(GROQ_API_KEYS)} Groq API keys failed. Last error: {last_error}")



# Backward compatibility alias
def call_gemini_with_fallback(prompt: str, keys=None, url=None) -> str:
    """Backward compatible wrapper - now uses Groq."""
    return call_groq(prompt)


def call_groq_whisper(audio_filename: str) -> str:
    """
    Transcribe audio using Groq Whisper model.
    Uses centralized key rotation.
    """
    from groq import Groq
    
    if not GROQ_API_KEYS:
        raise ValueError("No GROQ_API_KEYS configured")
        
    last_error = None
    
    # Iterate through keys
    for key_idx, api_key in enumerate(GROQ_API_KEYS):
        try:
            client = Groq(api_key=api_key)
            logger.info(f"[GroqClient-Whisper] Trying key {key_idx+1}/{len(GROQ_API_KEYS)}")
            
            with open(audio_filename, "rb") as file:
                transcription = client.audio.transcriptions.create(
                    file=(audio_filename, file.read()),
                    model="whisper-large-v3",
                    response_format="json",
                    language="en", 
                    temperature=0.0
                )
                
            logger.info(f"[GroqClient-Whisper] Success with key {key_idx+1}")
            return transcription.text
            
        except Exception as e:
            error_str = str(e)
            logger.warning(f"[GroqClient-Whisper] Key {key_idx+1} failed: {error_str[:100]}")
            
            # If rate limit, try next key immediately
            if "rate_limit" in error_str.lower() or "429" in error_str:
                continue
                
            last_error = str(e)
            continue
            
    raise ValueError(f"All keys failed for Whisper. Last error: {last_error}")
