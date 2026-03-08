import numpy as np
from scipy.sparse import csr_matrix
from scipy.sparse.csgraph import dijkstra
from ..cache import get_current_adj_matrix

def _shortest_path(adj_matrix, source, target):
    dist_matrix, predecessors = dijkstra(
        csgraph=adj_matrix,
        directed=False,
        indices=source,
        return_predecessors=True
    )
    if predecessors[target] == -9999:
        return None, float('inf')
    
    path = []
    curr = target
    while curr != source:
        path.append(curr)
        curr = predecessors[curr]
        if curr == -9999: # safety check
            return None, float('inf')
    path.append(source)
    path.reverse()
    return path, dist_matrix[target]

def compute_yen_ksp(origin_node, dest_node, k):
    """
    Yen's algorithm for k-shortest loopless paths.
    """
    adj_matrix = get_current_adj_matrix()
    if adj_matrix is None:
        return []
        
    A = []
    path, cost = _shortest_path(adj_matrix, origin_node, dest_node)
    if not path:
        return []
        
    A.append({'path': path, 'cost': cost})
    B = []
    
    for k_idx in range(1, k):
        prev_path = A[k_idx - 1]['path']
        for i in range(len(prev_path) - 1):
            spur_node = prev_path[i]
            root_path = prev_path[:i + 1]
            
            # Use LIL for efficient modification
            mod_adj = adj_matrix.tolil()
            
            for p in A:
                p_path = p['path']
                if len(p_path) > i and p_path[:i + 1] == root_path:
                    u = p_path[i]
                    v = p_path[i + 1]
                    mod_adj[u, v] = 0
                    mod_adj[v, u] = 0
            
            for root_node in root_path[:-1]:
                # Remove nodes completely from graph
                mod_adj[root_node, :] = 0
                mod_adj[:, root_node] = 0
                
            mod_csr = mod_adj.tocsr()
            mod_csr.eliminate_zeros()
            
            spur_path, spur_cost = _shortest_path(mod_csr, spur_node, dest_node)
            
            if spur_path:
                total_path = root_path[:-1] + spur_path
                total_cost = 0
                for n1, n2 in zip(total_path[:-1], total_path[1:]):
                    # Cost extraction
                    val = adj_matrix[n1, n2]
                    if val > 0:
                        total_cost += val
                    else:
                        total_cost += float('inf')
                        
                potential = {'path': total_path, 'cost': total_cost}
                if potential not in B:
                    B.append(potential)
                    
        if not B:
            break
            
        B.sort(key=lambda x: x['cost'])
        A.append(B.pop(0))
        
    return [p['path'] for p in A]
