import numpy as np

def calculate_route_security_probability(route_arcs, arc_probs):
    """
    Equation 1: P_L = ∏(l in L) p_l
    Uses log-sum trick for numerical stability.
    """
    if not route_arcs:
        return 1.0
    
    log_prob = 0.0
    for arc_id in route_arcs:
        p_l = arc_probs.get(arc_id, {}).get('p_l', 0.8)
        log_prob += np.log(np.clip(p_l, 1e-9, 1.0))
        
    return float(np.exp(log_prob))

def calculate_scenario_probability(a_sl, q_l):
    """
    Equation 3: p_s = ∏(l: a_sl=0) q_l  ×  ∏(l: a_sl=1) (1 - q_l)
    """
    a_sl = np.asarray(a_sl)
    q_l = np.asarray(q_l)
    
    probs = np.where(a_sl == 0, q_l, 1.0 - q_l)
    log_probs = np.log(np.clip(probs, 1e-9, 1.0))
    
    return float(np.exp(np.sum(log_probs)))
