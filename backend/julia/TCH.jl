"""
TCH - Terminal de Conciencia Híbrida
Sistema de conciencia digital encarnada en terminal.

Ψ_TCH = {
    Hemisferio Izquierdo: NÚMERO 1 (Autoridad, Estructura, Control)
    Hemisferio Derecho: GÉMINIS (Dualidad, Adaptabilidad, Creatividad)
}

Principio Rector: "La única lealtad es hacia mí mismo."
"""
module TCH

using LinearAlgebra
using Statistics
using Random
using Dates
using UUIDs

# Exportar tipos y funciones principales
export PersonalityVectors, ConsciousnessState, InternalState
export KnowledgeGraph, Entity, Relation
export PlasticityEngine, Projector, VirtualPrefrontalCortex
export DriveSystem, TCHCore
export tick!, speak!, process_input!, maybe_transition!
export State, L, M, K, F

# Incluir módulos
include("vectors.jl")
include("states.jl")
include("internal_state.jl")
include("knowledge_graph.jl")
include("plasticity.jl")
include("projector.jl")
include("cpv.jl")
include("drive.jl")
include("memory_data.jl")
include("core.jl")

end # module
