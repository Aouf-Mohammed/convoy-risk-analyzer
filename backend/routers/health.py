from fastapi import APIRouter

router = APIRouter(tags=["health"])

@router.get("/health")
def health_check():
    return {"status": "online", "project": "Convoy Risk Analyzer"}

@router.get("/metrics")
def get_metrics():
    # Middleware metrics attached to app state usually. For now basic.
    return {
        "status": "online",
        "description": "API Metrics Endpoint. Global middleware tracks absolute request counts."
    }
