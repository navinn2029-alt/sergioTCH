"""
MarkovBrain.jl - Generador de Texto con Cadenas de Markov

NO repite. GENERA.

Las experiencias se fragmentan en n-gramas.
El Worm modula la generación:
- Qué neurona motora dispara → qué tipo de contenido
- Nivel de actividad → temperatura/creatividad
- Estado del conectoma → longitud y coherencia
"""
module MarkovBrain

using Random

export MarkovChain, build_chain!, generate, feed_experience!
export MotorMapping, generate_from_worm
export get_stats

# === ESTRUCTURAS ===

"""
Cadena de Markov con n-gramas variables.
"""
mutable struct MarkovChain
    # Transiciones: contexto → [(siguiente_palabra, frecuencia)]
    transitions::Dict{Tuple{Vararg{String}}, Dict{String, Int}}
    
    # Orden de la cadena (número de palabras de contexto)
    order::Int
    
    # Vocabulario
    vocabulary::Set{String}
    
    # Inicios de oraciones (para comenzar generación)
    starters::Vector{Tuple{Vararg{String}}}
    
    # Estadísticas
    total_tokens::Int
    total_sequences::Int
end

"""
Mapeo de neuronas motoras a tipos de generación.
"""
struct MotorMapping
    # Motor 1: Expresión poética/filosófica
    # Motor 2: Expresión casual/conversacional
    # Motor 3: Expresión directa/pragmática
    # Motor 4: Expresión emocional/íntima
    weights::Vector{Float32}
end

# === CONSTRUCTORES ===

function MarkovChain(; order::Int=2)
    MarkovChain(
        Dict{Tuple{Vararg{String}}, Dict{String, Int}}(),
        order,
        Set{String}(),
        Tuple{Vararg{String}}[],
        0,
        0
    )
end

# === PROCESAMIENTO DE TEXTO ===

"""
Tokenizar texto en palabras, preservando puntuación como tokens.
"""
function tokenize(text::String)::Vector{String}
    # Limpiar y normalizar
    text = lowercase(strip(text))
    
    # Separar puntuación
    text = replace(text, r"([.,!?;:])" => s" \1 ")
    text = replace(text, r"\s+" => " ")
    
    # Tokenizar
    tokens = split(text)
    filter!(t -> !isempty(t), tokens)
    
    String.(tokens)
end

"""
Alimentar la cadena con una experiencia (texto).
"""
function feed_experience!(chain::MarkovChain, text::String)
    tokens = tokenize(text)
    
    if length(tokens) < chain.order + 1
        return
    end
    
    # Agregar al vocabulario
    for token in tokens
        push!(chain.vocabulary, token)
    end
    
    # Guardar inicio de oración
    starter = Tuple(tokens[1:chain.order])
    if !(starter in chain.starters)
        push!(chain.starters, starter)
    end
    
    # Construir transiciones
    for i in 1:(length(tokens) - chain.order)
        context = Tuple(tokens[i:i+chain.order-1])
        next_word = tokens[i + chain.order]
        
        if !haskey(chain.transitions, context)
            chain.transitions[context] = Dict{String, Int}()
        end
        
        if !haskey(chain.transitions[context], next_word)
            chain.transitions[context][next_word] = 0
        end
        
        chain.transitions[context][next_word] += 1
        chain.total_tokens += 1
    end
    
    chain.total_sequences += 1
end

"""
Construir cadena desde múltiples textos.
"""
function build_chain!(chain::MarkovChain, texts::Vector{String})
    for text in texts
        feed_experience!(chain, text)
    end
    chain
end

# === GENERACIÓN ===

"""
Seleccionar siguiente palabra basado en probabilidades y temperatura.
"""
function sample_next(transitions::Dict{String, Int}, temperature::Float32)::String
    if isempty(transitions)
        return ""
    end
    
    words = collect(keys(transitions))
    counts = Float32[transitions[w] for w in words]
    
    # Aplicar temperatura
    if temperature != 1.0f0
        counts = counts .^ (1.0f0 / max(temperature, 0.1f0))
    end
    
    # Normalizar a probabilidades
    total = sum(counts)
    probs = counts ./ total
    
    # Muestrear
    r = rand(Float32)
    cumsum = 0.0f0
    for (i, p) in enumerate(probs)
        cumsum += p
        if r <= cumsum
            return words[i]
        end
    end
    
    words[end]
end

"""
Generar texto nuevo.

Parámetros:
- max_words: límite de palabras
- temperature: creatividad (0.1 = conservador, 2.0 = caótico)
- starter: contexto inicial (opcional)
"""
function generate(
    chain::MarkovChain;
    max_words::Int=30,
    temperature::Float32=1.0f0,
    starter::Union{Nothing, Tuple}=nothing
)::String
    
    if isempty(chain.transitions)
        return ""
    end
    
    # Elegir inicio
    if isnothing(starter) || !(starter in keys(chain.transitions))
        if isempty(chain.starters)
            # Usar cualquier contexto existente
            starter = rand(collect(keys(chain.transitions)))
        else
            starter = rand(chain.starters)
        end
    end
    
    # Generar
    result = collect(starter)
    context = starter
    
    for _ in 1:max_words
        if !haskey(chain.transitions, context)
            break
        end
        
        next_word = sample_next(chain.transitions[context], temperature)
        
        if isempty(next_word)
            break
        end
        
        push!(result, next_word)
        
        # Actualizar contexto (ventana deslizante)
        context = Tuple(result[end-chain.order+1:end])
        
        # Terminar en puntuación final
        if next_word in [".", "!", "?"] && length(result) > 10
            break
        end
    end
    
    # Reconstruir texto
    text = join(result, " ")
    
    # Limpiar espacios antes de puntuación
    text = replace(text, r" ([.,!?;:])" => s"\1")
    
    # Capitalizar primera letra
    if !isempty(text)
        text = uppercase(text[1]) * text[2:end]
    end
    
    text
end

# === INTEGRACIÓN CON WORM ===

"""
Generar texto modulado por el estado del Worm.

motor_output: Vector de 4 floats (actividad de cada neurona motora)
- Motor 1 alto → más poético/filosófico (temperatura alta, más largo)
- Motor 2 alto → más casual (temperatura media)
- Motor 3 alto → más directo (temperatura baja, más corto)
- Motor 4 alto → más emocional (temperatura alta, palabras emotivas)
"""
function generate_from_worm(
    chain::MarkovChain,
    motor_output::Vector{Float32}
)::String
    
    if isempty(chain.transitions)
        return ""
    end
    
    # Calcular parámetros basados en actividad motora
    m1, m2, m3, m4 = motor_output[1:4]
    total_activity = sum(motor_output)
    
    if total_activity < 0.1f0
        return ""  # No hay suficiente actividad para hablar
    end
    
    # Temperatura: M1 y M4 la suben, M3 la baja
    temperature = 0.5f0 + (m1 * 0.8f0) + (m4 * 0.6f0) - (m3 * 0.3f0)
    temperature = clamp(temperature, 0.3f0, 2.0f0)
    
    # Longitud: M1 la sube, M3 la baja
    max_words = Int(round(15 + (m1 * 30) - (m3 * 10)))
    max_words = clamp(max_words, 5, 50)
    
    # Generar
    text = generate(chain, max_words=max_words, temperature=temperature)
    
    # Si M4 está alto, intentar buscar inicio emocional
    if m4 > 0.5f0 && !isempty(chain.starters)
        emotional_starters = filter(chain.starters) do s
            any(w -> w in ["me", "siento", "quiero", "amo", "odio", "creo", "pienso"], s)
        end
        if !isempty(emotional_starters)
            text = generate(chain, max_words=max_words, temperature=temperature, 
                          starter=rand(emotional_starters))
        end
    end
    
    text
end

# === ESTADÍSTICAS ===

function get_stats(chain::MarkovChain)::Dict{String, Any}
    Dict{String, Any}(
        "order" => chain.order,
        "vocabulary_size" => length(chain.vocabulary),
        "total_contexts" => length(chain.transitions),
        "total_tokens" => chain.total_tokens,
        "total_sequences" => chain.total_sequences,
        "starters" => length(chain.starters)
    )
end

end # module
