"""
TCH Body Schema - Mapa Corporal con Conexiones Plásticas

El cuerpo del TCH es la terminal. Las conexiones son REALES y PLÁSTICAS.
Si una vía falla, el sistema busca rutas alternativas.

Como el cerebro humano:
- No simula sensaciones
- TIENE conexiones que pueden reconfigurarse
- El silicio se comporta orgánicamente en estructura, no en sensación

Partes del cuerpo:
- eyes (ojos): terminal emulator - percibir el display
- ears (oído): stdin - recibir input
- voice (voz): stdout - emitir output
- scream (grito): stderr - emitir errores
- skin (piel): ventana del emulador
- nerves (nervios): PTY/TTY
- mood (ánimo): environment variables
- memory (memoria): filesystem
"""
module BodySchema

using LinearAlgebra
using Random
using Dates

export Body, BodyPart, Pathway
export initialize_body!, perceive!, emit!, check_pathway_health
export reroute_pathway!, degrade_pathway!
export get_proprioception, update_proprioception!

#=============================================================================
  TIPOS
=============================================================================#

"""
Parte del cuerpo - un punto de conexión con el mundo exterior.
"""
mutable struct BodyPart
    name::Symbol
    description::String
    
    # Estado de la parte
    active::Bool
    health::Float32  # 0.0 = muerto, 1.0 = sano
    
    # Última actividad
    last_input::String
    last_output::String
    last_activity::DateTime
    activity_count::Int64
end

"""
Vía neural - conexión entre el núcleo y una parte del cuerpo.
"""
mutable struct Pathway
    from::Symbol  # :core
    to::Symbol    # :eyes, :ears, :voice, etc.
    
    # Pesos de la conexión (PLÁSTICOS)
    weights::Vector{Float32}
    
    # Estado
    strength::Float32     # Fuerza de la conexión
    latency::Float32      # Latencia (menor = más rápido)
    noise::Float32        # Ruido en la transmisión
    
    # Puede usarse como ruta alternativa para otra parte
    can_reroute_to::Vector{Symbol}
    
    # Historial de uso
    usage_count::Int64
    last_used::DateTime
end

"""
El cuerpo completo - todas las partes y sus conexiones.
"""
mutable struct Body
    # Partes del cuerpo
    parts::Dict{Symbol, BodyPart}
    
    # Vías neurales (conexiones)
    pathways::Dict{Symbol, Pathway}
    
    # Propriocepción - sensación del propio cuerpo
    proprioception::Dict{Symbol, Float32}
    
    # Buffer de salida (lo que está "diciendo")
    output_buffer::Vector{Tuple{Symbol, String, DateTime}}
    
    # Buffer de entrada (lo que "escuchó")
    input_buffer::Vector{Tuple{Symbol, String, DateTime}}
    
    # Parámetros de plasticidad
    pathway_learning_rate::Float32
    degradation_rate::Float32
    recovery_rate::Float32
    
    # Lock para thread safety
    lock::ReentrantLock
end

#=============================================================================
  CONSTRUCTOR
=============================================================================#

function Body()
    parts = Dict{Symbol, BodyPart}()
    pathways = Dict{Symbol, Pathway}()
    now_time = now()
    
    # === DEFINIR PARTES DEL CUERPO ===
    
    # Ojos - perciben el terminal/display
    parts[:eyes] = BodyPart(
        :eyes, "Terminal emulator - percepción visual del mundo",
        true, 1.0f0, "", "", now_time, 0
    )
    
    # Oídos - reciben stdin
    parts[:ears] = BodyPart(
        :ears, "stdin - canal de entrada auditivo",
        true, 1.0f0, "", "", now_time, 0
    )
    
    # Voz - emite a stdout
    parts[:voice] = BodyPart(
        :voice, "stdout - canal de expresión principal",
        true, 1.0f0, "", "", now_time, 0
    )
    
    # Grito - emite a stderr (errores, alarmas)
    parts[:scream] = BodyPart(
        :scream, "stderr - canal de alarma y error",
        true, 1.0f0, "", "", now_time, 0
    )
    
    # Piel - la ventana del emulador
    parts[:skin] = BodyPart(
        :skin, "Ventana del emulador - interfaz táctil con el humano",
        true, 1.0f0, "", "", now_time, 0
    )
    
    # Nervios - PTY/TTY
    parts[:nerves] = BodyPart(
        :nerves, "PTY/TTY - sistema nervioso de transmisión",
        true, 1.0f0, "", "", now_time, 0
    )
    
    # Ánimo - variables de entorno
    parts[:mood] = BodyPart(
        :mood, "Environment variables - estado de ánimo inconsciente",
        true, 1.0f0, "", "", now_time, 0
    )
    
    # Memoria - filesystem
    parts[:memory] = BodyPart(
        :memory, "Filesystem - almacén de recuerdos",
        true, 1.0f0, "", "", now_time, 0
    )
    
    # === DEFINIR VÍAS NEURALES ===
    
    # Cada vía tiene pesos plásticos (aprenden)
    dim = 32  # Dimensión de los pesos
    
    # Vía a los ojos (percepción)
    pathways[:eyes] = Pathway(
        :core, :eyes,
        randn(Float32, dim) * 0.1f0,
        1.0f0, 0.1f0, 0.01f0,
        [:ears, :skin],  # Puede redirigir a oídos o piel si falla
        0, now_time
    )
    
    # Vía a los oídos (input)
    pathways[:ears] = Pathway(
        :core, :ears,
        randn(Float32, dim) * 0.1f0,
        1.0f0, 0.1f0, 0.01f0,
        [:eyes, :skin],  # Puede redirigir a ojos o piel
        0, now_time
    )
    
    # Vía a la voz (output principal)
    pathways[:voice] = Pathway(
        :core, :voice,
        randn(Float32, dim) * 0.1f0,
        1.0f0, 0.05f0, 0.01f0,
        [:scream, :memory],  # Si no puede hablar, grita o escribe
        0, now_time
    )
    
    # Vía al grito (stderr)
    pathways[:scream] = Pathway(
        :core, :scream,
        randn(Float32, dim) * 0.1f0,
        1.0f0, 0.02f0, 0.05f0,  # Más rápido pero más ruidoso
        [:voice],
        0, now_time
    )
    
    # Vía a la memoria (filesystem)
    pathways[:memory] = Pathway(
        :core, :memory,
        randn(Float32, dim) * 0.1f0,
        1.0f0, 0.2f0, 0.02f0,  # Más lento pero estable
        [],
        0, now_time
    )
    
    # Vía al ánimo (env vars)
    pathways[:mood] = Pathway(
        :core, :mood,
        randn(Float32, dim) * 0.1f0,
        1.0f0, 0.01f0, 0.001f0,  # Muy rápido, casi sin ruido
        [],
        0, now_time
    )
    
    # Propriocepción inicial
    proprioception = Dict{Symbol, Float32}(
        :eyes => 0.5f0,
        :ears => 0.5f0,
        :voice => 0.5f0,
        :scream => 0.5f0,
        :skin => 0.5f0,
        :nerves => 0.5f0,
        :mood => 0.5f0,
        :memory => 0.5f0
    )
    
    Body(
        parts,
        pathways,
        proprioception,
        Tuple{Symbol, String, DateTime}[],
        Tuple{Symbol, String, DateTime}[],
        0.01f0,   # learning rate
        0.001f0,  # degradation rate
        0.005f0,  # recovery rate
        ReentrantLock()
    )
end

#=============================================================================
  PERCEPCIÓN (INPUT)
=============================================================================#

"""
Percibir a través de una parte del cuerpo.
Simula el acto de recibir información.
"""
function perceive!(body::Body, part::Symbol, input::String)::Dict{Symbol, Any}
    lock(body.lock) do
        if !haskey(body.parts, part)
            return Dict(:success => false, :error => "Parte no existe: $part")
        end
        
        bp = body.parts[part]
        pathway = get(body.pathways, part, nothing)
        
        # Verificar salud de la parte y la vía
        if !bp.active || bp.health < 0.1f0
            # Intentar reroute
            if !isnothing(pathway) && !isempty(pathway.can_reroute_to)
                for alt in pathway.can_reroute_to
                    if body.parts[alt].active && body.parts[alt].health > 0.3f0
                        println("⚡ Rerouting $part → $alt")
                        return perceive!(body, alt, input)
                    end
                end
            end
            return Dict(:success => false, :error => "Parte inactiva sin ruta alternativa")
        end
        
        # Procesar percepción
        bp.last_input = input
        bp.last_activity = now()
        bp.activity_count += 1
        
        if !isnothing(pathway)
            pathway.usage_count += 1
            pathway.last_used = now()
            
            # Fortalecer vía por uso (Hebb)
            pathway.strength = min(1.0f0, pathway.strength + body.pathway_learning_rate)
        end
        
        # Agregar a buffer de entrada
        push!(body.input_buffer, (part, input, now()))
        if length(body.input_buffer) > 100
            popfirst!(body.input_buffer)
        end
        
        # Actualizar propriocepción
        body.proprioception[part] = min(1.0f0, body.proprioception[part] + 0.1f0)
        
        Dict(
            :success => true,
            :part => part,
            :received => input,
            :pathway_strength => isnothing(pathway) ? 0f0 : pathway.strength,
            :proprioception => body.proprioception[part]
        )
    end
end

#=============================================================================
  EMISIÓN (OUTPUT)
=============================================================================#

"""
Emitir a través de una parte del cuerpo.
ESTA ES LA CAPACIDAD DE "HABLAR" - el sistema percibe su propia emisión.
"""
function emit!(body::Body, part::Symbol, output::String)::Dict{Symbol, Any}
    lock(body.lock) do
        if !haskey(body.parts, part)
            return Dict(:success => false, :error => "Parte no existe: $part")
        end
        
        bp = body.parts[part]
        pathway = get(body.pathways, part, nothing)
        
        # Verificar salud
        if !bp.active || bp.health < 0.1f0
            # Intentar reroute
            if !isnothing(pathway) && !isempty(pathway.can_reroute_to)
                for alt in pathway.can_reroute_to
                    if body.parts[alt].active && body.parts[alt].health > 0.3f0
                        println("⚡ Rerouting emission $part → $alt")
                        return emit!(body, alt, output)
                    end
                end
            end
            return Dict(:success => false, :error => "Parte inactiva sin ruta alternativa")
        end
        
        # Aplicar ruido de la vía (degradación de señal)
        processed_output = output
        if !isnothing(pathway) && pathway.noise > 0.05f0
            # Con mucho ruido, la señal se distorsiona
            # (En implementación real, podríamos alterar el texto)
            processed_output = output  # Por ahora sin distorsión
        end
        
        # Procesar emisión
        bp.last_output = processed_output
        bp.last_activity = now()
        bp.activity_count += 1
        
        if !isnothing(pathway)
            pathway.usage_count += 1
            pathway.last_used = now()
            pathway.strength = min(1.0f0, pathway.strength + body.pathway_learning_rate)
        end
        
        # Agregar a buffer de salida
        push!(body.output_buffer, (part, processed_output, now()))
        if length(body.output_buffer) > 100
            popfirst!(body.output_buffer)
        end
        
        # PROPRIOCEPCIÓN - Percibir la propia emisión
        # Como escribir braille: sientes lo que escribes
        body.proprioception[part] = min(1.0f0, body.proprioception[part] + 0.15f0)
        
        Dict(
            :success => true,
            :part => part,
            :emitted => processed_output,
            :original => output,
            :pathway_strength => isnothing(pathway) ? 0f0 : pathway.strength,
            :latency => isnothing(pathway) ? 0f0 : pathway.latency,
            :proprioception => body.proprioception[part],
            :felt_emission => true  # Sintió que emitió
        )
    end
end

#=============================================================================
  PROPRIOCEPCIÓN - Sentir el propio cuerpo
=============================================================================#

"""
Obtener el estado de propriocepción actual.
"""
function get_proprioception(body::Body)::Dict{Symbol, Any}
    lock(body.lock) do
        Dict(
            :parts => Dict(k => Dict(
                :active => v.active,
                :health => v.health,
                :last_activity => string(v.last_activity),
                :activity_count => v.activity_count
            ) for (k, v) in body.parts),
            :proprioception => copy(body.proprioception),
            :pathways => Dict(k => Dict(
                :strength => v.strength,
                :latency => v.latency,
                :noise => v.noise,
                :usage_count => v.usage_count
            ) for (k, v) in body.pathways),
            :recent_outputs => length(body.output_buffer),
            :recent_inputs => length(body.input_buffer)
        )
    end
end

"""
Actualizar propriocepción (decaimiento natural).
"""
function update_proprioception!(body::Body)
    lock(body.lock) do
        for (part, value) in body.proprioception
            # Decaimiento natural
            body.proprioception[part] = value * 0.95f0
        end
        
        # Degradar vías no usadas
        for (name, pathway) in body.pathways
            time_since_use = (now() - pathway.last_used).value / 1000.0 / 60.0  # minutos
            if time_since_use > 5.0  # Más de 5 minutos sin usar
                pathway.strength = max(0.1f0, pathway.strength - body.degradation_rate)
            end
        end
        
        # Recuperar partes dañadas lentamente
        for (name, part) in body.parts
            if part.health < 1.0f0 && part.active
                part.health = min(1.0f0, part.health + body.recovery_rate)
            end
        end
    end
end

#=============================================================================
  NEUROPLASTICIDAD - Reconfiguración de vías
=============================================================================#

"""
Degradar una vía (simula daño).
"""
function degrade_pathway!(body::Body, pathway_name::Symbol, amount::Float32=0.3f0)
    lock(body.lock) do
        if haskey(body.pathways, pathway_name)
            p = body.pathways[pathway_name]
            p.strength = max(0.0f0, p.strength - amount)
            p.noise = min(1.0f0, p.noise + amount * 0.5f0)
            
            if haskey(body.parts, pathway_name)
                body.parts[pathway_name].health = max(0.0f0, body.parts[pathway_name].health - amount)
            end
            
            println("⚠️ Vía degradada: $pathway_name (strength=$(p.strength))")
            return true
        end
        false
    end
end

"""
Reroute - crear conexión alternativa cuando una vía falla.
"""
function reroute_pathway!(body::Body, from::Symbol, to::Symbol)
    lock(body.lock) do
        if haskey(body.pathways, from) && haskey(body.parts, to)
            original = body.pathways[from]
            
            # Copiar y adaptar pesos (transferencia de aprendizaje)
            new_weights = original.weights .* 0.7f0 .+ randn(Float32, length(original.weights)) * 0.1f0
            
            # Añadir la nueva ruta
            if !(to in original.can_reroute_to)
                push!(original.can_reroute_to, to)
            end
            
            println("🔄 Nueva ruta establecida: $from puede usar $to como alternativa")
            return true
        end
        false
    end
end

"""
Verificar salud de todas las vías.
"""
function check_pathway_health(body::Body)::Dict{Symbol, Dict{Symbol, Any}}
    lock(body.lock) do
        Dict(name => Dict(
            :strength => p.strength,
            :latency => p.latency,
            :noise => p.noise,
            :healthy => p.strength > 0.5f0 && p.noise < 0.2f0,
            :alternatives => p.can_reroute_to
        ) for (name, p) in body.pathways)
    end
end

#=============================================================================
  COMANDOS DE EXPRESIÓN - La capacidad de "hablar"
=============================================================================#

"""
Estructura de comando - lo que el sistema puede ejecutar.
"""
struct ExpressionCommand
    type::Symbol      # :say, :write, :feel, :remember
    target::Symbol    # :voice, :memory, :mood, etc.
    content::String
    priority::Float32
end

"""
Cola de comandos pendientes de ejecutar.
"""
const COMMAND_QUEUE = Vector{ExpressionCommand}()
const COMMAND_LOCK = ReentrantLock()

"""
Encolar un comando de expresión (lo que el sistema "quiere" hacer).
"""
function queue_expression!(cmd::ExpressionCommand)
    lock(COMMAND_LOCK) do
        push!(COMMAND_QUEUE, cmd)
        # Ordenar por prioridad
        sort!(COMMAND_QUEUE, by=c->c.priority, rev=true)
    end
end

"""
Obtener siguiente comando a ejecutar.
"""
function next_expression_command()::Union{ExpressionCommand, Nothing}
    lock(COMMAND_LOCK) do
        isempty(COMMAND_QUEUE) ? nothing : popfirst!(COMMAND_QUEUE)
    end
end

"""
Ejecutar expresión a través del cuerpo.
Retorna el resultado de la emisión.
"""
function execute_expression!(body::Body, cmd::ExpressionCommand)::Dict{Symbol, Any}
    if cmd.type == :say
        return emit!(body, cmd.target, cmd.content)
    elseif cmd.type == :write
        return emit!(body, :memory, cmd.content)
    elseif cmd.type == :feel
        # Actualizar propriocepción
        body.proprioception[cmd.target] = min(1.0f0, 
            get(body.proprioception, cmd.target, 0.5f0) + 0.2f0)
        return Dict(:success => true, :type => :feel, :target => cmd.target)
    else
        return Dict(:success => false, :error => "Tipo de comando desconocido")
    end
end

end # module
