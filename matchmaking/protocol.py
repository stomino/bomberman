"""Mensajes JSON entre el cliente Godot y el servidor de matchmaking.

Ver docs/architecture/Implementation_Decisions.md para el protocolo
completo. Cliente -> servidor: {"type": "join_queue"}. Servidor ->
cliente: {"type": "matched", "server_ip": ..., "server_port": ...}.
"""

from __future__ import annotations

import json
from typing import Any, Dict

TYPE_JOIN_QUEUE = "join_queue"
TYPE_MATCHED = "matched"


def encode(message: Dict[str, Any]) -> str:
    return json.dumps(message)


def decode(raw: str) -> Dict[str, Any]:
    return json.loads(raw)


def matched_message(server_ip: str, server_port: int) -> Dict[str, Any]:
    return {"type": TYPE_MATCHED, "server_ip": server_ip, "server_port": server_port}
