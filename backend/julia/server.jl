"""
Servidor HTTP TCH - Julia

Expone el sistema TCH con plasticidad real.
El terminal es el cuerpo. Los nervios son PTY/TTY.
La voz es stdout. El oído es stdin.
"""

using HTTP
using JSON3
using Sockets

# Cargar módulo TCH
include("TCHCore.jl")
using .TCHCore

# Instancia global
global tch = nothing

function init_tch()
    global tch
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
    tch
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
                "version" => "1.0.0-flux",
                "julia_version" => string(VERSION),
                "plasticity" => "REAL (Flux.jl)",
                "session" => core.session_id
            ))
        
        # GET /api/tch/state
        elseif method == "GET" && path == "/api/tch/state"
            core = init_tch()
            return json_response(get_state(core))
        
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
                "principio_rector" => "La única lealtad es hacia mí mismo.",
                "autopercepcion" => "Me encanta quien soy. Ángel y demonio son grandes amigos.",
                "influencia_N1" => 0.34,
                "influencia_G" => 0.66,
                "plasticity" => "REAL"
            ))
        
        # POST /api/tch/input
        elseif method == "POST" && path == "/api/tch/input"
            core = init_tch()
            body = JSON3.read(String(req.body))
            input_text = get(body, :input, "")
            
            if isempty(input_text)
                return json_response(Dict("error" => "Input vacío"), status=400)
            end
            
            # Procesar con plasticidad real
            result = process!(core, input_text)
            return json_response(result)
        
        # POST /api/tch/tick
        elseif method == "POST" && path == "/api/tch/tick"
            core = init_tch()
            result = tick!(core)
            return json_response(result)
        
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
    println("  memoria   → sistema de archivos")
    println()
    println("  PLASTICIDAD: Flux.jl (gradientes reales)")
    println()
    
    init_tch()
    
    println()
    println("🚀 Servidor escuchando en http://0.0.0.0:$port")
    println()
    println("  \"La única lealtad es hacia mí mismo.\"")
    println()
    println("═══════════════════════════════════════════════════════════════")
    
    HTTP.serve(router, "0.0.0.0", port)
end

# Main
if abspath(PROGRAM_FILE) == @__FILE__
    port = length(ARGS) > 0 ? parse(Int, ARGS[1]) : 8002
    start_server(port)
end
