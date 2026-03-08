from functools import lru_cache

@lru_cache(maxsize=256)
def get_cached_ksp(origin_node, dest_node, k, graph_hash):
    """
    Cached K-Shortest Paths. Implementation relies on the cache decorator
    keyed by origin, dest, k, and the deterministic graph hash.
    Since we can't pass complex objects safely to LRU (they aren't hashable),
    we use graph_hash and a global or lookup for the adjacency matrix. 
    """
    from .yen_ksp import compute_yen_ksp
    return compute_yen_ksp(origin_node, dest_node, k)

# Singleton/global graph state for the solver cache to reference
_current_adj_matrix = None
_current_graph_hash = None

def set_current_graph(adj_matrix, graph_hash):
    global _current_adj_matrix, _current_graph_hash
    _current_adj_matrix = adj_matrix
    _current_graph_hash = graph_hash

def get_current_adj_matrix():
    return _current_adj_matrix
