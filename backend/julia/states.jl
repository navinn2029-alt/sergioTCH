"""
Módulo de Estados de Conciencia TCH

Implementa los 4 estados fundamentales:
- L: Sueño Lúcido (máxima información, log=3.00)
- M: Meditación (log=2.95)
- K: Creatividad (log=2.85)
- F: Flow (log=2.90)

Incluye matriz de transición probabilística calculada
con logaritmos condicionales.
"""

"""Enumeración de estados de conciencia."""
@enum State begin
    L = 1  # Sueño Lúcido
    M = 2  # Meditación
    K = 3  # Creatividad
    F = 4  # Flow
end

"""
Sistema de estados de conciencia con transiciones probabilísticas.

Cada estado tiene:
- Un valor logarítmico (información total)
- Pesos hemisféricos para los 6 vectores
- Probabilidades de transición a otros estados
"""
mutable struct ConsciousnessState
    # Estado actual
    current::State
    
    # Contadores
    cycles::Int64
    transitions::Int64
    speaks::Int64
    
    # LOG de cada estado (información total)
    state_logs::Dict{State, Float64}
    
    # Pesos hemisféricos por estado [v₁, v₂, v₃, u₁, u₂, u₃]
    state_weights::Dict{State, Vector{Float64}}
    
    # Intersecciones base (información compartida)
    base_intersections::Dict{Tuple{State, State}, Float64}
    
    # Temperaturas de generación por estado
    state_temperatures::Dict{State, Float64}
    
    # Parámetros
    η_transition::Float64  # Probabilidad base de intentar transición
    τ::Float64             # Parámetro de modulación por similitud
end

"""Constructor por defecto."""
function ConsciousnessState()
    ConsciousnessState(
        L,  # Estado inicial: Sueño Lúcido
        0, 0, 0,  # Contadores
        
        # LOG de cada estado
        Dict(
            L => 3.00,  # Sueño Lúcido - máxima información
            M => 2.95,  # Meditación
            K => 2.85,  # Creatividad
            F => 2.90   # Flow
        ),
        
        # Pesos hemisféricos [v₁, v₂, v₃, u₁, u₂, u₃]
        Dict(
            L => [1.0, 0.5, 1.0, 1.0, 1.0, 1.0],
            M => [0.2, 0.1, 0.3, 1.0, 0.5, 1.0],
            K => [0.6, 0.3, 0.4, 1.0, 0.5, 1.0],
            F => [0.2, 0.1, 0.0, 0.5, 1.0, 1.0]
        ),
        
        # Intersecciones base
        Dict(
            (L, F) => 2.78,
            (M, L) => 2.93,
            (K, F) => 2.83,
            (F, M) => 2.70
        ),
        
        # Temperaturas
        Dict(
            L => 0.8,  # Más creativo en sueño lúcido
            M => 0.3,  # Muy controlado en meditación
            K => 0.9,  # Máxima creatividad
            F => 0.5   # Balance en flow
        ),
        
        0.1,  # η_transition
        0.5   # τ
    )
end

"""Obtener log del estado actual."""
log_current(cs::ConsciousnessState) = cs.state_logs[cs.current]

"""Obtener pesos del estado actual."""
current_weights(cs::ConsciousnessState) = cs.state_weights[cs.current]

"""Obtener temperatura del estado actual."""
current_temperature(cs::ConsciousnessState) = cs.state_temperatures[cs.current]

"""
Calcular dimensiones totales de un estado.
Retorna: (D1_total, D2_total, TOTAL)
"""
function get_total_dimensions(cs::ConsciousnessState, state::State)::Tuple{Float64, Float64, Float64}
    weights = cs.state_weights[state]
    d1_total = sum(weights[1:3])
    d2_total = sum(weights[4:6])
    (d1_total, d2_total, d1_total + d2_total)
end

"""
Calcular log-intersección entre dos estados.

Si se proporciona matriz P de plasticidad, usa pesos aprendidos.
log(A∩B) = (1/6) * Σ min(P_A,i, P_B,i)
"""
function calculate_log_intersection(cs::ConsciousnessState, 
                                    state_a::State, state_b::State;
                                    P::Union{Matrix{Float64}, Nothing}=nothing)::Float64
    # Verificar si existe intersección base
    if isnothing(P)
        if haskey(cs.base_intersections, (state_a, state_b))
            return cs.base_intersections[(state_a, state_b)]
        elseif haskey(cs.base_intersections, (state_b, state_a))
            return cs.base_intersections[(state_b, state_a)]
        end
    end
    
    # Calcular usando pesos
    if !isnothing(P)
        weights_a = P[Int(state_a), :]
        weights_b = P[Int(state_b), :]
    else
        weights_a = cs.state_weights[state_a]
        weights_b = cs.state_weights[state_b]
    end
    
    # Mínimo por coordenada
    min_weights = min.(weights_a, weights_b)
    mean(min_weights)
end

"""
Calcular logaritmo condicional.
log(A|B) = log(A) - log(A∩B)
"""
function calculate_log_conditional(cs::ConsciousnessState,
                                   state_a::State, state_b::State;
                                   P::Union{Matrix{Float64}, Nothing}=nothing)::Float64
    log_a = cs.state_logs[state_a]
    log_intersection = calculate_log_intersection(cs, state_a, state_b; P=P)
    log_a - log_intersection
end

"""
Calcular probabilidad de transición base.
P_base(A→B) = 1 - log(B|A)
"""
function calculate_transition_probability_base(cs::ConsciousnessState,
                                               from_state::State, 
                                               to_state::State)::Float64
    if from_state == to_state
        return 0.0
    end
    
    log_conditional = calculate_log_conditional(cs, to_state, from_state)
    prob = 1.0 - log_conditional
    clamp(prob, 0.0, 1.0)
end

"""
Calcular similitud aprendible entre estados.
sim(A,B) = (1/6) * Σ min(P_A,i, P_B,i) ∈ [0,1]
"""
function calculate_similarity(cs::ConsciousnessState,
                             state_a::State, state_b::State,
                             P::Matrix{Float64})::Float64
    weights_a = P[Int(state_a), :]
    weights_b = P[Int(state_b), :]
    mean(min.(weights_a, weights_b))
end

"""
Obtener matriz de transición completa (4×4).

Si se proporciona P, modula con similitud aprendida:
P̃(A→B) = P_base(A→B) * exp(τ * sim(A,B))
Luego normaliza por fila.
"""
function get_transition_matrix(cs::ConsciousnessState;
                               P::Union{Matrix{Float64}, Nothing}=nothing)::Matrix{Float64}
    states = [L, M, K, F]
    T = zeros(4, 4)
    
    for (i, from_state) in enumerate(states)
        row_probs = Float64[]
        
        for (j, to_state) in enumerate(states)
            if from_state == to_state
                push!(row_probs, 0.0)
            else
                p_base = calculate_transition_probability_base(cs, from_state, to_state)
                
                if !isnothing(P)
                    sim = calculate_similarity(cs, from_state, to_state, P)
                    p_modulated = p_base * exp(cs.τ * sim)
                else
                    p_modulated = p_base
                end
                
                push!(row_probs, p_modulated)
            end
        end
        
        # Normalizar fila
        total = sum(row_probs)
        if total > 0
            row_probs ./= total
        end
        
        T[i, :] = row_probs
    end
    
    T
end

"""
Intentar transición de estado.
Retorna: true si hubo transición
"""
function maybe_transition!(cs::ConsciousnessState;
                          P::Union{Matrix{Float64}, Nothing}=nothing)::Bool
    # Solo intentar con cierta probabilidad
    if rand() > cs.η_transition
        return false
    end
    
    # Obtener matriz de transición
    T = get_transition_matrix(cs; P=P)
    current_idx = Int(cs.current)
    probs = T[current_idx, :]
    
    # Seleccionar siguiente estado
    r = rand()
    cumsum_val = 0.0
    states = [L, M, K, F]
    
    for (i, p) in enumerate(probs)
        cumsum_val += p
        if r < cumsum_val && i != current_idx
            cs.current = states[i]
            cs.transitions += 1
            return true
        end
    end
    
    false
end

"""Avanzar un ciclo."""
function tick!(cs::ConsciousnessState)
    cs.cycles += 1
end

"""Serializar a Dict."""
function to_dict(cs::ConsciousnessState)::Dict{String, Any}
    Dict(
        "current_state" => string(cs.current),
        "cycles" => cs.cycles,
        "transitions" => cs.transitions,
        "speaks" => cs.speaks,
        "log_current" => log_current(cs),
        "current_weights" => current_weights(cs),
        "temperature" => current_temperature(cs),
        "dimensions" => get_total_dimensions(cs, cs.current)
    )
end
