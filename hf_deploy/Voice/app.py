"""
AGROW Voice Service
===================
Lightweight audio transcription service using Groq Whisper.
"""

import os
import logging
import traceback
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import shutil

# Import modules from parent directory
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/..")
from groq_client import call_groq_whisper

# ============================================================================
# LOGGING
# ============================================================================
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger("VoiceService")

# ============================================================================
# FASTAPI
# ============================================================================
app = FastAPI(
    title="AGROW Voice Service",
    description="Audio transcription using Groq Whisper",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def home():
    return {"status": "running", "service": "AGROW Voice Service"}


@app.post("/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    """
    Transcribe uploaded audio file using Groq Whisper.
    """
    try:
        logger.info(f"Received audio file: {file.filename}, content_type: {file.content_type}")
        
        # Create temp file
        temp_filename = f"temp_{file.filename}"
        with open(temp_filename, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        try:
            # Transcribe
            logger.info("Sending to Groq Whisper...")
            text = call_groq_whisper(temp_filename)
            logger.info(f"Transcription success: {len(text)} chars")
            return {"transcription": text}
            
        finally:
            # Cleanup
            if os.path.exists(temp_filename):
                os.remove(temp_filename)
                
    except Exception as e:
        logger.error(f"Transcription error: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=7860)
