from fastapi import Header, HTTPException, Depends
from db.database import supabase

async def get_current_user(authorization: str = Header(...)):
    try:
        code = authorization.replace("Bearer ", "").strip()
        result = supabase.table("users").select("*").eq("batch_number", code).single().execute()
        if not result.data:
            raise HTTPException(status_code=401, detail="Invalid access code")
        return result.data
    except:
        raise HTTPException(status_code=401, detail="Unauthorized")

def require_role(*roles):
    async def checker(user=Depends(get_current_user)):
        if user["role"] not in roles:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return user
    return checker
