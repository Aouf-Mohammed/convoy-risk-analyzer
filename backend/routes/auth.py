from fastapi import APIRouter, HTTPException
from db.database import supabase
from pydantic import BaseModel

router = APIRouter(prefix="/auth", tags=["auth"])

class LoginRequest(BaseModel):
    access_code: str  # your access code based login

@router.post("/login")
async def login(body: LoginRequest):
    try:
        # Lookup user by access_code stored in users table
        result = supabase.table("users").select("*").eq("batch_number", body.access_code).single().execute()
        if not result.data:
            raise HTTPException(status_code=401, detail="Invalid access code")
        return {"user": result.data}
    except:
        raise HTTPException(status_code=401, detail="Invalid access code")
