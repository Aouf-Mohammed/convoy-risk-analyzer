#!/bin/bash
echo "Starting Backend..."
./run_backend.sh &
BACKEND_PID=$!

echo "Waiting for backend to initialize..."
sleep 3
curl -s http://localhost:8000/health || (echo "Backend failed to start!" && exit 1)

echo "Backend is UP. Starting Frontend..."
./run_flutter.sh

kill $BACKEND_PID
