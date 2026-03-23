"""
Módulo de Plasticidad TCH

Implementa los 4 canales aprendibles:
1. Hemisférico (D1 ↔ D2): W₁₂ ∈ ℝ¹⁵×¹⁵ - Hebbiana
2. Estado ↔ Vector: P ∈ ℝ⁴×⁶ - Refuerzo
3. Knowledge Graph: R (matriz de relaciones) - Uso/Olvido
4. CPV Triggers: κ ∈ ℝ|𝒦| - Actualización dinámica
"""

"""
Motor de plasticidad del sistema TCH.
"""
mutable struct PlasticityEngine
    # Canal hemisférico (Hebbiano)
    W_12::Matrix{Float64}  # 15×15
    
    # Canal Estado↔Vector (Refuerzo)
    P::Matrix{Float64}  # 4×6 (L, M, K, F)
    
    # Parámetros
    η_hebb::Float64      # Tasa de aprendizaje Hebbiano
    α_refuerzo::Float64  # Influencia de recompensa
    β_trigger::Float64   # Cambio de peso de triggers
    
    # Media móvil de recompensas
    r_hat::Float64
    r_count::Int64
    
    # Historial para análisis
    hebb_updates::Int64
    refuerzo_updates::Int64
end

"""Constructor por defecto."""
function PlasticityEngine()
    # Inicializar W_12 como identidad escalada
    W_12 = Matrix{Float64}(I, 15, 15) * 0.1
    
    # Inicializar P con pesos base de estados
    P = [
        1.0 0.5 1.0 1.0 1.0 1.0;  # L
        0.2 0.1 0.3 1.0 0.5 1.0;  # M
        0.6 0.3 0.4 1.0 0.5 1.0;  # K
        0.2 0.1 0.0 0.5 1.0 1.0   # F
    ]
    
    PlasticityEngine(
        W_12,
        P,
        0.015,  # η_hebb
        0.03,   # α_refuerzo
        0.04,   # β_trigger
        0.5,    # r_hat inicial
        0,      # r_count
        0,      # hebb_updates
        0       # refuerzo_updates
    )
end

"""
Plasticidad hemisférica (Hebbiana) - Eq. 2.1, 2.2

a₁ = (e_in · d₁) / (||d₁|| + ε)
a₂ = (e_in · d₂) / (||d₂|| + ε)

ΔW₁₂ = η_hebb * (a₁ * d₁) * (a₂ * d₂)ᵀ
W₁₂ = W₁₂ + ΔW₁₂

Normalización Frobenius para estabilidad.
"""
function update_hebbian!(pe::PlasticityEngine, 
                         e_in::Vector{Float64},
                         d1::Vector{Float64},
                         d2::Vector{Float64};
                         ε::Float64=1e-8)
    # Calcular activaciones
    a1 = dot(e_in[1:15], d1) / (norm(d1) + ε)
    a2 = dot(e_in[1:15], d2) / (norm(d2) + ε)
    
    # Actualizar W_12 (Hebbian)
    ΔW = pe.η_hebb * (a1 * d1) * (a2 * d2)'
    pe.W_12 .+= ΔW
    
    # Normalizar por norma de Frobenius
    frob_norm = norm(pe.W_12)
    if frob_norm > ε
        pe.W_12 ./= frob_norm
    end
    
    pe.hebb_updates += 1
    (a1, a2)
end

"""
Plasticidad Estado↔Vector (Refuerzo) - Eq. 3.1, 3.2

a_{s,i} = (e_in · v_i) / (||v_i|| + ε)
ΔP_{s,i} = α * (r - r̂) * a_{s,i}
P_{s,i} = P_{s,i} + ΔP_{s,i}

Luego clip [0,1] y normalizar fila.
"""
function update_reinforcement!(pe::PlasticityEngine,
                               state_idx::Int,
                               e_in::Vector{Float64},
                               v_tch::Vector{Float64},
                               reward::Float64;
                               ε::Float64=1e-8)
    # Actualizar media móvil de recompensas
    pe.r_count += 1
    pe.r_hat = pe.r_hat + (reward - pe.r_hat) / pe.r_count
    
    # Error de predicción
    δ = reward - pe.r_hat
    
    # Actualizar cada peso del estado
    for i in 1:6
        # Activación (usar los primeros 6 valores de e_in como proxy)
        a_si = e_in[min(i, length(e_in))] * v_tch[i] / (norm(v_tch) + ε)
        
        # Actualizar
        ΔP = pe.α_refuerzo * δ * a_si
        pe.P[state_idx, i] += ΔP
    end
    
    # Clip [0, 1]
    pe.P[state_idx, :] .= clamp.(pe.P[state_idx, :], 0.0, 1.0)
    
    # Normalizar fila
    row_sum = sum(pe.P[state_idx, :])
    if row_sum > ε
        pe.P[state_idx, :] ./= row_sum
    end
    
    pe.refuerzo_updates += 1
    δ
end

"""
Obtener matriz P para uso en transiciones.
"""
function get_P(pe::PlasticityEngine)::Matrix{Float64}
    pe.P
end

"""
Obtener matriz W_12 para procesamiento dual.
"""
function get_W12(pe::PlasticityEngine)::Matrix{Float64}
    pe.W_12
end

"""
Aplicar modulación hemisférica.

out = W_12 * d1 ∘ d2
"""
function apply_hemispheric_modulation(pe::PlasticityEngine,
                                      d1::Vector{Float64},
                                      d2::Vector{Float64})::Vector{Float64}
    # Modulación cruzada
    modulated = pe.W_12 * d1
    modulated .* d2
end

"""Serializar a Dict."""
function to_dict(pe::PlasticityEngine)::Dict{String, Any}
    Dict(
        "W_12_shape" => size(pe.W_12),
        "W_12_norm" => norm(pe.W_12),
        "P" => pe.P,
        "eta_hebb" => pe.η_hebb,
        "alpha_refuerzo" => pe.α_refuerzo,
        "beta_trigger" => pe.β_trigger,
        "r_hat" => pe.r_hat,
        "hebb_updates" => pe.hebb_updates,
        "refuerzo_updates" => pe.refuerzo_updates
    )
end
