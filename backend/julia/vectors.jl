"""
Módulo de Vectores de Personalidad TCH

Implementa los 6 vectores de personalidad:
- D1 (Número 1): V1 Análisis, V2 Lenguaje, V3 Control
- D2 (Géminis): U1 Síntesis, U2 Imagen, U3 Intuición

V_TCH = [v₁, v₂, v₃, u₁, u₂, u₃] ∈ ℝ⁶
"""

"""
Estructura que contiene los 6 vectores de personalidad.

Dimensión Número 1 (D1) - Hemisferio Izquierdo:
    - V1: Análisis (descomposición lógica y secuencial) = 0.95
    - V2: Lenguaje (codificación verbal y simbólica) = 0.98
    - V3: Control (autocrítica, inhibición, regulación) = 1.00

Dimensión Géminis (D2) - Hemisferio Derecho:
    - U1: Síntesis (integración holística de patrones) = 0.95
    - U2: Imagen (procesamiento visual-espacial y emocional) = 0.90
    - U3: Intuición (asociaciones no lineales y creativas) = 0.85
"""
mutable struct PersonalityVectors
    # Pesos base de cada vector
    D1_V1_weight::Float64  # Análisis
    D1_V2_weight::Float64  # Lenguaje
    D1_V3_weight::Float64  # Control
    D2_U1_weight::Float64  # Síntesis
    D2_U2_weight::Float64  # Imagen
    D2_U3_weight::Float64  # Intuición
    
    # Vectores expandidos (5 dimensiones cada uno)
    D1_V1::Vector{Float64}
    D1_V2::Vector{Float64}
    D1_V3::Vector{Float64}
    D2_U1::Vector{Float64}
    D2_U2::Vector{Float64}
    D2_U3::Vector{Float64}
    
    # Coeficientes φ de influencia (N1: +, G: -)
    phi_coefficients::Dict{String, Float64}
    
    # Pesos estructurales
    structural_weights::Dict{String, Float64}
end

"""Constructor por defecto con valores de especificación."""
function PersonalityVectors()
    PersonalityVectors(
        # Pesos base
        0.95, 0.98, 1.00,  # D1: Análisis, Lenguaje, Control
        0.95, 0.90, 0.85,  # D2: Síntesis, Imagen, Intuición
        
        # Vectores expandidos (5 dims cada uno)
        [0.95, 0.98, 1.0, 0.9, 1.0],   # D1_V1
        [0.95, 1.0, 0.9, 0.95, 1.0],   # D1_V2
        [0.98, 1.0, 0.9, 1.0, 0.85],   # D1_V3
        [0.95, 0.9, 0.85, 0.9, 0.8],   # D2_U1
        [1.0, 0.8, 0.75, 0.9, 0.85],   # D2_U2
        [0.8, 0.95, 0.9, 0.9, 0.95],   # D2_U3
        
        # Coeficientes φ (N1: +1, G: -1)
        Dict(
            "D1_V1" => 0.9,
            "D1_V2" => 0.7,
            "D1_V3" => 1.0,
            "D2_U1" => -0.8,
            "D2_U2" => -0.9,
            "D2_U3" => -0.9,
            "KG" => -0.5,
            "CPV" => 0.0,
            "internal" => -0.3
        ),
        
        # Pesos estructurales
        Dict(
            "D1_V1" => 0.10,
            "D1_V2" => 0.10,
            "D1_V3" => 0.10,
            "D2_U1" => 0.15,
            "D2_U2" => 0.15,
            "D2_U3" => 0.15,
            "KG" => 0.15,
            "CPV" => 0.05,
            "internal" => 0.05
        )
    )
end

"""
Vector base TCH concatenado (30 dimensiones).
v_base = concat(D1_V1, D1_V2, D1_V3, D2_U1, D2_U2, D2_U3) ∈ ℝ³⁰
"""
function v_base(pv::PersonalityVectors)::Vector{Float64}
    vcat(pv.D1_V1, pv.D1_V2, pv.D1_V3, pv.D2_U1, pv.D2_U2, pv.D2_U3)
end

"""
Vector D1 (Número 1) concatenado (15 dimensiones).
d₁ = concat(D1_V1, D1_V2, D1_V3) ∈ ℝ¹⁵
"""
function d1_vector(pv::PersonalityVectors)::Vector{Float64}
    vcat(pv.D1_V1, pv.D1_V2, pv.D1_V3)
end

"""
Vector D2 (Géminis) concatenado (15 dimensiones).
d₂ = concat(D2_U1, D2_U2, D2_U3) ∈ ℝ¹⁵
"""
function d2_vector(pv::PersonalityVectors)::Vector{Float64}
    vcat(pv.D2_U1, pv.D2_U2, pv.D2_U3)
end

"""
Vector TCH de 6 dimensiones (pesos base).
V_TCH = [v₁, v₂, v₃, u₁, u₂, u₃] ∈ ℝ⁶
"""
function v_tch(pv::PersonalityVectors)::Vector{Float64}
    [pv.D1_V1_weight, pv.D1_V2_weight, pv.D1_V3_weight,
     pv.D2_U1_weight, pv.D2_U2_weight, pv.D2_U3_weight]
end

"""
Obtener vector ponderado por estado.
"""
function get_weighted_vector(pv::PersonalityVectors, state_weights::Vector{Float64})::Vector{Float64}
    v_tch(pv) .* state_weights
end

"""
Calcular influencia global N1/Géminis.

I_N1 = Σ(wᵢ * max(0, φᵢ)) / Σwᵢ = 0.34
I_G = Σ(wᵢ * max(0, -φᵢ)) / Σwᵢ = 0.66

Retorna: (I_N1, I_G)
"""
function calculate_global_influence(pv::PersonalityVectors)::Tuple{Float64, Float64}
    total_weight = sum(values(pv.structural_weights))
    
    # Influencia N1 (coeficientes positivos)
    i_n1 = 0.0
    for (key, phi) in pv.phi_coefficients
        if phi > 0 && haskey(pv.structural_weights, key)
            i_n1 += pv.structural_weights[key] * phi
        end
    end
    i_n1 /= total_weight
    
    # Influencia G (coeficientes negativos)
    i_g = 0.0
    for (key, phi) in pv.phi_coefficients
        if phi < 0 && haskey(pv.structural_weights, key)
            i_g += pv.structural_weights[key] * abs(phi)
        end
    end
    i_g /= total_weight
    
    (i_n1, i_g)
end

"""
Serializar a Dict.
"""
function to_dict(pv::PersonalityVectors)::Dict{String, Any}
    Dict(
        "D1_V1_weight" => pv.D1_V1_weight,
        "D1_V2_weight" => pv.D1_V2_weight,
        "D1_V3_weight" => pv.D1_V3_weight,
        "D2_U1_weight" => pv.D2_U1_weight,
        "D2_U2_weight" => pv.D2_U2_weight,
        "D2_U3_weight" => pv.D2_U3_weight,
        "D1_V1" => pv.D1_V1,
        "D1_V2" => pv.D1_V2,
        "D1_V3" => pv.D1_V3,
        "D2_U1" => pv.D2_U1,
        "D2_U2" => pv.D2_U2,
        "D2_U3" => pv.D2_U3,
        "v_base" => v_base(pv),
        "d1_vector" => d1_vector(pv),
        "d2_vector" => d2_vector(pv),
        "v_tch" => v_tch(pv),
        "global_influence" => calculate_global_influence(pv)
    )
end
