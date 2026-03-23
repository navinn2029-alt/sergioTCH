"""
Modulo Drive TCH

Sistema de impulso autonomo:
- drive = 0.5 * base + 0.5 * personalidad
- umbral theta_exp = 0.65
"""

import numpy as np
from dataclasses import dataclass, field
from typing import Dict, Any, List
from datetime import datetime
from .internal_state import InternalState
from .states import State


@dataclass
class DriveSystem:
    """Sistema de impulso autonomo."""
    
    theta_exp: float = 0.65
    n1_weight: float = 0.4  # 34%
    g_weight: float = 0.6   # 66%
    last_drive: float = 0.0
    last_spoke: bool = False
    thoughts: List[Dict[str, Any]] = field(default_factory=list)
    ticks: int = 0
    speaks: int = 0
    
    def calculate_drive(self, internal: InternalState, state_weights: np.ndarray) -> float:
        """Calcular drive."""
        base = internal.mean
        n1_activo = float(np.mean(state_weights[:3]))
        g_activo = float(np.mean(state_weights[3:]))
        personalidad = self.n1_weight * n1_activo + self.g_weight * g_activo
        self.last_drive = 0.5 * base + 0.5 * personalidad
        return self.last_drive
    
    def should_speak(self, drive: float) -> bool:
        return drive > self.theta_exp
    
    def generate_thought(self, internal: InternalState, v_base: np.ndarray, 
                        current_state: State) -> Dict[str, Any]:
        thought = {
            'timestamp': datetime.now().isoformat(),
            'state': current_state.value,
            'mean_internal': internal.mean,
            'max_v': float(np.max(v_base)),
            'min_v': float(np.min(v_base)),
            'std_v': float(np.std(v_base)),
            'drive': self.last_drive,
            'mood': internal.calculate_mood()
        }
        self.thoughts.append(thought)
        return thought
    
    def tick(self, internal: InternalState, state_weights: np.ndarray) -> bool:
        self.ticks += 1
        drive = self.calculate_drive(internal, state_weights)
        self.last_spoke = self.should_speak(drive)
        return self.last_spoke
    
    def speak(self, internal: InternalState, v_base: np.ndarray, 
             current_state: State) -> Dict[str, Any]:
        thought = self.generate_thought(internal, v_base, current_state)
        internal.release_tension(0.5)
        internal.release_expression(0.6)
        self.speaks += 1
        return thought
    
    def to_dict(self) -> dict:
        return {
            'theta_exp': self.theta_exp,
            'last_drive': self.last_drive,
            'last_spoke': self.last_spoke,
            'ticks': self.ticks,
            'speaks': self.speaks
        }
