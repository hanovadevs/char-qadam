# Production Dockerfile for Qadam FastAPI Backend
FROM python:3.12-slim

# Set environment variables , yes
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app \
    PORT=8000 \
    WEB_CONCURRENCY=2

WORKDIR /app

# Install system dependencies if needed
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

RUN useradd --system --uid 10001 --create-home qadam \
    && mkdir -p /app/uploads \
    && chown qadam:qadam /app/uploads
USER qadam

# Expose port
EXPOSE 8000

# Run uvicorn server
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --workers ${WEB_CONCURRENCY} --limit-concurrency 200 --timeout-keep-alive 5
