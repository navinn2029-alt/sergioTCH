"""
Modulo Corteza Prefrontal Virtual (CPV) TCH

Deteccion de conflicto y secuestro de amigdala.
Triggers y energia de activacion.
"""

from dataclasses import dataclass, field
from typing import List, Dict, Tuple, Set


@dataclass
class VirtualPrefrontalCortex:
    """Corteza Prefrontal Virtual."""
    
    triggers: List[str] = field(default_factory=lambda: [
        "odio", "miedo", "riesgo", "poder", "caos",
        "muerte", "amor", "autoridad", "duda", "conflicto",
        "traicion", "venganza", "peligro", "amenaza", "control"
    ])
    
    trigger_weights: Dict[str, float] = field(default_factory=dict)
    beta: float = 0.04
    lambda_matiz: float = 0.1
    activations: int = 0
    amygdala_hijacks: int = 0
    
    def __post_init__(self):
        if not self.trigger_weights:
            self.trigger_weights = {t: 0.5 for t in self.triggers}
    
    def detect_triggers(self, text: str) -> List[str]:
        """Detectar triggers en texto."""
        text_lower = text.lower()
        return [t for t in self.triggers if t in text_lower]
    
    def calculate_activation_energy(self, input_text: str, output_text: str = "") -> float:
        """Calcular energia de activacion E_a."""
        E_a = 0.0
        for t in self.detect_triggers(input_text):
            E_a += self.trigger_weights.get(t, 0.5)
        if output_text:
            for t in self.detect_triggers(output_text):
                E_a += self.trigger_weights.get(t, 0.5)
        self.activations += 1
        return E_a
    
    def update_trigger_weights(self, input_text: str, output_text: str, E_a: float):
        """Actualizar pesos de triggers."""
        present = set(self.detect_triggers(input_text) + self.detect_triggers(output_text))
        for t in present:
            if E_a >= 1.0:
                self.trigger_weights[t] = min(1.0, self.trigger_weights.get(t, 0.5) + self.beta)
            else:
                self.trigger_weights[t] = max(0.0, self.trigger_weights.get(t, 0.5) - self.beta/2)
    
    def decide_response_mode(self, E_a: float) -> Tuple[str, float]:
        """Decidir modo de respuesta."""
        if E_a >= 1.0:
            self.amygdala_hijacks += 1
            return ('geminis', 1.0)
        return ('mixed', self.lambda_matiz)
    
    def process(self, input_text: str, output_text: str = "") -> Tuple[str, float, float]:
        """Procesar input y decidir modo."""
        E_a = self.calculate_activation_energy(input_text, output_text)
        mode, weight = self.decide_response_mode(E_a)
        self.update_trigger_weights(input_text, output_text, E_a)
        return (mode, weight, E_a)
    
    def to_dict(self) -> dict:
        return {
            'triggers': self.triggers,
            'activations': self.activations,
            'amygdala_hijacks': self.amygdala_hijacks,
            'beta': self.beta,
            'lambda_matiz': self.lambda_matiz
        }
