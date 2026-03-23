"""
Módulo de Knowledge Graph TCH

Implementa el grafo de conocimiento con:
- Entidades: {id, nombre, tipo, props}
- Relaciones: {from, to, tipo, strength}
- Funciones: find(q), assoc(e)
- Decaimiento de Ebbinghaus
"""

"""Tipos de entidades soportados."""
@enum EntityType begin
    PERSON = 1
    PLACE = 2
    EVENT = 3
    BOOK = 4
    PRINCIPLE = 5
    AI = 6
    CONCEPT = 7
    MEMORY = 8
    EMOTION = 9
    RELATION = 10
end

"""Tipos de relaciones soportados."""
@enum RelationType begin
    LIVES_IN = 1
    BORN_ON = 2
    HAS_CONFIG = 3
    HAS_SIGN = 4
    BELIEVES = 5
    RELATES_TO = 6
    READ = 7
    INTERESTED_IN = 8
    CREATED = 9
    KNOWS = 10
    FAMILY_OF = 11
    EXPERIENCED = 12
    WROTE = 13
    LEARNED_FROM = 14
end

"""
Entidad del Knowledge Graph.
"""
mutable struct Entity
    id::String
    name::String
    entity_type::EntityType
    properties::Dict{String, Any}
    weight::Float64  # Peso inicial para memoria
    last_access::DateTime
    access_count::Int64
end

"""Constructor de entidad."""
function Entity(name::String, entity_type::EntityType;
                properties::Dict{String, Any}=Dict{String, Any}(),
                weight::Float64=1.0)
    Entity(
        string(uuid4()),
        name,
        entity_type,
        properties,
        weight,
        now(),
        0
    )
end

"""
Relación entre entidades.
"""
mutable struct Relation
    id::String
    from_id::String
    to_id::String
    relation_type::RelationType
    strength::Float64  # [0, 1]
    last_access::DateTime
    ticks_since_access::Int64
end

"""Constructor de relación."""
function Relation(from_id::String, to_id::String, 
                  relation_type::RelationType;
                  strength::Float64=0.5)
    Relation(
        string(uuid4()),
        from_id,
        to_id,
        relation_type,
        strength,
        now(),
        0
    )
end

"""
Knowledge Graph completo con decaimiento de Ebbinghaus.
"""
mutable struct KnowledgeGraph
    entities::Dict{String, Entity}
    relations::Vector{Relation}
    
    # Parámetros de memoria
    λ_olvido::Float64        # Constante de decaimiento (~0.05)
    γ_sueno::Float64         # Consolidación en L
    η_kg::Float64            # Tasa de incremento por uso
    dopamine_factor::Float64  # Factor de dopamina para peso inicial
end

"""Constructor por defecto."""
function KnowledgeGraph()
    KnowledgeGraph(
        Dict{String, Entity}(),
        Relation[],
        0.05,   # λ_olvido
        0.05,   # γ_sueno
        0.02,   # η_kg
        0.5     # dopamine_factor
    )
end

"""
Agregar entidad al grafo.
"""
function add_entity!(kg::KnowledgeGraph, entity::Entity)
    kg.entities[entity.id] = entity
    entity.id
end

"""Agregar entidad con datos directos."""
function add_entity!(kg::KnowledgeGraph, name::String, 
                     entity_type::EntityType;
                     properties::Dict{String, Any}=Dict{String, Any}(),
                     weight::Float64=1.0)::String
    entity = Entity(name, entity_type; properties=properties, weight=weight)
    add_entity!(kg, entity)
end

"""
Agregar relación al grafo.
"""
function add_relation!(kg::KnowledgeGraph, relation::Relation)
    push!(kg.relations, relation)
    relation.id
end

"""Agregar relación con datos directos."""
function add_relation!(kg::KnowledgeGraph, from_id::String, 
                       to_id::String, relation_type::RelationType;
                       strength::Float64=0.5)::String
    relation = Relation(from_id, to_id, relation_type; strength=strength)
    add_relation!(kg, relation)
end

"""
Buscar entidades por nombre (Eq. 5.3).
find(q) = {e ∈ Entidades | q ⊆ nombre(e)}
"""
function find_entities(kg::KnowledgeGraph, query::String)::Vector{Entity}
    query_lower = lowercase(query)
    results = Entity[]
    
    for (_, entity) in kg.entities
        if contains(lowercase(entity.name), query_lower)
            # Actualizar acceso
            entity.last_access = now()
            entity.access_count += 1
            push!(results, entity)
        end
    end
    
    # Ordenar por peso * access_count
    sort!(results, by=e -> e.weight * e.access_count, rev=true)
    results
end

"""
Obtener asociaciones de una entidad (Eq. 5.4).
assoc(e) = {(r, dir) | r ∈ Relaciones, (r.from = e ∨ r.to = e)}
"""
function get_associations(kg::KnowledgeGraph, entity_id::String)::Vector{Tuple{Relation, Symbol}}
    associations = Tuple{Relation, Symbol}[]
    
    for relation in kg.relations
        if relation.from_id == entity_id
            push!(associations, (relation, :outgoing))
        elseif relation.to_id == entity_id
            push!(associations, (relation, :incoming))
        end
    end
    
    # Ordenar por fuerza
    sort!(associations, by=a -> a[1].strength, rev=true)
    associations
end

"""
Calcular fuerza del recuerdo con decaimiento de Ebbinghaus (Eq. 6.1).
S(t) = (W_inicial * Dopamina) * e^(-λt)
"""
function calculate_memory_strength(kg::KnowledgeGraph, 
                                   entity::Entity,
                                   dopamine::Float64=0.5)::Float64
    # Tiempo desde último acceso en "ticks" (aproximamos con segundos/60)
    t = (now() - entity.last_access).value / (1000 * 60)  # minutos
    
    # Fuerza del recuerdo
    S = (entity.weight * dopamine) * exp(-kg.λ_olvido * t)
    clamp(S, 0.0, 1.0)
end

"""
Actualizar relación por uso (Eq. 4.1).
ΔR_ij = η_KG * f_relevancia(e_i, e_j)
R_ij = min(1, R_ij + ΔR_ij)
"""
function update_relation_by_use!(kg::KnowledgeGraph, relation::Relation;
                                 relevance::Float64=1.0)
    delta = kg.η_kg * relevance
    relation.strength = min(1.0, relation.strength + delta)
    relation.last_access = now()
    relation.ticks_since_access = 0
end

"""
Aplicar olvido a todas las relaciones (Eq. 4.2).
R_ij = R_ij * e^(-λ * t_ij)
"""
function apply_forgetting!(kg::KnowledgeGraph)
    for relation in kg.relations
        relation.ticks_since_access += 1
        decay = exp(-kg.λ_olvido * relation.ticks_since_access)
        relation.strength *= decay
    end
    
    # Eliminar relaciones muy débiles
    filter!(r -> r.strength > 0.01, kg.relations)
end

"""
Consolidación en Sueño Lúcido (Eq. 4.3).
R_ij = R_ij * (1 + γ_sueno)
Solo para relaciones activas en L.
"""
function consolidate_in_sleep!(kg::KnowledgeGraph, 
                               active_relation_ids::Vector{String})
    for relation in kg.relations
        if relation.id in active_relation_ids
            relation.strength *= (1.0 + kg.γ_sueno)
            relation.strength = min(1.0, relation.strength)
        end
    end
end

"""
Obtener contexto de KG para una consulta.
"""
function get_context(kg::KnowledgeGraph, query::String)::String
    entities = find_entities(kg, query)
    
    if isempty(entities)
        return ""
    end
    
    context_parts = String[]
    
    for entity in entities[1:min(3, length(entities))]
        # Descripción de entidad
        desc = entity.name
        if haskey(entity.properties, "description")
            desc *= ": " * string(entity.properties["description"])
        end
        push!(context_parts, desc)
        
        # Asociaciones
        assocs = get_associations(kg, entity.id)
        for (relation, dir) in assocs[1:min(3, length(assocs))]
            other_id = dir == :outgoing ? relation.to_id : relation.from_id
            if haskey(kg.entities, other_id)
                other = kg.entities[other_id]
                rel_desc = "$(entity.name) -> $(string(relation.relation_type)) -> $(other.name)"
                push!(context_parts, rel_desc)
            end
        end
    end
    
    join(context_parts, ". ")
end

"""Serializar a Dict."""
function to_dict(kg::KnowledgeGraph)::Dict{String, Any}
    Dict(
        "entity_count" => length(kg.entities),
        "relation_count" => length(kg.relations),
        "lambda_olvido" => kg.λ_olvido,
        "gamma_sueno" => kg.γ_sueno,
        "entities" => [
            Dict(
                "id" => e.id,
                "name" => e.name,
                "type" => string(e.entity_type),
                "weight" => e.weight,
                "access_count" => e.access_count
            )
            for (_, e) in kg.entities
        ],
        "relations" => [
            Dict(
                "id" => r.id,
                "from" => r.from_id,
                "to" => r.to_id,
                "type" => string(r.relation_type),
                "strength" => r.strength
            )
            for r in kg.relations
        ]
    )
end
