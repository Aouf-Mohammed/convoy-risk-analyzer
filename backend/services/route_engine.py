import networkx as nx
import numpy as np
from math import radians, sin, cos, sqrt, atan2

def haversine_distance(coord1, coord2):
    lat1, lon1 = radians(coord1[0]), radians(coord1[1])
    lat2, lon2 = radians(coord2[0]), radians(coord2[1])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    distance = 6371 * c
    return distance

def build_graph(arcs):
    G = nx.DiGraph()
    for arc in arcs:
        start = (arc["start_lat"], arc["start_lon"])
        end = (arc["end_lat"], arc["end_lon"])
        distance = haversine_distance(start, end)
        risk = arc.get("composite_risk_score", 0.1)
        weight = distance * (1 + risk)
        G.add_edge(start, end, weight=weight, risk=risk, distance=distance)
    return G


def find_k_safest_routes(G, origin, destination, k=3):
    routes = []
    for path in nx.shortest_simple_paths(G, origin, destination, weight="weight"):
        routes.append(path)
        if len(routes) >= k:
            break
    return routes


def calculate_route_safety(G, path):
    safety = 1      
    
    for a, b in zip(path, path[1:]):    
        risk = G[a][b]["risk"]
        arc_safety = 1 - risk       
        safety = safety * arc_safety       
    
    return safety
