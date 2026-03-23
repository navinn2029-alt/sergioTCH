"""
Módulo Drive TCH

Implementa el sistema de impulso autónomo:
- Cálculo de drive (impulso a hablar)
- Umbral de expresión θ_exp = 0.65
- Funciones tick!, maybe_transition!, speak!

Drive = 0.5 * base + 0.5 * personalidad
base = mean(S_int)
personalidad = 0.4 * n1_activo + 0.6 * g_activo (asimetría 34/66)
"""

"""
Sistema de impulso autónomo.
"""
mutable struct DriveSystem
    # Umbral de expresión
    θ_exp::Float64
    
    # Pesos de personalidad (asimetría 34/66)
    n1_weight::Float64  # 0.4 (34%)
    g_weight::Float64   # 0.6 (66%)
    
    # Estado
    last_drive::Float64
    last_spoke::Bool
    thoughts::Vector{Dict{String, Any}}
    
    # Contadores
    ticks::Int64
    speaks::Int64
end

"""Constructor por defecto."""
function DriveSystem()
    DriveSystem(
        0.65,  # θ_exp
        0.4,   # n1_weight (34%)
        0.6,   # g_weight (66%)
        0.0,
        false,
        Dict{String, Any}[],
        0,
        0
    )
end

"""
Calcular activación hemisférica por estado.

n1_activo = (v₁ + v₂ + v₃) / 3
g_activo = (u₁ + u₂ + u₃) / 3
"""
function calculate_hemisphere_activation(state_weights::Vector{Float64})::Tuple{Float64, Float64}
    n1_activo = mean(state_weights[1:3])
    g_activo = mean(state_weights[4:6])
    (n1_activo, g_activo)
end

"""
Calcular drive (impulso a hablar).

base = mean(S_int)
personalidad = 0.4 * n1_activo + 0.6 * g_activo
drive = 0.5 * base + 0.5 * personalidad
"""
function calculate_drive(ds::DriveSystem,
                         internal_state::InternalState,
                         state_weights::Vector{Float64})::Float64
    # Base del estado interno
    base = mean_state(internal_state)
    
    # Activación hemisférica
    n1_activo, g_activo = calculate_hemisphere_activation(state_weights)
    
    # Personalidad activa (con asimetría 34/66)
    personalidad = ds.n1_weight * n1_activo + ds.g_weight * g_activo
    
    # Drive final
    drive = 0.5 * base + 0.5 * personalidad
    
    ds.last_drive = drive
    drive
end

"""
Evaluar si debe hablar.

hablar = drive > θ_exp
"""
function should_speak(ds::DriveSystem, drive::Float64)::Bool
    drive > ds.θ_exp
end

"""
Generar pensamiento (cuando decide hablar).

thought = [mean(S_int), max(v_base), min(v_base), std(v_base)]
"""
function generate_thought(ds::DriveSystem,
                          internal_state::InternalState,
                          v_base::Vector{Float64},
                          current_state::State)::Dict{String, Any}
    thought = Dict{String, Any}(
        "timestamp" => now(),
        "state" => string(current_state),
        "mean_internal" => mean_state(internal_state),
        "max_v" => maximum(v_base),
        "min_v" => minimum(v_base),
        "std_v" => std(v_base),
        "drive" => ds.last_drive,
        "mood" => calculate_mood(internal_state)
    )
    
    push!(ds.thoughts, thought)
    thought
end

"""
Ciclo tick! - avanzar un ciclo del sistema.

Retorna: true si debe hablar
"""
function tick!(ds::DriveSystem,
               internal_state::InternalState,
               state_weights::Vector{Float64})::Bool
    ds.ticks += 1
    
    # Calcular drive
    drive = calculate_drive(ds, internal_state, state_weights)
    
    # Evaluar si debe hablar
    ds.last_spoke = should_speak(ds, drive)
    ds.last_spoke
end

"""
Hablar - ejecutar cuando tick! retorna true.

Libera tensión y expresión después de hablar.
"""
function speak!(ds::DriveSystem,
                internal_state::InternalState,
                v_base::Vector{Float64},
                current_state::State)::Dict{String, Any}
    # Generar pensamiento
    thought = generate_thought(ds, internal_state, v_base, current_state)
    
    # Liberar tensión y expresión
    release_tension!(internal_state, 0.5)
    release_expression!(internal_state, 0.6)
    
    ds.speaks += 1
    thought
end

"""Serializar a Dict."""
function to_dict(ds::DriveSystem)::Dict{String, Any}
    Dict(
        "theta_exp" => ds.θ_exp,
        "n1_weight" => ds.n1_weight,
        "g_weight" => ds.g_weight,
        "last_drive" => ds.last_drive,
        "last_spoke" => ds.last_spoke,
        "ticks" => ds.ticks,
        "speaks" => ds.speaks,
        "thoughts_count" => length(ds.thoughts)
    )
end
