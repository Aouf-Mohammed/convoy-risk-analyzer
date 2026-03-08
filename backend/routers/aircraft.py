from fastapi import APIRouter
import httpx

router = APIRouter()

@router.get("/api/aircraft")
async def get_aircraft(lamin: float, lomin: float, lamax: float, lomax: float):
    url = f"https://opensky-network.org/api/states/all?lamin={lamin}&lomin={lomin}&lamax={lamax}&lomax={lomax}"
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, timeout=5.0)
            if response.status_code == 200:
                return response.json()
        except Exception:
            pass
    return {"states": []}
