# AGROW - AI-Powered Agricultural Intelligence Platform

## Project Summary
A Flutter mobile application providing real-time crop health monitoring and AI-powered farming recommendations using satellite imagery (Sentinel-1 SAR & Sentinel-2 optical) and machine learning.

## Key Technical Achievements

### 🛰️ Satellite Data Integration
- **Sentinel-2 optical imagery**: NDVI, EVI, NDRE vegetation indices for crop health
- **Sentinel-1 SAR radar**: Soil moisture, salinity, roughness analysis (works through clouds/night)
- **Time series forecasting**: 30-day predictions using historical satellite data

### 🤖 AI/ML Backend
- **LLM-powered chatbot** (Groq/Llama 3.3 70B): Context-aware farming advice
- **Hybrid routing system**: Fast Lane (quick answers) + Deep Dive (detailed analysis)
- **Real-time streaming**: SSE-based typewriter effect for chat responses

### 📱 Flutter Mobile App
- **Cache-first architecture**: 5-day versioned cache with 3-iteration fallback
- **Background refresh service**: Auto-updates all fields without user intervention
- **Offline support**: File-based caching for time series, SharedPreferences for analysis

### ☁️ Cloud Infrastructure
- **Hugging Face Spaces**: Docker-based microservices (Chatbot, SAR, Sentinel-2, Heatmap)
- **Supabase**: PostgreSQL database for user profiles and farm data
- **Firebase**: Push notifications and authentication

## Technologies Used

| Category | Technologies |
|----------|-------------|
| **Mobile** | Flutter, Dart, Google Maps SDK, fl_chart |
| **Backend** | Python, FastAPI, Docker |
| **AI/ML** | Groq API, LangChain, Scikit-learn |
| **Satellite** | Sentinel Hub API, SAR processing, GeoTIFF |
| **Database** | Supabase (PostgreSQL), Firebase |
| **DevOps** | Hugging Face Spaces, Git |

## Architecture Highlights
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Flutter App    │◄──►│  HuggingFace     │◄──►│  Sentinel Hub   │
│  (Mobile UI)    │    │  Spaces (API)    │    │  (Satellite)    │
│                 │    │  • Chatbot       │    │                 │
│  • Real-time    │    │  • SAR Analysis  │    │  • Sentinel-1   │
│  • Caching      │    │  • Sentinel-2    │    │  • Sentinel-2   │
│  • Offline      │    │  • Heatmap       │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                      │
        ▼                      ▼
┌─────────────────┐    ┌──────────────────┐
│  Supabase       │    │  Groq LLM        │
│  (Database)     │    │  (AI Reasoning)  │
└─────────────────┘    └──────────────────┘
```

## Code Metrics
- **15+ Flutter services** with full documentation
- **4 Python backend microservices**
- **3-layer caching system** (memory, file, SharedPreferences)
- **Retry logic with exponential backoff** for resilient API calls
