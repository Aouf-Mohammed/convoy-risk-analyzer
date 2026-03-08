from fastapi import APIRouter, Depends
from db.database import supabase
from models.schemas import ConvoyCreate
from typing import List

router = APIRouter(prefix="/convoys", tags=["convoys"])

@router.post("/")
async def create_convoy(body: ConvoyCreate):
    result = supabase.table("convoys").insert({
        "name": body.name,
        "origin": body.origin,
        "destination": body.destination,
        "waypoints": body.waypoints,
        "vehicle_ids": body.vehicle_ids,
        "status": "planned"
    }).execute()
    return result.data

@router.get("/")
async def get_convoys():
    result = supabase.table("convoys").select("*").execute()
    return result.data

@router.patch("/{convoy_id}/status")
async def update_status(convoy_id: str, status: str):
    result = supabase.table("convoys").update({"status": status}).eq("id", convoy_id).execute()
    return result.data
