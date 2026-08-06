"""Punto de entrada del servidor de matchmaking — conecta QueueManager y
MatchLauncher con conexiones WebSocket reales.

Correr con: python -m matchmaking.server
"""

from __future__ import annotations

import asyncio
import logging

import websockets

from . import config, protocol
from .match_launcher import MatchLauncher
from .queue_manager import QueueManager

logging.basicConfig(level=logging.INFO, format="%(asctime)s [matchmaking] %(message)s")
logger = logging.getLogger("matchmaking")

_queue = QueueManager()
_launcher = MatchLauncher()


async def _handle_client(websocket) -> None:
    logger.info("Cliente conectado: %s", websocket.remote_address)
    try:
        async for raw_message in websocket:
            message = protocol.decode(raw_message)
            if message.get("type") == protocol.TYPE_JOIN_QUEUE:
                await _on_join_queue(websocket)
    except websockets.exceptions.ConnectionClosed:
        # Desconexión abrupta (cliente cerrado de golpe, sin handshake de
        # cierre) — esperable, no es un error del servidor. El registro
        # de "Cliente desconectado" de abajo ya deja constancia.
        pass
    finally:
        _queue.remove(websocket)
        logger.info("Cliente desconectado: %s", websocket.remote_address)


async def _on_join_queue(websocket) -> None:
    _queue.add(websocket)
    logger.info("Jugador anotado en la cola (%d esperando)", _queue.waiting_count())

    pair = _queue.pop_pair()
    if pair is None:
        return

    await _launch_and_notify(pair)


async def _launch_and_notify(pair) -> None:
    player_a, player_b = pair
    port = _launcher.allocate_port()
    logger.info("Emparejados — lanzando partida en el puerto %d", port)

    _launcher.launch_match(port)
    await asyncio.sleep(config.SERVER_STARTUP_DELAY_SECONDS)

    message = protocol.encode(protocol.matched_message(config.MATCH_SERVER_HOST, port))
    for player in (player_a, player_b):
        try:
            await player.send(message)
        except Exception:
            logger.warning("Un jugador se desconectó antes de recibir el emparejamiento")


async def main() -> None:
    async with websockets.serve(_handle_client, config.MATCHMAKING_HOST, config.MATCHMAKING_PORT):
        logger.info(
            "Matchmaking escuchando en ws://%s:%d", config.MATCHMAKING_HOST, config.MATCHMAKING_PORT
        )
        await asyncio.Future()  # corre para siempre


if __name__ == "__main__":
    asyncio.run(main())
