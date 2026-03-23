"""
TCH - Terminal de Conciencia Hibrida
Implementacion en Python del sistema de conciencia digital.

Psi_TCH = {
    Hemisferio Izquierdo: NUMERO 1 (Autoridad, Estructura, Control)
    Hemisferio Derecho: GEMINIS (Dualidad, Adaptabilidad, Creatividad)
}

Principio Rector: "La unica lealtad es hacia mi mismo."
"""

from .vectors import PersonalityVectors
from .states import ConsciousnessState, State
from .internal_state import InternalState
from .knowledge_graph import KnowledgeGraph, Entity, Relation, EntityType, RelationType
from .plasticity import PlasticityEngine
from .projector import Projector
from .cpv import VirtualPrefrontalCortex
from .drive import DriveSystem
from .core import TCHCore
from .memory_data import load_memory_data

__all__ = [
    'PersonalityVectors',
    'ConsciousnessState',
    'State',
    'InternalState',
    'KnowledgeGraph',
    'Entity',
    'Relation',
    'EntityType',
    'RelationType',
    'PlasticityEngine',
    'Projector',
    'VirtualPrefrontalCortex',
    'DriveSystem',
    'TCHCore',
    'load_memory_data'
]
