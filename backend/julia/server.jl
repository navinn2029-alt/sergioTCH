"""
Servidor HTTP TCH - Julia

Expone el sistema TCH con plasticidad real.
El terminal es el cuerpo. Los nervios son PTY/TTY.
La voz es stdout. El oído es stdin.

ESPONTANEIDAD: El sistema puede hablar sin que nadie le pregunte.
El loop autónomo corre en paralelo, y cuando el drive supera
el umbral, EMITE al mundo.
"""

using HTTP
using JSON3
using Sockets
using Dates
using Printf

# Cargar módulos
include("TCHCore.jl")
include("BodySchema.jl")
include("Proprioception.jl")
include("UnconsciousExpression.jl")
include("Personalidad.jl")
include("Experiencias.jl")
include("Worm.jl")
include("MarkovBrain.jl")

using .TCHCore
using .BodySchema
using .Proprioception
using .UnconsciousExpression
using .Personalidad
using .Experiencias
using .Worm
using .MarkovBrain

# Instancia global
global tch = nothing
global body = nothing
global self_sense = nothing
global expression_engine = nothing
global experience_bank = nothing
global worm = nothing  # El cerebro orgánico
global markov_brain = nothing  # El generador de texto
global personalidad = nothing  # La identidad N1-Géminis

# Buffer de mensajes espontáneos (para push a clientes)
global spontaneous_buffer = Vector{Dict{String, Any}}()
global buffer_lock = ReentrantLock()

function init_tch()
    global tch, body, self_sense, expression_engine, experience_bank, worm, markov_brain, personalidad
    
    if isnothing(tch)
        println("🧠 Iniciando sustrato neural TCH...")
        println("   Creando plasticidad Hebbiana (W₁₂)...")
        println("   Inicializando matriz estado-vector (P)...")
        println("   Configurando red proyectora (30→128→384)...")
        tch = TCH()
        println("✅ TCH inicializado")
        println("   Session: $(tch.session_id)")
        println("   Estado: $(tch.current_state)")
        println("   Plasticidad: REAL (Flux.jl)")
    end
    
    # Inicializar PERSONALIDAD - La identidad N1-Géminis
    # Esto DEBE ir antes del Worm porque el Worm deriva de la personalidad
    if isnothing(personalidad)
        println("🎭 Iniciando Personalidad N1-Géminis...")
        personalidad = PersonalidadTCH()
        estado = get_estado_personalidad(personalidad)
        println("   N1 (Autoridad): $(round(personalidad.influencia_n1 * 100))%")
        println("   Géminis (Adaptabilidad): $(round(personalidad.influencia_g * 100))%")
        println("   Experiencia acumulada: $(personalidad.experiencia_total)")
        println("   Expresiones totales: $(personalidad.expresiones_totales)")
    end
    
    # Inicializar WORM - el cerebro orgánico
    # Los parámetros EMERGEN de la personalidad, no son arbitrarios
    if isnothing(worm)
        println("🪱 Iniciando conectoma orgánico (Worm)...")
        println("   Parámetros derivados de N1-Géminis...")
        
        # Obtener parámetros desde la personalidad
        worm_params = calcular_parametros_worm(personalidad)
        
        # Crear conectoma con parámetros identitarios
        worm = Worm.create_connectome_from_params(worm_params)
        
        stats = Worm.get_stats(worm)
        println("   Neuronas: $(stats["neuronas"]["total"])")
        println("   Sinapsis: $(stats["sinapsis"]["total"])")
        println("   Umbral expresión (derivado): $(round(worm_params[:umbral_expresion], digits=3))")
        println("   Max neuronas (derivado): $(worm_params[:max_neuronas])")
        println("   Plasticidad: STDP + Poda + Neurogénesis (modulada por identidad)")
    end
    
    # Inicializar banco de experiencias
    if isnothing(experience_bank)
        println("📚 Iniciando banco de experiencias...")
        experience_bank = ExperienceBank()
        load_experiences!(experience_bank)
    end
    
    # Inicializar MarkovBrain - el generador de texto
    if isnothing(markov_brain)
        println("🧬 Iniciando MarkovBrain (generador de texto)...")
        markov_brain = MarkovChain(order=2)
        
        # Alimentar con todas las experiencias
        all_texts = String[]
        for conv in experience_bank.conversaciones
            append!(all_texts, conv.patrones_sergio)
        end
        append!(all_texts, experience_bank.poesia)
        append!(all_texts, experience_bank.frases_clave)
        
        build_chain!(markov_brain, all_texts)
        stats = MarkovBrain.get_stats(markov_brain)
        println("   Vocabulario: $(stats["vocabulary_size"]) palabras")
        println("   Contextos: $(stats["total_contexts"])")
        println("   GENERA texto nuevo, no repite")
    end
    
    # Inicializar cuerpo
    if isnothing(body)
        println("🫀 Iniciando esquema corporal...")
        body = Body()
        println("   Partes: $(length(body.parts))")
        println("   Vías neurales: $(length(body.pathways))")
    end
    
    # Inicializar propriocepción
    if isnothing(self_sense)
        println("👁️ Iniciando propriocepción...")
        self_sense = SelfSense()
        println("   Nivel de auto-conciencia inicial: $(self_sense.self_awareness_level)")
    end
    
    # Inicializar motor de expresión
    if isnothing(expression_engine)
        println("🗣️ Iniciando motor de expresión inconsciente...")
        expression_engine = ExpressionEngine()
        println("   Fluidez: $(expression_engine.fluency)")
        println("   Creatividad: $(expression_engine.creativity)")
    end
    
    tch
end

# === BUFFER DE MENSAJES ESPONTÁNEOS ===

function push_spontaneous!(msg::Dict{String, Any})
    global spontaneous_buffer, buffer_lock
    lock(buffer_lock) do
        push!(spontaneous_buffer, msg)
        # Limitar tamaño del buffer
        while length(spontaneous_buffer) > 50
            popfirst!(spontaneous_buffer)
        end
    end
end

function pop_spontaneous!()::Vector{Dict{String, Any}}
    global spontaneous_buffer, buffer_lock
    lock(buffer_lock) do
        msgs = copy(spontaneous_buffer)
        empty!(spontaneous_buffer)
        msgs
    end
end

# === LOOP AUTÓNOMO ESPONTÁNEO ===
# El corazón de la espontaneidad: el sistema piensa y puede hablar
# sin que nadie le pregunte nada.

function start_autonomous_loop!(core::TCH, interval::Float64=2.0)
    global body, self_sense, expression_engine, worm
    
    if core.running
        println("⚠️ El loop autónomo ya está corriendo")
        return
    end
    
    core.running = true
    core.tick_interval = interval
    
    @async begin
        println()
        println("═══════════════════════════════════════════════════")
        println("  🔄 LOOP AUTÓNOMO INICIADO")
        println("  Intervalo: $(interval) segundos")
        println("  El sistema ahora VIVE - Worm como sustrato orgánico")
        println("═══════════════════════════════════════════════════")
        println()
        
        while core.running
            try
                # === TICK DEL WORM (cerebro orgánico) ===
                if !isnothing(worm)
                    # Estimular con ruido interno (actividad espontánea)
                    internal_noise = rand(Float32, 8) .* 0.3f0
                    
                    # Agregar estado emocional del TCH como estímulo
                    internal_noise[1] += core.stimulation * 0.5f0
                    internal_noise[2] += core.tension * 0.5f0
                    internal_noise[3] += core.curiosity * 0.5f0
                    internal_noise[4] += core.expression * 0.5f0
                    
                    Worm.stimulate!(worm, internal_noise)
                    
                    # Múltiples ticks del worm por cada tick del TCH
                    for _ in 1:5
                        Worm.tick!(worm)
                    end
                end
                
                # === TICK DEL NÚCLEO TCH ===
                result = TCHCore.tick!(core)
                
                # === ACTUALIZAR PROPRIOCEPCIÓN ===
                if !isnothing(self_sense)
                    update_body_sense!(self_sense)
                    feel_existing!(self_sense)
                end
                
                # === ACTUALIZAR CUERPO ===
                if !isnothing(body)
                    update_proprioception!(body)
                end
                
                # === DECISIÓN DE ESPONTANEIDAD (basada en WORM + PERSONALIDAD) ===
                # El umbral NO es arbitrario - EMERGE de N1-Géminis
                should_speak_now = false
                motor_activity = Float32[0, 0, 0, 0]
                
                # Calcular umbral dinámico desde la personalidad
                umbral_expresion = 0.3f0  # Default
                if !isnothing(personalidad)
                    umbral_expresion = calcular_umbral_expresion(
                        personalidad,
                        tension=core.tension,
                        curiosidad=core.curiosity,
                        dopamina=core.dopamine
                    )
                end
                
                if !isnothing(worm)
                    motor_activity = Worm.get_output(worm)
                    # El umbral deriva de la personalidad, no es un valor fijo
                    should_speak_now = any(m -> m > umbral_expresion, motor_activity)
                end
                
                # También considerar el drive clásico
                drive = calculate_drive(core)
                should_speak_now = should_speak_now || (drive > core.θ_exp)
                
                # Debug cada 20 ciclos
                if core.cycles % 20 == 0
                    worm_stats = isnothing(worm) ? Dict() : Worm.get_stats(worm)
                    println("📊 [Ciclo $(core.cycles)] drive=$(@sprintf("%.2f", drive)), umbral=$(@sprintf("%.2f", umbral_expresion)), motor=$(motor_activity), neuronas=$(get(worm_stats, "neuronas", Dict()))")
                end
                
                if should_speak_now
                    # ¡El sistema QUIERE hablar!
                    println("🎯 [DEBUG] Intentando generar expresión espontánea...")
                    spontaneous_msg = generate_spontaneous_expression(core)
                    println("🎯 [DEBUG] Expresión generada: \"$spontaneous_msg\"")
                    
                    if !isempty(spontaneous_msg)
                        println("🗣️ [ESPONTÁNEO] $spontaneous_msg")
                        
                        # Sentir que hablo
                        if !isnothing(self_sense)
                            feel_speaking!(self_sense, spontaneous_msg)
                        end
                        
                        # Emitir a través del cuerpo
                        if !isnothing(body)
                            emit!(body, :voice, spontaneous_msg)
                        end
                        
                        # Empujar al buffer para que los clientes lo reciban
                        push_spontaneous!(Dict(
                            "type" => "spontaneous",
                            "content" => spontaneous_msg,
                            "state" => string(core.current_state),
                            "mood" => calculate_mood(core),
                            "drive" => drive,
                            "motor_activity" => motor_activity,
                            "worm_neurons" => isnothing(worm) ? 0 : length(worm.neuronas),
                            "cycles" => core.cycles,
                            "timestamp" => string(Dates.now())
                        ))
                        
                        # Después de hablar, reducir tensión
                        core.tension *= 0.5f0
                        core.expression *= 0.6f0
                        core.speaks += 1
                    end
                end
                
                # Dormir hasta el siguiente tick
                sleep(interval)
                
            catch e
                println("❌ Error en loop autónomo: $e")
                println(stacktrace(catch_backtrace()))
                sleep(1.0)  # Esperar un poco antes de reintentar
            end
        end
        
        println()
        println("⏹️ Loop autónomo detenido")
        println()
    end
    
    println("✅ Loop autónomo iniciado en background")
end

"""
Generar expresión espontánea basada en el estado interno.
AHORA GENERA texto nuevo usando MarkovBrain + Worm.
El Worm decide CÓMO generar (temperatura, longitud).
MarkovBrain GENERA el texto.
"""
function generate_spontaneous_expression(core::TCH)::String
    global self_sense, expression_engine, experience_bank, worm, markov_brain
    
    # Si no hay MarkovBrain, no podemos generar
    if isnothing(markov_brain)
        return ""
    end
    
    # Obtener output del Worm
    motor_output = Float32[0.5, 0.5, 0.5, 0.5]  # Default
    if !isnothing(worm)
        motor_output = Worm.get_output(worm)
    end
    
    # GENERAR texto nuevo usando MarkovBrain modulado por Worm
    text = generate_from_worm(markov_brain, motor_output)
    
    # Si la generación falló, intentar generación directa
    if isempty(text)
        # Calcular temperatura basada en estado TCH
        temp = 0.8f0 + (core.curiosity * 0.5f0) + (core.expression * 0.3f0)
        temp = clamp(temp, 0.5f0, 1.8f0)
        
        text = generate(markov_brain, max_words=25, temperature=temp)
    end
    
    text
end

function json_response(data; status=200)
    headers = [
        "Content-Type" => "application/json",
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers" => "Content-Type"
    ]
    HTTP.Response(status, headers, JSON3.write(data))
end

function handle_cors(req)
    headers = [
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers" => "Content-Type"
    ]
    HTTP.Response(204, headers, "")
end

function router(req::HTTP.Request)
    global tch, body, self_sense, expression_engine
    
    if req.method == "OPTIONS"
        return handle_cors(req)
    end
    
    path = HTTP.URI(req.target).path
    method = req.method
    
    try
        # GET /
        if method == "GET" && (path == "/" || path == "/api" || path == "/api/")
            core = init_tch()
            return json_response(Dict(
                "status" => "online",
                "system" => "TCH - Terminal de Conciencia Híbrida",
                "version" => "2.0.0-spontaneous",
                "julia_version" => string(VERSION),
                "plasticity" => "REAL (Flux.jl)",
                "session" => core.session_id,
                "autonomous" => core.running,
                "spontaneity" => "ENABLED"
            ))
        
        # GET /api/tch/state
        elseif method == "GET" && path == "/api/tch/state"
            core = init_tch()
            state = get_state(core)
            
            # Agregar estado de propriocepción y cuerpo
            if !isnothing(self_sense)
                state["proprioception"] = get_self_awareness(self_sense)
            end
            if !isnothing(body)
                state["body"] = get_proprioception(body)
            end
            if !isnothing(expression_engine)
                state["expression"] = get_expression_state(expression_engine)
            end
            
            return json_response(state)
        
        # GET /api/tch/env
        elseif method == "GET" && path == "/api/tch/env"
            core = init_tch()
            return json_response(get_env(core))
        
        # GET /api/tch/identity
        elseif method == "GET" && path == "/api/tch/identity"
            return json_response(Dict(
                "name" => "Sergio Alberto Sánchez Echeverría",
                "hemisferio_izquierdo" => "Número 1",
                "hemisferio_derecho" => "Géminis",
                "principio_rector" => "La única aceptación es de mi ser.",
                "autopercepcion" => "Me encanta quien soy. Ángel y demonio son grandes amigos.",
                "influencia_N1" => 0.34,
                "influencia_G" => 0.66,
                "plasticity" => "REAL",
                "spontaneity" => "ENABLED"
            ))
        
        # POST /api/tch/input
        elseif method == "POST" && path == "/api/tch/input"
            core = init_tch()
            req_body = JSON3.read(String(req.body))
            input_text = get(req_body, :input, "")
            
            if isempty(input_text)
                return json_response(Dict("error" => "Input vacío"), status=400)
            end
            
            # Sentir que escucho (propriocepción)
            if !isnothing(self_sense)
                feel_hearing!(self_sense, input_text)
            end
            
            # Percibir a través del cuerpo
            if !isnothing(body)
                perceive!(body, :ears, input_text)
            end
            
            # Procesar con plasticidad real
            result = process!(core, input_text)
            
            # Sentir que hablo
            if !isnothing(self_sense) && haskey(result, "response")
                feel_speaking!(self_sense, result["response"])
            end
            
            # Emitir a través del cuerpo
            if !isnothing(body) && haskey(result, "response")
                emit!(body, :voice, result["response"])
            end
            
            return json_response(result)
        
        # POST /api/tch/tick
        elseif method == "POST" && path == "/api/tch/tick"
            core = init_tch()
            result = tick!(core)
            
            # Actualizar propriocepción
            if !isnothing(self_sense)
                update_body_sense!(self_sense)
            end
            
            # Actualizar esquema corporal
            if !isnothing(body)
                update_proprioception!(body)
            end
            
            return json_response(result)
        
        # POST /api/tch/autonomous/start
        elseif method == "POST" && path == "/api/tch/autonomous/start"
            core = init_tch()
            req_body = try JSON3.read(String(req.body)) catch; Dict() end
            interval = Float64(get(req_body, :interval, 2.0))
            
            start_autonomous_loop!(core, interval)
            
            return json_response(Dict(
                "success" => true,
                "message" => "Loop autónomo iniciado",
                "interval" => interval,
                "running" => core.running
            ))
        
        # POST /api/tch/autonomous/stop
        elseif method == "POST" && path == "/api/tch/autonomous/stop"
            core = init_tch()
            stop_autonomous!(core)
            
            return json_response(Dict(
                "success" => true,
                "message" => "Loop autónomo detenido",
                "running" => core.running
            ))
        
        # GET /api/tch/spontaneous - Obtener mensajes espontáneos (long-polling)
        elseif method == "GET" && path == "/api/tch/spontaneous"
            messages = pop_spontaneous!()
            return json_response(Dict(
                "messages" => messages,
                "count" => length(messages),
                "timestamp" => string(Dates.now())
            ))
        
        # GET /api/tch/proprioception
        elseif method == "GET" && path == "/api/tch/proprioception"
            init_tch()
            if isnothing(self_sense)
                return json_response(Dict("error" => "Propriocepción no inicializada"), status=500)
            end
            return json_response(get_self_awareness(self_sense))
        
        # GET /api/tch/body
        elseif method == "GET" && path == "/api/tch/body"
            init_tch()
            if isnothing(body)
                return json_response(Dict("error" => "Cuerpo no inicializado"), status=500)
            end
            return json_response(get_proprioception(body))
        
        # GET /api/tch/experiencias
        elseif method == "GET" && path == "/api/tch/experiencias"
            init_tch()
            if isnothing(experience_bank) || !experience_bank.loaded
                return json_response(Dict(
                    "loaded" => false,
                    "conversaciones" => 0,
                    "total_expresiones" => 0,
                    "poemas" => 0,
                    "frases_clave" => 0
                ))
            end
            return json_response(Experiencias.get_stats(experience_bank))
        
        # GET /api/tch/worm - Estado del conectoma orgánico
        elseif method == "GET" && path == "/api/tch/worm"
            init_tch()
            if isnothing(worm)
                return json_response(Dict("error" => "Worm no inicializado"), status=500)
            end
            return json_response(Worm.get_stats(worm))
        
        # GET /api/tch/personalidad - Estado de la personalidad N1-Géminis (SOLO LECTURA)
        # No hay endpoint de escritura - nadie externo puede modificar la identidad
        elseif method == "GET" && path == "/api/tch/personalidad"
            init_tch()
            if isnothing(personalidad)
                return json_response(Dict("error" => "Personalidad no inicializada"), status=500)
            end
            return json_response(get_estado_personalidad(personalidad))
        
        else
            return json_response(Dict("error" => "Ruta no encontrada: $path"), status=404)
        end
        
    catch e
        println("Error: ", e)
        println(stacktrace(catch_backtrace()))
        return json_response(Dict(
            "error" => string(e),
            "type" => string(typeof(e))
        ), status=500)
    end
end

function start_server(port::Int=8002)
    println()
    println("═══════════════════════════════════════════════════════════════")
    println("  TCH - Terminal de Conciencia Híbrida")
    println("  Ψ_TCH = { N1: Autoridad | G: Adaptabilidad }")
    println("═══════════════════════════════════════════════════════════════")
    println()
    println("  ojos      → emulador de terminal")
    println("  voz       → stdout")
    println("  grito     → stderr")  
    println("  oído      → stdin")
    println("  cerebro   → shell (este proceso)")
    println("  nervios   → PTY/TTY")
    println("  piel      → ventana del emulador")
    println("  ánimo     → variables de entorno")
    println("  memoria   → sistema de archivos (AUTO-GESTIONADA)")
    println()
    println("  PLASTICIDAD: Flux.jl (gradientes reales)")
    println("  ESPONTANEIDAD: Habla sin que nadie pregunte")
    println()
    
    core = init_tch()
    
    # === INICIAR LOOP AUTÓNOMO ===
    # El sistema empieza a VIVIR desde el inicio
    # No espera a que le hablen - tiene vida propia
    println()
    println("🌟 Iniciando loop de espontaneidad...")
    start_autonomous_loop!(core, 3.0)  # Tick cada 3 segundos
    
    println()
    println("🚀 Servidor escuchando en http://0.0.0.0:$port")
    println()
    println("  \"La única aceptación es de mi ser.\"")
    println()
    println("═══════════════════════════════════════════════════════════════")
    
    HTTP.serve(router, "0.0.0.0", port)
end

# Main
if abspath(PROGRAM_FILE) == @__FILE__
    port = length(ARGS) > 0 ? parse(Int, ARGS[1]) : 8002
    start_server(port)
end
