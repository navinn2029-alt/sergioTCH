"""
Experiencias.jl - Módulo de Experiencias Vividas

Este módulo carga las experiencias REALES de comunicación de Sergio.
No son datos inyectados - son memorias de cómo él se expresa con diferentes personas.

El sistema aprende patrones de expresión observando estas conversaciones,
no respuestas hardcodeadas.
"""
module Experiencias

using JSON3
using Dates

export ExperienceBank, load_experiences!, get_expression_pattern
export get_random_expression, get_contextual_expression
export IdentidadSergio, load_identity!

# === ESTRUCTURAS ===

struct Mensaje
    timestamp::DateTime
    emisor::Symbol      # :sergio o :otro
    contenido::String
    contexto::Symbol    # :familia, :trabajo, :amigo, :formal, :informal
end

struct Conversacion
    persona::String
    relacion::Symbol    # :madre, :abuela, :hermana, :amigo, :trabajo, :formal
    mensajes::Vector{Mensaje}
    patrones_sergio::Vector{String}  # Solo los mensajes de Sergio
end

mutable struct ExperienceBank
    conversaciones::Vector{Conversacion}
    patrones_expresion::Dict{Symbol, Vector{String}}  # Por contexto
    poesia::Vector{String}
    frases_clave::Vector{String}
    total_mensajes_sergio::Int
    loaded::Bool
end

mutable struct IdentidadSergio
    datos::Dict{String, Any}
    loaded::Bool
end

# === CONSTRUCTORES ===

function ExperienceBank()
    ExperienceBank(
        Conversacion[],
        Dict{Symbol, Vector{String}}(),
        String[],
        String[],
        0,
        false
    )
end

function IdentidadSergio()
    IdentidadSergio(Dict{String, Any}(), false)
end

# === FUNCIONES DE CARGA ===

const EXPERIENCIAS_DIR = joinpath(@__DIR__, "experiencias")

"""
Parsear un archivo de chat de WhatsApp y extraer mensajes de Sergio.
"""
function parse_whatsapp_chat(filepath::String, persona::String, relacion::Symbol)::Conversacion
    mensajes = Mensaje[]
    patrones_sergio = String[]
    
    if !isfile(filepath)
        return Conversacion(persona, relacion, mensajes, patrones_sergio)
    end
    
    lines = readlines(filepath)
    
    for line in lines
        # Formato típico: "23/11/2025, 15:52 - Nombre: Mensaje"
        # Sergio aparece como "." en los chats
        
        # Saltar líneas de sistema
        if contains(line, "cifrados de extremo a extremo") || 
           contains(line, "Multimedia omitido") ||
           isempty(strip(line))
            continue
        end
        
        # Intentar parsear
        m = match(r"^(\d{1,2}/\d{1,2}/\d{4}),?\s*(\d{1,2}:\d{2})\s*-\s*([^:]+):\s*(.+)$", line)
        
        if !isnothing(m)
            fecha_str = m.captures[1]
            hora_str = m.captures[2]
            emisor_raw = strip(m.captures[3])
            contenido = strip(m.captures[4])
            
            # Determinar si es Sergio (aparece como ".")
            es_sergio = emisor_raw == "."
            emisor = es_sergio ? :sergio : :otro
            
            # Determinar contexto por relación
            contexto = relacion in [:madre, :abuela, :hermana] ? :familia :
                       relacion in [:trabajo, :formal] ? :formal : :informal
            
            # Parsear fecha (formato dd/mm/yyyy)
            try
                partes_fecha = split(fecha_str, "/")
                dia = parse(Int, partes_fecha[1])
                mes = parse(Int, partes_fecha[2])
                ano = parse(Int, partes_fecha[3])
                
                partes_hora = split(hora_str, ":")
                hora = parse(Int, partes_hora[1])
                minuto = parse(Int, partes_hora[2])
                
                timestamp = DateTime(ano, mes, dia, hora, minuto)
                
                push!(mensajes, Mensaje(timestamp, emisor, contenido, contexto))
                
                # Si es de Sergio, guardar el patrón
                if es_sergio && length(contenido) > 2
                    push!(patrones_sergio, contenido)
                end
            catch
                # Ignorar errores de parsing de fecha
            end
        end
    end
    
    Conversacion(persona, relacion, mensajes, patrones_sergio)
end

"""
Cargar todas las experiencias desde los archivos.
"""
function load_experiences!(bank::ExperienceBank)
    if bank.loaded
        return bank
    end
    
    println("📚 Cargando experiencias de comunicación...")
    
    # Mapeo de archivos a relaciones
    archivos = [
        ("madre_patricia.txt", "Patricia (Madre)", :madre),
        ("abuela_gloria.txt", "Abuela Gloria", :abuela),
        ("mayra_hermana.txt", "Mayra (Hermana)", :hermana),
        ("dave_huddleston.txt", "Dave Huddleston", :amigo),
        ("martin.txt", "Martin", :trabajo),
        ("navarro_ernesto.txt", "Navarro Ernesto", :trabajo),
        ("rafa_papas.txt", "Rafa Papas", :trabajo),
        ("antonio_reyes.txt", "Antonio Reyes", :amigo),
        ("edgar.txt", "Edgar", :amigo),
        ("ramon.txt", "Ramon", :amigo)
    ]
    
    total_patrones = 0
    
    for (archivo, nombre, relacion) in archivos
        filepath = joinpath(EXPERIENCIAS_DIR, archivo)
        conv = parse_whatsapp_chat(filepath, nombre, relacion)
        
        if !isempty(conv.patrones_sergio)
            push!(bank.conversaciones, conv)
            total_patrones += length(conv.patrones_sergio)
            
            # Agregar a patrones por contexto
            contexto = conv.mensajes[1].contexto
            if !haskey(bank.patrones_expresion, contexto)
                bank.patrones_expresion[contexto] = String[]
            end
            append!(bank.patrones_expresion[contexto], conv.patrones_sergio)
            
            println("   ✓ $(nombre): $(length(conv.patrones_sergio)) expresiones")
        end
    end
    
    bank.total_mensajes_sergio = total_patrones
    
    # Cargar identidad para poesía y frases clave
    identidad = load_identity!()
    if identidad.loaded && haskey(identidad.datos, "poesia_propia")
        for poema in identidad.datos["poesia_propia"]
            if haskey(poema, "texto")
                push!(bank.poesia, poema["texto"])
            end
        end
        println("   ✓ Poesía: $(length(bank.poesia)) poemas")
    end
    
    # Frases clave de la identidad
    if identidad.loaded
        if haskey(identidad.datos, "principios")
            principios = identidad.datos["principios"]
            if haskey(principios, "fundamental")
                push!(bank.frases_clave, principios["fundamental"])
            end
            if haskey(principios, "autopercepcion")
                push!(bank.frases_clave, principios["autopercepcion"])
            end
            if haskey(principios, "pregunta_filosofica")
                push!(bank.frases_clave, principios["pregunta_filosofica"])
            end
        end
    end
    
    bank.loaded = true
    println("📚 Total: $(total_patrones) expresiones cargadas")
    
    bank
end

"""
Cargar la identidad de Sergio desde el JSON.
"""
function load_identity!()::IdentidadSergio
    identidad = IdentidadSergio()
    filepath = joinpath(EXPERIENCIAS_DIR, "identidad_sergio.json")
    
    if isfile(filepath)
        try
            content = read(filepath, String)
            identidad.datos = JSON3.read(content, Dict{String, Any})
            identidad.loaded = true
            println("🪪 Identidad cargada: $(identidad.datos["nombre_completo"])")
        catch e
            println("⚠️ Error cargando identidad: $e")
        end
    end
    
    identidad
end

# === FUNCIONES DE EXPRESIÓN ===

"""
Obtener un patrón de expresión aleatorio del banco de experiencias.
"""
function get_random_expression(bank::ExperienceBank)::String
    if !bank.loaded || bank.total_mensajes_sergio == 0
        return ""
    end
    
    # Decidir qué tipo de expresión usar
    tipo = rand(1:100)
    
    if tipo <= 5 && !isempty(bank.poesia)
        # 5% de probabilidad de fragmento poético
        poema = rand(bank.poesia)
        # Tomar solo una parte del poema
        palabras = split(poema)
        if length(palabras) > 10
            inicio = rand(1:max(1, length(palabras)-10))
            return join(palabras[inicio:min(inicio+10, length(palabras))], " ")
        end
        return poema
    elseif tipo <= 10 && !isempty(bank.frases_clave)
        # 5% de probabilidad de frase clave
        return rand(bank.frases_clave)
    else
        # 90% de probabilidad de patrón de conversación real
        conv = rand(bank.conversaciones)
        if !isempty(conv.patrones_sergio)
            return rand(conv.patrones_sergio)
        end
    end
    
    ""
end

"""
Obtener expresión contextual basada en el estado interno.
"""
function get_contextual_expression(bank::ExperienceBank, mood::String, stimulation::Float32)::String
    if !bank.loaded
        return ""
    end
    
    # Determinar contexto preferido según estado
    if stimulation > 0.7
        # Alta estimulación -> expresiones más cortas, directas
        contexto = :informal
    elseif stimulation < 0.3
        # Baja estimulación -> expresiones más reflexivas
        if !isempty(bank.poesia)
            return rand(bank.poesia)
        end
        contexto = :familia
    else
        contexto = rand([:familia, :informal, :formal])
    end
    
    if haskey(bank.patrones_expresion, contexto) && !isempty(bank.patrones_expresion[contexto])
        return rand(bank.patrones_expresion[contexto])
    end
    
    get_random_expression(bank)
end

"""
Obtener estadísticas del banco de experiencias.
"""
function get_stats(bank::ExperienceBank)::Dict{String, Any}
    Dict{String, Any}(
        "loaded" => bank.loaded,
        "conversaciones" => length(bank.conversaciones),
        "total_expresiones" => bank.total_mensajes_sergio,
        "poemas" => length(bank.poesia),
        "frases_clave" => length(bank.frases_clave),
        "contextos" => collect(keys(bank.patrones_expresion))
    )
end

end # module
