from pydantic import BaseModel
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from enum import Enum

class RoleEnum(str, Enum):
    commander = "commander"
    driver = "driver"
    analyst = "analyst"

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

class UserOut(BaseModel):
    id: UUID
    name: str
    role: RoleEnum
    unit_name: str
    clearance_level: int
    batch_number: str

class ConvoyCreate(BaseModel):
    name: str
    origin: dict        # {lat, lng}
    destination: dict   # {lat, lng}
    waypoints: List[dict]
    vehicle_ids: List[UUID]

class ArcRiskUpdate(BaseModel):
    arc_id: UUID
    composite_risk_score: float
    threat_level: float
    weather_factor: float
    terrain_factor: float
    time_of_day_factor: float
