# Matchmaking (Fase 7 — solo emparejar)

Servicio Python, separado del proyecto Godot, que empareja jugadores y
lanza un `ServerRoot` (`scenes/server.tscn`) headless por partida. Ver
`docs/architecture/Implementation_Decisions.md` para las decisiones de
diseño y `docs/Product_Vision_and_Roadmap.md` para dónde encaja esto en
el roadmap general.

**Alcance de esta pasada:** solo emparejar dos clientes anónimos y
decirles a qué servidor conectarse. Sin cuentas, sin login, sin ranking
todavía.

## Instalar

```
pip install -r matchmaking/requirements.txt
```

## Configurar

Una sola variable es obligatoria de ajustar por máquina — la ruta al
ejecutable de Godot (no hay forma de adivinarla):

```
set GODOT_EXECUTABLE=C:\ruta\a\Godot_v4.7.1-stable_win64_console.exe
```

(en PowerShell: `$env:GODOT_EXECUTABLE = "C:\ruta\a\Godot.exe"`)

El resto de las variables tienen defaults razonables — ver
`matchmaking/config.py` para la lista completa
(`GODOT_PROJECT_PATH`, `MATCHMAKING_HOST`/`_PORT`,
`MATCH_PORT_RANGE_START`/`_END`, `SERVER_STARTUP_DELAY_SECONDS`).

## Correr

```
python -m matchmaking.server
```

Queda escuchando en `ws://127.0.0.1:8765` (o lo que diga
`MATCHMAKING_HOST`/`MATCHMAKING_PORT`). El cliente Godot se conecta
desde el botón "Buscar partida" del menú principal.

## Correr los tests

```
pytest matchmaking/tests/
```

## Limitaciones conocidas de esta pasada (a propósito, ver plan/docs)

- No cierra el proceso del `ServerRoot` cuando termina la partida.
- La espera tras lanzar el servidor es un tiempo fijo, no un handshake
  real de "ya está listo para conectarse".
- Sin cuentas/login/ranking — cola anónima, FIFO, empareja de a 2.
- Pensado para correr en la misma máquina que los clientes de prueba —
  sin hosting cloud todavía.
