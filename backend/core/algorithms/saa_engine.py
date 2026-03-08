import multiprocessing
import os
import numpy as np
from collections import Counter
from .bip_solver import solve_bip

def _solve_single_saa_iteration(args):
    N, I, J, K, arc_security_probs, t_sl_base, T_e, alpha, lambd = args
    num_arcs = len(arc_security_probs)
    
    p_l = np.array([arc['p_l'] for arc in arc_security_probs])
    theta_l = np.array([arc.get('theta_l', 0.2) for arc in arc_security_probs])
    
    # MC Sampling
    rand_draws = np.random.rand(N, num_arcs)
    a_sl = (rand_draws < p_l).astype(int)
    
    p_sl = np.where(a_sl == 1, 1.0, theta_l)
    log_p_sl = np.log(np.clip(p_sl, 1e-9, 1.0))
    
    # Vectorised Probability calculations using numpy
    P_ijks = np.zeros((I, J, K, N))
    for i in range(I):
        for j in range(J):
            for k in range(K):
                route_mask = alpha[:, i, j, k]
                # Matrix multiply across scenarios
                log_probs = log_p_sl @ route_mask
                P_ijks[i, j, k, :] = np.exp(log_probs)
                
    p_s = np.ones(N) / N
    
    t_sl = np.zeros((J, K, N))
    for j in range(J):
        for k in range(K):
            t_sl[j, k, :] = t_sl_base[j, k]
            
    obj, selected = solve_bip(I, J, K, N, P_ijks, p_s, t_sl, T_e, alpha, lambd)
    return tuple(sorted(selected))

def run_saa_optimization(I, J, K, arc_security_probs, t_sl_base, T_e, alpha, lambd, M=10, initial_N=100):
    """
    Sample Average Approximation (SAA) dynamic N evaluation loop.
    Uses multiprocessing.Pool for parallel scenario solving across M iterations.
    """
    N = initial_N
    best_solution = None
    
    workers = min(4, os.cpu_count() or 4)
    
    while N <= 1000:
        pool_args = [(N, I, J, K, arc_security_probs, t_sl_base, T_e, alpha, lambd) for _ in range(M)]
        with multiprocessing.Pool(workers) as pool:
            results = pool.map(_solve_single_saa_iteration, pool_args)
            
        counter = Counter(results)
        most_recurring_solution = counter.most_common(1)[0][0]
        
        # Stop condition based on recurrence
        if counter[most_recurring_solution] >= M / 2:
            best_solution = most_recurring_solution
            break
            
        N += 100
        best_solution = most_recurring_solution
        
    return best_solution
