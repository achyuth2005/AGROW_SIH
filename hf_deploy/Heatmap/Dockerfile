FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libgdal-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all application files
COPY app.py .
COPY vegetation_indices.py .
COPY stress_detection_model.py .
COPY stress_detection_preprocessing.py .
COPY llm_analysis.py .
COPY groq_client.py .

# Expose port
EXPOSE 7860

# Run the application
CMD ["python", "app.py"]
