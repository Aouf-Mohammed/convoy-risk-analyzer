from fastapi import APIRouter, Depends
from db.database import supabase
from middleware.auth_guard import get_current_user, require_role
from pydantic import BaseModel
from typing import List
from uuid import UUID

router = APIRouter(prefix="/convoys", tags=["convoys"])

class ConvoyCreate(BaseModel):
    name: str
    origin: dict
    destination: dict
    waypoints: List[dict]
    vehicle_ids: List[str]

@router.post("/")
async def create_convoy(body: ConvoyCreate, user=Depends(require_role("commander"))):
    result = supabase.table("convoys").insert({
        "name": body.name,
        "commander_id": user["id"],
        "origin": body.origin,
        "destination": body.destination,
        "waypoints": body.waypoints,
        "vehicle_ids": body.vehicle_ids,
        "status": "planned"
    }).execute()
    return result.data

@router.get("/")
async def get_convoys(user=Depends(get_current_user)):
    result = supabase.table("convoys").select("*").execute()
    return result.data

@router.patch("/{convoy_id}/status")
async def update_status(convoy_id: str, status: str, user=Depends(require_role("commander"))):
    result = supabase.table("convoys").update({"status": status}).eq("id", convoy_id).execute()
    return result.data
