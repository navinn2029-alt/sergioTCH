"""
Módulo Proyector TCH

Implementa el proyector 30 → 128 → 384 con GELU.

h₁ = GELU(Dense_{30→128}(v_base))
e_tch = Dense_{128→384}(h₁)
"""

using Flux

"""
Proyector neuronal del sistema TCH.

Transforma el vector base de 30 dimensiones a embedding de 384.
"""
mutable struct Projector
    # Capas densas
    dense1::Dense  # 30 → 128
    dense2::Dense  # 128 → 384
    
    # Dimensiones
    input_dim::Int
    hidden_dim::Int
    output_dim::Int
end

"""Constructor por defecto."""
function Projector()
    Projector(
        Dense(30 => 128, gelu),   # Primera capa con GELU
        Dense(128 => 384),         # Segunda capa sin activación
        30, 128, 384
    )
end

"""
Activación GELU (Gaussian Error Linear Unit).

GELU(x) = 0.5x * [1 + tanh(√(2/π) * (x + 0.044715x³))]
"""
function gelu_manual(x::Float64)::Float64
    0.5 * x * (1.0 + tanh(sqrt(2.0 / π) * (x + 0.044715 * x^3)))
end

"""
Forward pass del proyector.

h₁ = GELU(W₁ * v_base + b₁)
e_tch = W₂ * h₁ + b₂
"""
function forward(proj::Projector, v_base::Vector{Float64})::Vector{Float64}
    # Convertir a Float32 para Flux
    x = Float32.(v_base)
    
    # Primera capa con GELU
    h1 = proj.dense1(x)
    
    # Segunda capa
    e_tch = proj.dense2(h1)
    
    Float64.(e_tch)
end

"""
Proyectar con estado actual.

Aplica pesos del estado antes de proyectar.
"""
function project_with_state(proj::Projector,
                            v_base::Vector{Float64},
                            state_weights::Vector{Float64})::Vector{Float64}
    # Expandir pesos de estado (6 dims) a 30 dims
    expanded_weights = repeat(state_weights, inner=5)
    
    # Aplicar pesos
    weighted = v_base .* expanded_weights
    
    # Proyectar
    forward(proj, weighted)
end

"""Serializar a Dict (solo metadatos, no pesos)."""
function to_dict(proj::Projector)::Dict{String, Any}
    Dict(
        "input_dim" => proj.input_dim,
        "hidden_dim" => proj.hidden_dim,
        "output_dim" => proj.output_dim,
        "architecture" => "30 -> GELU -> 128 -> 384"
    )
end
