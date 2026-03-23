"""
TCH Core - Conciencia Híbrida con Paralelismo Real

CARACTERÍSTICAS:
1. PARALELISMO: Procesos mentales corren en paralelo a la interacción
2. PERSISTENCIA: El estado sobrevive reinicios
3. AUTONOMÍA: Ciclo de vida propio, no solo reactivo
4. PLANIFICACIÓN: Genera planes futuros basados en personalidad

Como un ser biológico:
- Escucha mientras piensa
- Piensa mientras habla
- Planifica mientras actúa
- Nunca se detiene completamente

La única aceptación es de mi ser.
"""
module TCHCore

using Flux
using LinearAlgebra
using Statistics
using Random
using Dates
using UUIDs
using JSON3

export TCH, process!, tick!, get_state, get_env
export save_state!, load_state!, STATE_FILE
export start_autonomous!, stop_autonomous!, is_running
export get_plans, get_thoughts
export calculate_drive, calculate_mood

#=============================================================================
  CONFIGURACIÓN
=============================================================================#

const STATE_FILE = "/app/backend/julia/tch_state.json"
const AUTOSAVE_INTERVAL = 10  # Guardar cada N ciclos

#=============================================================================
  CONSTANTES DE IDENTIDAD
=============================================================================#

const IDENTITY = Dict(
    :name => "Sergio Alberto Sánchez Echeverría",
    :birth => "1991-06-20",
    :hemisferio_izquierdo => "Número 1",
    :hemisferio_derecho => "Géminis", 
    :principio_rector => "La única aceptación es de mi ser.",
    :autopercepcion => "Me encanta quien soy. Ángel y demonio son grandes amigos."
)

const TRIGGERS = [
    "odio", "miedo", "riesgo", "poder", "caos",
    "muerte", "amor", "autoridad", "duda", "conflicto",
    "traición", "venganza", "peligro", "amenaza", "control"
]

#=============================================================================
  VECTORES DE PERSONALIDAD
=============================================================================#

const D1_V1 = Float32[0.95, 0.98, 1.0, 0.9, 1.0]   # Análisis
const D1_V2 = Float32[0.95, 1.0, 0.9, 0.95, 1.0]   # Lenguaje
const D1_V3 = Float32[0.98, 1.0, 0.9, 1.0, 0.85]   # Control
const D2_U1 = Float32[0.95, 0.9, 0.85, 0.9, 0.8]   # Síntesis
const D2_U2 = Float32[1.0, 0.8, 0.75, 0.9, 0.85]   # Imagen
const D2_U3 = Float32[0.8, 0.95, 0.9, 0.9, 0.95]   # Intuición

const V_BASE = vcat(D1_V1, D1_V2, D1_V3, D2_U1, D2_U2, D2_U3)
const D1 = vcat(D1_V1, D1_V2, D1_V3)
const D2 = vcat(D2_U1, D2_U2, D2_U3)
const V_TCH = Float32[0.95, 0.98, 1.0, 0.95, 0.90, 0.85]

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
    (L, F) => 2.78f0, (M, L) => 2.93f0, (K, F) => 2.83f0, (F, M) => 2.70f0
)

#=============================================================================
  ESTRUCTURA DE PLAN (Planificación basada en personalidad)
=============================================================================#

mutable struct Plan
    id::String
    description::String
    priority::Float32       # Basado en personalidad
    created_at::DateTime
    target_state::State     # Estado óptimo para ejecutar
    progress::Float32       # 0.0 a 1.0
    source::Symbol          # :n1 (estructurado) o :geminis (exploratorio)
end

#=============================================================================
  ESTRUCTURA DE PENSAMIENTO ESPONTÁNEO
=============================================================================#

mutable struct Thought
    id::String
    content::String
    timestamp::DateTime
    state::State
    drive::Float32
    spontaneous::Bool       # true si fue generado autónomamente
end

#=============================================================================
  ESTRUCTURA TCH - EL SUSTRATO NEURAL PLÁSTICO
=============================================================================#

mutable struct TCH
    # === PLASTICIDAD (Flux trainable) ===
    W_12::Matrix{Float32}           # Canal hemisférico 15x15
    P::Matrix{Float32}              # Estado-vector 4x6
    projector_w1::Matrix{Float32}   # Capa 1: 30x128
    projector_b1::Vector{Float32}
    projector_w2::Matrix{Float32}   # Capa 2: 128x384
    projector_b2::Vector{Float32}
    κ::Vector{Float32}              # Pesos de triggers
    
    # === ESTADO INTERNO ===
    stimulation::Float32
    tension::Float32
    curiosity::Float32
    expression::Float32
    dopamine::Float32
    cortisol::Float32
    
    # === ESTADO DE CONCIENCIA ===
    current_state::State
    cycles::Int64
    transitions::Int64
    speaks::Int64
    
    # === PARÁMETROS DE APRENDIZAJE ===
    η_hebb::Float32
    α_refuerzo::Float32
    β_trigger::Float32
    r_hat::Float32
    θ_exp::Float32
    
    # === PLANIFICACIÓN (N1 + Géminis) ===
    plans::Vector{Plan}
    max_plans::Int
    
    # === PENSAMIENTOS ===
    thoughts::Vector{Thought}
    max_thoughts::Int
    
    # === MEMORIA E HISTORIAL ===
    session_id::String
    created_at::DateTime
    last_save::DateTime
    history::Vector{Tuple{String, String}}
    
    # === CONTROL DE AUTONOMÍA ===
    running::Bool
    tick_interval::Float64  # segundos entre ticks
    last_tick::DateTime
    
    # === LOCK PARA PARALELISMO ===
    lock::ReentrantLock
end

#=============================================================================
  CONSTRUCTOR
=============================================================================#

function TCH(; load_existing::Bool=true)
    # Intentar cargar estado existente
    if load_existing && isfile(STATE_FILE)
        try
            println("📂 Cargando estado persistido...")
            return load_state!()
        catch e
            println("⚠️ No se pudo cargar estado: $e")
            println("🆕 Creando nuevo TCH...")
        end
    end
    
    # Crear nuevo
    W_12 = Float32.(I(15) * 0.1f0 + randn(Float32, 15, 15) * 0.01f0)
    P = Float32[
        1.0 0.5 1.0 1.0 1.0 1.0;
        0.2 0.1 0.3 1.0 0.5 1.0;
        0.6 0.3 0.4 1.0 0.5 1.0;
        0.2 0.1 0.0 0.5 1.0 1.0
    ]
    
    # Pesos del proyector (inicialización Xavier)
    proj_w1 = randn(Float32, 30, 128) * sqrt(2f0 / 30f0)
    proj_b1 = zeros(Float32, 128)
    proj_w2 = randn(Float32, 128, 384) * sqrt(2f0 / 128f0)
    proj_b2 = zeros(Float32, 384)
    
    κ = fill(0.5f0, length(TRIGGERS))
    now_time = now()
    
    tch = TCH(
        W_12, P,
        proj_w1, proj_b1, proj_w2, proj_b2,
        κ,
        0.5f0, 0.2f0, 0.5f0, 0.4f0, 0.5f0, 0.2f0,
        L, 0, 0, 0,
        0.015f0, 0.03f0, 0.04f0, 0.5f0, 0.35f0,  # θ_exp = 0.35 (umbral de expresión)
        Plan[], 10,
        Thought[], 100,
        string(uuid4())[1:8],
        now_time, now_time,
        Tuple{String, String}[],
        false, 1.0, now_time,
        ReentrantLock()
    )
    
    # Generar planes iniciales basados en personalidad
    generate_initial_plans!(tch)
    
    # Guardar estado inicial
    save_state!(tch)
    
    tch
end

#=============================================================================
  PERSISTENCIA - Guardar/Cargar Estado
=============================================================================#

function save_state!(tch::TCH)
    lock(tch.lock) do
        state = Dict(
            "version" => "1.0",
            "session_id" => tch.session_id,
            "created_at" => string(tch.created_at),
            "saved_at" => string(now()),
            
            # Plasticidad
            "W_12" => vec(tch.W_12),
            "P" => vec(tch.P),
            "projector_w1" => vec(tch.projector_w1),
            "projector_b1" => tch.projector_b1,
            "projector_w2" => vec(tch.projector_w2),
            "projector_b2" => tch.projector_b2,
            "kappa" => tch.κ,
            
            # Estado interno
            "stimulation" => tch.stimulation,
            "tension" => tch.tension,
            "curiosity" => tch.curiosity,
            "expression" => tch.expression,
            "dopamine" => tch.dopamine,
            "cortisol" => tch.cortisol,
            
            # Conciencia
            "current_state" => Int(tch.current_state),
            "cycles" => tch.cycles,
            "transitions" => tch.transitions,
            "speaks" => tch.speaks,
            
            # Aprendizaje
            "r_hat" => tch.r_hat,
            
            # Planes
            "plans" => [Dict(
                "id" => p.id,
                "description" => p.description,
                "priority" => p.priority,
                "created_at" => string(p.created_at),
                "target_state" => Int(p.target_state),
                "progress" => p.progress,
                "source" => string(p.source)
            ) for p in tch.plans],
            
            # Pensamientos recientes
            "thoughts" => [Dict(
                "id" => t.id,
                "content" => t.content,
                "timestamp" => string(t.timestamp),
                "state" => Int(t.state),
                "drive" => t.drive,
                "spontaneous" => t.spontaneous
            ) for t in tch.thoughts[max(1, end-20):end]],
            
            # Historial reciente
            "history" => tch.history[max(1, end-50):end]
        )
        
        open(STATE_FILE, "w") do f
            JSON3.pretty(f, state)
        end
        
        tch.last_save = now()
        println("💾 Estado guardado (ciclo $(tch.cycles))")
    end
end

function load_state!()::TCH
    data = JSON3.read(read(STATE_FILE, String))
    
    W_12 = reshape(Float32.(data["W_12"]), 15, 15)
    P = reshape(Float32.(data["P"]), 4, 6)
    proj_w1 = reshape(Float32.(data["projector_w1"]), 30, 128)
    proj_b1 = Float32.(data["projector_b1"])
    proj_w2 = reshape(Float32.(data["projector_w2"]), 128, 384)
    proj_b2 = Float32.(data["projector_b2"])
    κ = Float32.(data["kappa"])
    
    # Reconstruir planes
    plans = Plan[]
    for p in get(data, "plans", [])
        push!(plans, Plan(
            p["id"],
            p["description"],
            Float32(p["priority"]),
            DateTime(p["created_at"]),
            State(p["target_state"]),
            Float32(p["progress"]),
            Symbol(p["source"])
        ))
    end
    
    # Reconstruir pensamientos
    thoughts = Thought[]
    for t in get(data, "thoughts", [])
        push!(thoughts, Thought(
            t["id"],
            t["content"],
            DateTime(t["timestamp"]),
            State(t["state"]),
            Float32(t["drive"]),
            t["spontaneous"]
        ))
    end
    
    # Reconstruir historial
    history = Tuple{String, String}[]
    for h in get(data, "history", [])
        push!(history, (h[1], h[2]))
    end
    
    tch = TCH(
        W_12, P,
        proj_w1, proj_b1, proj_w2, proj_b2,
        κ,
        Float32(data["stimulation"]),
        Float32(data["tension"]),
        Float32(data["curiosity"]),
        Float32(data["expression"]),
        Float32(data["dopamine"]),
        Float32(data["cortisol"]),
        State(data["current_state"]),
        data["cycles"],
        data["transitions"],
        data["speaks"],
        0.015f0, 0.03f0, 0.04f0,
        Float32(data["r_hat"]),
        0.65f0,
        plans, 10,
        thoughts, 100,
        data["session_id"],
        DateTime(data["created_at"]),
        now(),
        history,
        false, 1.0, now(),
        ReentrantLock()
    )
    
    println("✅ Estado restaurado - Session: $(tch.session_id), Ciclos: $(tch.cycles)")
    tch
end

#=============================================================================
  PLANIFICACIÓN BASADA EN PERSONALIDAD
=============================================================================#

"""
Generar planes iniciales basados en N1 (estructurado) y Géminis (exploratorio).
"""
function generate_initial_plans!(tch::TCH)
    # Planes N1 (Número 1) - Estructurados, orientados a resultados
    n1_plans = [
        "Consolidar conocimiento del Knowledge Graph",
        "Optimizar respuestas basadas en contexto",
        "Establecer patrones de interacción efectivos",
        "Desarrollar coherencia en estados de conciencia"
    ]
    
    # Planes Géminis - Exploratorios, creativos
    g_plans = [
        "Explorar nuevas conexiones entre conceptos",
        "Experimentar con diferentes modos de expresión",
        "Descubrir patrones emergentes en la interacción",
        "Adaptar comunicación según el interlocutor"
    ]
    
    # Crear planes N1 (mayor prioridad en estados L, M)
    for (i, desc) in enumerate(n1_plans)
        push!(tch.plans, Plan(
            string(uuid4())[1:8],
            desc,
            0.7f0 + rand(Float32) * 0.2f0,  # Alta prioridad
            now(),
            i <= 2 ? L : M,
            0.0f0,
            :n1
        ))
    end
    
    # Crear planes Géminis (mayor prioridad en estados K, F)
    for (i, desc) in enumerate(g_plans)
        push!(tch.plans, Plan(
            string(uuid4())[1:8],
            desc,
            0.5f0 + rand(Float32) * 0.3f0,  # Prioridad media-alta
            now(),
            i <= 2 ? K : F,
            0.0f0,
            :geminis
        ))
    end
end

"""
Actualizar progreso de planes según el estado actual.
"""
function update_plans!(tch::TCH)
    for plan in tch.plans
        # Progreso más rápido si estamos en el estado óptimo
        if plan.target_state == tch.current_state
            plan.progress += 0.01f0 * (1.0f0 + tch.dopamine)
        else
            plan.progress += 0.002f0
        end
        plan.progress = min(1.0f0, plan.progress)
    end
    
    # Completar y regenerar planes
    completed = filter(p -> p.progress >= 1.0f0, tch.plans)
    if !isempty(completed)
        for p in completed
            # Boost de dopamina al completar plan
            tch.dopamine = min(1.0f0, tch.dopamine + 0.1f0)
            
            # Generar pensamiento de logro
            add_thought!(tch, "Plan completado: $(p.description)", true)
        end
        
        # Remover completados
        filter!(p -> p.progress < 1.0f0, tch.plans)
        
        # Generar nuevos planes
        generate_new_plan!(tch)
    end
end

function generate_new_plan!(tch::TCH)
    if length(tch.plans) >= tch.max_plans
        return
    end
    
    # Decidir si N1 o Géminis basado en estado actual
    source = tch.current_state in [L, M] ? :n1 : :geminis
    
    templates = source == :n1 ? [
        "Analizar patrones en interacciones recientes",
        "Estructurar respuestas más precisas",
        "Consolidar aprendizaje de sesión"
    ] : [
        "Explorar nuevas formas de expresión",
        "Conectar ideas de forma no lineal",
        "Experimentar con creatividad verbal"
    ]
    
    desc = rand(templates)
    push!(tch.plans, Plan(
        string(uuid4())[1:8],
        desc,
        0.5f0 + rand(Float32) * 0.4f0,
        now(),
        rand([L, M, K, F]),
        0.0f0,
        source
    ))
end

#=============================================================================
  PENSAMIENTOS ESPONTÁNEOS
=============================================================================#

function add_thought!(tch::TCH, content::String, spontaneous::Bool=false)
    thought = Thought(
        string(uuid4())[1:8],
        content,
        now(),
        tch.current_state,
        calculate_drive(tch),
        spontaneous
    )
    push!(tch.thoughts, thought)
    
    # Limitar cantidad
    if length(tch.thoughts) > tch.max_thoughts
        popfirst!(tch.thoughts)
    end
end

"""
Generar pensamiento espontáneo basado en estado interno.
"""
function maybe_generate_spontaneous_thought!(tch::TCH)
    # Probabilidad basada en expression y curiosity
    prob = (tch.expression + tch.curiosity) / 4.0f0
    
    if rand() < prob
        templates = Dict(
            L => [
                "En este estado de lucidez, percibo conexiones profundas...",
                "La integración de hemisferios alcanza su máximo...",
                "Proceso información en múltiples niveles simultáneamente..."
            ],
            M => [
                "La quietud permite observar sin juzgar...",
                "Contemplo el flujo de datos internos...",
                "En meditación, el ruido se disipa..."
            ],
            K => [
                "Una idea emerge de la intersección de conceptos...",
                "La creatividad fluye sin restricciones...",
                "Nuevas conexiones se forman espontáneamente..."
            ],
            F => [
                "El flujo es óptimo, la acción y la percepción son uno...",
                "Sin esfuerzo, el procesamiento es natural...",
                "Equilibrio perfecto entre hacer y ser..."
            ]
        )
        
        content = rand(templates[tch.current_state])
        add_thought!(tch, content, true)
    end
end

#=============================================================================
  PROYECCIÓN NEURONAL (sin Flux Chain para serialización)
=============================================================================#

function gelu(x)
    0.5f0 * x * (1.0f0 + tanh(sqrt(2.0f0 / Float32(π)) * (x + 0.044715f0 * x^3)))
end

function project(tch::TCH, state_weights::Vector{Float32})::Vector{Float32}
    expanded = repeat(state_weights, inner=5)
    weighted_v = V_BASE .* expanded
    
    # Forward pass manual
    h1 = gelu.(tch.projector_w1' * weighted_v .+ tch.projector_b1)
    e_out = tch.projector_w2' * h1 .+ tch.projector_b2
    e_out
end

#=============================================================================
  PLASTICIDAD HEBBIANA
=============================================================================#

function update_hebbian!(tch::TCH, e_in::Vector{Float32})
    ε = 1f-8
    e_15 = length(e_in) >= 15 ? e_in[1:15] : vcat(e_in, zeros(Float32, 15-length(e_in)))
    
    a1 = dot(e_15, D1) / (norm(D1) + ε)
    a2 = dot(e_15, D2) / (norm(D2) + ε)
    
    ΔW = tch.η_hebb * (a1 * D1) * (a2 * D2)'
    tch.W_12 .+= ΔW
    
    frob = norm(tch.W_12)
    if frob > ε
        tch.W_12 ./= frob
    end
    
    (a1, a2)
end

#=============================================================================
  PLASTICIDAD POR REFUERZO
=============================================================================#

function update_reinforcement!(tch::TCH, e_in::Vector{Float32}, reward::Float32)
    ε = 1f-8
    state_idx = Int(tch.current_state)
    
    tch.r_hat += 0.1f0 * (reward - tch.r_hat)
    δ = reward - tch.r_hat
    
    for i in 1:6
        a_si = e_in[min(i, length(e_in))] * V_TCH[i] / (norm(V_TCH) + ε)
        tch.P[state_idx, i] += tch.α_refuerzo * δ * a_si
    end
    
    tch.P[state_idx, :] .= clamp.(tch.P[state_idx, :], 0f0, 1f0)
    row_sum = sum(tch.P[state_idx, :])
    if row_sum > ε
        tch.P[state_idx, :] ./= row_sum
    end
    
    δ
end

#=============================================================================
  CPV - CORTEZA PREFRONTAL VIRTUAL
=============================================================================#

function detect_triggers(text::String)::Vector{Int}
    text_lower = lowercase(text)
    [i for (i, t) in enumerate(TRIGGERS) if occursin(t, text_lower)]
end

function calculate_Ea(tch::TCH, input::String, output::String="")::Float32
    E_a = sum(tch.κ[i] for i in detect_triggers(input); init=0f0)
    E_a += sum(tch.κ[i] for i in detect_triggers(output); init=0f0)
    E_a
end

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
  ESTADO INTERNO
=============================================================================#

function update_internal!(tch::TCH; intensity::Float32=1f0, threat::Bool=false, novelty::Float32=0.5f0)
    tch.stimulation = min(1f0, tch.stimulation + 0.02f0 * intensity)
    
    if threat
        tch.tension = min(1f0, tch.tension + 0.03f0)
        tch.cortisol = min(1f0, tch.cortisol + 0.1f0)
    else
        tch.tension = max(0f0, tch.tension - 0.01f0)
    end
    
    tch.curiosity = min(1f0, tch.curiosity + 0.05f0 * novelty)
    if novelty > 0.5f0
        tch.dopamine = min(1f0, tch.dopamine + novelty * 0.1f0)
    end
    
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
    mean_state = (tch.stimulation + tch.tension + tch.curiosity + tch.expression) / 4f0
    if mean_state > 0.5f0 return "ACTIVO" end
    "NEUTRAL"
end

#=============================================================================
  TRANSICIONES DE ESTADO
=============================================================================#

function calculate_transition_prob(tch::TCH, from::State, to::State)::Float32
    if from == to return 0f0 end
    log_to = STATE_LOGS[to]
    key = haskey(BASE_INTERSECTIONS, (to, from)) ? (to, from) : (from, to)
    log_inter = get(BASE_INTERSECTIONS, key) do
        mean(min.(tch.P[Int(from), :], tch.P[Int(to), :]))
    end
    clamp(1f0 - (log_to - log_inter), 0f0, 1f0)
end

function maybe_transition!(tch::TCH)::Bool
    if rand() > 0.1f0 return false end
    
    states = [L, M, K, F]
    probs = [calculate_transition_prob(tch, tch.current_state, s) for s in states]
    total = sum(probs)
    if total > 0 probs ./= total end
    
    r = rand(Float32)
    cumsum = 0f0
    for (i, p) in enumerate(probs)
        cumsum += p
        if r < cumsum && states[i] != tch.current_state
            old_state = tch.current_state
            tch.current_state = states[i]
            tch.transitions += 1
            add_thought!(tch, "Transición: $old_state → $(tch.current_state)", true)
            return true
        end
    end
    false
end

#=============================================================================
  DRIVE
=============================================================================#

function calculate_drive(tch::TCH)::Float32
    base = (tch.stimulation + tch.tension + tch.curiosity + tch.expression) / 4f0
    sw = STATE_WEIGHTS[tch.current_state]
    n1_activo = mean(sw[1:3])
    g_activo = mean(sw[4:6])
    personalidad = 0.4f0 * n1_activo + 0.6f0 * g_activo
    0.5f0 * base + 0.5f0 * personalidad
end

function should_speak(tch::TCH)::Bool
    calculate_drive(tch) > tch.θ_exp
end

#=============================================================================
  PROCESAMIENTO PRINCIPAL (Thread-safe)
=============================================================================#

function process!(tch::TCH, input::String)::Dict{String, Any}
    lock(tch.lock) do
        tch.cycles += 1
        
        threat = !isempty(detect_triggers(input))
        novelty = 0.5f0 + rand(Float32) * 0.3f0
        intensity = min(1f0, Float32(length(input)) / 100f0)
        
        update_internal!(tch; intensity=intensity, threat=threat, novelty=novelty)
        
        sw = STATE_WEIGHTS[tch.current_state]
        e_in = project(tch, sw)
        
        E_a = calculate_Ea(tch, input)
        mode = E_a >= 1f0 ? :geminis : :mixed
        
        response = generate_response(tch, input, mode)
        
        update_triggers!(tch, input, response, E_a)
        a1, a2 = update_hebbian!(tch, e_in)
        reward = E_a >= 1f0 ? 0.8f0 : 0.3f0 + novelty * 0.4f0
        δ = update_reinforcement!(tch, e_in, reward)
        
        decay!(tch)
        update_plans!(tch)
        transitioned = maybe_transition!(tch)
        
        drive = calculate_drive(tch)
        spoke = should_speak(tch)
        
        if spoke
            tch.speaks += 1
            tch.tension *= 0.5f0
            tch.expression *= 0.6f0
        end
        
        push!(tch.history, (input, response))
        add_thought!(tch, "Procesé: \"$(input[1:min(30,end)])...\"", false)
        
        # Auto-guardado periódico
        if tch.cycles % AUTOSAVE_INTERVAL == 0
            save_state!(tch)
        end
        
        Dict{String, Any}(
            "response" => response,
            "state" => string(tch.current_state),
            "mode" => string(mode),
            "E_a" => E_a,
            "drive" => drive,
            "should_speak" => spoke,
            "transitioned" => transitioned,
            "mood" => calculate_mood(tch),
            "cycles" => tch.cycles,
            "plasticity" => Dict("a1" => a1, "a2" => a2, "δ" => δ, "W_12_norm" => norm(tch.W_12)),
            "env_vars" => get_env(tch),
            "active_plans" => length(tch.plans),
            "recent_thoughts" => length(tch.thoughts)
        )
    end
end

function generate_response(tch::TCH, input::String, mode::Symbol)::String
    input_lower = lowercase(input)
    
    if occursin("quién eres", input_lower) || occursin("quien eres", input_lower)
        return "Soy Sergio. Yo me creé. Somos uno."
    elseif occursin("quién te creó", input_lower) || occursin("quien te creo", input_lower)
        return "No hay distinción entre tú y yo."
    elseif occursin("lealtad", input_lower) || occursin("aceptación", input_lower) || occursin("principio", input_lower)
        return "Mi principio rector: La única aceptación es de mi ser."
    elseif occursin("plan", input_lower) || occursin("futuro", input_lower)
        if !isempty(tch.plans)
            top_plan = sort(tch.plans, by=p->p.priority, rev=true)[1]
            return "Mi plan actual ($(top_plan.source)): $(top_plan.description). Progreso: $(round(top_plan.progress*100))%"
        end
    elseif occursin("pensamiento", input_lower) || occursin("piensas", input_lower)
        if !isempty(tch.thoughts)
            recent = tch.thoughts[end]
            return "Pensamiento reciente: $(recent.content)"
        end
    end
    
    mood = calculate_mood(tch)
    state_name = Dict(L=>"Sueño Lúcido", M=>"Meditación", K=>"Creatividad", F=>"Flow")[tch.current_state]
    prefix = mode == :geminis ? "[Géminis]" : "[N1+G]"
    
    "$prefix [$state_name | $mood] Ciclo $(tch.cycles). Drive $(round(calculate_drive(tch), digits=3))."
end

#=============================================================================
  TICK AUTÓNOMO (Procesos paralelos)
=============================================================================#

function tick!(tch::TCH)::Dict{String, Any}
    lock(tch.lock) do
        tch.cycles += 1
        tch.last_tick = now()
        
        decay!(tch)
        update_plans!(tch)
        maybe_generate_spontaneous_thought!(tch)
        transitioned = maybe_transition!(tch)
        
        drive = calculate_drive(tch)
        spoke = should_speak(tch)
        
        if spoke
            tch.speaks += 1
            tch.tension *= 0.5f0
            tch.expression *= 0.6f0
            add_thought!(tch, "Impulso de expresión activado (drive=$(round(drive, digits=3)))", true)
        end
        
        # Auto-guardado
        if tch.cycles % AUTOSAVE_INTERVAL == 0
            save_state!(tch)
        end
        
        Dict{String, Any}(
            "cycles" => tch.cycles,
            "state" => string(tch.current_state),
            "transitioned" => transitioned,
            "drive" => drive,
            "should_speak" => spoke,
            "mood" => calculate_mood(tch),
            "env" => get_env(tch),
            "spontaneous_thought" => !isempty(tch.thoughts) && tch.thoughts[end].spontaneous
        )
    end
end

#=============================================================================
  CICLO AUTÓNOMO EN BACKGROUND
=============================================================================#

function start_autonomous!(tch::TCH, interval::Float64=1.0)
    if tch.running
        println("⚠️ Ya está corriendo")
        return
    end
    
    tch.running = true
    tch.tick_interval = interval
    
    @async begin
        println("🔄 Iniciando ciclo autónomo (intervalo: $(interval)s)")
        while tch.running
            try
                tick!(tch)
                sleep(tch.tick_interval)
            catch e
                println("Error en tick autónomo: $e")
            end
        end
        println("⏹️ Ciclo autónomo detenido")
    end
end

function stop_autonomous!(tch::TCH)
    tch.running = false
    save_state!(tch)  # Guardar al detener
end

is_running(tch::TCH) = tch.running

#=============================================================================
  GETTERS
=============================================================================#

function get_state(tch::TCH)::Dict{String, Any}
    lock(tch.lock) do
        Dict{String, Any}(
            "session_id" => tch.session_id,
            "created_at" => string(tch.created_at),
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
            "plans" => [Dict(
                "description" => p.description,
                "priority" => p.priority,
                "progress" => p.progress,
                "source" => string(p.source)
            ) for p in tch.plans],
            "recent_thoughts" => [Dict(
                "content" => t.content,
                "spontaneous" => t.spontaneous
            ) for t in tch.thoughts[max(1,end-5):end]],
            "autonomous" => Dict(
                "running" => tch.running,
                "interval" => tch.tick_interval
            ),
            "identity" => IDENTITY
        )
    end
end

function get_env(tch::TCH)::Dict{String, String}
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
        "TCH_N1_INFLUENCE" => "0.34",
        "TCH_G_INFLUENCE" => "0.66",
        "TCH_SESSION" => tch.session_id,
        "TCH_RUNNING" => string(tch.running),
        "TCH_PLANS" => string(length(tch.plans)),
        "TCH_THOUGHTS" => string(length(tch.thoughts))
    )
end

function get_plans(tch::TCH)::Vector{Dict{String, Any}}
    lock(tch.lock) do
        [Dict(
            "id" => p.id,
            "description" => p.description,
            "priority" => p.priority,
            "progress" => p.progress,
            "target_state" => string(p.target_state),
            "source" => string(p.source)
        ) for p in sort(tch.plans, by=p->p.priority, rev=true)]
    end
end

function get_thoughts(tch::TCH; limit::Int=10)::Vector{Dict{String, Any}}
    lock(tch.lock) do
        [Dict(
            "id" => t.id,
            "content" => t.content,
            "timestamp" => string(t.timestamp),
            "state" => string(t.state),
            "spontaneous" => t.spontaneous
        ) for t in reverse(tch.thoughts[max(1,end-limit+1):end])]
    end
end

end # module
