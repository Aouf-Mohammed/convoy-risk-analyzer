import osmnx as ox
import networkx as nx
from scipy.sparse import csr_matrix
import hashlib
import numpy as np

from .cache import set_current_graph

from fastapi import HTTPException

def build_scenario_graph(origin, destination, buffer_m=5000):
    """
    Builds the graph from OSM between origin and destination.
    Converts to SciPy sparse adjacency matrix for Yen's algorithm.
    """
    for point in (origin, destination):
        if not (-90 <= point[0] <= 90) or not (-180 <= point[1] <= 180):
            raise HTTPException(status_code=422, detail="Invalid coordinates. Latitude must be -90 to 90 and longitude -180 to 180.")

    north = max(origin[0], destination[0])
    south = min(origin[0], destination[0])
    east = max(origin[1], destination[1])
    west = min(origin[1], destination[1])
    
    # Expand bbox by buffer
    lat_buffer = buffer_m / 111000.0
    lon_buffer = buffer_m / (111000.0 * np.cos(np.radians((north + south) / 2)))
    
    bbox = (north + lat_buffer, south - lat_buffer, east + lon_buffer, west - lon_buffer)
    
    # Try to load graph
    try:
        G = ox.graph_from_bbox(bbox[0], bbox[1], bbox[2], bbox[3], network_type='drive')
    except Exception as e:
        # Fallback to small graph around origin
        try:
            G = ox.graph_from_point((origin[0], origin[1]), dist=2000, network_type='drive')
        except Exception:
            raise HTTPException(status_code=422, detail="No road network found near these coordinates")
        
    nodes = list(G.nodes())
    node_mapping = {n: i for i, n in enumerate(nodes)}
    n = len(nodes)
    
    row = []
    col = []
    data = []
    
    for u, v, k, d in G.edges(keys=True, data=True):
        i, j = node_mapping[u], node_mapping[v]
        length = d.get('length', 1.0)
        risk = d.get('risk', 0.1) 
        weight = length * (1 + risk)
        
        row.append(i)
        col.append(j)
        data.append(weight)
        
    adj_matrix = csr_matrix((data, (row, col)), shape=(n, n))
    
    hash_str = hashlib.md5(np.array(data).tobytes()).hexdigest()
    set_current_graph(adj_matrix, hash_str)
    
    return G, node_mapping, adj_matrix, hash_str
