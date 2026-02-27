from pydantic import BaseModel
from typing import List, Tuple

class RouteRequest(BaseModel):
    origin: Tuple[float, float]        
    destination: Tuple[float, float]   
    k: int = 3                         
