import pulp

def solve_bip(num_vehicles_I, num_dests_J, num_routes_K, num_scenarios_S,
             P_ijks, p_s, t_sl, T_e, alpha_lijk, lambda_l):
    """
    Solves the binary integer programming model for route selection
    under uncertain battlefield environment across sampled scenarios.
    """
    if num_routes_K == 0 or num_vehicles_I == 0 or num_dests_J == 0:
        return 0, []
        
    prob = pulp.LpProblem("Convoy_BIP", pulp.LpMaximize)
    
    # Binary decision variables x_ijk
    x = pulp.LpVariable.dicts("x", 
        ((i, j, k) for i in range(num_vehicles_I) 
                   for j in range(num_dests_J) 
                   for k in range(num_routes_K)),
        cat='Binary'
    )
    
    # Objective: max Z = Σ_s Σ_i Σ_j Σ_k x_ijk * P_ijks * p_s
    prob += pulp.lpSum(
        x[i, j, k] * P_ijks[i, j, k, s] * p_s[s]
        for i in range(num_vehicles_I)
        for j in range(num_dests_J)
        for k in range(num_routes_K)
        for s in range(num_scenarios_S)
    )
    
    # C5: Σ_j Σ_k x_ijk = 1 ∀i (all vehicles dispatched)
    for i in range(num_vehicles_I):
        prob += pulp.lpSum(x[i, j, k] for j in range(num_dests_J) for k in range(num_routes_K)) == 1
        
    # C6: Σ_i Σ_k x_ijk <= 1 ∀j (one vehicle per dest)
    for j in range(num_dests_J):
        prob += pulp.lpSum(x[i, j, k] for i in range(num_vehicles_I) for k in range(num_routes_K)) <= 1
        
    # C7: x_ijk * Σ_l t_sl <= T_e ∀i,j,k (time deadline)
    for i in range(num_vehicles_I):
        for j in range(num_dests_J):
            for k in range(num_routes_K):
                for s in range(num_scenarios_S):
                    prob += x[i, j, k] * t_sl[j, k, s] <= T_e
                    
    # C10: Σ_i Σ_j Σ_k α_lijk * x_ijk <= λ_l ∀l (arc capacity)
    num_arcs = len(lambda_l)
    for l in range(num_arcs):
        prob += pulp.lpSum(
            alpha_lijk[l, i, j, k] * x[i, j, k]
            for i in range(num_vehicles_I)
            for j in range(num_dests_J)
            for k in range(num_routes_K)
        ) <= lambda_l[l]
        
    prob.solve(pulp.PULP_CBC_CMD(msg=0))
    
    if prob.status == pulp.LpStatusOptimal:
        selected = []
        for i in range(num_vehicles_I):
            for j in range(num_dests_J):
                for k in range(num_routes_K):
                    if pulp.value(x[i, j, k]) and pulp.value(x[i, j, k]) > 0.5:
                        selected.append((i, j, k))
        return pulp.value(prob.objective), selected
    return 0, []
