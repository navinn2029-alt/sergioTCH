"""
Modulo de Knowledge Graph TCH

Grafo de conocimiento con:
- Entidades: {id, nombre, tipo, props}
- Relaciones: {from, to, tipo, strength}
- Decaimiento de Ebbinghaus
"""

import numpy as np
from enum import Enum
from dataclasses import dataclass, field
from typing import Dict, List, Tuple, Any, Optional
from datetime import datetime
import uuid
import math


class EntityType(Enum):
    PERSON = "PERSON"
    PLACE = "PLACE"
    EVENT = "EVENT"
    BOOK = "BOOK"
    PRINCIPLE = "PRINCIPLE"
    CONCEPT = "CONCEPT"
    MEMORY = "MEMORY"
    EMOTION = "EMOTION"


class RelationType(Enum):
    LIVES_IN = "LIVES_IN"
    BORN_ON = "BORN_ON"
    HAS_CONFIG = "HAS_CONFIG"
    BELIEVES = "BELIEVES"
    RELATES_TO = "RELATES_TO"
    READ = "READ"
    INTERESTED_IN = "INTERESTED_IN"
    CREATED = "CREATED"
    KNOWS = "KNOWS"
    FAMILY_OF = "FAMILY_OF"
    EXPERIENCED = "EXPERIENCED"
    WROTE = "WROTE"
    LEARNED_FROM = "LEARNED_FROM"


@dataclass
class Entity:
    id: str
    name: str
    entity_type: EntityType
    properties: Dict[str, Any] = field(default_factory=dict)
    weight: float = 1.0
    last_access: datetime = field(default_factory=datetime.now)
    access_count: int = 0
    
    @classmethod
    def create(cls, name: str, entity_type: EntityType, 
               properties: Dict = None, weight: float = 1.0):
        return cls(
            id=str(uuid.uuid4())[:8],
            name=name,
            entity_type=entity_type,
            properties=properties or {},
            weight=weight
        )


@dataclass
class Relation:
    id: str
    from_id: str
    to_id: str
    relation_type: RelationType
    strength: float = 0.5
    last_access: datetime = field(default_factory=datetime.now)
    ticks_since_access: int = 0
    
    @classmethod
    def create(cls, from_id: str, to_id: str, 
               relation_type: RelationType, strength: float = 0.5):
        return cls(
            id=str(uuid.uuid4())[:8],
            from_id=from_id,
            to_id=to_id,
            relation_type=relation_type,
            strength=strength
        )


class KnowledgeGraph:
    """Knowledge Graph con decaimiento de Ebbinghaus."""
    
    def __init__(self):
        self.entities: Dict[str, Entity] = {}
        self.relations: List[Relation] = []
        self.lambda_olvido = 0.05
        self.gamma_sueno = 0.05
        self.eta_kg = 0.02
    
    def add_entity(self, name: str, entity_type: EntityType, 
                   properties: Dict = None, weight: float = 1.0) -> str:
        entity = Entity.create(name, entity_type, properties, weight)
        self.entities[entity.id] = entity
        return entity.id
    
    def add_relation(self, from_id: str, to_id: str, 
                     relation_type: RelationType, strength: float = 0.5) -> str:
        relation = Relation.create(from_id, to_id, relation_type, strength)
        self.relations.append(relation)
        return relation.id
    
    def find_entities(self, query: str) -> List[Entity]:
        """Buscar entidades por nombre."""
        query_lower = query.lower()
        results = []
        for entity in self.entities.values():
            if query_lower in entity.name.lower():
                entity.last_access = datetime.now()
                entity.access_count += 1
                results.append(entity)
        return sorted(results, key=lambda e: e.weight * e.access_count, reverse=True)
    
    def get_associations(self, entity_id: str) -> List[Tuple[Relation, str]]:
        """Obtener relaciones de una entidad."""
        results = []
        for rel in self.relations:
            if rel.from_id == entity_id:
                results.append((rel, 'outgoing'))
            elif rel.to_id == entity_id:
                results.append((rel, 'incoming'))
        return sorted(results, key=lambda x: x[0].strength, reverse=True)
    
    def calculate_memory_strength(self, entity: Entity, dopamine: float = 0.5) -> float:
        """S(t) = (W * Dopamina) * e^(-lambda*t)"""
        t = (datetime.now() - entity.last_access).total_seconds() / 60
        S = (entity.weight * dopamine) * math.exp(-self.lambda_olvido * t)
        return max(0.0, min(1.0, S))
    
    def update_relation_by_use(self, relation: Relation, relevance: float = 1.0):
        """Incrementar fuerza por uso."""
        delta = self.eta_kg * relevance
        relation.strength = min(1.0, relation.strength + delta)
        relation.last_access = datetime.now()
        relation.ticks_since_access = 0
    
    def apply_forgetting(self):
        """Aplicar olvido a todas las relaciones."""
        for rel in self.relations:
            rel.ticks_since_access += 1
            decay = math.exp(-self.lambda_olvido * rel.ticks_since_access)
            rel.strength *= decay
        self.relations = [r for r in self.relations if r.strength > 0.01]
    
    def consolidate_in_sleep(self, active_ids: List[str]):
        """Consolidacion en Sueno Lucido."""
        for rel in self.relations:
            if rel.id in active_ids:
                rel.strength = min(1.0, rel.strength * (1 + self.gamma_sueno))
    
    def get_context(self, query: str) -> str:
        """Obtener contexto para una consulta."""
        entities = self.find_entities(query)
        if not entities:
            return ""
        
        parts = []
        for entity in entities[:3]:
            desc = entity.name
            if 'description' in entity.properties:
                desc += f": {entity.properties['description']}"
            parts.append(desc)
            
            assocs = self.get_associations(entity.id)
            for rel, direction in assocs[:2]:
                other_id = rel.to_id if direction == 'outgoing' else rel.from_id
                if other_id in self.entities:
                    other = self.entities[other_id]
                    parts.append(f"{entity.name} -> {rel.relation_type.value} -> {other.name}")
        
        return ". ".join(parts)
    
    def to_dict(self) -> dict:
        return {
            'entity_count': len(self.entities),
            'relation_count': len(self.relations),
            'entities': [
                {'id': e.id, 'name': e.name, 'type': e.entity_type.value, 'weight': e.weight}
                for e in self.entities.values()
            ][:20],
            'relations': [
                {'from': r.from_id, 'to': r.to_id, 'type': r.relation_type.value, 'strength': r.strength}
                for r in self.relations
            ][:20]
        }
