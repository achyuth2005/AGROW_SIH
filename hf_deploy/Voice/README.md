---
title: AGROW Chatbot
emoji: 🌾
colorFrom: green
colorTo: yellow
sdk: docker
pinned: false
license: mit
---

# AGROW Agricultural Chatbot

AI-powered agricultural advisor using Gemini LLM with Supabase conversation storage.

## Features
- Gemini 1.5 Flash for intelligent responses
- Agricultural expertise (crop health, soil, weather)
- Conversation history persistence
- Pipeline context integration

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/chat` | POST | Send message, get AI response |
| `/session/new` | POST | Create new chat session |
| `/session/{id}/history` | GET | Get conversation history |
| `/sessions/{user_id}` | GET | List user's sessions |

## Environment Variables

- `GEMINI_API_KEY` - Google Gemini API key
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_KEY` - Supabase anon key

## Example Request

```bash
curl -X POST https://YOUR-SPACE.hf.space/chat \
  -H "Content-Type: application/json" \
  -d '{"session_id": "abc123", "message": "What is my crop health status?"}'
```
