from fastapi import FastAPI
from db.database import supabase
from models.route_models import RouteRequest
from services.route_engine import build_graph, find_k_safest_routes, calculate_route_safety

app = FastAPI()

@app.get("/health")
def health_check():
    return {"status": "online", "project": "Convoy Risk Analyzer"}

@app.get("/")
def default_check():
    return {"message": "Welcome to Convoy Risk Analyzer"}

@app.get("/db-test")
def db_test():
    response = supabase.table("users").select("*").execute()
    return {"connected": True, "data": response.data}

@app.post("/route/plan")
def plan_route(request: RouteRequest):
    # Dummy arcs for testing - we'll replace with real DB data later
    test_arcs = [
        {"start_lat": request.origin[0], "start_lon": request.origin[1],
         "end_lat": 20.0, "end_lon": 80.0, "composite_risk_score": 0.2},
        {"start_lat": 20.0, "start_lon": 80.0,
         "end_lat": request.destination[0], "end_lon": request.destination[1],
         "composite_risk_score": 0.3},
        {"start_lat": request.origin[0], "start_lon": request.origin[1],
         "end_lat": 22.0, "end_lon": 79.0, "composite_risk_score": 0.6},
        {"start_lat": 22.0, "start_lon": 79.0,
         "end_lat": request.destination[0], "end_lon": request.destination[1],
         "composite_risk_score": 0.1},
    ]

    G = build_graph(test_arcs)
    paths = find_k_safest_routes(G, request.origin, request.destination, request.k)
    
    results = []
    for path in paths:
        safety = calculate_route_safety(G, path)
        results.append({
            "path": path,
            "safety_probability": round(safety, 4),
            "safety_percentage": f"{round(safety * 100, 2)}%"
        })
    
    return {"routes": results, "total_found": len(results)}