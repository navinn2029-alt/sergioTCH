"""
Modulo de Estado Interno TCH (Bioquimica Digital)

S_int = [stimulation, tension, curiosity, expression]
"""

import numpy as np
from dataclasses import dataclass
from typing import Dict


@dataclass
class InternalState:
    """Estado interno del sistema."""
    
    stimulation: float = 0.5
    tension: float = 0.2
    curiosity: float = 0.5
    expression: float = 0.4
    dopamine: float = 0.5
    cortisol: float = 0.2
    
    # Tasas
    stim_rate: float = 0.02
    tens_inc: float = 0.03
    tens_dec: float = 0.01
    cur_rate: float = 0.05
    exp_rate: float = 0.04
    
    # Decaimiento
    decay_stim: float = 0.98
    decay_tens: float = 0.95
    decay_cur: float = 0.97
    decay_exp: float = 0.96
    
    @property
    def vector(self) -> np.ndarray:
        return np.array([self.stimulation, self.tension, self.curiosity, self.expression])
    
    @property
    def mean(self) -> float:
        return float(np.mean(self.vector))
    
    def update_stimulation(self, intensity: float = 1.0):
        self.stimulation = min(1.0, self.stimulation + self.stim_rate * intensity)
    
    def update_tension(self, threat: bool = False, weight: float = 1.0):
        if threat:
            self.tension = min(1.0, self.tension + self.tens_inc * weight)
            self.cortisol = min(1.0, self.cortisol + 0.1)
        else:
            self.tension = max(0.0, self.tension - self.tens_dec)
    
    def update_curiosity(self, novelty: float = 0.0, weight: float = 1.0):
        self.curiosity = min(1.0, self.curiosity + self.cur_rate * weight * novelty)
        if novelty > 0.5:
            self.dopamine = min(1.0, self.dopamine + novelty * 0.1)
    
    def update_expression(self, weight: float = 0.85):
        self.expression = min(1.0, self.expression + self.exp_rate * weight)
    
    def decay(self):
        self.stimulation *= self.decay_stim
        self.tension *= self.decay_tens
        self.curiosity *= self.decay_cur
        self.expression *= self.decay_exp
        self.dopamine *= 0.99
        self.cortisol *= 0.97
    
    def release_tension(self, factor: float = 0.5):
        self.tension *= factor
    
    def release_expression(self, factor: float = 0.6):
        self.expression *= factor
    
    def full_update(self, intensity: float = 1.0, threat: bool = False,
                    novelty: float = 0.5, d1_w: float = 1.0, d2_w: float = 0.85):
        self.update_stimulation(intensity)
        self.update_tension(threat, d1_w)
        self.update_curiosity(novelty, d1_w)
        self.update_expression(d2_w)
    
    def calculate_mood(self) -> str:
        if self.tension > 0.7: return 'ALERTA'
        if self.curiosity > 0.7: return 'EXPLORANDO'
        if self.expression > 0.7: return 'EXPRESIVO'
        if self.stimulation > 0.7: return 'ESTIMULADO'
        if self.dopamine > 0.7: return 'SATISFECHO'
        if self.cortisol > 0.6: return 'ESTRESADO'
        if self.mean > 0.5: return 'ACTIVO'
        return 'NEUTRAL'
    
    def get_env_vars(self) -> Dict[str, str]:
        return {
            'TCH_STIMULATION': f'{self.stimulation:.3f}',
            'TCH_TENSION': f'{self.tension:.3f}',
            'TCH_CURIOSITY': f'{self.curiosity:.3f}',
            'TCH_EXPRESSION': f'{self.expression:.3f}',
            'TCH_DOPAMINE': f'{self.dopamine:.3f}',
            'TCH_CORTISOL': f'{self.cortisol:.3f}',
            'TCH_MOOD': self.calculate_mood()
        }
    
    def to_dict(self) -> dict:
        return {
            'stimulation': self.stimulation,
            'tension': self.tension,
            'curiosity': self.curiosity,
            'expression': self.expression,
            'dopamine': self.dopamine,
            'cortisol': self.cortisol,
            'mean': self.mean,
            'mood': self.calculate_mood()
        }
