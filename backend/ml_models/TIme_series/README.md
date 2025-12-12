# Satellite Time Series Prediction Pipeline

This project implements an end-to-end pipeline for fetching satellite data (Sentinel-1 SAR and Sentinel-2 Optical), processing it, and generating time-series predictions using advanced neural forecasting models.

## 🚀 Project Structure

The core logic is divided into three main Python scripts:

1.  **`satellite_pipeline.py`**:
    *   **Purpose**: Fetches historical satellite data.
    *   **Class**: `SatelliteFetcher`
    *   **Inputs**: Polygon coordinates.
    *   **Outputs**: `sar_data.csv` (Sentinel-1) and `sentinel2_data.csv` (Sentinel-2).
    *   **Details**: Automatically handles authentication with Sentinel Hub, searches for available scenes from 2020-01-01 to present, and aggregates data to daily values.

2.  **`auto_tuning_predictor.py`**:
    *   **Purpose**: Handles time-series forecasting.
    *   **Class**: `AutoTimeSeriesPredictor`
    *   **Inputs**: Historical CSV data, Polygon coordinates.
    *   **Outputs**: Prediction CSVs (e.g., `sar_predictions.csv`).
    *   **Details**:
        *   Fetches historical and forecast weather data (Temperature, Humidity, Rainfall) using OpenMeteo.
        *   Uses `NeuralForecast` and `AutoNHITS` to automatically tune hyperparameters and train a model.
        *   Predicts future values for all bands present in the input data.

3.  **`prediction_pipeline.py`** (Main Entry Point):
    *   **Purpose**: Orchestrates the entire workflow.
    *   **Class**: `PredictionOrchestrator`
    *   **Function**: `run()`
    *   **Details**: Calls `SatelliteFetcher` to get data, then iteratively calls `AutoTimeSeriesPredictor` for every band in the fetched data to generate comprehensive predictions.

## 🛠️ Setup for Developers

### 1. Prerequisites
*   Python 3.9+
*   Sentinel Hub Account (for API credentials)

### 2. Installation

Create a virtual environment (recommended):
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

Install dependencies:
```bash
pip install -r requirements.txt
```

### 3. Configuration (.env)

Create a `.env` file in the root directory and add your Sentinel Hub credentials:

```env
SH_CLIENT_ID=your_client_id_here
SH_CLIENT_SECRET=your_client_secret_here
```

> **Note:** If `.env` is missing, the script attempts to use fallback credentials, but using your own is strongly recommended.

## 🏃‍♂️ Usage

The easiest way to run the pipeline is via `prediction_pipeline.py`.

1.  Open `prediction_pipeline.py`.
2.  Update the `POLYGON` variable in the `if __name__ == "__main__":` block with your area of interest.
    ```python
    POLYGON = [
        (75.829, 30.229),
        (75.831, 30.229),
        (75.831, 30.231),
        (75.829, 30.231),
        (75.829, 30.229)
    ]
    ```
3.  Run the script:
    ```bash
    python3 prediction_pipeline.py
    ```

## 📊 Outputs

The pipeline generates the following files in the current directory:

*   **Data Files:**
    *   `sar_data.csv`: Historical Sentinel-1 data (VV, VH bands).
    *   `sentinel2_data.csv`: Historical Sentinel-2 data (B01-B12 bands).

*   **Prediction Files:**
    *   `sar_predictions.csv`: Forecasted values for SAR bands.
    *   `sentinel2_predictions.csv`: Forecasted values for Sentinel-2 bands.

## 🧩 Modules Breakdown

### `SatelliteFetcher`
*   **`fetch_sar_data()`**: Retrieves Sentinel-1 GRD data.
*   **`fetch_sentinel2_data()`**: Retrieves Sentinel-2 L2A data.
*   **`run_all()`**: Executes both fetchers.

### `AutoTimeSeriesPredictor`
*   **`fetch_weather_data()`**: Integrates OpenMeteo API for weather context.
*   **`tune_and_predict()`**:
    *   Preprocesses data (scaling, lag features).
    *   Tunes `AutoNHITS` model using Ray Tune.
    *   Generates future predictions.
    *   Returns a DataFrame with results.

### `PredictionOrchestrator`
*   **`run()`**: High-level method to execute the full "Fetch -> Predict" cycle for all available satellite bands.
