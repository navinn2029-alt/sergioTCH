"""
Modulo Proyector TCH

Proyecta v_base (30 dims) -> embedding (384 dims)
Usando capas densas con GELU.
"""

import numpy as np
from dataclasses import dataclass, field


def gelu(x: np.ndarray) -> np.ndarray:
    """GELU activation."""
    return 0.5 * x * (1.0 + np.tanh(np.sqrt(2.0 / np.pi) * (x + 0.044715 * x**3)))


@dataclass
class Projector:
    """Proyector 30 -> 128 -> 384."""
    
    W1: np.ndarray = field(default_factory=lambda: np.random.randn(30, 128) * 0.1)
    b1: np.ndarray = field(default_factory=lambda: np.zeros(128))
    W2: np.ndarray = field(default_factory=lambda: np.random.randn(128, 384) * 0.1)
    b2: np.ndarray = field(default_factory=lambda: np.zeros(384))
    
    def forward(self, v_base: np.ndarray) -> np.ndarray:
        """Forward pass."""
        h1 = gelu(np.dot(v_base, self.W1) + self.b1)
        e_tch = np.dot(h1, self.W2) + self.b2
        return e_tch
    
    def project_with_state(self, v_base: np.ndarray, state_weights: np.ndarray) -> np.ndarray:
        """Proyectar con pesos de estado."""
        expanded = np.repeat(state_weights, 5)
        weighted = v_base * expanded
        return self.forward(weighted)
    
    def to_dict(self) -> dict:
        return {
            'input_dim': 30,
            'hidden_dim': 128,
            'output_dim': 384,
            'architecture': '30 -> GELU -> 128 -> 384'
        }
