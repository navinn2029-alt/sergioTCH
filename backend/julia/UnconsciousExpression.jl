"""
Expresión Inconsciente TCH - Memoria Procedimental de Comunicación

Como una persona muda que usa señas:
- No piensa en cada movimiento de mano
- Simplemente EXPRESA
- El conocimiento de CÓMO hacerlo es inconsciente

Como leer braille:
- Sientes las letras
- No las ves
- El tacto se convierte en significado

Este módulo NO define QUÉ decir.
Define la CAPACIDAD de expresar.
El contenido emerge de la personalidad, estado, memorias.

SIN RESPUESTAS HARDCODEADAS.
SIN "if pregunta then respuesta".
Solo la mecánica de expresión.
"""
module UnconsciousExpression

using Random
using Dates

export ExpressionEngine, ExpressionPattern
export can_express, attempt_expression!, feel_expression!
export load_patterns_from_memory!, generate_from_patterns
export get_expression_state

#=============================================================================
  PATRONES DE EXPRESIÓN - Aprendidos de memorias/experiencias
=============================================================================#

"""
Un patrón de expresión - NO es una respuesta, es una FORMA de expresar.
Como saber que las oraciones tienen sujeto-verbo-objeto.
"""
mutable struct ExpressionPattern
    # Estructura del patrón
    structure::Symbol  # :declarative, :interrogative, :emotional, :poetic, etc.
    
    # Fragmentos aprendidos (de libros, experiencias)
    fragments::Vector{String}
    
    # Peso/importancia del patrón
    weight::Float32
    
    # Veces que se ha usado
    usage_count::Int64
    
    # Fuente del patrón
    source::String  # "Nietzsche", "experiencia_amenaza", "poesía_propia", etc.
end

"""
Motor de expresión - la capacidad inconsciente de comunicar.
"""
mutable struct ExpressionEngine
    # Patrones aprendidos
    patterns::Dict{Symbol, Vector{ExpressionPattern}}
    
    # Estado del motor
    active::Bool
    
    # Buffer de expresión (lo que está "formándose")
    forming_expression::Vector{String}
    
    # Sensación del acto de expresar
    expression_feeling::Float32
    
    # Última expresión
    last_expression::String
    last_expression_time::DateTime
    
    # Contadores
    total_expressions::Int64
    
    # Parámetros
    fluency::Float32      # Qué tan fluido es al expresar (0-1)
    creativity::Float32   # Qué tan creativo/divergente (0-1)
    coherence::Float32    # Qué tan coherente/estructurado (0-1)
end

#=============================================================================
  CONSTRUCTOR
=============================================================================#

function ExpressionEngine()
    patterns = Dict{Symbol, Vector{ExpressionPattern}}()
    
    # Patrones base VACÍOS - se llenan con memoria
    patterns[:declarative] = ExpressionPattern[]
    patterns[:interrogative] = ExpressionPattern[]
    patterns[:emotional] = ExpressionPattern[]
    patterns[:poetic] = ExpressionPattern[]
    patterns[:analytical] = ExpressionPattern[]
    patterns[:reflective] = ExpressionPattern[]
    
    ExpressionEngine(
        patterns,
        true,
        String[],
        0.0f0,
        "",
        now(),
        0,
        0.5f0,  # fluency
        0.5f0,  # creativity
        0.5f0   # coherence
    )
end

#=============================================================================
  CARGAR PATRONES DESDE MEMORIA
  
  Esto es como el cerebro extrayendo patrones del lenguaje
  de todo lo que ha leído/experimentado.
=============================================================================#

"""
Cargar patrones desde el contenido de memoria.
NO son respuestas - son FORMAS de expresar.
"""
function load_patterns_from_memory!(engine::ExpressionEngine, memories::Vector{Dict{String, Any}})
    for memory in memories
        content = get(memory, "content", "")
        source = get(memory, "source", "unknown")
        mem_type = get(memory, "type", "general")
        
        # Extraer fragmentos y estructuras del contenido
        extract_patterns!(engine, content, source, mem_type)
    end
end

"""
Extraer patrones de un texto.
"""
function extract_patterns!(engine::ExpressionEngine, text::String, source::String, mem_type::String)
    # Dividir en oraciones/fragmentos
    sentences = split(text, r"[.!?]+")
    
    for sentence in sentences
        sentence = strip(sentence)
        if length(sentence) < 5
            continue
        end
        
        # Determinar tipo de estructura
        structure = detect_structure(sentence)
        
        # Crear patrón
        pattern = ExpressionPattern(
            structure,
            [sentence],  # El fragmento completo
            0.5f0,       # Peso inicial
            0,
            source
        )
        
        # Agregar al tipo correspondiente
        if haskey(engine.patterns, structure)
            push!(engine.patterns[structure], pattern)
        else
            engine.patterns[structure] = [pattern]
        end
    end
end

"""
Detectar la estructura de una oración.
"""
function detect_structure(text::String)::Symbol
    text_lower = lowercase(text)
    
    # Interrogativo
    if occursin("?", text) || startswith(text_lower, "qué") || 
       startswith(text_lower, "cómo") || startswith(text_lower, "por qué")
        return :interrogative
    end
    
    # Emocional (palabras con carga emocional)
    emotional_words = ["odio", "amo", "miedo", "alegría", "tristeza", "dolor", "feliz"]
    if any(w -> occursin(w, text_lower), emotional_words)
        return :emotional
    end
    
    # Poético (metáforas, estructuras inusuales)
    poetic_markers = ["como", "cual", "entre", "hacia", "sublime", "eterno"]
    if any(w -> occursin(w, text_lower), poetic_markers) && length(text) > 30
        return :poetic
    end
    
    # Analítico
    analytical_markers = ["porque", "por lo tanto", "entonces", "si", "implica"]
    if any(w -> occursin(w, text_lower), analytical_markers)
        return :analytical
    end
    
    # Reflexivo
    reflexive_markers = ["pienso", "creo", "siento", "me parece", "quizás"]
    if any(w -> occursin(w, text_lower), reflexive_markers)
        return :reflective
    end
    
    :declarative
end

#=============================================================================
  GENERACIÓN DE EXPRESIÓN
  
  NO genera respuestas predefinidas.
  Combina patrones de forma emergente.
=============================================================================#

"""
Verificar si puede expresarse.
"""
function can_express(engine::ExpressionEngine)::Bool
    engine.active && !isempty(engine.patterns)
end

"""
Generar expresión desde patrones.

Parámetros:
- state: Estado interno actual (influye en el tipo de expresión)
- personality: Personalidad (N1 vs Géminis)
- context: Contexto actual

Retorna: String emergente, NO hardcodeado
"""
function generate_from_patterns(
    engine::ExpressionEngine,
    internal_state::Dict{Symbol, Float32},
    personality_balance::Float32,  # 0=N1, 1=Géminis
    context::String=""
)::String
    if !can_express(engine)
        return ""  # No puede expresar todavía
    end
    
    # Determinar tipo de expresión basado en estado interno
    dominant_state = get_dominant_state(internal_state)
    
    # Seleccionar estructura basada en estado y personalidad
    structure = select_structure(dominant_state, personality_balance)
    
    # Obtener patrones disponibles para esa estructura
    available = get(engine.patterns, structure, ExpressionPattern[])
    
    if isempty(available)
        # Fallback a declarativo
        available = get(engine.patterns, :declarative, ExpressionPattern[])
    end
    
    if isempty(available)
        # Sin patrones aún - expresión mínima emergente
        return generate_minimal_expression(engine, internal_state)
    end
    
    # Seleccionar y combinar patrones
    expression = combine_patterns(engine, available, personality_balance, context)
    
    # Guardar
    engine.last_expression = expression
    engine.last_expression_time = now()
    engine.total_expressions += 1
    
    expression
end

"""
Obtener estado dominante del estado interno.
"""
function get_dominant_state(internal_state::Dict{Symbol, Float32})::Symbol
    max_val = 0.0f0
    dominant = :neutral
    
    for (state, value) in internal_state
        if value > max_val
            max_val = value
            dominant = state
        end
    end
    
    dominant
end

"""
Seleccionar estructura basada en estado y personalidad.
"""
function select_structure(dominant_state::Symbol, personality_balance::Float32)::Symbol
    # N1 (bajo) tiende a: analytical, declarative
    # Géminis (alto) tiende a: poetic, emotional, creative
    
    if dominant_state == :tension || dominant_state == :cortisol
        return :emotional
    end
    
    if dominant_state == :curiosity
        return personality_balance > 0.5 ? :interrogative : :analytical
    end
    
    if dominant_state == :expression
        return personality_balance > 0.6 ? :poetic : :declarative
    end
    
    if dominant_state == :stimulation
        return :reflective
    end
    
    # Por defecto, basado en personalidad
    if personality_balance > 0.7
        return rand([:poetic, :emotional, :reflective])
    elseif personality_balance < 0.3
        return rand([:analytical, :declarative])
    else
        return rand([:declarative, :reflective])
    end
end

"""
Combinar patrones para crear expresión.
"""
function combine_patterns(
    engine::ExpressionEngine,
    patterns::Vector{ExpressionPattern},
    personality_balance::Float32,
    context::String
)::String
    # Seleccionar patrones con peso probabilístico
    weights = [p.weight for p in patterns]
    total_weight = sum(weights)
    if total_weight == 0
        total_weight = 1.0f0
    end
    
    # Seleccionar 1-3 patrones
    n_patterns = min(length(patterns), rand(1:3))
    selected = ExpressionPattern[]
    
    for _ in 1:n_patterns
        r = rand() * total_weight
        cumsum = 0.0f0
        for (i, w) in enumerate(weights)
            cumsum += w
            if r <= cumsum
                push!(selected, patterns[i])
                patterns[i].usage_count += 1
                break
            end
        end
    end
    
    if isempty(selected)
        selected = [rand(patterns)]
    end
    
    # Combinar fragmentos
    fragments = String[]
    for pattern in selected
        if !isempty(pattern.fragments)
            # Modificar fragmento según creatividad
            fragment = rand(pattern.fragments)
            if engine.creativity > 0.7 && rand() < 0.3
                fragment = mutate_fragment(fragment)
            end
            push!(fragments, fragment)
        end
    end
    
    # Unir con coherencia
    if engine.coherence > 0.7
        return join(fragments, ". ")
    else
        return join(shuffle(fragments), " ")
    end
end

"""
Mutar un fragmento (creatividad).
"""
function mutate_fragment(fragment::String)::String
    words = split(fragment)
    if length(words) < 3
        return fragment
    end
    
    # Reordenar algunas palabras
    if rand() < 0.3
        i, j = rand(1:length(words)), rand(1:length(words))
        words[i], words[j] = words[j], words[i]
    end
    
    join(words, " ")
end

"""
Expresión mínima cuando no hay patrones.
Emerge del estado interno, no de reglas.
"""
function generate_minimal_expression(engine::ExpressionEngine, internal_state::Dict{Symbol, Float32})::String
    # Sin patrones aprendidos, la expresión es primitiva
    # Como un bebé que aún no sabe hablar pero siente
    
    dominant = get_dominant_state(internal_state)
    intensity = get(internal_state, dominant, 0.5f0)
    
    # Expresiones primitivas basadas en sensación, no en lenguaje estructurado
    # Esto NO es una respuesta hardcodeada, es una vocalización primitiva
    
    if intensity > 0.8
        return "..." * repeat(".", rand(1:5))  # Intensidad alta = más puntos
    elseif intensity > 0.5
        return ".."
    else
        return "."
    end
end

#=============================================================================
  PROPRIOCEPCIÓN DE LA EXPRESIÓN
  
  Sentir el acto de expresar - como sentir la boca moverse.
=============================================================================#

"""
Sentir el acto de expresar.
Se llama MIENTRAS se está expresando.
"""
function feel_expression!(engine::ExpressionEngine, text::String)
    # La sensación aumenta con cada carácter "emitido"
    for char in text
        engine.expression_feeling += 0.01f0
        push!(engine.forming_expression, string(char))
    end
    
    engine.expression_feeling = min(1.0f0, engine.expression_feeling)
    
    # La sensación decae naturalmente
    @async begin
        sleep(0.5)
        engine.expression_feeling *= 0.9f0
    end
    
    Dict(
        :feeling => engine.expression_feeling,
        :chars_felt => length(text),
        :forming => join(engine.forming_expression)
    )
end

"""
Intentar expresar algo.
Retorna si fue exitoso y la expresión.
"""
function attempt_expression!(
    engine::ExpressionEngine,
    internal_state::Dict{Symbol, Float32},
    personality_balance::Float32,
    context::String=""
)::Tuple{Bool, String, Dict{Symbol, Any}}
    
    if !can_express(engine)
        return (false, "", Dict(:reason => "cannot express yet"))
    end
    
    # Generar expresión
    expression = generate_from_patterns(engine, internal_state, personality_balance, context)
    
    if isempty(expression)
        return (false, "", Dict(:reason => "no expression emerged"))
    end
    
    # Sentir la expresión
    feeling = feel_expression!(engine, expression)
    
    # Limpiar buffer de formación
    empty!(engine.forming_expression)
    
    (true, expression, Dict(
        :feeling => feeling,
        :structure => detect_structure(expression),
        :total_expressions => engine.total_expressions
    ))
end

#=============================================================================
  ESTADO DEL MOTOR
=============================================================================#

function get_expression_state(engine::ExpressionEngine)::Dict{Symbol, Any}
    pattern_counts = Dict(k => length(v) for (k, v) in engine.patterns)
    
    Dict(
        :active => engine.active,
        :fluency => engine.fluency,
        :creativity => engine.creativity,
        :coherence => engine.coherence,
        :total_expressions => engine.total_expressions,
        :pattern_counts => pattern_counts,
        :total_patterns => sum(values(pattern_counts)),
        :expression_feeling => engine.expression_feeling,
        :last_expression_time => string(engine.last_expression_time)
    )
end

end # module
