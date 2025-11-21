# AGROW - SIH 2025

**SMART INDIA HACKATHON 2025**
- **Problem Statement ID**: SIH25099
- **Theme**: Agriculture, FoodTech & Rural Development
- **Team Name**: WhatTheHack (Team ID: 86238)
- **Category**: Software

## 🚀 Project Overview
**Title**: Multimodal AI-ML System for Proactive Crop Health and Stress Detection

AGROW is an AI-powered platform designed to revolutionize crop monitoring by leveraging multispectral/hyperspectral imaging and sensor data. It addresses critical agricultural challenges like weather disasters, soil degradation, and pest infestations through proactive, data-driven insights.

### 🎯 Problem Addressed
- **Reactive Detection**: Traditional methods only detect damage after it occurs.
- **Accessibility Gap**: Complex technical tools are often unusable for small farmers.
- **Institutional Friction**: Crop insurance and aid are slow and difficult to verify.

### 💡 Our Solution
- **Smart Monitoring**: Real-time alerts for weather, drought, and floods using CNN/LSTM models.
- **Soil Health**: Hyperspectral imaging for precise nutrient and moisture analysis.
- **Pest Control**: Early detection using AI image processing to stop infestations before they spread.
- **Farmer-Centric**: Vernacular language support, offline-first design, and simplified dashboards.

---

## 🏗️ Architecture & Workflow

The system follows a 4-Phase Data Pipeline:

### Phase 1: COLLECT 📥
- **User Input**: Farmers map their field coordinates via the mobile app.
- **Remote Sensing**: Data fetched from **Copernicus API** (Sentinel-2 & Sentinel-3 satellite imagery).
- **Weather Data**: Real-time integration with OpenWeather API.

### Phase 2: MANAGE / PREPROCESS ⚙️
- **Data Orchestration**: MATLAB toolboxes process raw satellite imagery (cloud removal, noise reduction).
- **Feature Engineering**: Calculation of spectral indices (NDVI, OSAVI, ARVI).
- **Temporal Stacking**: Creating time-series stacks (T×H×W×C) for historical analysis.

### Phase 3: MODELLING & INFERENCE 🧠
- **Spatio-Temporal Extractor**:
    - **CNN (Spatial)**: Analyzes field imagery for patterns and anomalies.
    - **LSTM (Temporal)**: Captures growth trends over time.
- **Forecasting Model**: Seq2Seq LSTM architecture for yield and weather impact prediction.
- **Classifier**: Probabilistic stress detection (High/Mid/Low risk).

### Phase 4: STORE & COMMUNICATE 📱
- **Database**: PostgreSQL (Supabase) for storing user data and analysis results.
- **Actionable Insights**:
    - **Dashboard**: Visual maps of crop health.
    - **Chatbot**: LLM-powered assistant (Llama 3.1 / GPT-4o) providing advice in local languages.
    - **Alerts**: SMS and push notifications for critical risks.

---

## 📱 App Features (Mobile)

The Flutter application serves as the primary interface for farmers:

1.  **Video Splash Screen**: Engaging introduction to the platform.
2.  **Main Menu**: Access to core features (Mapped Analytics, Settings, etc.).
3.  **Coordinate Entry**:
    -   Interactive **Google Maps** integration.
    -   Users tap 4 points to define their field boundary.
    -   Automatic polygon generation and validation.
4.  **Mapped Report Analysis**:
    -   Visualizes the defined field on a map.
    -   **Zoom Controls**: Pinch-to-zoom and manual controls for detailed inspection.
    -   **Analytics Dashboard**: Swipeable cards showing:
        -   Crop Health (NDVI)
        -   Soil Condition (Moisture, pH)
        -   Weather Impact
        -   Yield Prediction
        -   Risk Assessment

---

## 🛠️ Tech Stack

-   **Frontend**: Flutter (Dart)
-   **Backend**: Supabase (PostgreSQL, Auth)
-   **Maps**: Google Maps SDK (Android/iOS)
-   **AI/ML**: Python, MATLAB Image Processing Toolbox, PyTorch/TensorFlow
-   **Data Sources**: Copernicus Sentinel API, OpenWeather API

---

## 🚀 Getting Started

### Prerequisites
-   Flutter SDK (3.0+)
-   Google Maps API Key
-   Supabase Project

### Installation

1.  **Clone the repository**
    ```bash
    git clone https://github.com/your-repo/agroww_sih.git
    ```

2.  **Setup Environment Variables**
    Create a `.env` file in the root directory:
    ```env
    SUPABASE_URL=your_supabase_url
    SUPABASE_ANON_KEY=your_supabase_key
    GOOGLE_MAPS_API_KEY=your_google_maps_key
    ```

3.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

4.  **Run the App**
    ```bash
    flutter run
    ```

---

## 📄 Research & References
-   **Datasets**: Copernicus Open Access Hub
-   **Tools**: MATLAB Deep Learning Toolbox, Sentinel Hub
-   **Inspiration**: "Crop Monitoring Strategy Based on Remote Sensing Data"

---

**Built with ❤️ for Indian Farmers**
