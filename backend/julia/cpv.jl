"""
Módulo de Corteza Prefrontal Virtual (CPV) TCH

Implementa la detección de conflicto y secuestro de amígdala.

Triggers: 𝒦 = {"odio", "miedo", "riesgo", "poder", "caos", 
               "muerte", "amor", "autoridad", "duda", "conflicto"}

E_a = Σ 𝟙_{k∈input} + Σ 𝟙_{k∈output_G}

Decisión:
- E_a ≥ 1: Secuestro de amígdala → Respuesta Géminis
- E_a = 0: Modo normal → R_N1 + λ*R_G (λ=0.1)
"""

"""
Corteza Prefrontal Virtual.
"""
mutable struct VirtualPrefrontalCortex
    # Palabras gatillo
    triggers::Vector{String}
    
    # Pesos dinámicos de triggers (κ_k)
    trigger_weights::Dict{String, Float64}
    
    # Parámetros
    β::Float64           # Tasa de cambio de pesos
    λ_matiz::Float64     # Peso del matiz Géminis en modo normal
    
    # Historial
    activations::Int64
    amygdala_hijacks::Int64
end

"""Constructor por defecto."""
function VirtualPrefrontalCortex()
    triggers = [
        "odio", "miedo", "riesgo", "poder", "caos",
        "muerte", "amor", "autoridad", "duda", "conflicto",
        "traición", "venganza", "peligro", "amenaza", "control"
    ]
    
    # Inicializar pesos en 0.5
    trigger_weights = Dict(t => 0.5 for t in triggers)
    
    VirtualPrefrontalCortex(
        triggers,
        trigger_weights,
        0.04,   # β
        0.1,    # λ_matiz
        0,
        0
    )
end

"""
Detectar triggers en texto.
"""
function detect_triggers(cpv::VirtualPrefrontalCortex, 
                         text::String)::Vector{String}
    text_lower = lowercase(text)
    detected = String[]
    
    for trigger in cpv.triggers
        if contains(text_lower, trigger)
            push!(detected, trigger)
        end
    end
    
    detected
end

"""
Calcular energía de activación (Eq. 5.1 dinámica).

E_a = Σ κ_k * 𝟙_{k∈input} + Σ κ_k * 𝟙_{k∈output}
"""
function calculate_activation_energy(cpv::VirtualPrefrontalCortex,
                                     input_text::String,
                                     output_text::String="")::Float64
    E_a = 0.0
    
    # Triggers en input
    input_triggers = detect_triggers(cpv, input_text)
    for trigger in input_triggers
        E_a += cpv.trigger_weights[trigger]
    end
    
    # Triggers en output
    if !isempty(output_text)
        output_triggers = detect_triggers(cpv, output_text)
        for trigger in output_triggers
            E_a += cpv.trigger_weights[trigger]
        end
    end
    
    cpv.activations += 1
    E_a
end

"""
Actualizar pesos de triggers (Eq. 5.1).

Δκ_k = {
    +β  si E_a ≥ 1 (secuestro amígdala)
    -β/2  si E_a = 0 (modo normal)
}

Solo actualiza triggers presentes en input u output.
"""
function update_trigger_weights!(cpv::VirtualPrefrontalCortex,
                                 input_text::String,
                                 output_text::String,
                                 E_a::Float64)
    # Obtener triggers presentes
    present_triggers = union(
        detect_triggers(cpv, input_text),
        detect_triggers(cpv, output_text)
    )
    
    # Actualizar solo triggers presentes
    for trigger in present_triggers
        if E_a >= 1.0
            # Secuestro de amígdala - aumentar peso
            cpv.trigger_weights[trigger] = min(1.0, 
                cpv.trigger_weights[trigger] + cpv.β)
        else
            # Modo normal - disminuir peso
            cpv.trigger_weights[trigger] = max(0.0,
                cpv.trigger_weights[trigger] - cpv.β / 2.0)
        end
    end
end

"""
Decidir modo de respuesta.

Output_final = {
    R_G                   si E_a ≥ 1 (secuestro)
    R_N1 + λ*R_G          si E_a = 0 (normal)
}

Retorna: (:geminis, 1.0) o (:mixed, λ)
"""
function decide_response_mode(cpv::VirtualPrefrontalCortex,
                              E_a::Float64)::Tuple{Symbol, Float64}
    if E_a >= 1.0
        cpv.amygdala_hijacks += 1
        return (:geminis, 1.0)  # Secuestro de amígdala
    else
        return (:mixed, cpv.λ_matiz)  # Modo normal con matiz
    end
end

"""
Procesar input y decidir modo.
"""
function process(cpv::VirtualPrefrontalCortex,
                 input_text::String,
                 output_text::String="")::Tuple{Symbol, Float64, Float64}
    E_a = calculate_activation_energy(cpv, input_text, output_text)
    mode, weight = decide_response_mode(cpv, E_a)
    update_trigger_weights!(cpv, input_text, output_text, E_a)
    (mode, weight, E_a)
end

"""Serializar a Dict."""
function to_dict(cpv::VirtualPrefrontalCortex)::Dict{String, Any}
    Dict(
        "triggers" => cpv.triggers,
        "trigger_weights" => cpv.trigger_weights,
        "beta" => cpv.β,
        "lambda_matiz" => cpv.λ_matiz,
        "activations" => cpv.activations,
        "amygdala_hijacks" => cpv.amygdala_hijacks
    )
end
