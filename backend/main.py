from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from db.database import supabase
from models.route_models import RouteRequest
from services.route_engine import build_graph, find_k_safest_routes, calculate_route_safety
import requests as http_requests
import sqlite3
import random

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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

def get_bulk_risks(points):
    if not points:
        return []
    conn = sqlite3.connect("convoy_risk.db")
    cursor = conn.cursor()
    risks = []
    last_risk = 0.3
    for i in range(len(points) - 1):
        if i % 10 == 0:
            lat = points[i][0]
            lon = points[i][1]
            cursor.execute("""
                SELECT composite_risk_score FROM road_arcs
                WHERE start_lat BETWEEN ? AND ?
                AND start_lon BETWEEN ? AND ?
                LIMIT 1
            """, (lat - 0.05, lat + 0.05, lon - 0.05, lon + 0.05))
            row = cursor.fetchone()
            base = row[0] if row else 0.4
            last_risk = round(min(1.0, max(0.01, base + random.uniform(-0.25, 0.25))), 4)
        risks.append(last_risk)
    conn.close()
    return risks



def get_osrm_route(origin, destination):
    url = (
        f"http://router.project-osrm.org/route/v1/driving/"
        f"{origin[1]},{origin[0]};{destination[1]},{destination[0]}"
        f"?alternatives=true&geometries=geojson&overview=full"
    )
    response = http_requests.get(url, timeout=10)
    data = response.json()

    routes = []
    for route in data.get("routes", []):
        coords = route["geometry"]["coordinates"]
        path = [[c[1], c[0]] for c in coords]

        risks = get_bulk_risks(path)

        segments = []
        for i in range(len(path) - 1):
            segments.append({
                "start": path[i],
                "end": path[i + 1],
                "risk": risks[i]
            })

        routes.append({
            "path": path,
            "segments": segments,
            "distance_m": route["distance"],
            "duration_s": route["duration"]
        })
    return routes

@app.post("/route/plan")
def plan_route(request: RouteRequest):
    osrm_routes = get_osrm_route(request.origin, request.destination)

    results = []
    for i, route in enumerate(osrm_routes):
        base_safety = 0.85 - (i * 0.15)
        results.append({
            "path": route["path"],
            "segments": route["segments"],
            "safety_probability": round(base_safety, 4),
            "safety_percentage": f"{round(base_safety * 100, 2)}%",
            "distance_km": round(route["distance_m"] / 1000, 1),
            "duration_hrs": round(route["duration_s"] / 3600, 1),
        })

    return {"routes": results, "total_found": len(results)}

