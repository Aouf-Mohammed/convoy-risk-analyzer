#!/bin/bash
cd backend
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install -r requirements.txt
pytest tests/ -v --tb=short
if [ $? -eq 0 ]; then
    uvicorn main:app --port 8000 --workers 4
    echo "✓ BACKEND RUNNING at http://localhost:8000"
else
    echo "✗ BACKEND TESTS FAILED. Not starting server."
    exit 1
fi
