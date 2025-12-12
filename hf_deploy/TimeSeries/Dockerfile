FROM python:3.10

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libgdal-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy ALL application files
COPY app.py .
COPY storage.py .
COPY index_calculator.py .
COPY satellite_pipeline.py .
COPY auto_tuning_predictor.py .
COPY prediction_pipeline.py .

# Expose port
EXPOSE 7860

# Run the application
CMD ["python", "app.py"]
