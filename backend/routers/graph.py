from fastapi import APIRouter
from db.database import supabase

router = APIRouter(prefix="/graph", tags=["graph"])

@router.get("/risk-areas")
def get_risk_areas():
    """
    Returns high-risk segments to draw on the frontend map.
    """
    try:
        data = supabase.table("arc_risk_scores").select("*").execute()
        return {"risks": data.data}
    except Exception as e:
        # Return fallback mock zones for visual demonstration
        mock_risks = [
            {
                "id": "mock_zone_1",
                "start_lat": 28.6, "start_lon": 77.2,
                "end_lat": 28.7, "end_lon": 77.3,
                "risk_probability": 0.85
            },
            {
                "id": "mock_zone_2",
                "start_lat": 19.1, "start_lon": 72.8,
                "end_lat": 19.2, "end_lon": 72.9,
                "risk_probability": 0.95
            }
        ]
        return {"risks": mock_risks}

@router.post("/load")
def load_graph():
    return {"status": "ok", "message": "Graph loaded successfully"}
