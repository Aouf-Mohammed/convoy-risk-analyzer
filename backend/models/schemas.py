from pydantic import BaseModel, validator
from typing import Optional, List, Dict
from uuid import UUID
from datetime import datetime
from enum import Enum



class ConvoyStatus(str, Enum):
    planned = "planned"
    active = "active"
    completed = "completed"
    aborted = "aborted"

class VehicleType(str, Enum):
    tank = "tank"
    truck = "truck"
    apc = "APC"
    motorcycle = "motorcycle"
    artillery = "artillery"



class ConvoyCreate(BaseModel):
    name: str
    origin: dict        # {lat, lng}
    destination: dict   # {lat, lng}
    waypoints: List[dict]
    vehicle_ids: List[str]

class ArcRiskUpdate(BaseModel):
    arc_id: UUID
    composite_risk_score: float
    threat_level: float
    weather_factor: float
    terrain_factor: float
    time_of_day_factor: float

class RouteRequest(BaseModel):
    origin: List[float]
    destination: List[float]
    
    @validator('origin', 'destination')
    def validate_coords(cls, v):
        if len(v) != 2:
            raise ValueError('Coordinates must have exactly 2 elements: [lat, lon]')
        if not (-90 <= v[0] <= 90):
            raise ValueError('Latitude must be -90 to 90')
        if not (-180 <= v[1] <= 180):
            raise ValueError('Longitude must be -180 to 180')
        return [float(v[0]), float(v[1])]
        
    k: Optional[int] = 3
    vehicle_type: Optional[str] = "truck"
    convoy_composition: Optional[Dict[str, int]] = None
    risk_multiplier: Optional[float] = 1.0

