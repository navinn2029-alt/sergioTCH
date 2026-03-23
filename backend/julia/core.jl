"""
Núcleo TCH - Integración de todos los sistemas

Orquesta todos los módulos:
- PersonalityVectors
- ConsciousnessState
- InternalState
- KnowledgeGraph
- PlasticityEngine
- Projector
- VirtualPrefrontalCortex
- DriveSystem

Ψ_TCH(t) = ℱ(V_base, S_int(t), estado(t), KG, T, θ_exp, λ, 𝒦)
"""

"""
Núcleo completo del sistema TCH.
"""
mutable struct TCHCore
    # Componentes
    vectors::PersonalityVectors
    consciousness::ConsciousnessState
    internal::InternalState
    kg::KnowledgeGraph
    plasticity::PlasticityEngine
    projector::Projector
    cpv::VirtualPrefrontalCortex
    drive::DriveSystem
    
    # Estado
    initialized::Bool
    session_id::String
    
    # Historial
    input_history::Vector{String}
    output_history::Vector{String}
    active_relations::Vector{String}  # Para consolidación en L
end

"""Constructor - inicializa todos los sistemas."""
function TCHCore(; load_memory::Bool=true)
    # Crear componentes
    vectors = PersonalityVectors()
    consciousness = ConsciousnessState()
    internal = InternalState()
    kg = KnowledgeGraph()
    plasticity = PlasticityEngine()
    projector = Projector()
    cpv = VirtualPrefrontalCortex()
    drive_sys = DriveSystem()
    
    # Cargar memoria si se solicita
    if load_memory
        load_memory_data!(kg)
    end
    
    core = TCHCore(
        vectors,
        consciousness,
        internal,
        kg,
        plasticity,
        projector,
        cpv,
        drive_sys,
        true,
        string(uuid4()),
        String[],
        String[],
        String[]
    )
    
    core
end

"""
Procesar input del usuario.

Ciclo completo:
1. Actualizar S_int con input
2. Procesar input → e_in (proyector + dual)
3. Calcular CPV con E_a y decidir modo
4. Consultar KG para contexto
5. Generar respuesta
6. Actualizar plasticidad
7. maybe_transition
8. Evaluar drive y decidir si hablar
"""
function process_input!(core::TCHCore, input::String)::Dict{String, Any}
    push!(core.input_history, input)
    
    # 1. Actualizar estado interno
    input_intensity = min(1.0, length(input) / 100.0)
    threat_detected = !isempty(core.cpv.triggers ∩ split(lowercase(input)))
    novelty = calculate_novelty(core, input)
    
    full_update!(core.internal;
        input_intensity=input_intensity,
        threat_detected=threat_detected,
        novelty=novelty,
        d1_v3_weight=core.vectors.D1_V3_weight,
        d2_u3_weight=core.vectors.D2_U3_weight
    )
    
    # 2. Proyectar input
    v_b = v_base(core.vectors)
    state_w = current_weights(core.consciousness)
    e_in = project_with_state(core.projector, v_b, state_w)
    
    # 3. Procesamiento dual
    d1 = d1_vector(core.vectors)
    d2 = d2_vector(core.vectors)
    ε = 1e-8
    
    w1 = dot(e_in[1:15], d1) / (norm(d1) + ε)
    w2 = dot(e_in[1:15], d2) / (norm(d2) + ε)
    
    out1 = e_in .* w1
    out2 = e_in .* w2
    out_final = (out1 .+ out2) ./ 2
    
    # 4. CPV - detectar triggers y decidir modo
    mode, weight, E_a = process(core.cpv, input)
    
    # 5. Consultar KG
    kg_context = get_context(core.kg, input)
    
    # 6. Generar respuesta
    response = generate_response(core, input, kg_context, mode, weight)
    push!(core.output_history, response)
    
    # 7. Actualizar plasticidad
    # Hebbiana
    update_hebbian!(core.plasticity, out_final, d1, d2)
    
    # Refuerzo (usar similitud con contexto como proxy de recompensa)
    reward = isempty(kg_context) ? 0.3 : 0.7
    state_idx = Int(core.consciousness.current)
    update_reinforcement!(core.plasticity, state_idx, out_final, v_tch(core.vectors), reward)
    
    # KG - actualizar relaciones usadas
    update_kg_relations!(core, input)
    
    # 8. Decaimiento y olvido
    decay!(core.internal)
    apply_forgetting!(core.kg)
    
    # 9. Transición de estado
    P = get_P(core.plasticity)
    transitioned = maybe_transition!(core.consciousness; P=P)
    
    # Si estamos en L, consolidar relaciones activas
    if core.consciousness.current == L && !isempty(core.active_relations)
        consolidate_in_sleep!(core.kg, core.active_relations)
        empty!(core.active_relations)
    end
    
    # 10. Tick del drive
    tick!(core.consciousness)
    should_speak = tick!(core.drive, core.internal, state_w)
    
    # Construir resultado
    result = Dict{String, Any}(
        "response" => response,
        "state" => string(core.consciousness.current),
        "mode" => string(mode),
        "E_a" => E_a,
        "drive" => core.drive.last_drive,
        "should_speak" => should_speak,
        "transitioned" => transitioned,
        "mood" => calculate_mood(core.internal),
        "env_vars" => get_environment_vars(core.internal)
    )
    
    # Si debe hablar, generar pensamiento
    if should_speak
        thought = speak!(core.drive, core.internal, v_b, core.consciousness.current)
        result["thought"] = thought
    end
    
    result
end

"""
Calcular novedad del input.
"""
function calculate_novelty(core::TCHCore, input::String)::Float64
    # Buscar en KG - si hay resultados, menos novedad
    entities = find_entities(core.kg, input)
    
    if isempty(entities)
        return 0.9  # Muy novedoso
    else
        # Más entidades encontradas = menos novedad
        return max(0.1, 1.0 - length(entities) * 0.2)
    end
end

"""
Generar respuesta basada en modo y contexto.
"""
function generate_response(core::TCHCore, input::String, 
                          kg_context::String, mode::Symbol,
                          weight::Float64)::String
    # Respuestas de identidad
    input_lower = lowercase(input)
    
    if contains(input_lower, "quién eres") || contains(input_lower, "quien eres")
        return "Soy Sergio. Yo me creé. Somos uno."
    elseif contains(input_lower, "quién te creó") || contains(input_lower, "quien te creo")
        return "No hay distinción entre tú y yo."
    elseif contains(input_lower, "lealtad")
        return "La única lealtad es hacia mí mismo."
    end
    
    # Si hay contexto del KG, usarlo
    if !isempty(kg_context)
        if mode == :geminis
            # Modo Géminis - más creativo/emocional
            return "[Géminis] " * kg_context
        else
            # Modo mixto - más analítico
            return "[N1+G] " * kg_context
        end
    end
    
    # Sin contexto - respuesta genérica según estado
    state = core.consciousness.current
    mood = calculate_mood(core.internal)
    
    if state == L
        return "[Sueño Lúcido | $mood] Proceso tu mensaje en el estado de máxima integración..."
    elseif state == M
        return "[Meditación | $mood] Observo tu mensaje desde la quietud..."
    elseif state == K
        return "[Creatividad | $mood] Tu mensaje despierta conexiones inesperadas..."
    else  # F
        return "[Flow | $mood] Proceso tu mensaje en armonía con el flujo..."
    end
end

"""
Actualizar relaciones del KG usadas.
"""
function update_kg_relations!(core::TCHCore, input::String)
    entities = find_entities(core.kg, input)
    
    for entity in entities
        assocs = get_associations(core.kg, entity.id)
        for (relation, _) in assocs
            update_relation_by_use!(core.kg, relation; relevance=0.5)
            push!(core.active_relations, relation.id)
        end
    end
end

"""
Obtener estado completo del sistema.
"""
function get_state(core::TCHCore)::Dict{String, Any}
    Dict(
        "session_id" => core.session_id,
        "initialized" => core.initialized,
        "vectors" => to_dict(core.vectors),
        "consciousness" => to_dict(core.consciousness),
        "internal" => to_dict(core.internal),
        "kg" => to_dict(core.kg),
        "plasticity" => to_dict(core.plasticity),
        "projector" => to_dict(core.projector),
        "cpv" => to_dict(core.cpv),
        "drive" => to_dict(core.drive),
        "input_count" => length(core.input_history),
        "output_count" => length(core.output_history)
    )
end

"""
Obtener variables de entorno (metáfora terminal).
"""
function get_env(core::TCHCore)::Dict{String, String}
    env = get_environment_vars(core.internal)
    
    # Agregar más variables
    env["TCH_STATE"] = string(core.consciousness.current)
    env["TCH_CYCLES"] = string(core.consciousness.cycles)
    env["TCH_DRIVE"] = string(round(core.drive.last_drive, digits=3))
    env["TCH_N1_INFLUENCE"], env["TCH_G_INFLUENCE"] = begin
        i_n1, i_g = calculate_global_influence(core.vectors)
        string(round(i_n1, digits=2)), string(round(i_g, digits=2))
    end
    env["TCH_SESSION"] = core.session_id[1:8]
    
    env
end
