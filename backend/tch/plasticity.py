"""
Modulo de Plasticidad TCH

Canales aprendibles:
1. Hemisferico (D1-D2): W_12 - Hebbiana
2. Estado-Vector: P - Refuerzo
"""

import numpy as np
from dataclasses import dataclass, field


@dataclass
class PlasticityEngine:
    """Motor de plasticidad."""
    
    W_12: np.ndarray = field(default_factory=lambda: np.eye(15) * 0.1)
    P: np.ndarray = field(default_factory=lambda: np.array([
        [1.0, 0.5, 1.0, 1.0, 1.0, 1.0],
        [0.2, 0.1, 0.3, 1.0, 0.5, 1.0],
        [0.6, 0.3, 0.4, 1.0, 0.5, 1.0],
        [0.2, 0.1, 0.0, 0.5, 1.0, 1.0]
    ]))
    
    eta_hebb: float = 0.015
    alpha_refuerzo: float = 0.03
    beta_trigger: float = 0.04
    r_hat: float = 0.5
    r_count: int = 0
    hebb_updates: int = 0
    refuerzo_updates: int = 0
    
    def update_hebbian(self, e_in: np.ndarray, d1: np.ndarray, d2: np.ndarray, eps: float = 1e-8):
        """Plasticidad Hebbiana."""
        e_15 = e_in[:15] if len(e_in) >= 15 else np.pad(e_in, (0, 15-len(e_in)))
        a1 = np.dot(e_15, d1) / (np.linalg.norm(d1) + eps)
        a2 = np.dot(e_15, d2) / (np.linalg.norm(d2) + eps)
        
        delta_W = self.eta_hebb * np.outer(a1 * d1, a2 * d2)
        self.W_12 += delta_W
        
        frob = np.linalg.norm(self.W_12, 'fro')
        if frob > eps:
            self.W_12 /= frob
        
        self.hebb_updates += 1
        return a1, a2
    
    def update_reinforcement(self, state_idx: int, e_in: np.ndarray, 
                            v_tch: np.ndarray, reward: float, eps: float = 1e-8):
        """Plasticidad por refuerzo."""
        self.r_count += 1
        self.r_hat += (reward - self.r_hat) / self.r_count
        delta = reward - self.r_hat
        
        for i in range(6):
            a_si = e_in[min(i, len(e_in)-1)] * v_tch[i] / (np.linalg.norm(v_tch) + eps)
            self.P[state_idx, i] += self.alpha_refuerzo * delta * a_si
        
        self.P[state_idx] = np.clip(self.P[state_idx], 0.0, 1.0)
        row_sum = np.sum(self.P[state_idx])
        if row_sum > eps:
            self.P[state_idx] /= row_sum
        
        self.refuerzo_updates += 1
        return delta
    
    def get_P(self) -> np.ndarray:
        return self.P
    
    def to_dict(self) -> dict:
        return {
            'W_12_norm': float(np.linalg.norm(self.W_12, 'fro')),
            'P': self.P.tolist(),
            'r_hat': self.r_hat,
            'hebb_updates': self.hebb_updates,
            'refuerzo_updates': self.refuerzo_updates
        }
