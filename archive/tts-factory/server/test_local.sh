#!/bin/bash
# Local test script for TTS Factory server
# Usage: ./test_local.sh

set -e

echo "🚀 Starting TTS Factory server locally..."
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 required"
    exit 1
fi

# Create venv if not exists
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate venv
source venv/bin/activate

# Install deps
echo "📦 Installing dependencies..."
pip install -q -r requirements.txt

# Set test env vars
export APP_SECRET="test-secret-123"
export GOOGLE_APPLICATION_CREDENTIALS_JSON=""

echo ""
echo "✅ Server starting at http://localhost:8000"
echo "📋 Test endpoints:"
echo "   GET  http://localhost:8000/health"
echo "   POST http://localhost:8000/v1/jobs (x-app-secret: test-secret-123)"
echo ""

# Run server
uvicorn main:app --reload --port 8000
