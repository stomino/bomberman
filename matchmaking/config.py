"""Configuración del servidor de matchmaking, vía variables de entorno.

Ver matchmaking/README.md para cómo configurarlas en cada máquina.
"""

from __future__ import annotations

import os
from pathlib import Path

# Único valor sin default razonable: la ruta al ejecutable de Godot varía
# por máquina (ver Implementation_Decisions.md, Fase 6, sobre el mismo
# problema del lado de la documentación de comandos).
GODOT_EXECUTABLE = os.environ.get("GODOT_EXECUTABLE", "godot")

# Default: la carpeta del proyecto Godot es la carpeta padre de
# matchmaking/ — funciona sin configurar nada en este repo, ya que
# matchmaking/ vive junto a scripts/scenes/docs del proyecto Godot.
GODOT_PROJECT_PATH = os.environ.get(
    "GODOT_PROJECT_PATH", str(Path(__file__).resolve().parent.parent)
)

MATCHMAKING_HOST = os.environ.get("MATCHMAKING_HOST", "127.0.0.1")
MATCHMAKING_PORT = int(os.environ.get("MATCHMAKING_PORT", "8765"))

# Dirección que se le manda a los clientes para conectarse al ServerRoot
# de la partida — separada de MATCHMAKING_HOST (ese es solo el bind del
# propio servicio de matchmaking) porque conceptualmente son cosas
# distintas, aunque hoy coincidan (todo corre en la misma PC).
MATCH_SERVER_HOST = os.environ.get("MATCH_SERVER_HOST", "127.0.0.1")

# Rango de puertos para los ServerRoot que se lanzan por partida —
# separado del puerto 8910 que usa el flujo manual de hosteo (Fase 5/6)
# para no pisarse si el dueño del proyecto corre ambos a la vez.
MATCH_PORT_RANGE_START = int(os.environ.get("MATCH_PORT_RANGE_START", "9000"))
MATCH_PORT_RANGE_END = int(os.environ.get("MATCH_PORT_RANGE_END", "9099"))

# Tiempo fijo de espera tras lanzar el proceso del servidor antes de
# avisarle a los clientes que ya pueden conectarse — ver
# Implementation_Decisions.md sobre por qué no es un handshake real
# todavía (el servidor ya arrancaba a escuchar casi al instante en las
# pruebas de Fase 6).
SERVER_STARTUP_DELAY_SECONDS = float(os.environ.get("SERVER_STARTUP_DELAY_SECONDS", "1.5"))
