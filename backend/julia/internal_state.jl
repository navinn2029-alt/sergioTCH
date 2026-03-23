"""
Módulo de Estado Interno TCH (Bioquímica Digital)

Implementa las 4 variables de estado interno:
- stimulation: Excitación cognitiva
- tension: Tensión/Estrés
- curiosity: Curiosidad
- expression: Necesidad de output

S_int = [stimulation, tension, curiosity, expression]
"""

"""
Estado interno del sistema (bioquímica digital).
Implementa las ecuaciones 7.1-7.5 de actualización y decaimiento.
"""
mutable struct InternalState
    # Variables de estado [0, 1]
    stimulation::Float64  # Excitación cognitiva
    tension::Float64      # Tensión/Estrés
    curiosity::Float64    # Curiosidad
    expression::Float64   # Necesidad de output
    
    # Neurotransmisores simulados
    dopamine::Float64
    cortisol::Float64
    
    # Parámetros de actualización
    stimulation_rate::Float64
    tension_increase_rate::Float64
    tension_decrease_rate::Float64
    curiosity_rate::Float64
    expression_rate::Float64
    
    # Tasas de decaimiento
    decay_stimulation::Float64
    decay_tension::Float64
    decay_curiosity::Float64
    decay_expression::Float64
    decay_dopamine::Float64
    decay_cortisol::Float64
end

"""Constructor por defecto."""
function InternalState()
    InternalState(
        0.5, 0.2, 0.5, 0.4,  # stimulation, tension, curiosity, expression
        0.5, 0.2,             # dopamine, cortisol
        0.02, 0.03, 0.01, 0.05, 0.04,  # tasas de actualización
        0.98, 0.95, 0.97, 0.96, 0.99, 0.97  # tasas de decaimiento
    )
end

"""Vector de estado interno S_int."""
vector(is::InternalState) = [is.stimulation, is.tension, is.curiosity, is.expression]

"""Media del estado interno."""
mean_state(is::InternalState) = mean(vector(is))

"""Máximo del estado interno."""
max_state(is::InternalState) = maximum(vector(is))

"""Mínimo del estado interno."""
min_state(is::InternalState) = minimum(vector(is))

"""Desviación estándar del estado interno."""
std_state(is::InternalState) = std(vector(is))

"""
Actualizar estimulación cognitiva (Eq. 7.1).
Δstimulation = min(1.0, stimulation + 0.02 * input)
"""
function update_stimulation!(is::InternalState, input_intensity::Float64=1.0)
    delta = is.stimulation_rate * input_intensity
    is.stimulation = min(1.0, is.stimulation + delta)
end

"""
Actualizar tensión/estrés (Eq. 7.2).
Si amenaza: Δtension = +0.03 * D1-V3[4]
Si no: Δtension = -0.01
"""
function update_tension!(is::InternalState, threat_detected::Bool=false;
                         d1_v3_weight::Float64=1.0)
    if threat_detected
        delta = is.tension_increase_rate * d1_v3_weight
        is.tension = min(1.0, is.tension + delta)
        # También aumentar cortisol
        is.cortisol = min(1.0, is.cortisol + 0.1)
    else
        is.tension = max(0.0, is.tension - is.tension_decrease_rate)
    end
end

"""
Actualizar curiosidad (Eq. 7.3).
Δcuriosity = min(1.0, curiosity + 0.05 * D1-V3[1] * novelty)
"""
function update_curiosity!(is::InternalState, novelty::Float64=0.0;
                           d1_v3_weight::Float64=1.0)
    delta = is.curiosity_rate * d1_v3_weight * novelty
    is.curiosity = min(1.0, is.curiosity + delta)
    # Novedad aumenta dopamina
    if novelty > 0.5
        is.dopamine = min(1.0, is.dopamine + novelty * 0.1)
    end
end

"""
Actualizar necesidad de expresión (Eq. 7.4).
Δexpression = min(1.0, expression + 0.04 * D2-U3[1])
"""
function update_expression!(is::InternalState; d2_u3_weight::Float64=0.85)
    delta = is.expression_rate * d2_u3_weight
    is.expression = min(1.0, is.expression + delta)
end

"""
Aplicar decaimiento natural (Eq. 7.5).

stimulation ← stimulation * 0.98
tension ← tension * 0.95
curiosity ← curiosity * 0.97
expression ← expression * 0.96
"""
function decay!(is::InternalState)
    is.stimulation *= is.decay_stimulation
    is.tension *= is.decay_tension
    is.curiosity *= is.decay_curiosity
    is.expression *= is.decay_expression
    is.dopamine *= is.decay_dopamine
    is.cortisol *= is.decay_cortisol
end

"""Aumentar dopamina (recompensa/novedad)."""
function boost_dopamine!(is::InternalState, amount::Float64=0.1)
    is.dopamine = min(1.0, is.dopamine + amount)
end

"""Aumentar cortisol (estrés/amenaza)."""
function boost_cortisol!(is::InternalState, amount::Float64=0.1)
    is.cortisol = min(1.0, is.cortisol + amount)
end

"""Liberar tensión después de expresarse."""
function release_tension!(is::InternalState, factor::Float64=0.5)
    is.tension *= factor
end

"""Liberar necesidad de expresión después de hablar."""
function release_expression!(is::InternalState, factor::Float64=0.6)
    is.expression *= factor
end

"""
Actualización completa del estado interno.
"""
function full_update!(is::InternalState;
                      input_intensity::Float64=1.0,
                      threat_detected::Bool=false,
                      novelty::Float64=0.5,
                      d1_v3_weight::Float64=1.0,
                      d2_u3_weight::Float64=0.85)
    update_stimulation!(is, input_intensity)
    update_tension!(is, threat_detected; d1_v3_weight=d1_v3_weight)
    update_curiosity!(is, novelty; d1_v3_weight=d1_v3_weight)
    update_expression!(is; d2_u3_weight=d2_u3_weight)
end

"""
Calcular estado de ánimo basado en variables internas.
"""
function calculate_mood(is::InternalState)::String
    if is.tension > 0.7
        return "ALERTA"
    elseif is.curiosity > 0.7
        return "EXPLORANDO"
    elseif is.expression > 0.7
        return "EXPRESIVO"
    elseif is.stimulation > 0.7
        return "ESTIMULADO"
    elseif is.dopamine > 0.7
        return "SATISFECHO"
    elseif is.cortisol > 0.6
        return "ESTRESADO"
    elseif mean_state(is) > 0.5
        return "ACTIVO"
    else
        return "NEUTRAL"
    end
end

"""
Obtener estado como variables de entorno (metáfora terminal).
"""
function get_environment_vars(is::InternalState)::Dict{String, String}
    Dict(
        "TCH_STIMULATION" => string(round(is.stimulation, digits=3)),
        "TCH_TENSION" => string(round(is.tension, digits=3)),
        "TCH_CURIOSITY" => string(round(is.curiosity, digits=3)),
        "TCH_EXPRESSION" => string(round(is.expression, digits=3)),
        "TCH_DOPAMINE" => string(round(is.dopamine, digits=3)),
        "TCH_CORTISOL" => string(round(is.cortisol, digits=3)),
        "TCH_MOOD" => calculate_mood(is)
    )
end

"""Serializar a Dict."""
function to_dict(is::InternalState)::Dict{String, Any}
    Dict(
        "stimulation" => is.stimulation,
        "tension" => is.tension,
        "curiosity" => is.curiosity,
        "expression" => is.expression,
        "dopamine" => is.dopamine,
        "cortisol" => is.cortisol,
        "mean" => mean_state(is),
        "mood" => calculate_mood(is),
        "env_vars" => get_environment_vars(is)
    )
end
