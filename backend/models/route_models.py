from pydantic import BaseModel
from typing import List, Optional
from enum import Enum

class VehicleType(str, Enum):
    motorcycle = "motorcycle"
    truck = "truck"
    armored = "armored"
    tank = "tank"

class RouteRequest(BaseModel):
    origin: List[float]
    destination: List[float]
    k: int = 3
    vehicle_type: Optional[VehicleType] = VehicleType.truck
