import pandas as pd
import numpy as np
from shapely.geometry import Polygon
from sklearn.preprocessing import StandardScaler
import matplotlib.pyplot as plt

from neuralforecast import NeuralForecast
from neuralforecast.auto import AutoNHITS
from neuralforecast.losses.pytorch import MAE

import openmeteo_requests
import requests_cache
from retry_requests import retry
from openmeteo_sdk.Variable import Variable
from openmeteo_sdk.Aggregation import Aggregation
import warnings
import os
import datetime

# Suppress warnings
warnings.filterwarnings("ignore")

class AutoTimeSeriesPredictor:
    def __init__(self):
        # Coordinates will be set in tune_and_predict
        self.field_coords = None
        self.latitude = None
        self.longitude = None

        # OpenMeteo Client Setup
        cache_session = requests_cache.CachedSession(".cache", expire_after=-1)
        retry_session = retry(cache_session, retries=5, backoff_factor=0.2)
        self.openmeteo = openmeteo_requests.Client(session=retry_session)

        # Feature Configuration
        self.hist_exog_list = ["lag1", "diff"]
        self.futr_exog_list = ["temp", "rainfall", "humidity"]

        # Scalers
        self.y_scaler = StandardScaler()
        self.exog_scaler = StandardScaler()

    def set_coordinates(self, coords):
        """
        Sets the field coordinates and calculates the centroid latitude and longitude.
        """
        self.field_coords = coords
        field_polygon = Polygon(self.field_coords)
        self.latitude = field_polygon.centroid.y
        self.longitude = field_polygon.centroid.x

    def fetch_weather_data(self, start_date, end_date):
        """
        Fetches weather data, automatically switching between Historical and Ensemble Forecast APIs.
        """
        # Ensure dates are date objects
        if isinstance(start_date, pd.Timestamp):
            start_date = start_date.date()
        if isinstance(end_date, pd.Timestamp):
            end_date = end_date.date()

        today = datetime.date.today()
        
        dfs = []

        # 1. Historical Data (if start_date < today)
        if start_date < today:
            hist_end = min(end_date, today - datetime.timedelta(days=1))
            if start_date <= hist_end:
                print(f"Fetching historical data from {start_date} to {hist_end}...")
                try:
                    hist_df = self._fetch_historical_api(start_date, hist_end)
                    dfs.append(hist_df)
                except Exception as e:
                    print(f"Error fetching historical data: {e}")

        # 2. Forecast Data (if end_date >= today)
        if end_date >= today:
            print(f"Fetching forecast data from {today} to {end_date}...")
            try:
                # Calculate needed forecast days
                days_needed = (end_date - today).days + 1
                # API supports up to 35 days for ensemble
                forecast_days = min(max(days_needed, 1), 35) 
                
                forecast_df = self._fetch_ensemble_forecast_api(forecast_days)
                
                # Filter for requested range
                forecast_df = forecast_df[
                    (forecast_df["ds"].dt.date >= today) & 
                    (forecast_df["ds"].dt.date <= end_date)
                ]
                dfs.append(forecast_df)
            except Exception as e:
                print(f"Error fetching forecast data: {e}")

        if not dfs:
            print("Warning: No weather data fetched.")
            return pd.DataFrame(columns=["ds", "temp", "humidity", "rainfall"])

        final_df = pd.concat(dfs, ignore_index=True)
        final_df = final_df.sort_values("ds").reset_index(drop=True)
        
        # Aggregate to daily if not already (The helpers return daily)
        # But we need to ensure unique dates in case of overlap
        final_df = final_df.drop_duplicates(subset=["ds"], keep="last")
        
        # Filter to ensure exact range (handling timezone spillover)
        final_df = final_df[
            (final_df["ds"].dt.date >= start_date) & 
            (final_df["ds"].dt.date <= end_date)
        ]
        
        return final_df.reset_index(drop=True)

    def _fetch_historical_api(self, start_date, end_date):
        url = "https://archive-api.open-meteo.com/v1/archive"
        params = {
            "latitude": self.latitude,
            "longitude": self.longitude,
            "start_date": start_date.strftime("%Y-%m-%d"),
            "end_date": end_date.strftime("%Y-%m-%d"),
            "daily": ["temperature_2m_mean", "rain_sum"], # We need these for consistency check, but we use hourly aggregated
            "hourly": ["temperature_2m", "relative_humidity_2m", "rain"],
            "timezone": "auto",
        }
        
        responses = self.openmeteo.weather_api(url, params=params)
        response = responses[0]
        
        hourly = response.Hourly()
        hourly_data = {
            "date": pd.date_range(
                start=pd.to_datetime(hourly.Time(), unit="s", utc=True),
                end=pd.to_datetime(hourly.TimeEnd(), unit="s", utc=True),
                freq=pd.Timedelta(seconds=hourly.Interval()),
                inclusive="left",
            ),
            "temperature_2m": hourly.Variables(0).ValuesAsNumpy(),
            "relative_humidity_2m": hourly.Variables(1).ValuesAsNumpy(),
            "rain": hourly.Variables(2).ValuesAsNumpy(),
        }
        
        hourly_df = pd.DataFrame(data=hourly_data)
        
        # Daily aggregation
        hourly_df["ds"] = hourly_df["date"].dt.floor("D").dt.tz_convert(None)
        daily_weather = (
            hourly_df.groupby("ds")
            .agg(
                temp=("temperature_2m", "mean"),
                humidity=("relative_humidity_2m", "mean"),
                rainfall=("rain", "sum"),
            )
            .reset_index()
        )
        return daily_weather

    def _fetch_ensemble_forecast_api(self, forecast_days):
        url = "https://ensemble-api.open-meteo.com/v1/ensemble"
        params = {
            "latitude": self.latitude,
            "longitude": self.longitude,
            "hourly": ["temperature_2m", "relative_humidity_2m", "rain"],
            "models": ["ecmwf_ifs025", "gfs025", "icon_global", "icon_seamless", "gem_global", "bom_access_global_ensemble"],
            "timezone": "auto",
            "forecast_days": forecast_days,
        }
        responses = self.openmeteo.weather_api(url, params=params)
        
        # We will aggregate all models and members into a single mean
        all_hourly_dfs = []
        
        for response in responses:
            hourly = response.Hourly()
            
            # Helper to extract all members for a variable
            def get_members(variable_type):
                # variable_type is an enum from Variable class? 
                # The snippet uses filter on hourly.Variables()
                # We need to map the snippet logic here.
                vars_list = [hourly.Variables(i) for i in range(hourly.VariablesLength())]
                return [v for v in vars_list if v.Variable() == variable_type]

            # We need Variable enum. 
            # Note: The snippet imports Variable. 
            # We need to check if Variable.temperature is correct mapping for "temperature_2m"
            # In snippet: Variable.temperature and Altitude() == 2
            
            temp_vars = [v for v in [hourly.Variables(i) for i in range(hourly.VariablesLength())] 
                         if v.Variable() == Variable.temperature and v.Altitude() == 2]
            
            rh_vars = [v for v in [hourly.Variables(i) for i in range(hourly.VariablesLength())] 
                       if v.Variable() == Variable.relative_humidity and v.Altitude() == 2]
            
            rain_vars = [v for v in [hourly.Variables(i) for i in range(hourly.VariablesLength())] 
                         if v.Variable() == Variable.rain]

            # Create a DF for this model
            dates = pd.date_range(
                start=pd.to_datetime(hourly.Time(), unit="s", utc=True),
                end=pd.to_datetime(hourly.TimeEnd(), unit="s", utc=True),
                freq=pd.Timedelta(seconds=hourly.Interval()),
                inclusive="left",
            )
            
            model_df = pd.DataFrame({"date": dates})
            
            # Average members for this model
            if temp_vars:
                temps = np.stack([v.ValuesAsNumpy() for v in temp_vars])
                model_df["temp"] = np.mean(temps, axis=0)
            else:
                model_df["temp"] = np.nan
                
            if rh_vars:
                rhs = np.stack([v.ValuesAsNumpy() for v in rh_vars])
                model_df["humidity"] = np.mean(rhs, axis=0)
            else:
                model_df["humidity"] = np.nan
                
            if rain_vars:
                rains = np.stack([v.ValuesAsNumpy() for v in rain_vars])
                model_df["rainfall"] = np.mean(rains, axis=0)
            else:
                model_df["rainfall"] = 0
                
            all_hourly_dfs.append(model_df)
            
        # Concatenate all models
        full_hourly = pd.concat(all_hourly_dfs, ignore_index=True)
        
        # Group by date and take mean across all models
        full_hourly = full_hourly.groupby("date").mean().reset_index()
        
        # Daily aggregation
        full_hourly["ds"] = full_hourly["date"].dt.floor("D").dt.tz_convert(None)
        daily_weather = (
            full_hourly.groupby("ds")
            .agg(
                temp=("temp", "mean"),
                humidity=("humidity", "mean"),
                rainfall=("rainfall", "sum"),
            )
            .reset_index()
        )
        
        return daily_weather

    def preprocess_data(self, df):
        """
        Preprocesses the input dataframe:
        1. Fetches historical weather
        2. Creates lag/diff features
        3. Scales data
        """
        df = df.copy()
        df["ds"] = pd.to_datetime(df["ds"])
        df = df.sort_values("ds").reset_index(drop=True)
        df["unique_id"] = "VV" 

        # 1. Fetch Historical Weather
        start_date = df["ds"].min().date()
        end_date = df["ds"].max().date()
        print(f"Fetching historical weather from {start_date} to {end_date}...")
        weather_df = self.fetch_weather_data(start_date, end_date)
        
        df = df.merge(weather_df, on="ds", how="left")
        df[self.futr_exog_list] = df[self.futr_exog_list].ffill().bfill()

        # 2. Feature Engineering (Lags/Diffs)
        df["lag1"] = df["y"].shift(1)
        df["diff"] = df["y"].diff()
        
        df = df.dropna().reset_index(drop=True)

        # 3. Scaling
        df["y"] = self.y_scaler.fit_transform(df[["y"]])
        
        all_exog = self.hist_exog_list + self.futr_exog_list
        df[all_exog] = self.exog_scaler.fit_transform(df[all_exog])

        return df

    def tune_and_predict(self, csv_path, field_coords, target_col="y", output_file="auto_tuned_predictions.csv", num_samples=10):
        """
        Runs AutoNHITS tuning and predicts the next 20 days.
        """
        print(f"Setting coordinates to: {field_coords}")
        self.set_coordinates(field_coords)

        # 1. Load Data
        print("Loading data...")
        df = pd.read_csv(csv_path)
        
        # Rename target column to 'y' if it exists
        if target_col in df.columns:
            df = df.rename(columns={target_col: "y"})
            
        if "ds" not in df.columns or "y" not in df.columns:
            raise ValueError(f"CSV must contain 'ds' and '{target_col}' (mapped to 'y') columns.")
        
        # 2. Preprocess
        print("Preprocessing data...")
        train_df = self.preprocess_data(df)

        # 3. Prepare Future Dataframe
        last_date = train_df["ds"].max()
        # Ensure we predict for at least 30 days as per user request "next 1 month"
        # Data frequency is 5 Days, so 30 days / 5 = 6 periods
        prediction_days = 6 
        # Start 5 days after the last training date
        future_dates = pd.date_range(start=last_date + pd.Timedelta(days=5), periods=prediction_days, freq="5D")
        future_df = pd.DataFrame({"ds": future_dates, "unique_id": "VV"})

        # 4. Fetch Future Weather
        print("Fetching future weather forecast...")
        # The new fetch_weather_data handles the logic automatically
        weather_future = self.fetch_weather_data(future_dates[0].date(), future_dates[-1].date())

        future_df = future_df.merge(weather_future, on="ds", how="left")
        future_df[self.futr_exog_list] = future_df[self.futr_exog_list].fillna(0)

        # 5. Auto Model Definition
        import ray.tune as tune
        print(f"Initializing AutoNHITS model (tuning with {num_samples} samples)...")
        
        # Define a custom search space (same as auto_tuning_testing.py)
        config = {
            "input_size": tune.choice([60, 90, 120]),              # Lookback window
            "learning_rate": tune.loguniform(1e-4, 1e-2),          # Learning rate
            "n_blocks": tune.choice([[1, 1, 1], [3, 3, 3]]),       # Depth
            "mlp_units": tune.choice([                             # Width
                [[64, 64], [64, 64], [64, 64]],
                [[512, 512], [512, 512], [512, 512]]
            ]),
            "n_pool_kernel_size": tune.choice([                    # Pooling
                [2, 2, 1], 
                [4, 4, 2],
                [8, 4, 1]
            ]),
            "n_freq_downsample": tune.choice([                     # Downsampling
                [2, 1, 1],
                [4, 2, 1],
                [8, 4, 1]
            ])
        }

        # AutoNHITS configuration
        auto_nhits = AutoNHITS(
            h=prediction_days, # Horizon (6 steps = 30 days)
            loss=MAE(),
            config=config, 
            search_alg=None, # Use default search algorithm (HyperOpt)
            num_samples=num_samples, # Number of trials
            cpus=1,
            gpus=0, # Set to 1 if GPU available
            verbose=True,
            alias="AutoNHITS"
        )

        nf = NeuralForecast(models=[auto_nhits], freq="5D")

        # 6. Train (Tune) and Predict
        print("Tuning and Training model...")
        nf.fit(df=train_df)
        
        # Get best config
        # The model inside nf.models[0] is the trained AutoNHITS
        # It should have 'results' or 'best_config' attribute after fitting?
        # Actually, AutoNHITS replaces itself with the best model found or wraps it.
        
        print("Predicting...")
        # Prepare future exogenous features
        # Note: We need to scale them!
        X_futr = future_df[self.futr_exog_list].values
        
        # Get indices of futr_exog in the scaler
        # self.exog_scaler was fitted on [hist_exog + futr_exog]
        # futr_exog are the last columns, starting after hist_exog
        start_idx = len(self.hist_exog_list)
        futr_indices = [start_idx + i for i in range(len(self.futr_exog_list))]
        
        means = self.exog_scaler.mean_[futr_indices]
        scales = self.exog_scaler.scale_[futr_indices]
        
        X_futr_scaled = (X_futr - means) / scales
        future_df[self.futr_exog_list] = X_futr_scaled

        preds_df = nf.predict(futr_df=future_df)
        
        # 7. Inverse Scale Predictions
        y_pred_scaled = preds_df["AutoNHITS"].values.reshape(-1, 1)
        y_pred = self.y_scaler.inverse_transform(y_pred_scaled).flatten()
        
        result = pd.DataFrame({
            "ds": preds_df["ds"].values,
            "predicted_y": y_pred
        })
        
        # 8. Plot results
        result.to_csv(output_file, index=False)
        print(f"\nPredictions saved to {output_file}")
        
        return result
        
        try:
            from plot_predictions import plot_predictions
            print("\nGenerating plot...")
            plot_predictions(csv_path, output_file)
        except Exception as e:
            print(f"Warning: Could not generate plot: {e}")
            
        return result

if __name__ == "__main__":
    # Define the input file path here
    target_file = "vh_data_structured.csv"
    
    print(f"Using input file: {target_file}")
    
    if os.path.exists(target_file):
        predictor = AutoTimeSeriesPredictor()
        
        # Example coordinates
        coords = [
            (77.2090, 28.6139),
            (77.2100, 28.6139),
            (77.2100, 28.6149),
            (77.2090, 28.6149),
            (77.2090, 28.6139),
        ]
        
        try:
            predictions = predictor.tune_and_predict(target_file, field_coords=coords, num_samples=30) # 30 samples for better results
            print("\nPredictions for the next 20 days:")
            print(predictions)
        except Exception as e:
            print(f"An error occurred: {e}")
    else:
        print(f"File not found: {target_file}")
