FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source
COPY . .

# Cloud Run injects PORT env (default 8080)
ENV PORT=8080

EXPOSE 8080

# Use shell form to expand $PORT at runtime
CMD uvicorn main:app --host 0.0.0.0 --port $PORT
