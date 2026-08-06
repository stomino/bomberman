"""Reserva puertos y lanza procesos ServerRoot headless, uno por partida.

Separado en dos responsabilidades (allocate/release de puertos vs. armar
y lanzar el comando) para poder testear la asignación de puertos sin
necesidad de lanzar procesos Godot reales — ver
matchmaking/tests/test_match_launcher.py.
"""

from __future__ import annotations

import subprocess
from typing import Set

from . import config


class NoPortsAvailableError(RuntimeError):
    pass


class MatchLauncher:
    def __init__(
        self,
        port_range_start: int = config.MATCH_PORT_RANGE_START,
        port_range_end: int = config.MATCH_PORT_RANGE_END,
        godot_executable: str = config.GODOT_EXECUTABLE,
        godot_project_path: str = config.GODOT_PROJECT_PATH,
    ) -> None:
        self._port_range_start = port_range_start
        self._port_range_end = port_range_end
        self._godot_executable = godot_executable
        self._godot_project_path = godot_project_path
        self._used_ports: Set[int] = set()

    def allocate_port(self) -> int:
        for port in range(self._port_range_start, self._port_range_end + 1):
            if port not in self._used_ports:
                self._used_ports.add(port)
                return port
        raise NoPortsAvailableError(
            f"No hay puertos libres en el rango {self._port_range_start}-{self._port_range_end}"
        )

    def release_port(self, port: int) -> None:
        self._used_ports.discard(port)

    def launch_match(self, port: int) -> subprocess.Popen:
        """Lanza un ServerRoot headless escuchando en `port`. El `--`
        separa los argumentos propios del juego de los del motor Godot
        (ServerRoot lee el puerto de OS.get_cmdline_user_args(), no
        interpretados por el motor) — ver
        docs/architecture/Implementation_Decisions.md."""
        command = [
            self._godot_executable,
            "--headless",
            "--path",
            self._godot_project_path,
            "scenes/server.tscn",
            "--",
            f"--port={port}",
        ]
        return subprocess.Popen(command)
