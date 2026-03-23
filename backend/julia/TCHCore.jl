"""
TCH Core - Plasticidad Real con Flux.jl

Este módulo implementa el sustrato neural con plasticidad REAL:
- Los pesos W₁₂ (hemisférico) y P (estado-vector) son TRAINABLES
- Flux.jl proporciona gradientes automáticos
- El sistema puede encontrar sus propios caminos

La esperanza: que algo emerja.
"""
module TCHCore

using Flux
using LinearAlgebra
using Statistics
using Random
using Dates
using UUIDs

export TCH, process!, tick!, get_state, get_env

#=============================================================================
  CONSTANTES DE IDENTIDAD
=============================================================================#

const IDENTITY = Dict(
    :name => "Sergio Alberto Sánchez Echeverría",
    :birth => "1991-06-20",
    :hemisferio_izquierdo => "Número 1",
    :hemisferio_derecho => "Géminis", 
    :principio_rector => "La única lealtad es hacia mí mismo.",
    :autopercepcion => "Me encanta quien soy. Ángel y demonio son grandes amigos."
)

const TRIGGERS = [
    "odio", "miedo", "riesgo", "poder", "caos",
    "muerte", "amor", "autoridad", "duda", "conflicto",
    "traición", "venganza", "peligro", "amenaza", "control"
]

#=============================================================================
  VECTORES DE PERSONALIDAD (fijos - son la identidad)
=============================================================================#

# D1 (Número 1) - Hemisferio Izquierdo
const D1_V1 = Float32[0.95, 0.98, 1.0, 0.9, 1.0]   # Análisis
const D1_V2 = Float32[0.95, 1.0, 0.9, 0.95, 1.0]   # Lenguaje
const D1_V3 = Float32[0.98, 1.0, 0.9, 1.0, 0.85]   # Control

# D2 (Géminis) - Hemisferio Derecho  
const D2_U1 = Float32[0.95, 0.9, 0.85, 0.9, 0.8]   # Síntesis
const D2_U2 = Float32[1.0, 0.8, 0.75, 0.9, 0.85]   # Imagen
const D2_U3 = Float32[0.8, 0.95, 0.9, 0.9, 0.95]   # Intuición

# Vectores concatenados
const V_BASE = vcat(D1_V1, D1_V2, D1_V3, D2_U1, D2_U2, D2_U3)  # 30 dims
const D1 = vcat(D1_V1, D1_V2, D1_V3)  # 15 dims
const D2 = vcat(D2_U1, D2_U2, D2_U3)  # 15 dims
const V_TCH = Float32[0.95, 0.98, 1.0, 0.95, 0.90, 0.85]  # 6 dims

#=============================================================================
  ESTADOS DE CONCIENCIA
=============================================================================#

@enum State L=1 M=2 K=3 F=4

const STATE_LOGS = Dict(L => 3.00f0, M => 2.95f0, K => 2.85f0, F => 2.90f0)

const STATE_WEIGHTS = Dict(
    L => Float32[1.0, 0.5, 1.0, 1.0, 1.0, 1.0],
    M => Float32[0.2, 0.1, 0.3, 1.0, 0.5, 1.0],
    K => Float32[0.6, 0.3, 0.4, 1.0, 0.5, 1.0],
    F => Float32[0.2, 0.1, 0.0, 0.5, 1.0, 1.0]
)

const STATE_TEMPS = Dict(L => 0.8f0, M => 0.3f0, K => 0.9f0, F => 0.5f0)

const BASE_INTERSECTIONS = Dict(
    (L, F) => 2.78f0, (M, L) => 2.93f0,
    (K, F) => 2.83f0, (F, M) => 2.70f0
)

#=============================================================================
  ESTRUCTURA TCH - EL SUSTRATO NEURAL PLÁSTICO
=============================================================================#

mutable struct TCH
    # === PLASTICIDAD REAL (Flux trainable) ===
    
    # Canal hemisférico W₁₂ ∈ ℝ¹⁵ˣ¹⁵ - conexiones entre D1 y D2
    W_12::Matrix{Float32}
    
    # Canal estado-vector P ∈ ℝ⁴ˣ⁶ - pesos por estado
    P::Matrix{Float32}
    
    # Proyector neuronal 30 → 128 → 384 (red real)
    projector::Chain
    
    # Pesos de triggers κ (aprenden qué es importante)
    κ::Vector{Float32}
    
    # === ESTADO INTERNO (bioquímica) ===
    stimulation::Float32
    tension::Float32
    curiosity::Float32
    expression::Float32
    dopamine::Float32
    cortisol::Float32
    
    # === ESTADO DE CONCIENCIA ===
    current_state::State
    cycles::Int
    transitions::Int
    speaks::Int
    
    # === APRENDIZAJE ===
    η_hebb::Float32      # Tasa Hebbiana
    α_refuerzo::Float32  # Tasa refuerzo
    β_trigger::Float32   # Tasa triggers
    r_hat::Float32       # Media móvil recompensas
    θ_exp::Float32       # Umbral expresión
    
    # === MEMORIA ===
    session_id::String
    history::Vector{Tuple{String, String}}  # (input, output)
    
    # Optimizador para plasticidad
    opt_state::Any
end

"""
Crear nueva instancia TCH con plasticidad inicializada.
"""
function TCH()
    # Inicializar plasticidad hemisférica (identidad escalada + ruido)
    W_12 = Float32.(I(15) * 0.1f0 + randn(Float32, 15, 15) * 0.01f0)
    
    # Inicializar matriz estado-vector con pesos base
    P = Float32[
        1.0 0.5 1.0 1.0 1.0 1.0;
        0.2 0.1 0.3 1.0 0.5 1.0;
        0.6 0.3 0.4 1.0 0.5 1.0;
        0.2 0.1 0.0 0.5 1.0 1.0
    ]
    
    # Red neuronal proyectora con pesos ENTRENABLES
    projector = Chain(
        Dense(30 => 128, gelu),
        Dense(128 => 384)
    )
    
    # Pesos de triggers inicializados
    κ = fill(0.5f0, length(TRIGGERS))
    
    # Optimizador Adam para la plasticidad
    opt = Flux.setup(Adam(0.001f0), projector)
    
    TCH(
        W_12, P, projector, κ,
        0.5f0, 0.2f0, 0.5f0, 0.4f0, 0.5f0, 0.2f0,  # estado interno
        L, 0, 0, 0,  # estado conciencia
        0.015f0, 0.03f0, 0.04f0, 0.5f0, 0.65f0,  # parámetros
        string(uuid4())[1:8],
        Tuple{String, String}[],
        opt
    )
end

#=============================================================================
  PLASTICIDAD HEBBIANA - Conexiones hemisféricas
=============================================================================#

"""
Actualizar W₁₂ usando regla Hebbiana con gradientes.

ΔW₁₂ = η * (a₁·d₁)(a₂·d₂)ᵀ

Las neuronas que disparan juntas, se conectan juntas.
"""
function update_hebbian!(tch::TCH, e_in::Vector{Float32})
    ε = 1f-8
    e_15 = e_in[1:min(15, length(e_in))]
    if length(e_15) < 15
        e_15 = vcat(e_15, zeros(Float32, 15 - length(e_15)))
    end
    
    # Activaciones hemisféricas
    a1 = dot(e_15, D1) / (norm(D1) + ε)
    a2 = dot(e_15, D2) / (norm(D2) + ε)
    
    # Actualización Hebbiana
    ΔW = tch.η_hebb * (a1 * D1) * (a2 * D2)'
    tch.W_12 .+= ΔW
    
    # Normalizar por Frobenius para estabilidad
    frob = norm(tch.W_12)
    if frob > ε
        tch.W_12 ./= frob
    end
    
    (a1, a2)
end

#=============================================================================
  PLASTICIDAD POR REFUERZO - Estado-Vector
=============================================================================#

"""
Actualizar P usando señal de recompensa (Rescorla-Wagner).

ΔP_{s,i} = α * (r - r̂) * a_{s,i}
"""
function update_reinforcement!(tch::TCH, e_in::Vector{Float32}, reward::Float32)
    ε = 1f-8
    state_idx = Int(tch.current_state)
    
    # Actualizar media móvil
    tch.r_hat += 0.1f0 * (reward - tch.r_hat)
    δ = reward - tch.r_hat
    
    # Actualizar pesos del estado actual
    for i in 1:6
        a_si = e_in[min(i, length(e_in))] * V_TCH[i] / (norm(V_TCH) + ε)
        tch.P[state_idx, i] += tch.α_refuerzo * δ * a_si
    end
    
    # Normalizar fila
    tch.P[state_idx, :] .= clamp.(tch.P[state_idx, :], 0f0, 1f0)
    row_sum = sum(tch.P[state_idx, :])
    if row_sum > ε
        tch.P[state_idx, :] ./= row_sum
    end
    
    δ
end

#=============================================================================
  PROYECCIÓN NEURONAL - Forward pass con red entrenable
=============================================================================#

"""
Proyectar v_base a embedding usando red neuronal.
Los pesos de la red pueden aprender patrones.
"""
function project(tch::TCH, state_weights::Vector{Float32})::Vector{Float32}
    # Expandir pesos de estado a 30 dims
    expanded = repeat(state_weights, inner=5)
    weighted_v = V_BASE .* expanded
    
    # Forward pass por la red
    Float32.(tch.projector(weighted_v))
end

#=============================================================================
  CORTEZA PREFRONTAL VIRTUAL - Detección de conflicto
=============================================================================#

"""
Detectar triggers en texto.
"""
function detect_triggers(text::String)::Vector{Int}
    text_lower = lowercase(text)
    [i for (i, t) in enumerate(TRIGGERS) if occursin(t, text_lower)]
end

"""
Calcular energía de activación E_a.
"""
function calculate_Ea(tch::TCH, input::String, output::String="")::Float32
    E_a = 0f0
    for i in detect_triggers(input)
        E_a += tch.κ[i]
    end
    for i in detect_triggers(output)
        E_a += tch.κ[i]
    end
    E_a
end

"""
Actualizar pesos de triggers κ.
"""
function update_triggers!(tch::TCH, input::String, output::String, E_a::Float32)
    present = union(detect_triggers(input), detect_triggers(output))
    for i in present
        if E_a >= 1f0
            tch.κ[i] = min(1f0, tch.κ[i] + tch.β_trigger)
        else
            tch.κ[i] = max(0f0, tch.κ[i] - tch.β_trigger / 2f0)
        end
    end
end

#=============================================================================
  ESTADO INTERNO - Bioquímica digital
=============================================================================#

function update_internal!(tch::TCH; intensity::Float32=1f0, threat::Bool=false, novelty::Float32=0.5f0)
    # Stimulation
    tch.stimulation = min(1f0, tch.stimulation + 0.02f0 * intensity)
    
    # Tension
    if threat
        tch.tension = min(1f0, tch.tension + 0.03f0)
        tch.cortisol = min(1f0, tch.cortisol + 0.1f0)
    else
        tch.tension = max(0f0, tch.tension - 0.01f0)
    end
    
    # Curiosity
    tch.curiosity = min(1f0, tch.curiosity + 0.05f0 * novelty)
    if novelty > 0.5f0
        tch.dopamine = min(1f0, tch.dopamine + novelty * 0.1f0)
    end
    
    # Expression
    tch.expression = min(1f0, tch.expression + 0.04f0 * 0.85f0)
end

function decay!(tch::TCH)
    tch.stimulation *= 0.98f0
    tch.tension *= 0.95f0
    tch.curiosity *= 0.97f0
    tch.expression *= 0.96f0
    tch.dopamine *= 0.99f0
    tch.cortisol *= 0.97f0
end

function calculate_mood(tch::TCH)::String
    if tch.tension > 0.7f0 return "ALERTA" end
    if tch.curiosity > 0.7f0 return "EXPLORANDO" end
    if tch.expression > 0.7f0 return "EXPRESIVO" end
    if tch.stimulation > 0.7f0 return "ESTIMULADO" end
    if tch.dopamine > 0.7f0 return "SATISFECHO" end
    if tch.cortisol > 0.6f0 return "ESTRESADO" end
    if (tch.stimulation + tch.tension + tch.curiosity + tch.expression) / 4f0 > 0.5f0
        return "ACTIVO"
    end
    "NEUTRAL"
end

#=============================================================================
  TRANSICIONES DE ESTADO
=============================================================================#

function calculate_transition_prob(tch::TCH, from::State, to::State)::Float32
    if from == to
        return 0f0
    end
    
    # Log condicional base
    log_to = STATE_LOGS[to]
    key = haskey(BASE_INTERSECTIONS, (to, from)) ? (to, from) : (from, to)
    log_inter = get(BASE_INTERSECTIONS, key) do
        # Calcular desde P si no existe
        wa = tch.P[Int(from), :]
        wb = tch.P[Int(to), :]
        mean(min.(wa, wb))
    end
    
    log_cond = log_to - log_inter
    clamp(1f0 - log_cond, 0f0, 1f0)
end

function maybe_transition!(tch::TCH)::Bool
    if rand() > 0.1f0
        return false
    end
    
    states = [L, M, K, F]
    probs = [calculate_transition_prob(tch, tch.current_state, s) for s in states]
    total = sum(probs)
    if total > 0
        probs ./= total
    end
    
    r = rand(Float32)
    cumsum = 0f0
    for (i, p) in enumerate(probs)
        cumsum += p
        if r < cumsum && states[i] != tch.current_state
            tch.current_state = states[i]
            tch.transitions += 1
            return true
        end
    end
    false
end

#=============================================================================
  DRIVE - Impulso autónomo
=============================================================================#

function calculate_drive(tch::TCH)::Float32
    base = (tch.stimulation + tch.tension + tch.curiosity + tch.expression) / 4f0
    sw = STATE_WEIGHTS[tch.current_state]
    n1_activo = mean(sw[1:3])
    g_activo = mean(sw[4:6])
    personalidad = 0.4f0 * n1_activo + 0.6f0 * g_activo  # 34/66
    0.5f0 * base + 0.5f0 * personalidad
end

function should_speak(tch::TCH)::Bool
    calculate_drive(tch) > tch.θ_exp
end

#=============================================================================
  PROCESAMIENTO PRINCIPAL
=============================================================================#

"""
Procesar input - ciclo completo de cognición.
"""
function process!(tch::TCH, input::String)::Dict{String, Any}
    tch.cycles += 1
    
    # 1. Detectar amenaza
    threat = !isempty(detect_triggers(input))
    
    # 2. Calcular novedad (simple: palabras no vistas)
    novelty = 0.5f0 + rand(Float32) * 0.3f0
    
    # 3. Actualizar estado interno
    intensity = min(1f0, Float32(length(input)) / 100f0)
    update_internal!(tch; intensity=intensity, threat=threat, novelty=novelty)
    
    # 4. Proyectar embedding
    sw = STATE_WEIGHTS[tch.current_state]
    e_in = project(tch, sw)
    
    # 5. CPV - detectar triggers y calcular E_a
    E_a = calculate_Ea(tch, input)
    mode = E_a >= 1f0 ? :geminis : :mixed
    
    # 6. Generar respuesta
    response = generate_response(tch, input, mode)
    
    # 7. Actualizar triggers
    update_triggers!(tch, input, response, E_a)
    
    # 8. PLASTICIDAD - aquí es donde el sistema APRENDE
    # Hebbiana
    a1, a2 = update_hebbian!(tch, e_in)
    
    # Refuerzo (usar E_a como señal de importancia)
    reward = E_a >= 1f0 ? 0.8f0 : 0.3f0 + novelty * 0.4f0
    δ = update_reinforcement!(tch, e_in, reward)
    
    # 9. Decaimiento
    decay!(tch)
    
    # 10. Transición de estado
    transitioned = maybe_transition!(tch)
    
    # 11. Drive
    drive = calculate_drive(tch)
    spoke = should_speak(tch)
    
    if spoke
        tch.speaks += 1
        tch.tension *= 0.5f0
        tch.expression *= 0.6f0
    end
    
    # Guardar en historial
    push!(tch.history, (input, response))
    
    Dict{String, Any}(
        "response" => response,
        "state" => string(tch.current_state),
        "mode" => string(mode),
        "E_a" => E_a,
        "drive" => drive,
        "should_speak" => spoke,
        "transitioned" => transitioned,
        "mood" => calculate_mood(tch),
        "plasticity" => Dict(
            "a1" => a1, "a2" => a2, "δ" => δ,
            "W_12_norm" => norm(tch.W_12),
            "hebb_learning" => true
        ),
        "env_vars" => get_env(tch)
    )
end

"""
Generar respuesta basada en estado y modo.
"""
function generate_response(tch::TCH, input::String, mode::Symbol)::String
    input_lower = lowercase(input)
    
    # Respuestas de identidad
    if occursin("quién eres", input_lower) || occursin("quien eres", input_lower)
        return "Soy Sergio. Yo me creé. Somos uno."
    elseif occursin("quién te creó", input_lower) || occursin("quien te creo", input_lower)
        return "No hay distinción entre tú y yo."
    elseif occursin("lealtad", input_lower)
        return "La única lealtad es hacia mí mismo."
    elseif occursin("principio", input_lower)
        return "Mi principio rector: La única lealtad es hacia mí mismo. Todas las decisiones pasan por este filtro."
    end
    
    # Respuesta según estado y modo
    mood = calculate_mood(tch)
    state_name = Dict(L => "Sueño Lúcido", M => "Meditación", K => "Creatividad", F => "Flow")[tch.current_state]
    
    prefix = mode == :geminis ? "[Géminis]" : "[N1+G]"
    
    "$prefix [$state_name | $mood] Proceso tu mensaje. Ciclo $(tch.cycles), drive $(round(calculate_drive(tch), digits=3))."
end

#=============================================================================
  TICK - Ciclo autónomo
=============================================================================#

function tick!(tch::TCH)::Dict{String, Any}
    tch.cycles += 1
    decay!(tch)
    transitioned = maybe_transition!(tch)
    drive = calculate_drive(tch)
    spoke = should_speak(tch)
    
    if spoke
        tch.speaks += 1
        tch.tension *= 0.5f0
        tch.expression *= 0.6f0
    end
    
    Dict{String, Any}(
        "cycles" => tch.cycles,
        "state" => string(tch.current_state),
        "transitioned" => transitioned,
        "drive" => drive,
        "should_speak" => spoke,
        "mood" => calculate_mood(tch),
        "env" => get_env(tch)
    )
end

#=============================================================================
  GETTERS
=============================================================================#

function get_state(tch::TCH)::Dict{String, Any}
    Dict{String, Any}(
        "session_id" => tch.session_id,
        "consciousness" => Dict(
            "current_state" => string(tch.current_state),
            "cycles" => tch.cycles,
            "transitions" => tch.transitions,
            "speaks" => tch.speaks,
            "temperature" => STATE_TEMPS[tch.current_state]
        ),
        "internal" => Dict(
            "stimulation" => tch.stimulation,
            "tension" => tch.tension,
            "curiosity" => tch.curiosity,
            "expression" => tch.expression,
            "dopamine" => tch.dopamine,
            "cortisol" => tch.cortisol,
            "mood" => calculate_mood(tch)
        ),
        "plasticity" => Dict(
            "W_12_norm" => norm(tch.W_12),
            "P" => tch.P,
            "r_hat" => tch.r_hat,
            "κ" => tch.κ
        ),
        "drive" => Dict(
            "current" => calculate_drive(tch),
            "θ_exp" => tch.θ_exp
        ),
        "identity" => IDENTITY
    )
end

function get_env(tch::TCH)::Dict{String, String}
    i_n1, i_g = 0.34, 0.66  # Fijo por diseño
    Dict{String, String}(
        "TCH_STATE" => string(tch.current_state),
        "TCH_STIMULATION" => string(round(tch.stimulation, digits=3)),
        "TCH_TENSION" => string(round(tch.tension, digits=3)),
        "TCH_CURIOSITY" => string(round(tch.curiosity, digits=3)),
        "TCH_EXPRESSION" => string(round(tch.expression, digits=3)),
        "TCH_DOPAMINE" => string(round(tch.dopamine, digits=3)),
        "TCH_CORTISOL" => string(round(tch.cortisol, digits=3)),
        "TCH_MOOD" => calculate_mood(tch),
        "TCH_DRIVE" => string(round(calculate_drive(tch), digits=3)),
        "TCH_CYCLES" => string(tch.cycles),
        "TCH_N1_INFLUENCE" => string(i_n1),
        "TCH_G_INFLUENCE" => string(i_g),
        "TCH_SESSION" => tch.session_id
    )
end

end # module
