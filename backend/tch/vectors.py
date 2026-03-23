"""
Modulo de Vectores de Personalidad TCH

Implementa los 6 vectores de personalidad:
- D1 (Numero 1): V1 Analisis, V2 Lenguaje, V3 Control
- D2 (Geminis): U1 Sintesis, U2 Imagen, U3 Intuicion

V_TCH = [v1, v2, v3, u1, u2, u3] in R^6
"""

import numpy as np
from dataclasses import dataclass, field
from typing import Dict, Tuple


@dataclass
class PersonalityVectors:
    """Los 6 Vectores de Personalidad del sistema TCH."""
    
    # Pesos base
    D1_V1_weight: float = 0.95  # Analisis
    D1_V2_weight: float = 0.98  # Lenguaje
    D1_V3_weight: float = 1.00  # Control
    D2_U1_weight: float = 0.95  # Sintesis
    D2_U2_weight: float = 0.90  # Imagen
    D2_U3_weight: float = 0.85  # Intuicion
    
    # Vectores expandidos (5 dims cada uno)
    D1_V1: np.ndarray = field(default_factory=lambda: np.array([0.95, 0.98, 1.0, 0.9, 1.0]))
    D1_V2: np.ndarray = field(default_factory=lambda: np.array([0.95, 1.0, 0.9, 0.95, 1.0]))
    D1_V3: np.ndarray = field(default_factory=lambda: np.array([0.98, 1.0, 0.9, 1.0, 0.85]))
    D2_U1: np.ndarray = field(default_factory=lambda: np.array([0.95, 0.9, 0.85, 0.9, 0.8]))
    D2_U2: np.ndarray = field(default_factory=lambda: np.array([1.0, 0.8, 0.75, 0.9, 0.85]))
    D2_U3: np.ndarray = field(default_factory=lambda: np.array([0.8, 0.95, 0.9, 0.9, 0.95]))
    
    # Coeficientes phi de influencia
    phi_coefficients: Dict[str, float] = field(default_factory=lambda: {
        'D1_V1': 0.9, 'D1_V2': 0.7, 'D1_V3': 1.0,
        'D2_U1': -0.8, 'D2_U2': -0.9, 'D2_U3': -0.9,
        'KG': -0.5, 'CPV': 0.0, 'internal': -0.3
    })
    
    structural_weights: Dict[str, float] = field(default_factory=lambda: {
        'D1_V1': 0.10, 'D1_V2': 0.10, 'D1_V3': 0.10,
        'D2_U1': 0.15, 'D2_U2': 0.15, 'D2_U3': 0.15,
        'KG': 0.15, 'CPV': 0.05, 'internal': 0.05
    })
    
    def __post_init__(self):
        for attr in ['D1_V1', 'D1_V2', 'D1_V3', 'D2_U1', 'D2_U2', 'D2_U3']:
            val = getattr(self, attr)
            if not isinstance(val, np.ndarray):
                setattr(self, attr, np.array(val))
    
    @property
    def v_base(self) -> np.ndarray:
        """Vector base 30 dims."""
        return np.concatenate([self.D1_V1, self.D1_V2, self.D1_V3,
                              self.D2_U1, self.D2_U2, self.D2_U3])
    
    @property
    def d1_vector(self) -> np.ndarray:
        """Vector D1 (N1) 15 dims."""
        return np.concatenate([self.D1_V1, self.D1_V2, self.D1_V3])
    
    @property
    def d2_vector(self) -> np.ndarray:
        """Vector D2 (Geminis) 15 dims."""
        return np.concatenate([self.D2_U1, self.D2_U2, self.D2_U3])
    
    @property
    def v_tch(self) -> np.ndarray:
        """Vector TCH 6 dims."""
        return np.array([self.D1_V1_weight, self.D1_V2_weight, self.D1_V3_weight,
                        self.D2_U1_weight, self.D2_U2_weight, self.D2_U3_weight])
    
    def calculate_global_influence(self) -> Tuple[float, float]:
        """Calcular influencia global N1/G (34%/66%)."""
        total = sum(self.structural_weights.values())
        i_n1 = sum(self.structural_weights.get(k, 0) * max(0, v) 
                   for k, v in self.phi_coefficients.items()) / total
        i_g = sum(self.structural_weights.get(k, 0) * max(0, -v) 
                  for k, v in self.phi_coefficients.items()) / total
        return (i_n1, i_g)
    
    def to_dict(self) -> dict:
        i_n1, i_g = self.calculate_global_influence()
        return {
            'v_tch': self.v_tch.tolist(),
            'd1_vector': self.d1_vector.tolist(),
            'd2_vector': self.d2_vector.tolist(),
            'influence_N1': round(i_n1, 2),
            'influence_G': round(i_g, 2)
        }
