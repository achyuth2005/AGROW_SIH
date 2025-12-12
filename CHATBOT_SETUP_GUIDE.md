# Chatbot System - Complete Setup Guide

## Yes, Hugging Face Can Host Your ML Pipeline! 🤗

**Hugging Face Spaces** is a free/low-cost platform to host your Python ML pipelines as APIs.

---

## System Overview (Simple Explanation)

```
┌─────────────────┐      ┌──────────────────────┐      ┌─────────────┐
│  Flutter App    │ ───► │  Hugging Face Space  │ ───► │  Supabase   │
│  (Your UI)      │ ◄─── │  (FastAPI + ML)      │ ◄─── │  (Storage)  │
└─────────────────┘      └──────────────────────┘      └─────────────┘
                                   │
                                   ▼
                         ┌─────────────────┐
                         │   Gemini LLM    │
                         │   (Chat Brain)  │
                         └─────────────────┘
```

**What Each Part Does:**
- **Flutter App**: Your chat UI (already built)
- **Hugging Face Space**: Hosts your Python code as a web API (FREE tier available)
- **Supabase**: Stores chat history & user sessions
- **Gemini LLM**: Powers intelligent responses

---

## Step-by-Step Procedure

### Phase 1: Prepare Files (Local)

| File | Purpose |
|:---|:---|
| `app.py` | FastAPI server with `/chat` endpoint |
| `context_aggregator.py` | Combines all pipeline outputs |
| `requirements.txt` | Python dependencies |
| `.env` | API keys (Gemini, Supabase) |

### Phase 2: Deploy to Hugging Face

```bash
# 1. Create Hugging Face account (free)
# 2. Create new Space → Select "Docker" or "Gradio"
# 3. Upload your files
# 4. Add secrets (API keys) in Space settings
# 5. Space auto-deploys → You get a URL like:
#    https://your-name-chatbot.hf.space
```

### Phase 3: Connect Flutter

```dart
// In your Flutter app
final response = await http.post(
  Uri.parse('https://your-name-chatbot.hf.space/chat'),
  body: jsonEncode({
    'message': userMessage,
    'session_id': sessionId,
  }),
);
```

---

## Files We'll Create

```
chatbot/
├── app.py                 # FastAPI server (main entry)
├── context_aggregator.py  # Collects pipeline results
├── prompts.py             # LLM system prompts
├── supabase_client.py     # Chat history storage
├── requirements.txt       # Dependencies
├── Dockerfile             # For Hugging Face deployment
└── README.md              # API documentation
```

---

## API Endpoints (What Flutter Calls)

| Endpoint | Method | What It Does |
|:---|:---|:---|
| `/chat` | POST | Send message, get AI response |
| `/session/new` | POST | Start new chat session |
| `/context/load` | POST | Load pipeline results into session |

### Example Request
```json
POST /chat
{
  "session_id": "abc123",
  "message": "What is my crop health status?"
}
```

### Example Response
```json
{
  "response": "Based on your field analysis, your wheat crop shows moderate stress...",
  "context_used": ["stress_detection", "ndvi_analysis"]
}
```

---

## Technical Details (For Developers)

### Context Flow
1. **Pipeline runs** → Outputs saved to Supabase
2. **User opens chat** → Flutter calls `/session/new`
3. **Backend loads context** → Fetches latest pipeline results
4. **User sends message** → Backend adds context to LLM prompt
5. **LLM responds** → Backend returns response to Flutter

### What Context Includes
- 13 vegetation indices (NDVI, EVI, SMI, etc.)
- Stress scores per field zone
- Cluster analysis (4 stress categories)
- Anomaly detection results
- Forecast predictions (next 20 days)
- Field metadata (location, crop type)

### LLM Prompt Structure
```
[System: You are an agricultural advisor...]
[Context: Stress score 0.65, Cluster 3, NDVI trend -0.02...]
[History: Previous conversation...]
[User: What should I do about the dry patches?]
```

---

## Why Hugging Face?

| Feature | Benefit |
|:---|:---|
| **Free Tier** | 2 CPUs, 16GB RAM |
| **Auto-scaling** | Handles traffic spikes |
| **Git-based Deploy** | Push code → Auto redeploy |
| **Secrets Management** | Secure API key storage |
| **Custom Domains** | Optional: Use your own domain |

---

## Next Steps

1. **I create the files** (chatbot folder with all code)
2. **You create Hugging Face account**
3. **We deploy together**
4. **You connect Flutter**

Ready to proceed? Just say "Go" and I'll create all the files!
