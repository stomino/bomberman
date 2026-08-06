"""Cola de emparejamiento — lógica pura, sin async ni sockets.

Separada de server.py a propósito (mismo criterio que ya sigue todo el
proyecto Godot: lógica de negocio separada de infraestructura, ver
docs/architecture/Engine_Architecture_Specification_v1.0.md) para poder
testearla con pytest normal, sin necesidad de un event loop ni
conexiones reales.
"""

from __future__ import annotations

from collections import deque
from typing import Any, Deque, Optional, Tuple


class QueueManager:
    """Cola FIFO simple: empareja de a 2, en el orden en que llegaron."""

    def __init__(self) -> None:
        self._waiting: Deque[Any] = deque()

    def add(self, client: Any) -> None:
        if client in self._waiting:
            return
        self._waiting.append(client)

    def remove(self, client: Any) -> None:
        """No falla si client ya no está en la cola (ej. se desconectó
        antes de matchear, o nunca llegó a anotarse)."""
        try:
            self._waiting.remove(client)
        except ValueError:
            pass

    def pop_pair(self) -> Optional[Tuple[Any, Any]]:
        """Si hay 2 o más esperando, saca a los primeros 2 (FIFO) y los
        devuelve. None si todavía no hay suficientes."""
        if len(self._waiting) < 2:
            return None
        first = self._waiting.popleft()
        second = self._waiting.popleft()
        return (first, second)

    def waiting_count(self) -> int:
        return len(self._waiting)
