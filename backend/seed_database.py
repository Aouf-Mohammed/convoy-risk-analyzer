import osmnx as ox
import sqlite3
import random

conn = sqlite3.connect("convoy_risk.db")
cursor = conn.cursor()

cursor.execute("""
CREATE TABLE IF NOT EXISTS road_arcs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    start_lat REAL,
    start_lon REAL,
    end_lat REAL,
    end_lon REAL,
    highway_type TEXT,
    length_m REAL,
    composite_risk_score REAL
)
""")

risk_map = {
    "motorway": 0.05,
    "trunk": 0.10,
    "primary": 0.20,
    "secondary": 0.35,
    "tertiary": 0.50,
    "residential": 0.65,
    "unclassified": 0.70,
}

# Key cities along Delhi-Mumbai corridor
cities = [
    "Nagpur, India",
    "Aurangabad, India",
    "Mumbai, India",
]


total = 0

for city in cities:
    try:
        print(f"Downloading {city}...")
        G = ox.graph_from_place(city, network_type="drive", simplify=True)
        print(f"  {len(G.edges())} edges found")

        for u, v, data in G.edges(data=True):
            start = G.nodes[u]
            end = G.nodes[v]

            highway = data.get("highway", "unclassified")
            if isinstance(highway, list):
                highway = highway[0]

            base_risk = risk_map.get(highway, 0.60)
            risk = round(min(1.0, max(0.01, base_risk + random.uniform(-0.05, 0.05))), 4)

            cursor.execute("""
                INSERT INTO road_arcs (start_lat, start_lon, end_lat, end_lon, highway_type, length_m, composite_risk_score)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                start["y"], start["x"],
                end["y"], end["x"],
                highway,
                data.get("length", 0),
                risk
            ))
            total += 1

        conn.commit()
        print(f"  ✅ {city} done")

    except Exception as e:
        print(f"  ❌ Failed {city}: {e}")

conn.close()
print(f"\n✅ Total arcs inserted: {total}")
