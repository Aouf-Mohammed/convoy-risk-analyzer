from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends
from fastapi.middleware.cors import CORSMiddleware
from db.database import supabase
from models.route_models import RouteRequest
from middleware.auth_guard import get_current_user, require_role
import requests as http_requests
import random
from typing import List

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SPEED_MAP = {
    "motorcycle": 60, "truck": 40,
    "APC": 30, "tank": 20, "artillery": 25
}

VEHICLE_FALLBACK = {
    "motorcycle": {"max_road_width": 2.0, "max_bridge_load": 1.0,  "max_weight": 0.3},
    "truck":      {"max_road_width": 3.5, "max_bridge_load": 20.0, "max_weight": 15.0},
    "APC":        {"max_road_width": 4.0, "max_bridge_load": 30.0, "max_weight": 25.0},
    "tank":       {"max_road_width": 5.0, "max_bridge_load": 60.0, "max_weight": 55.0},
    "artillery":  {"max_road_width": 4.5, "max_bridge_load": 40.0, "max_weight": 35.0},
}

# ── WebSocket ──────────────────────────────────────────────
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            await connection.send_json(message)

manager = ConnectionManager()

@app.websocket("/ws/risk-updates")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_json()
            await manager.broadcast({
                "type": "risk_update",
                "route_id": data.get("route_id"),
                "risk_score": data.get("risk_score"),
                "message": f"Route {data.get('route_id')} risk updated"
            })
    except WebSocketDisconnect:
        manager.disconnect(websocket)

# ── Health ─────────────────────────────────────────────────
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

# ── Auth ───────────────────────────────────────────────────
@app.post("/auth/verify-code")
async def verify_code(payload: dict):
    code = payload.get("code", "").strip()
    try:
        result = supabase.table("users").select("*").eq("batch_number", code).single().execute()
        if result.data:
            user = result.data
            return {
                "valid": True,
                "role": user["role"],
                "unit_name": user["unit_name"],
                "name": user["name"],
                "clearance_level": user["clearance_level"],
                "user_id": user["id"],
            }
    except Exception as e:
        print(f"Auth error: {e}")
    return {"valid": False}

# ── Vehicles ───────────────────────────────────────────────
async def get_vehicle_constraints(vehicle_type: str):
    try:
        response = supabase.table("vehicles").select("*").eq("type", vehicle_type).limit(1).execute()
        if response.data:
            v = response.data[0]
            return {
                "max_road_width": v["min_road_width_metres"],
                "max_bridge_load": v["max_bridge_load_tonnes"],
                "max_weight": v["max_weight_tonnes"],
            }
    except Exception as e:
        print(f"Vehicle fetch failed: {e}")
    return VEHICLE_FALLBACK.get(vehicle_type, VEHICLE_FALLBACK["truck"])

# ── Risk from Supabase (replaces SQLite) ───────────────────
def get_bulk_risks(points):
    if not points:
        return []
    risks = []
    last_risk = 0.3
    for i in range(len(points) - 1):
        if i % 10 == 0:
            try:
                lat, lon = points[i][0], points[i][1]
                result = supabase.table("arc_risk_scores") \
                    .select("composite_risk_score") \
                    .limit(1).execute()
                base = result.data[0]["composite_risk_score"] if result.data else 0.4
                last_risk = round(min(1.0, max(0.01, base + random.uniform(-0.25, 0.25))), 4)
            except:
                last_risk = 0.4
        risks.append(last_risk)
    return risks

# ── OSRM ───────────────────────────────────────────────────
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
        segments = [{"start": path[i], "end": path[i+1], "risk": risks[i]} for i in range(len(path)-1)]
        routes.append({
            "path": path,
            "segments": segments,
            "distance_m": route["distance"],
            "duration_s": route["duration"]
        })
    return routes

# ── Route Planning (CMD only) ──────────────────────────────
@app.post("/route/plan")
async def plan_route(request: RouteRequest, user=Depends(require_role("commander"))):
    osrm_routes = get_osrm_route(request.origin, request.destination)
    vehicle = request.vehicle_type or "truck"
    constraints = await get_vehicle_constraints(vehicle)
    speed = SPEED_MAP.get(vehicle, 40)

    results = []
    for i, route in enumerate(osrm_routes):
        base_safety = 0.85 - (i * 0.15)
        adjusted_duration = route["duration_s"] * (40 / speed)
        result = {
            "path": route["path"],
            "segments": route["segments"],
            "safety_probability": round(base_safety, 4),
            "safety_percentage": f"{round(base_safety * 100, 2)}%",
            "distance_km": round(route["distance_m"] / 1000, 1),
            "duration_hrs": round(adjusted_duration / 3600, 1),
            "vehicle_type": vehicle,
            "constraints": constraints,
        }
        results.append(result)
        await manager.broadcast({
            "type": "route_computed",
            "route_id": i,
            "safety": result["safety_percentage"],
            "distance_km": result["distance_km"],
            "vehicle_type": vehicle,
        })

    # Save to audit_logs with user_id
    try:
        supabase.table("audit_logs").insert({
            "user_id": user["id"],
            "action_type": "route_planned",
            "metadata": {
                "origin": request.origin,
                "destination": request.destination,
                "vehicle_type": vehicle,
                "best_safety": results[0]["safety_percentage"],
                "distance_km": results[0]["distance_km"],
                "total_routes": len(results),
            }
        }).execute()
    except Exception as e:
        print(f"Audit log failed: {e}")

    return {"routes": results, "total_found": len(results)}

# ── Convoys ────────────────────────────────────────────────
@app.get("/convoys")
async def get_convoys(user=Depends(get_current_user)):
    result = supabase.table("convoys").select("*").execute()
    return result.data

@app.post("/convoys")
async def create_convoy(payload: dict, user=Depends(require_role("commander"))):
    result = supabase.table("convoys").insert({
        **payload,
        "commander_id": user["id"],
        "status": "planned"
    }).execute()
    return result.data

@app.patch("/convoys/{convoy_id}/status")
async def update_convoy_status(convoy_id: str, payload: dict, user=Depends(require_role("commander"))):
    result = supabase.table("convoys").update({"status": payload["status"]}).eq("id", convoy_id).execute()
    return result.data
