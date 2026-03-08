@echo off
cd backend
IF NOT EXIST venv (
    python -m venv venv
)
call venv\Scripts\activate
pip install -r requirements.txt
pytest tests/ -v --tb=short
IF %ERRORLEVEL% EQU 0 (
    uvicorn main:app --port 8000 --workers 4
    echo ✓ BACKEND RUNNING at http://localhost:8000
) ELSE (
    echo ✗ BACKEND TESTS FAILED. Not starting server.
    exit /b 1
)
