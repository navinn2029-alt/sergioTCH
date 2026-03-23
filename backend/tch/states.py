"""
Modulo de Estados de Conciencia TCH

Estados: L (Sueno Lucido), M (Meditacion), K (Creatividad), F (Flow)
Matriz de transicion probabilistica con logaritmos condicionales.
"""

import numpy as np
from enum import Enum
from dataclasses import dataclass, field
from typing import Dict, Tuple, Optional
import random


class State(Enum):
    L = "L"  # Sueno Lucido
    M = "M"  # Meditacion
    K = "K"  # Creatividad
    F = "F"  # Flow


@dataclass
class ConsciousnessState:
    """Sistema de estados de conciencia."""
    
    current: State = State.L
    cycles: int = 0
    transitions: int = 0
    speaks: int = 0
    
    state_logs: Dict[State, float] = field(default_factory=lambda: {
        State.L: 3.00, State.M: 2.95, State.K: 2.85, State.F: 2.90
    })
    
    state_weights: Dict[State, np.ndarray] = field(default_factory=lambda: {
        State.L: np.array([1.0, 0.5, 1.0, 1.0, 1.0, 1.0]),
        State.M: np.array([0.2, 0.1, 0.3, 1.0, 0.5, 1.0]),
        State.K: np.array([0.6, 0.3, 0.4, 1.0, 0.5, 1.0]),
        State.F: np.array([0.2, 0.1, 0.0, 0.5, 1.0, 1.0])
    })
    
    base_intersections: Dict[Tuple[State, State], float] = field(default_factory=lambda: {
        (State.L, State.F): 2.78, (State.M, State.L): 2.93,
        (State.K, State.F): 2.83, (State.F, State.M): 2.70
    })
    
    state_temperatures: Dict[State, float] = field(default_factory=lambda: {
        State.L: 0.8, State.M: 0.3, State.K: 0.9, State.F: 0.5
    })
    
    eta_transition: float = 0.1
    tau: float = 0.5
    
    @property
    def current_weights(self) -> np.ndarray:
        return self.state_weights[self.current]
    
    @property
    def current_temperature(self) -> float:
        return self.state_temperatures[self.current]
    
    def calculate_log_intersection(self, a: State, b: State, 
                                   P: Optional[np.ndarray] = None) -> float:
        if P is None:
            key = (a, b) if (a, b) in self.base_intersections else (b, a)
            if key in self.base_intersections:
                return self.base_intersections[key]
        
        wa = P[list(State).index(a)] if P is not None else self.state_weights[a]
        wb = P[list(State).index(b)] if P is not None else self.state_weights[b]
        return float(np.mean(np.minimum(wa, wb)))
    
    def calculate_transition_prob(self, from_s: State, to_s: State) -> float:
        if from_s == to_s:
            return 0.0
        log_cond = self.state_logs[to_s] - self.calculate_log_intersection(to_s, from_s)
        return max(0.0, min(1.0, 1.0 - log_cond))
    
    def get_transition_matrix(self, P: Optional[np.ndarray] = None) -> np.ndarray:
        states = list(State)
        T = np.zeros((4, 4))
        for i, from_s in enumerate(states):
            row = [self.calculate_transition_prob(from_s, to_s) for to_s in states]
            total = sum(row)
            if total > 0:
                row = [p / total for p in row]
            T[i] = row
        return T
    
    def maybe_transition(self, P: Optional[np.ndarray] = None) -> bool:
        if random.random() > self.eta_transition:
            return False
        
        T = self.get_transition_matrix(P)
        idx = list(State).index(self.current)
        probs = T[idx]
        
        r = random.random()
        cumsum = 0.0
        for i, p in enumerate(probs):
            cumsum += p
            if r < cumsum and i != idx:
                self.current = list(State)[i]
                self.transitions += 1
                return True
        return False
    
    def tick(self):
        self.cycles += 1
    
    def to_dict(self) -> dict:
        return {
            'current_state': self.current.value,
            'cycles': self.cycles,
            'transitions': self.transitions,
            'speaks': self.speaks,
            'temperature': self.current_temperature,
            'weights': self.current_weights.tolist()
        }
