# Implementation Decisions

Este documento registra decisiones de implementación tomadas al aplicar
`Engine_Architecture_Specification_v1.0.md` a casos concretos que el spec
no detalla. El spec define los principios permanentes; este documento
explica cómo se aterrizaron y por qué, para que se puedan revisar o
revertir con contexto si el juego evoluciona (por ejemplo, si se migra de
motor).

## Editor de mapas (Fase 3.5): MapDefinition como segundo origen de GameMap

**Decisión:** `GameMap` ya no tiene un único constructor balance-driven —
tiene dos factories estáticas intercambiables: `GameMap.from_balance(balance)`
(el camino procedural de siempre, mismo comportamiento exacto que antes,
solo renombrado) y `GameMap.from_definition(definition)` (nuevo: un mapa
completo hecho a mano, `MapDefinition`, cargado desde `maps/*.json`).
`regenerate()` recuerda de qué origen vino cada instancia y reconstruye
la grilla igual — con balance, vuelve a borde+vacío (los destructibles los
repone `BombSystem`); con un `MapDefinition`, vuelve a la grilla completa
tal como la pintó su autor (destructibles incluidos, ya que ahí SÍ forman
parte del mapa, no de un patrón separado).

`MapDefinition` es una clase nueva, separada de `GameBalance` a
propósito: es contenido (el diseño concreto de un mapa), no config
numérica de balance — mismo principio que ya se aplicó separando
`PowerUpBalance` de `GameBalance`.

`BombSystem` recibió un parámetro `populate_from_balance_pattern`
(default `true`, no rompe nada existente): en `false` no superpone el
patrón centrado de `GameBalance` sobre un mapa custom, porque ahí el
autor del mapa ya pintó sus propios bloques destructibles directamente en
la grilla — superponer el patrón genérico encima podría pintar sobre
paredes puestas a propósito.

**Selección de mapa entre escenas:** el menú principal guarda la ruta del
mapa elegido en `get_tree().root.set_meta("selected_map_path", ...)`
antes de cambiar a la escena de Sandbox; `GameRoot` la lee en `_ready()`.
Se evitó deliberadamente un autoload nuevo para esto — ya se había sacado
uno (`GameBalance`) por las razones documentadas más abajo, habría sido
contradictorio reintroducir esa forma de acoplamiento por un dato que
solo hace falta una vez, al cambiar de escena.

**UI construida por código, no a mano en `.tscn`:** tanto el menú como el
editor arman sus `Button`/`Container`/`OptionButton` en `_ready()` vía
GDScript en vez de definirlos en el archivo de escena. Es más confiable
de producir sin poder ver el editor de Godot visualmente, y es una
práctica normal para herramientas (no para UI final de producto, donde sí
valdría la pena diseñarla a mano en el editor más adelante).

**Qué quedó explícitamente fuera de esta primera pasada** (para no
sobre-alcanzar el pedido original): redimensionar un mapa ya creado
(`Nuevo` siempre crea 13x11), soporte de scroll/zoom para mapas más
grandes que la ventana, y guardar mapas de jugadores en `user://` en vez
de `res://` (hace falta el día que se exporte el juego, porque `res://`
es de solo lectura en un build empaquetado — hoy corremos siempre desde
el árbol de fuentes, así que no es un problema todavía).

## Sistema de rondas: reglas simples, decididas por el dueño del producto

**Decisión:** ronda termina cuando queda un solo jugador vivo (gana, suma
`Player.rounds_won`) o cero (empate técnico, nadie suma). Al terminar una
ronda: `GameMap.regenerate()` + `BombSystem.reset_round()` +
`PowerUpSystem.clear_all()` + `PlayerSystem.reset_for_new_round()` para
cada jugador (esto último también resetea los powerups acumulados —
cada ronda arranca pareja). La partida termina cuando
`state.tick >= balance.match_duration_seconds * balance.tick_rate`; gana
quien tenga más rondas ganadas, empate si están iguales
(`GameState.winner_id = -1`).

Toda esta lógica vive en `GameManager` (no es un system nuevo): no posee
entidades propias, solo coordina el ciclo de vida de una ronda entre
systems que ya existen — encaja con su rol ya establecido de coordinador
(mismo patrón que `apply_explosion_damage`/`_resolve_powerup_pickups`).

**Guardia importante:** con menos de 2 jugadores registrados,
`_check_round_end`/`_check_match_end` no hacen nada. El modo actual
(sandbox de un jugador, sobrevivir y respawnear indefinidamente) sigue
funcionando sin cambios — las reglas de ronda/partida recién se activan
cuando hay más de un jugador real, que todavía no existe en este proyecto
(llega en Fase 4/5). Se decidió así explícitamente para no romper el único
modo jugable que existe hoy.

`GameManager.tick()` ahora no hace nada hasta que se llama
`start_match()` explícitamente (antes tickeaba desde el primer frame).
`GameRoot._ready()` lo llama una vez, al final de su setup — hace el
arranque de partida explícito en vez de implícito en el primer tick.

Se renombró `GameBalance.round_time_seconds` (nunca usado desde que
existía) a `match_duration_seconds`, porque el nombre y el valor por
defecto (120s) no correspondían a ningún concepto implementado; el
nuevo nombre sí. `overtime_seconds` queda sin usar por ahora — podría
servir el día que se quiera desempatar la partida en vez de declarar
empate, pero eso no se pidió todavía.

## Balance base vs. balance de powerups: dos lugares separados a propósito

**Decisión:** `GameBalance` sigue siendo la única fuente de la base del
juego (`bomb_range_base`, `max_bombs_per_player`,
`base_speed_cells_per_second`, etc. — igual para todos los jugadores).
Se agregó `PowerUpBalance` (`config/powerup_balance.json` +
`scripts/engine/core/powerup_balance.gd`) como el único lugar para
balancear qué hace cada powerup: cuánto suma por stack y cuántas veces se
puede stackear. `GameBalance.powerups: PowerUpBalance` lo compone, así
`GameRoot` sigue teniendo un solo punto de carga
(`GameBalance.load_from_file()`), pero balancear un powerup nunca implica
tocar la config base ni viceversa.

`Player` (domain) no guarda valores finales (velocidad, rango, etc.) —
guarda **cuántos powerups de cada tipo acumuló**
(`speed_powerup_stacks`, `bomb_range_powerup_stacks`,
`extra_bomb_powerup_stacks`, `shield_ticks_remaining`). El valor efectivo
siempre se deriva en el momento, en `PlayerSystem`
(`get_effective_speed/bomb_range/max_bombs`), como
`base (GameBalance) + stacks (Player) × bonus (PowerUpBalance)`. Nunca se
cachea ni se muta un valor final — evita el bug de la vieja
`apply_speed_multiplier()`, que mutaba `player.speed` permanentemente y no
había forma de saber después cuál era la base.

**Por qué:** pedido explícito para tener una arquitectura de balance clara
y fácil de ajustar: un lugar para la base del juego, otro lugar aparte
para los powerups, y que combinarlos sea una operación transparente
(suma), no un efecto secundario oculto en el código de gameplay.

Esto también resolvió `BombSystem.place_bomb()`: antes leía
`balance.max_bombs_per_player` como un límite global; ahora recibe
`bomb_range`/`max_bombs_for_owner` explícitos por llamada, calculados por
el caller (`GameRoot`, vía `PlayerSystem.get_effective_*`). `BombSystem`
no sabe nada de jugadores ni de powerups — solo de bombas — y evita un
acoplamiento circular con `PlayerSystem` (que ya lo referencia a él para
chequear colisiones).

## Tests unitarios con un runner propio, no un addon (GUT)

**Decisión:** `tests/test_case.gd` (assertions básicas) + `tests/test_runner.gd`
(descubre y corre todo lo que hay en `tests/unit/*.gd`, sin editor ni
escena). Se corre con:

```
godot --headless --path . -s tests/test_runner.gd
```

Sale con código 1 si algo falla (para CI más adelante), 0 si todo pasa.

**Por qué:** Domain y Systems son `RefCounted` puro, sin dependencias de
Godot — se pueden instanciar y testear directo, igual que ya veníamos
validando por CLI durante todo el desarrollo. Un addon como GUT da mejor
reporting y es el estándar de la comunidad, pero suma una dependencia
externa (descarga, versionado, compatibilidad con 4.7) para resolver un
problema que un runner de ~70 líneas ya resuelve. Si el equipo necesita
más adelante mocks, fixtures más ricos, o integración con un pipeline de
CI más sofisticado, migrar a GUT es una decisión reversible — nada en los
tests actuales depende de la implementación del runner, solo de
`TestCase.assert_*`.

**Nota real que encontraron los tests apenas se escribieron:** el primer
test de `BombSystem` reveló que la explosión reconocía bloques
destructibles únicamente a través de su propia lista interna
`destructible_blocks`, no a través de `GameMap.is_destructible()` — dos
fuentes de verdad para el mismo dato, en contra de la regla "one owner
per piece of data" del spec. Se corrigió para que `GameMap` sea la única
fuente de verdad de qué celda es destructible (ver commit correspondiente
a esta fecha). Vale como ejemplo concreto de por qué esta fase se hizo
antes de seguir apilando features de Fase 3 encima.

## El movimiento del jugador simula en ticks enteros, no en float

**Decisión:** `Player.move_ticks_elapsed` / `Player.move_ticks_total` (int)
reemplazan al viejo `move_progress: float`. `PlayerSystem._update_player()`
incrementa el contador en 1 por tick — ya no acumula `speed * delta`. La
cantidad de ticks que toma cruzar una celda se deriva una sola vez, al
iniciar cada movimiento, con `roundi(balance.tick_rate / player.speed)`.
`GameManager.tick()`, `PlayerSystem.tick()` y `BombSystem.tick()` perdieron
el parámetro `delta` — ya no existe como concepto en la simulación.

**Por qué:** `docs/Product_Vision_and_Roadmap.md` (el documento de
producto) es explícito: *"La lógica trabajará únicamente con coordenadas
enteras... no se utilizarán posiciones flotantes para la simulación. Esto
simplifica sincronización online, reproducibilidad, determinismo y
depuración."* El diseño anterior acumulaba `move_progress` con el `delta`
real de Godot — funcionaba para un solo cliente, pero no garantiza que el
mismo input produzca exactamente el mismo resultado en dos ejecuciones
distintas (servidor vs. cliente), que es la base de cualquier esquema de
predicción/reconciliación con servidor autoritativo (Fase 4+ del roadmap).
`BombSystem` ya cumplía esto — sus timers siempre fueron enteros
(`bomb_timer_base_ticks`, etc.); `PlayerSystem` era la única pieza que
todavía dependía de tiempo real.

La interpolación visual (`get_position_for_render`, la animación "en el
lugar" de `player_node.gd`) sigue usando float — eso es Presentation, y el
documento lo permite explícitamente ("las animaciones podrán interpolarse
visualmente"). La regla es: el estado autoritativo nunca es float: solo su
representación en pantalla puede serlo.

## GameBalance vive en Core como RefCounted inyectado, no como autoload

**Decisión:** `GameBalance` (`scripts/engine/core/game_balance.gd`) es una
clase `RefCounted` con variables de instancia. Se crea una única vez en
`GameRoot._ready()` vía `GameBalance.load_from_file()` y se inyecta por
constructor en `GameMap`, `BombSystem`, `Bomb`, `Explosion`.

**Por qué:** una versión anterior lo tenía como autoload de Godot (`extends
Node`, registrado en `project.godot`, con `static var` accedidas
globalmente como `GameBalance.algo`). Eso viola dos Golden Rules del spec
a la vez: "No gameplay singletons" y "Dependencies are created only at the
application root". Más concretamente, con el juego con el objetivo de ser
portable a otro motor en el futuro, un autoload es un mecanismo específico
de Godot: cualquier clase de Domain/Systems que lo referenciara quedaba
atada al árbol de escena de Godot, no solo a los datos de balance.

Con la versión actual, `GameBalance` es un objeto de datos plano. La única
función que toca una API de Godot (`FileAccess`, para leer el JSON) es
`load_from_file()` / `load()` — si el juego migrara de motor, ese es el
único punto a reemplazar; el resto del Core/Domain/Systems no cambia.

## GameLogger es una excepción documentada, no un GameBalance más

**Decisión:** `GameLogger` (`scripts/utils/logger.gd`) mantiene su propio
`static var enabled: bool`, en vez de recibir un `GameBalance` inyectado
para consultar un flag de debug.

**Por qué:** `GameBalance` inyectado resuelve la config de *gameplay*
(velocidad, timers de bombas, etc.), que sí necesita ser determinista e
idéntica en todas las instancias de un mismo match. El logging de
desarrollo es una preocupación distinta: es infraestructura pura, no
afecta el resultado de la simulación, y forzar su inyección en cada
constructor de Domain/Systems solo para poder loguear habría sido
burocracia sin beneficio. Se trata como una excepción pragmática, al
mismo nivel que un logger estático de cualquier librería (log4j,
Serilog, etc.).

Nota aparte: Godot 4.7 ya trae una clase nativa `Logger` (usada para
redirigir la salida de logs del engine vía `OS.add_logger()`, con métodos
virtuales `_log_message`/`_log_error`). No sirve como reemplazo — es
infraestructura de bajo nivel para capturar logs del motor, no un helper
de `debug()/info()/warning()` con gating por flag. Por eso nuestra clase
se llama `GameLogger` y no `Logger`.

## TickLoop no existe todavía como clase separada

**Decisión:** el spec lista `TickLoop` como componente de Core, pero hoy
no hay una clase `TickLoop` — `GameRoot._physics_process(delta)` llama
directo a `GameManager.tick(delta)`.

**Por qué:** `_physics_process` de Godot ya corre a paso fijo (configurable
en Project Settings), que es exactamente lo que un `TickLoop` propio
haría. Agregar una clase intermedia hoy sería una abstracción sin
propósito real. Si en algún momento se necesita desacoplar el tick del
`_physics_process` de Godot específicamente — por ejemplo, para
correr la simulación a una tasa fija independiente del motor de
rendering, o al migrar de motor — ese es el momento de extraer
`TickLoop` como una clase propia que `GameRoot` (o su equivalente en el
otro motor) alimente con delta.

## Fase 4: Commands como pipeline único de input (local y en red)

**Decisión:** `MoveCommand`/`PlaceBombCommand`
(`scripts/engine/core/commands/`) son objetos `RefCounted` inmutables que
representan intent, tal como pide el spec ("Input → Commands →
GameManager", Golden Rule 6) — hueco que existía desde el principio:
`GameRoot` llamaba directo a `player_system`/`bomb_system`. `GameManager`
gana `queue_command()` + una cola interna que se drena al inicio de cada
`tick()` (`_apply_pending_commands()`), antes del resto de la lógica de
tick. La regla de "bomba efectiva" (calcular `bomb_range`/`max_bombs` vía
`PlayerSystem.get_effective_*` y llamar `BombSystem.place_bomb`), que
antes vivía en `GameRoot.try_place_bomb()`, se movió adentro de
`GameManager._apply_place_bomb()` — un solo dueño de esa regla, en Core.

`GameRoot` (sandbox local, sin red) también pasó a encolar Commands en
vez de mutar `player_system` directo. Efecto observable: el input tarda
un tick más en aplicarse (antes era inmediato); a 60 ticks/seg es
imperceptible.

**Por qué:** los Commands son la unidad natural que viaja del Cliente al
Servidor por RPC (ver más abajo). Se decidió que el modo sandbox local
pasara por el mismo pipeline — no un camino aparte "solo para red" — para
que un solo código (`GameManager._apply_pending_commands`) sea la única
fuente de verdad de cómo se aplica el input, y que el sandbox local siga
siendo un test fiel de cómo se va a comportar el juego en red.

`clear_input()` de `PlayerSystem` se eliminó (dead code): pasar
`Vector2i.ZERO` a `set_move_direction` ya hacía exactamente lo mismo, así
que no hace falta un `ClearInputCommand` separado — `GameRoot.clear_player_input()`
y `ClientRoot.clear_player_input()` encolan/mandan un `MoveCommand` con
`Vector2i.ZERO`.

## Fase 4: ServerRoot y ClientRoot — cliente-servidor real (ENet) en una sola PC

**Decisión:** Se implementó con red real desde el día 1, no un transporte
simulado: `ServerRoot` (`scripts/engine/infrastructure/network/server_root.gd`)
crea un `ENetMultiplayerPeer.create_server()`; `ClientRoot`
(`client_root.gd`) crea `ENetMultiplayerPeer.create_client()`. Ambos
corren como procesos separados de Godot en la misma PC, conectados por
`127.0.0.1`. Nuevas escenas `scenes/server.tscn` / `scenes/client.tscn`,
accesibles desde botones nuevos en el menú principal ("Servidor" y
"Cliente" con IP).

`ClientRoot extends GameRoot`: reutiliza sin cambios toda la superficie
de lectura que ya usan `player_node.gd`/`game_renderer.gd`
(`is_player_alive`, `get_player_render_position`, etc.) — esos métodos ya
solo leían `player_system`/`bomb_system`/`powerup_system`/`game_map`, así
que alcanza con poblar esos mismos contenedores desde snapshots en vez de
simularlos. Solo sobreescribe `_ready()` (arma contenedores vacíos +
conecta como cliente en vez de simular), `_physics_process()` (no llama
`game_manager.tick()` — el cliente nunca es autoritativo), y los 3
métodos de input (mandan RPC al servidor en vez de encolar localmente).
Para esto, `GameRoot.LOCAL_PLAYER_ID` pasó de `const` a `var`:
`ClientRoot` la sobreescribe con `multiplayer.get_unique_id()` (el peer
id que Godot asigna al conectar) al conectarse, en vez de `0` fijo.

`ServerRoot` no hereda de `GameRoot` (arma simulación para N jugadores
remotos, no 1 local; no tiene Presentation que inyectar) — duplica la
composición de `balance`/`game_map`/systems/`game_manager` (~6 líneas, no
amerita una fábrica compartida). Jugadores se crean/borran en
`peer_connected`/`peer_disconnected`, con `Player.id = peer_id` (los
peer ids de Godot son globalmente únicos; el servidor siempre es `1`).

**Ajuste real respecto al plan original — NodePath de RPC:** Godot solo
rutea un RPC entre dos peers si el nodo que lo declara existe en el
**mismo NodePath** en ambos árboles de escena (confirmado contra la
documentación oficial). El plan inicial asumía que `ClientRoot` podía
seguir siendo hermano de `Player`/`GameRenderer` como hoy es `GameRoot`
en `main.tscn` — eso pone a `ClientRoot` en `/root/Match/ClientRoot`, que
NO coincide con `/root/Match` (el path de `ServerRoot`, que sí es la raíz
de `server.tscn`). Se corrigió durante la implementación: en
`client.tscn`, `ClientRoot` es la **raíz** de la escena (nodo "Match",
igual que en `server.tscn`), y `Player`/`GameRenderer` pasaron a ser sus
hijos directos. Esto obligó a sobreescribir
`_inject_into_player_node()`/`_inject_into_game_renderer()` en
`ClientRoot` (paths `"Player"`/`"GameRenderer"` en vez de
`"../Player"`/`"../GameRenderer"`) — la única parte de la superficie de
`GameRoot` que si necesitó cambiar, justamente porque depende de la
posición del nodo en el árbol, no del estado del juego.

También como consecuencia: la raíz de `client.tscn` es `type="Node2D"`
(no `"Node"`) con `scale = Vector2(2, 2)` puesto ahí directamente (antes
esa escala vivía en el nodo "Main", separado del `GameRoot`) — un script
`extends Node` puede attachearse a un nodo `Node2D` sin problema (Node2D
es-un Node), así que `ClientRoot`/`GameRoot` siguen siendo válidos ahí.

Cada script declara sus propios métodos `@rpc` en vez de heredarlos de
una clase base compartida (`ServerRoot.submit_move`/`submit_place_bomb`
con lógica real + stub vacío de `receive_snapshot`; `ClientRoot` al
revés) — GDScript tuvo bugs históricos con anotaciones `@rpc` no
heredadas correctamente en subclases, así que se prefirió texto repetido
pero explícito.

**Por qué red real y no un transporte simulado:** para que Fase 5 (LAN) y
Fase 6 (Internet) sean "cambiar la IP" sobre el mismo protocolo, no
reescribir el transporte — evita exactamente la clase de solución
temporal que el documento de producto pide evitar.

## Fase 4: SnapshotCodec — snapshot completo por tick, sin DTOs nuevos

**Decisión:** `scripts/engine/infrastructure/network/snapshot_codec.gd`
(`SnapshotCodec`, funciones estáticas `serialize`/`apply`) traduce
`GameState`/`PlayerSystem`/`BombSystem`/`PowerUpSystem`/`GameMap` a un
`Dictionary` y de vuelta. `apply()` reconstruye/actualiza in-place las
mismas clases Domain que ya existen (`Player`, `Bomb`, `Explosion`,
`PowerUp`, `GameMap.grid`) — no se inventaron DTOs de red separados. El
cliente nunca llama `.tick()` sobre estos objetos: son un espejo de solo
lectura.

El servidor manda el mapa completo (`grid`, ancho, alto, `cell_size`) en
cada snapshot, no solo una vez al conectar — así el cliente no necesita
adivinar qué mapa eligió el servidor (default o uno del editor); lo
aprende del snapshot, igual que el resto del estado.

`ClientRoot` sí carga su propio `GameBalance.load_from_file()`
localmente (mismo archivo que usa el servidor) — pero solo se usa para
constantes cosméticas de Presentation (ej. el degradé de la mecha de la
bomba en `game_renderer.gd`), nunca para decidir nada de gameplay; todo
lo que afecta el resultado del juego llega exclusivamente por snapshot.

**Hallazgo real probando en vivo (servidor + cliente reales sobre
loopback, no solo tests unitarios):** el snapshot completo (mapa 13x11 +
entidades) supera fácil el MTU de ENet (~1392 bytes; se vieron paquetes
de ~1900 bytes) — mandarlo por el canal `"unreliable"` que tenía
`receive_snapshot` en el plan original tira el warning de ENet "above
the MTU... higher packet loss". Se cambió `receive_snapshot` a
`"reliable"` (ENet sí fragmenta paquetes reliable en varios paquetes
chicos automáticamente) en ambos lados (`ServerRoot`/`ClientRoot`, tienen
que matchear). Con esto, una prueba real end-to-end (mover al jugador,
colocar bomba, esperar la explosión y el respawn) se vio reflejada
correctamente en el cliente en cada paso, sin errores ni warnings.

**Qué quedó explícitamente fuera de esta primera pasada** (Fase 4 se
acotó a 1 jugador vía red, decisión tomada con el dueño del producto
antes de implementar): 2+ jugadores conectados simultáneamente
(`ServerRoot` ya soporta N del lado servidor — mismo `PlayerSystem.players`
como diccionario de siempre — pero `ClientRoot` en esta pasada solo
renderiza al jugador local, no rivales), predicción de cliente /
reconciliación (`GameBalance.prediction_enabled`/`reconciliation_enabled`
siguen en `false` — no hacen falta con latencia ~0 en loopback),
delta-compression / snapshot rate configurable (optimización, Fase 10),
reconexión, espectador, y servidor dedicado headless empaquetado (Fase 6).

## Fase 4, iteración 2: `scenes/player.tscn` + spawn dinámico de rivales

**Decisión:** se extrajo `scenes/player.tscn` (CharacterBody2D +
`player_node.gd` + CollisionShape2D + AnimatedSprite2D, con todos los
`AtlasTexture` del spritesheet) como escena reutilizable — antes ese
árbol estaba duplicado inline en `scenes/main.tscn` y `scenes/client.tscn`.
`main.tscn` ahora instancia `player.tscn` para su único jugador estático
del sandbox (sin cambio de comportamiento). `client.tscn` perdió el nodo
Player por completo: `ClientRoot` instancia `player.tscn` en runtime, una
vez por cada `player_id` presente en el snapshot recibido
(`_sync_player_nodes()`, llamado desde `receive_snapshot()`), y destruye
(`queue_free()`) los nodos de jugadores que ya no están en el snapshot
(cubre tanto la muerte/respawn normal — que no saca al jugador de
`player_system.players` — como una desconexión real).

`player_node.gd` pasó de operar implícitamente sobre "el" jugador a
recibir su propio `player_id` en `set_game_root(root, player_id)`, y
calcula `is_local := player_id == root.LOCAL_PLAYER_ID` una sola vez al
spawnear. Los 7 getters de lectura de `GameRoot`
(`is_player_alive`, `get_player_render_position`, etc.) pasaron a recibir
`player_id` como parámetro en vez de usar `LOCAL_PLAYER_ID` implícito —
ya delegaban en `player_system.get_player(player_id)`, así que fue
mecánico. Los 3 métodos de input (`set_player_move_direction`,
`clear_player_input`, `try_place_bomb`) **no cambiaron de firma**: siguen
siendo siempre "el jugador local", porque el teclado de una instancia de
Godot solo puede representar a un humano — `player_node.gd` los llama
únicamente si `is_local` es true, así el nodo de un rival es puramente
visual y nunca genera input.

**Por qué:** `ServerRoot` ya soportaba N jugadores desde la Fase 4
original (`_broadcast_snapshot()` ya mandaba a cada peer el snapshot
completo con todos los jugadores) — lo único que faltaba era que
`ClientRoot` supiera mostrar más de uno. Reusar `player_node.gd` tal
cual (con el agregado de `player_id`/`is_local`) para representar tanto
al jugador propio como a los rivales evita un tipo de nodo nuevo
"jugador remoto" — es el mismo componente, la única diferencia real es
si escucha teclado o no.

**Probado en vivo:** servidor + 2 clientes reales sobre loopback,
verificado con logs temporales (sacados después de confirmar) — ambos
clientes terminaron con `player_system.players.size() == 2` y 2 nodos
Player spawneados, sin errores de RPC. Cuando uno de los dos procesos
cliente se cerró, el otro despawneó correctamente el nodo del rival
desconectado — confirma que `_sync_player_nodes()` también resuelve el
camino de baja, no solo el de alta. Como efecto colateral, esta fue
también la primera vez que la lógica de fin de ronda
(`GameManager._check_round_end`, gateada en `players.size() >= 2`) corrió
de verdad sobre una partida en red — funcionó sin cambios.

## Fase 5: LAN — sin cambios de protocolo, solo mostrar la IP

**Decisión:** no hizo falta tocar el protocolo de red para pasar de
loopback a LAN. `ENetMultiplayerPeer.create_server(DEFAULT_PORT, ...)`
(`ServerRoot._start_server()`) ya escucha en todas las interfaces de la
máquina, no solo `127.0.0.1` — eso ya lo daba Fase 4 sin saberlo. Lo
único que faltaba era una forma de que quien hostea supiera qué IP
pasarle al otro jugador sin ir a buscarla a mano (`ipconfig`/Ajustes de
red):

- `ServerRoot._get_lan_ip()`: filtra `IP.get_local_addresses()`
  descartando IPv6 y loopback, prioriza rangos privados típicos
  (`192.168.*`, `10.*`, `172.16-31.*`); si no encuentra ninguno, devuelve
  la primera IPv4 no-loopback como mejor esfuerzo.
- `ServerRoot` ahora arma un `CanvasLayer`/`Label` mínimo
  (`_build_status_ui()`) mostrando `IP:puerto` y `jugadores conectados/
  máximo`, actualizado en conexión/desconexión — el servidor no tenía
  ningún nodo de Presentation antes (Fase 4 original: "no dibuja nada"),
  pero para host manual en LAN hace falta poder leer el dato en pantalla,
  no solo en el log (que además está apagado por defecto).

**Probado:** servidor + cliente conectando por la IP de LAN real de la
máquina (`192.168.x.x`, no `127.0.0.1`) en vez de loopback — conecta sin
errores. Esto valida el camino de red no-loopback, pero **no reemplaza
una prueba real con una segunda PC física en la misma red** — eso quedó
pendiente de que el dueño del proyecto lo pruebe (yo no tengo forma de
manejar dos máquinas físicas).

**Fuera de alcance:** abrir el puerto en el Firewall de Windows es una
configuración del sistema operativo del usuario — no es algo que se
automatice desde el código ni algo que un asistente deba tocar por su
cuenta; si la conexión falla entre dos PCs reales, es el primer lugar
para mirar. IPv6 se descarta a propósito en `_get_lan_ip()` (no en el
transporte en sí) para no complicar el primer host manual con múltiples
IPs candidatas — ENet igual podría funcionar sobre IPv6 si se le pasa
esa dirección a mano.

## Fase 6: Servidor dedicado, juego por Internet

**Decisión:** igual que Fase 5 (LAN) no necesitó tocar el protocolo, Fase 6
tampoco — `ENetMultiplayerPeer.create_server()` ya escucha en todas las
interfaces desde Fase 4, así que un servidor alcanzable por Internet es
exactamente el mismo binario/escena con el puerto (8910) reenviado en el
router de quien hostea, no un camino de código distinto. Los dos gaps
reales que sí hacían falta cerrar eran operativos: el servidor no tenía
forma de reportar su estado sin pantalla, y el cliente no reaccionaba en
absoluto a una caída de conexión.

**Sin exportar/empaquetar todavía:** decisión explícita del dueño del
producto para esta pasada. El servidor dedicado corre headless directo
desde código fuente:

```
godot --headless --path . scenes/server.tscn
```

Pasar una escena por línea de comandos hace que Godot la use en vez de
`run/main_scene` — no hace falta ningún cambio de código para "saltear" el
menú principal en una máquina sin display. Exportar un binario standalone
(`export_presets.cfg` + export templates) queda deferred a una futura
optimización de deploy; no bloqueaba probar que el juego funciona por
Internet.

**`ServerRoot` headless-friendly:** `_is_headless` (seteado en `_ready()`
vía `DisplayServer.get_name() == "headless"`) hace que `_build_status_ui()`
no construya ningún `CanvasLayer`/`Label` bajo un driver de display nulo, y
que `_update_status_ui()` llame a `_print_status()` en su lugar — mismo
contenido que ya tenía el Label (`IP:puerto`, jugadores conectados/máximo),
pero por `print()` plano, no vía `GameLogger` (que está apagado por
default, ver Fase 5 — para quien realmente está operando un servidor esto
no es un log de debug opcional, es la única forma de ver que el proceso
está vivo y respondiendo). Los tres call sites que ya actualizaban el
status (`_start_server`, `_on_peer_connected`, `_on_peer_disconnected`) no
cambiaron: el branch headless vive centralizado en
`_build_status_ui`/`_update_status_ui`, sin duplicar nada.

**`ClientRoot` gana detección básica de desconexión:** hasta ahora
`_on_connection_failed()` solo hacía `push_error` (invisible para un
jugador real) y no había ninguna conexión a `multiplayer.server_disconnected`
— si el servidor caía a mitad de partida, el cliente quedaba congelado con
el último snapshot, sin ningún aviso. Ahora ambas señales
(`connection_failed` y `server_disconnected`) rutean a un helper común,
`_fail_and_return_to_menu(message)`: cierra el peer (`close()` + `= null`,
para que un segundo intento de conexión arranque limpio), guarda el
mensaje vía `get_tree().root.set_meta("connection_error", message)` —
mismo patrón ya usado para `server_ip`/`selected_map_path` — y vuelve a
`main_menu.tscn`. `main_menu.gd._ready()` lee y limpia ese meta de
inmediato (para que no reaparezca en una visita al menú no relacionada) y
lo muestra como un `Label` rojo. Dos mensajes distintos según la causa
("No se pudo conectar al servidor." vs. "Se perdió la conexión con el
servidor.") porque le sirve al jugador saber cuál pasó.

**Probado en vivo (real, no solo por ausencia de errores):** servidor
levantado headless de verdad (`godot --headless --path . scenes/server.tscn`)
mostrando por stdout `[ServerRoot] IP:puerto — Jugadores: 0/4`; un cliente
normal (con ventana) conectó y el contador subió a `1/4` en un nuevo print.
Matar el proceso del servidor abruptamente (sin shutdown prolijo) hizo que
el cliente, tras el timeout de ENet, detectara `server_disconnected` y
volviera al menú mostrando "Se perdió la conexión con el servidor." —
confirmado con una captura de pantalla real del cliente en ese estado.
Se probó también el camino de falla al conectar (cliente apuntando a un
puerto sin nada escuchando): mismo comportamiento, mensaje "No se pudo
conectar al servidor.", confirmado con otra captura real. Ninguna
regresión en la suite de tests (76/76).

Nota honesta, igual que Fase 5: esto **no reemplaza una prueba real por
Internet** con el port forwarding del router del dueño del proyecto y una
segunda PC en otra red — eso queda pendiente de que él lo pruebe (no
tengo forma de manejar dos redes distintas).

**Fuera de alcance:** abrir/reenviar el puerto 8910 en el router es
configuración del usuario, no algo que se automatice desde el código —
mismo criterio que el Firewall de Windows en Fase 5. Reconexión a una
partida en curso, modo espectador, y cualquier diseño de resincronización
de estado quedan explícitamente afuera: una desconexión hoy siempre
termina la partida para ese cliente, sin excepción.

## Fix: el cliente de red solo avanzaba una celda por tecla apretada

**El problema real, encontrado probando en vivo la Fase 6:** al jugar por
red (LAN o Internet) y mantener apretada una tecla de movimiento, el
personaje avanzaba exactamente una celda y se frenaba, aunque la tecla
siguiera apretada — en el Sandbox local esto nunca pasaba.

**Causa:** `PlayerSystem.set_move_direction()` no reinicia el movimiento
si lo llaman con la misma dirección mientras el jugador ya se está
moviendo hacia ahí — para seguir cruzando celdas hace falta que quien
llama insista en cada tick, así al completarse una celda (`is_moving`
vuelve a `false`) la siguiente llamada lo reinicie
(`PlayerSystem._try_start_move`). `player_node.gd` ya hace exactamente
eso: llama a `set_player_move_direction()` en cada `_physics_process`
mientras la tecla está apretada, sin excepción. Pero
`ClientRoot.set_player_move_direction()` tenía una deduplicación
(`_last_sent_direction`/`_has_sent_direction`) que evitaba reenviar el
RPC si la dirección no había cambiado — pensada como optimización de
ancho de banda en Fase 4, nunca se probó sosteniendo una tecla contra un
servidor real hasta ahora. Efecto: el servidor recibía una sola orden de
movimiento, movía al jugador una celda, y como nunca llegaba una segunda
orden, `next_direction` quedaba en cero y el movimiento se frenaba ahí —
exactamente lo que documenta `Implementation_Decisions.md` (Fase 4,
Commands) sobre por qué el sandbox local pasa por el mismo pipeline que
la red: sirve como test fiel de cómo se comporta el juego en red, y acá
justamente divergían.

**Decisión:** se sacó la deduplicación. `ClientRoot.set_player_move_direction()`
manda el RPC en cada frame que lo llaman, igual que `GameRoot` hace
localmente — sin ninguna condición. El canal ya es `unreliable_ordered`
(paquete chico), así que mandar más seguido no es un problema de ancho de
banda real a la escala de este juego (1v1/FFA de pocos jugadores).

**Probado:** suite completa (77/77, incluye un test nuevo,
`test_player_keeps_moving_across_multiple_cells_when_direction_resent_every_tick`
en `tests/unit/test_player_system.gd`, que reproduce exactamente el
contrato que rompía este bug — reenviar la misma dirección tick a tick
debe cruzar más de una celda, no frenarse después de la primera).
También verificado con servidor headless + cliente reales que la suite
de tests de Fase 6 (conexión, desconexión, contador de jugadores) sigue
funcionando sin regresión tras el cambio.

## Fase 4: marcador "VOS" para distinguir al jugador propio

**Decisión:** `scenes/player.tscn` gana un hijo `Label` ("LocalIndicator",
texto "VOS", amarillo con contorno negro, `visible = false` por
default), posicionado arriba de la cabeza. `player_node.gd` lo prende o
apaga en `_physics_process` según `is_local` — no en `set_game_root()`,
a propósito: en Sandbox, `GameRoot._ready()` llama `set_game_root()`
antes de que corra el propio `_ready()` del nodo Player (GameRoot es
hermano y arranca antes en el orden de la escena), así que el `@onready
var local_indicator` todavía no estaría asignado en ese momento.
`_physics_process` siempre corre después de que el árbol completo
terminó de armarse, así que ahí es seguro tanto para el caso estático
(Sandbox) como para el dinámico (`ClientRoot._spawn_player_node`, donde
el orden es al revés: `add_child()` dispara `_ready()` del hijo antes de
que se llame `set_game_root()`).

**Por qué:** con 2+ jugadores en pantalla (ver más arriba) todos se ven
idénticos — no hay forma de saber "cuál soy yo" a simple vista sin esto.
Se usa el mismo criterio de "arte de programador" que ya declara
`game_renderer.gd` (texto/formas simples en vez de arte final) — es un
placeholder funcional, reemplazable más adelante sin tocar Domain/Systems.

Verificado visualmente (no solo por ausencia de errores): se corrió
`scenes/main.tscn` con un script temporal fuera de headless que le sacó
una captura de pantalla real después de unos frames, confirmando que el
label aparece legible y bien posicionado arriba del jugador — se descartó
el script después de verificar, no quedó en el repo.

## Editor de mapas: redimensionar + scroll/zoom (pendientes de Fase 3.5)

**Decisión — `MapDefinition.resize(new_width, new_height)`:** redimensiona
anclado en (0,0) — agrega/saca columnas por la derecha y filas por
abajo, nunca cambia el origen. El contenido existente se copia tal cual
(sin distinguir "esto era borde automático" de "pared puesta a mano" —
`MapDefinition` no guarda esa distinción); al final siempre se vuelve a
estampar el borde indestructible sobre el nuevo perímetro, igual que
`create_empty()`. Efecto secundario aceptado a propósito: si se agranda
un mapa, el borde viejo queda como pared "suelta" en lo que ahora es
interior — el autor del mapa ya tiene la herramienta "Borrar (Piso)"
para limpiarlo en dos clics si no lo quiere; la alternativa (adivinar y
auto-limpiar el borde viejo) es una heurística ambigua que no valía la
complejidad para esta pasada. `spawn_positions` que queden fuera de los
nuevos límites, o justo sobre el borde nuevo, se eliminan.

**Decisión — `map_editor.gd`: cámara real en vez de escala fija.** Se
reemplazó la constante `DISPLAY_SCALE` (matemática manual en `_draw()` y
en la conversión click→celda) por el transform real del propio `Node2D`:
`scale` para zoom (rueda del mouse, clamped 0.5x–4x), `position` para
paneo (flechas del teclado). `_draw()` ahora dibuja en tamaño de celda
real, sin escalar a mano. El pintado usa
`Node2D.get_local_mouse_position()` en vez de convertir `event.position`
a mano — Godot ya hace la conversión inversa del transform del nodo por
nosotros, así que el pintado sigue siendo preciso sin importar el zoom o
paneo actuales.

Se agrega `_auto_fit()`: al crear/cargar/redimensionar un mapa, calcula
el zoom que hace entrar el mapa completo en la ventana (sin piso mínimo
— un mapa gigante debe verse completo, aunque quede chico, en vez de
cortado por un límite arbitrario) y resetea el paneo — así nunca hace
falta salir a buscar el mapa a mano después de una acción que cambia sus
dimensiones.

**Por qué:** los dos quedaron acoplados a propósito — redimensionar sin
scroll/zoom dejaría zonas de un mapa grande invisibles e imposibles de
pintar con el mouse.

**Probado en vivo** (no solo por ausencia de errores): un script
temporal fuera de headless redimensionó un mapa a 40x30, confirmó que
`_auto_fit()` calculó el zoom correcto (0.675, acotado por la altura de
la ventana) para que entrara completo, movió el cursor real (`warp_mouse`)
a la posición de pantalla de una celda conocida, pintó, y verificó en
`MapDefinition` que se modificó exactamente esa celda y ninguna vecina —
confirma que la conversión pantalla→celda sigue siendo exacta después de
cambiar el zoom. Se sacó una captura de pantalla real además de los
prints. El script se descartó después, no quedó en el repo.

**Fuera de esta pasada:** guardar mapas en `user://` (sigue sin hacer
falta hasta exportar el juego), zoom anclado al cursor, redimensionar
con un anclaje distinto a "arriba-izquierda fijo".

## Tope de 30x30 en mapas + zoom ajustable en el juego real (no solo el editor)

**El problema real:** el auto-fit del editor (entrada anterior) solo
resolvía la herramienta de diseño. El juego jugable (`GameRoot`/
`main.tscn` para Sandbox, `ClientRoot`/`client.tscn` para el cliente de
red) seguía con una escala **fija** de 2x — funcionaba con el mapa
default (13x11) pero no entraba en la ventana con cualquier mapa más
grande hecho en el editor. Confirmado por el dueño del producto jugando:
"los mapas no entran en la ventana que se abre con F5".

**Decisión — tope de tamaño:** `MAX_MAP_SIZE` en `map_editor.gd` baja de
100 a 30. Los mapas del juego nunca superan 30x30.

**Decisión — `GameRoot` pasa a `extends Node2D` (era `extends Node`):**
para poder aplicar un zoom calculado con `self.scale` directo (sin
casteos `as Node2D` ni tocar el padre), `GameRoot` necesita ser él mismo
el nodo con transform — el mismo rol que `ClientRoot` ya cumplía en
`client.tscn` desde la iteración de "2+ jugadores". Esto obligó a
fusionar, en `main.tscn`, el nodo "Main" (Node2D, tenía la escala fija) y
el nodo "GameRoot" (Node, tenía el script) en uno solo; "GameRenderer"/
"Player" pasan a ser hijos directos de esa raíz en vez de hermanos —
misma forma que ya tiene `client.tscn`. Como consecuencia,
`_inject_into_player_node()`/`_inject_into_game_renderer()` en
`GameRoot` pasan de buscar `"../Player"`/`"../GameRenderer"` a
`"Player"`/`"GameRenderer"` (hijos directos) — y los overrides que
`ClientRoot` tenía de esos dos métodos quedaron **idénticos** a la base
una vez actualizada, así que se eliminaron de `client_root.gd` (menos
código duplicado, mismo comportamiento).

**Decisión — `GameRoot._apply_map_zoom()`:** calcula
`min(viewport.x / mapa_px.x, viewport.y / mapa_px.y)`, con tope superior
en `2.0` (la escala "de diseño" original, para que un mapa chico no se
vea artificialmente gigante) y **sin piso mínimo** — un mapa de 30x30
siempre debe entrar completo, aunque los sprites se vean más chicos que
hoy; el dueño del producto ya eligió este criterio sabiendo el
trade-off, en vez de la alternativa (cámara que sigue al jugador, más
fiel a los propios ejemplos del documento de producto — Valorant/LoL/
CS/Rocket League — pero mucho más trabajo). Se llama desde
`GameRoot._ready()` (sandbox, dimensiones conocidas de entrada) y desde
`ClientRoot.receive_snapshot()` (el cliente no conoce el tamaño del mapa
hasta el primer snapshot del servidor), con un guard
(`_last_zoomed_width/height`) para no reasignar `scale` en cada
snapshot si el mapa no cambió de tamaño.

`game_renderer.gd`/`player_node.gd` no cambiaron: ya dibujan/posicionan
en tamaño de celda real, el zoom vive enteramente en el transform del
nodo raíz.

**Probado:** Sandbox real (no headless) con un mapa de 30x30 (scale
resultante 0.675, acotado por el alto de la ventana) y uno de 8x8 (scale
2.0, tope superior funcionando) — capturas de pantalla confirmando que
ambos entran bien. Servidor+cliente reales sobre loopback con un mapa de
25x25 vía `GameBalance` — sin errores, `_apply_map_zoom()` corrió una
sola vez pese a cientos de snapshots (el guard funciona). Nota honesta:
el valor de zoom que logueó el cliente en esa prueba (corrida
`--headless`, sin ventana real) no coincidió con el cálculo esperado —
`get_viewport_rect().size` no reporta lo mismo sin una ventana real que
con una. No es un bug del código: ningún jugador real corre el cliente
headless (necesita ver la pantalla por definición), y la prueba en
Sandbox con ventana real sí dio los valores exactos esperados en los dos
casos. Se deja documentado por si en el futuro se automatizan tests de
red headless que dependan de este cálculo.

## Habilidades, primera pasada: Velocidad + Dash, loadout fijo

**Decisión:** del backlog "Ideas futuras" (loadout de 2 habilidades por
jugador), se implementó una primera pasada acotada a propósito
(acordada con el dueño del producto): **Velocidad** (activa, disponible
de entrada — tecla **Q**) + **Dash** (activa, se desbloquea a los 30s de
partida — tecla **E**), **loadout fijo para todos los jugadores** — sin
pantalla de selección todavía. Empujar bombas y Flash quedan para
después: son mecánicas más grandes, con decisiones de diseño propias sin
resolver (Empujar bombas rompe la regla de "nunca pisar una bomba";
Flash es una primitiva de movimiento nueva, no una extensión de la
actual).

**Revisión sobre la versión inicial:** Velocidad arrancó como un bonus
*pasivo* siempre activo. El dueño del producto pidió que las dos
habilidades se disparen con una tecla (Q la primera, E la segunda) — una
vez que Velocidad tiene un momento de activación, dejó de tener sentido
que fuera un buff permanente, así que pasó a ser una **ráfaga temporal
con cooldown** (`PlayerSystem.try_activate_speed_boost`): mientras
`Player.speed_boost_ticks_remaining > 0` el bonus de
`AbilityBalance.speed_ability_bonus` aplica en `get_effective_speed()`
(antes aplicaba incondicionalmente); `Player.speed_boost_cooldown_ticks_remaining`
bloquea reactivarla hasta que se agota. Mismo patrón de contador que
`shield_ticks_remaining`/`ability_unlock_progress_ticks`, ambos se
resetean en `reset_for_new_round()`. `AbilityBalance` suma
`speed_boost_duration_ticks` (180 = 3s) y `speed_boost_cooldown_ticks`
(300 = 5s).

`SpeedBoostCommand` es un espejo exacto de `DashCommand` (mismo patrón
en `GameManager`/`GameRoot`/`ClientRoot`/`ServerRoot`). A diferencia de
Dash, `try_activate_speed_boost` no depende de `is_moving` (es un buff,
no un desplazamiento) ni de ningún flag de desbloqueo — sigue
"disponible de entrada", solo sujeta a su propio cooldown.

`speed_ability_bonus` en esta pasada aplica igual para **todos** los
jugadores mientras la ráfaga esté activa, porque `Player` todavía no
tiene un flag de "qué habilidades tiene equipadas" (el loadout fijo
hardcodeado hace que sea indistinguible de una habilidad de verdad por
ahora — la diferencia real aparece en CUÁNDO se activa, no en quién la
tiene). El día que exista selección real de loadout, "quién tiene esta
habilidad" pasa a ser un dato de `Player`, no un cambio de fórmula — la
canalización ya está armada para eso.

`Player.ability_unlock_progress_ticks` es un **contador**, no un
timestamp absoluto (mismo patrón que `shield_ticks_remaining`) —
`PlayerSystem.tick()` lo incrementa cada tick mientras `dash_unlocked`
sea falso; al llegar a `AbilityBalance.dash_unlock_ticks` (1800 = 30s a
60 ticks/seg), desbloquea. Esto evita tener que pasarle `state.tick` a
`reset_for_new_round`/a donde se crean los jugadores
(`GameRoot._spawn_local_player`, `ServerRoot._on_peer_connected`).
`reset_for_new_round()` resetea `dash_unlocked`/
`ability_unlock_progress_ticks` (cada ronda arranca pareja, mismo
criterio que los powerups); `_respawn()` (muerte dentro de la ronda) NO
los resetea — igual que los powerups tampoco se pierden al morir.

**`Player.move_distance_cells`** generaliza el movimiento (default `1`,
`2` durante un dash) para que Dash reuse el mecanismo de
`PlayerSystem._update_player()` en vez de un camino de movimiento
aparte — único cambio al sistema de movimiento existente
(`grid_position + move_direction` pasó a
`grid_position + move_direction * move_distance_cells`), retrocompatible
por el default `1`. `PlayerSystem.try_dash()` valida la celda intermedia
Y la de destino antes de arrancar (si cualquiera está bloqueada, no pasa
nada — mismo criterio fail-fast que el movimiento normal); el dash dura
lo mismo en ticks que un paso normal, se siente como un impulso, no un
desplazamiento proporcionalmente más lento.

`DashCommand` sigue el mismo patrón que `PlaceBombCommand`
(`GameManager._apply_pending_commands`/`_apply_dash`); el wiring de red
(`GameRoot.try_dash`/`ClientRoot.try_dash`+`submit_dash`/
`ServerRoot.submit_dash`) es un espejo exacto de cómo ya viaja
`PlaceBombCommand`. Acciones de input en `project.godot`: `speed_boost`
en **Q** (habilidad 1), `dash` en **E** (habilidad 2) — originalmente
Dash estaba en Shift, se movió a E cuando se agregó la activación de
Velocidad para que las dos habilidades convivan en teclas consistentes
(Q/E), dejando Shift libre.

Como el bonus de Velocidad ya no es incondicional (depende de
`speed_boost_ticks_remaining > 0`), un test existente
(`test_player_moves_one_cell_after_ticks_for_speed`) que en la versión
pasiva había necesitado neutralizar el bonus a mano
(`balance.abilities.speed_ability_bonus = 0.0` en el helper
`_make_balance()`) ya no lo necesita — sin activar la ráfaga, el bonus
simplemente no aplica. Se sacó esa línea del helper.

**Probado:** suite completa (75/75, incluye los 9 tests de Dash más 4
nuevos de la ráfaga de Velocidad: aplica el bonus mientras dura y expira
sola, no se puede reactivar durante el cooldown, sí se puede después de
que el cooldown termina). Verificación visual real en Sandbox usando
`state.tick` como reloj (no conteo de frames de `_process`, que corren a
un ritmo distinto del tick rate de la simulación — lección aprendida
verificando Dash): activar con `try_speed_boost()`, confirmar que
`get_effective_speed()` sube durante la duración configurada y vuelve a
la base exactamente después, y que reactivarla durante el cooldown
efectivamente falla.

**Fuera de esta pasada:** Empujar bombas, Flash, pantalla de selección
de loadout, objetivos de desbloqueo por ubicación/estructura (solo
tiempo fijo por ahora), cooldown de Dash una vez desbloqueado (se puede
usar sin límite mientras no se esté moviendo — si el playtesting muestra
que hace falta, es un campo más en `AbilityBalance`).

## Habilidades: alcance de Dash configurable, no hardcodeado

**Decisión:** el pedido explícito del dueño del producto fue "quiero que
las habilidades sean fáciles de balancear... poder corregir en un solo
lugar cosas como cooldowns, duraciones, alcances". Auditando el código
existente, el único valor de una habilidad que NO estaba en
`AbilityBalance` era el alcance de Dash — estaba hardcodeado como `2` en
`PlayerSystem.try_dash()`. Se agregó `AbilityBalance.dash_range: int = 3`
(`config/ability_balance.json`, `dash.range`) y `try_dash()` pasó de
chequear a mano "celda intermedia + celda destino" (asumía 2 celdas fijo)
a un loop `for step in range(1, dash_range + 1)` que valida **cada**
celda del camino — necesario para que un alcance de 3+ celdas respete
colisión en el medio, no solo al final. `player.move_distance_cells` se
fija a `dash_range` en vez de un `2` literal.

De paso, siguiendo el mismo pedido como ejemplo concreto de balance, se
subió el default de 2 a 3 celdas ("una casilla más de alcance").

**Nota de nombrado:** dentro de `try_dash()` la variable local se llama
`dash_range`, no `range` — GDScript no tiene problema en que una
variable local se llame igual que una función built-in, pero
`range()` (la función que arma la secuencia del `for`) queda
tapada/shadowed dentro de ese scope si se usa ese nombre, y el `for step
in range(...)` de la misma función dejaría de compilar. Vale la pena
dejarlo anotado porque es un error fácil de reintroducir sin querer.

## Habilidad Flash + selección de habilidades por slot en el menú

**El problema real:** hasta acá el loadout de habilidades era fijo en
código — Velocidad siempre en Q, Dash siempre en E
(`player_node.gd._input()` llamaba directo a `try_speed_boost()`/
`try_dash()` según el nombre literal de la acción de input). Al diseñar
una tercera habilidad (Flash), agregarla reemplazando a Dash en la tecla
E habría sido arbitrario — el dueño del producto pidió en su lugar que el
**menú principal** deje elegir qué habilidad va en cada tecla, de las 3
disponibles.

**Decisión — Flash, tres decisiones de diseño que el roadmap dejaba
abiertas:**
1. **Validación: solo la celda de aterrizaje.** A diferencia de Dash
   (`PlayerSystem.try_dash`, valida cada celda del camino con un loop
   `for step in range(1, dash_range + 1)`), `try_flash()` calcula
   directo `target := grid_position + facing_direction * flash_range` y
   solo valida esa celda (`_is_cell_free(target)`, la misma función que
   ya maneja fuera-de-mapa vía `GameMap.is_walkable` →
   `is_within_bounds`, sin código nuevo para ese caso). Puede "saltar"
   sobre bombas u obstáculos intermedios — es lo que le da identidad
   propia frente a Dash, que si no sería un Dash con otro alcance.
2. **Instantáneo, no animado.** No reusa el pipeline de
   `move_direction`/`move_ticks_total`/`is_moving` que sí usa Dash (ver
   "Habilidades, primera pasada" más arriba) — `try_flash()` asigna
   `grid_position` directo, en el mismo tick que se llama. Por eso
   tampoco necesita el guard `not player.is_moving` que sí tiene Dash: al
   no tocar el estado de movimiento en curso, no hay con qué pisarse —
   si el jugador estaba a mitad de cruzar una celda por un paso normal,
   esa animación simplemente sigue desde la nueva posición.
3. **Desbloqueo: solo cooldown, disponible desde el arranque** — mismo
   patrón que Velocidad (`flash_cooldown_ticks_remaining`, decrementado
   en `_tick_flash_cooldown()`), sin el mecanismo de desbloqueo por
   tiempo que sí tiene Dash (`dash_unlocked`/
   `ability_unlock_progress_ticks`). Resto del wiring (`FlashCommand`,
   `GameManager._apply_flash`, `GameRoot.try_flash`,
   `ClientRoot.try_flash`/`submit_flash`, `ServerRoot.submit_flash`) es un
   espejo exacto de cómo ya viaja Dash en cada capa.

**Decisión — generalizar input a slots, no a habilidades específicas:**
las acciones de `project.godot` `speed_boost`/`dash` se renombraron a
`ability_1`/`ability_2` (mismas teclas físicas, Q/E — nadie nota el
cambio si no toca el menú nuevo). `player_node.gd._input()` ya no llama
`try_speed_boost()`/`try_dash()` directo; llama
`game_root.try_ability_slot(1)`/`try_ability_slot(2)`.
`GameRoot.try_ability_slot(slot)` resuelve qué habilidad corresponde
(lee `get_tree().root.get_meta("ability_slot_1"/"ability_slot_2")`,
default `speed`/`dash` si no hay meta — preserva el comportamiento de
antes para quien no toque el menú nuevo) y llama al `try_*`
correspondiente. **No hizo falta overridearlo en `ClientRoot`**: como
internamente llama a los métodos que `ClientRoot` sí overridea
(`try_dash`/`try_speed_boost`/`try_flash`, que mandan RPC en vez de
encolar local), el mismo código sirve para sandbox y red sin duplicar
nada — mismo criterio que ya motivó unificar el pipeline de Commands en
Fase 4.

**Decisión — selección en el menú, alcance explícito:** `main_menu.gd`
gana dos `OptionButton` ("Habilidad 1 (Q)"/"Habilidad 2 (E)", opciones
Velocidad/Dash/Flash, default Q=Velocidad E=Dash — igual que el
comportamiento de siempre). La selección se guarda vía
`get_tree().root.set_meta("ability_slot_1"/"ability_slot_2", ...)` antes
de ir a Sandbox o Cliente — mismo patrón ya usado para
`selected_map_path`/`server_ip`. **No** se pasa al camino de Servidor: el
servidor no tiene input propio ni Presentation (ver Fase 4), así que la
selección es irrelevante ahí. Importante: esto es una **conveniencia de
qué tecla dispara qué llamada**, no una restricción real de "solo 2 de 3
habilidades disponibles" — el servidor no conoce ni valida la selección
del cliente, solo ejecuta el RPC que le llegue (`submit_flash`,
`submit_dash`, etc., los tres siguen existiendo y siendo válidos siempre
para cualquier jugador). Un sistema de loadout real con validación
server-side, veto de mapa, y flujo de selección pre-partida sigue siendo
trabajo futuro más grande — ver "Diseño del sistema de slots" en
`docs/Product_Vision_and_Roadmap.md`.

**Decisión — todas las habilidades disponibles desde el arranque, para
pruebas:** pedido explícito del dueño del producto — "para pruebas da lo
mismo cuál habilidad va en qué slot, todas están disponibles desde el
inicio". Único cambio: `config/ability_balance.json`,
`dash.unlock_ticks` de `1800` a `0` — con esto `dash_unlocked` pasa a
`true` en el primer tick (`ability_unlock_progress_ticks` empieza en 0,
se incrementa a 1, `1 >= 0`), en vez de a los 30s. El mecanismo de
`PlayerSystem`/`Player` que hace el desbloqueo por tiempo **no se tocó**
— queda intacto y reversible con solo cambiar el número de vuelta, para
cuando se quiera retomar la idea (mencionada por el dueño del producto)
de que la habilidad del slot 2 se desbloquee por alguna condición (ej.
tiempo transcurrido de ronda) mientras la del slot 1 esté siempre
disponible — eso es un rediseño más grande (el desbloqueo pasaría a ser
por slot, no por habilidad específica como hoy) que se deja para cuando
se aborde de verdad el sistema de loadout.

**Probado:** 83/83 tests (agrega 6 nuevos de Flash en
`tests/unit/test_player_system.gd` — aterrizaje ignorando obstáculos
intermedios, falla si la celda de aterrizaje está bloqueada, falla si
cae fuera del mapa, instantáneo/no-animado, cooldown bloquea y luego
permite reactivar; también actualiza `tests/unit/test_ability_balance.gd`
para reflejar `dash_unlock_ticks = 0` en la config real). Verificado en
vivo con un script temporal (descartado después, no quedó en el repo)
que arrancó Sandbox real, activó slot 1 (Flash) y slot 2 (Dash) por
código (sin depender de foco de ventana/teclado, que resultó poco
confiable para automatizar en este entorno) y confirmó por captura de
pantalla real que el jugador saltó sobre el clúster de bloques
destructibles con Flash y siguió el descenso con Dash. También probado
en red real (servidor headless + cliente): el cliente mandó
`submit_flash`, el servidor lo aplicó vía `FlashCommand`, y el siguiente
snapshot reflejó la nueva posición en el cliente.

**Nota aparte, encontrada durante esta verificación:** el archivo nuevo
`flash_command.gd` no era resuelto por nombre de clase global
(`FlashCommand` no declarado) hasta que Godot regeneró
`.godot/global_script_class_cache.cfg` — ese archivo es un caché de
build (gitignored, no versionado) que Godot arma escaneando `class_name`
en el proyecto; una corrida vía `-s script.gd` no dispara ese escaneo
por sí sola si el caché ya existía de una corrida anterior. No es un bug
de código, es un artefacto de caché local — se resuelve solo con que el
editor (o una build fresca) rescanee el proyecto.

## Empujar bombas: último ítem del backlog de Habilidades

> **Superada por la siguiente entrada** ("Empujar bombas: rediseño como
> habilidad seleccionable"): el dueño del producto revisó esta primera
> versión (empuje automático de 1 celda al caminar) y pidió que fuera
> una habilidad seleccionable, con la bomba disparándose varias celdas
> hasta chocar, no un solo paso. Se deja esta entrada intacta como
> registro histórico de las decisiones y el hallazgo real que motivaron
> el diseño de `try_launch_bomb`/`_tick_bomb_movement` que sí sigue
> vigente — la sección técnica sobre por qué `grid_pos` tiene que
> actualizarse al instante sigue aplicando tal cual a la versión nueva.

**Decisión:** caminar contra una bomba ya no bloquea sin más — la
empuja una celda en la misma dirección, si esa celda está libre. Cinco
decisiones de diseño, confirmadas con el dueño del producto:

1. **Solo movimiento normal empuja.** Dash y Flash no cambian — si
   terminan sobre una celda con bomba, siguen fallando exactamente como
   antes. Son habilidades con sus propias reglas de colisión ya
   probadas; no se tocan (`try_dash`/`try_flash` no pasan por
   `_try_start_move`, que es el único call site que cambió).
2. **Se desliza animado**, no teletransporta — mismo "feel" que el paso
   normal del jugador.
3. **Colisión:** si la celda destino del empuje no es caminable o ya
   tiene otra bomba, el empuje falla y el jugador tampoco se mueve —
   mismo fail-fast que contra una pared. Colisión contra otro jugador no
   aplica: el motor nunca bloqueó movimiento por posición de otro
   jugador (confirmado auditando `_is_cell_free` antes de este cambio —
   solo chequeaba pared y bomba), así que una bomba empujada hacia la
   celda de un jugador simplemente coexiste, igual que ya coexisten hoy
   jugadores y powerups. No se introdujo colisión jugador-jugador nueva
   para esto.
4. Cualquier bomba es empujable, propia o de un rival.
5. Duración del empuje = la misma cantidad de ticks que le toma al
   jugador cruzar esa celda (`_ticks_for_speed(get_effective_speed(player))`)
   — bomba y jugador se mueven en sincronía, sin agregar un balance
   nuevo de "velocidad de empuje".

**`Bomb`** gana `move_direction`/`move_ticks_total`/`move_ticks_elapsed`/
`is_moving` — mismo patrón que `Player`, más `get_move_progress()`
(vive en `Bomb`, no en `BombSystem`, porque `Bomb` ya es dueño de su
propia lógica de tick — `tick_update()` — a diferencia de `Player`, que
es puro dato).

**`BombSystem`** gana `get_bomb_at(cell)` (scan lineal, mismo patrón que
`is_cell_occupied_by_bomb`) y `try_push_bomb(bomb, direction, ticks_total)`.
`tick()` gana `_tick_bomb_movement()` como primer paso.

**Hallazgo real durante la implementación — por qué `grid_pos` se
actualiza al instante en `try_push_bomb`, no al completar el
deslizamiento (a diferencia de `Player.grid_position`, que sí es
lazy):** la primera versión mirror exacto de `Player` (mover `grid_pos`
recién en `_tick_bomb_movement`, al llegar a `move_ticks_total`) falló un
test real (`test_player_pushes_bomb_when_walking_into_it`): el jugador se
frenaba a último momento, pese a que el empuje ya se había validado y
comprometido al arrancar. Causa: `GameManager.tick()` llama
`player_system.tick(state)` y `bomb_system.tick(state)` por separado —
en el tick en que el jugador completa su movimiento y `_update_player`
re-valida `_is_cell_free(next_cell)` (re-chequeo de llegada, sin cambios,
ver más abajo), la bomba todavía no había corrido su propio
`_tick_bomb_movement()` de ese mismo tick (corre después, en la llamada
siguiente), así que seguía reportando `grid_pos` en la celda vieja —
el jugador se veía bloqueado por una bomba que en la práctica ya se
había ido. La solución: `try_push_bomb` actualiza `grid_pos` al instante
al comprometerse el empuje (nada puede interrumpirlo después de
empezado); los campos `move_*` quedan puramente cosméticos, solo para
que `game_renderer.gd` interpole el deslizamiento visual desde la celda
vieja hacia `grid_pos` (que ya es la nueva) — `_draw_bombs()` calcula el
offset como `-move_direction * (1 - progress) * cell_size` en vez de
`+move_direction * progress * cell_size` que usa `Player`, justamente
porque acá `grid_pos` es el destino, no el origen. Con esto, no hay
ninguna ventana de inconsistencia posible entre jugador y bomba sin
importar el orden de los `tick()`.

**`PlayerSystem._try_start_move`** — único call site que cambió: si la
celda destino no es caminable, falla igual que siempre; si tiene una
bomba, busca la bomba (`get_bomb_at`) e intenta empujarla
(`try_push_bomb`) antes de fallar. Como vive acá y no en
`_update_player`, empujar también funciona para movimiento encadenado
(sostener la tecla y cruzar varias bombas seguidas) sin tocar ese
código — `_update_player` ya vuelve a llamar `_try_start_move` para cada
celda nueva vía `next_direction`. El re-chequeo de llegada que ya hacía
`_update_player` (`_is_cell_free` al completar una celda) se deja sin
cambios a propósito: el empuje se resuelve una sola vez, al arrancar el
movimiento, no se reintenta en la llegada.

`snapshot_codec.gd` suma los 4 campos nuevos de `Bomb` al dict
serializado/deserializado, mismo patrón que los campos de movimiento de
`Player`.

**Probado:** 87/87 tests (empuje exitoso con jugador y bomba
sincronizados, empuje bloqueado por pared, empuje bloqueado por otra
bomba, confirmación de que Dash y Flash no empujan). El
round-trip de `snapshot_codec.gd` se extendió para cubrir explícitamente
una bomba **a mitad de empuje** (`is_moving=true`, `move_ticks_elapsed`
parcial), no solo el caso estático — mismo criterio que ya cubría
`Player.move_direction` a mitad de paso. Verificado en vivo en Sandbox
real (script temporal, descartado después de confirmar) sosteniendo la
tecla de movimiento contra una bomba: empujó, y al seguir sosteniendo la
tecla encadenó varios empujes seguidos (la bomba terminó 2 celdas
adelante del jugador tras 4 empujes consecutivos) — confirmado con
capturas de pantalla reales mostrando el deslizamiento. No se repitió la
verificación en vivo por red (servidor+cliente reales): el mecanismo de
red para el nuevo estado de `Bomb` es idéntico en tipo al que ya mueve
`Player.move_direction` por snapshot desde Fase 4, y quedó cubierto por
el test de round-trip con bomba a mitad de empuje — repetir la
automatización de dos procesos no agregaba señal nueva.

## Empujar bombas: rediseño como habilidad seleccionable

**Por qué se rediseñó:** la primera versión (entrada anterior) hacía que
caminar contra **cualquier** bomba la empujara automáticamente 1 celda,
siempre — el dueño del producto la probó y pidió que fuera una **4ta
habilidad seleccionable** más (junto a Velocidad/Dash/Flash, en el mismo
menú de slots Q/E), y que el disparo fuera mucho más contundente: la
bomba sale despedida en la dirección del empujón **hasta chocar con algo
colisionable**, no una sola celda.

**Decisión, confirmada con el dueño del producto:**

1. **Es una habilidad, no una mecánica automática.** Activarla abre una
   ventana de tiempo configurable (`bomb_push_window_ticks`, default 120
   = 2s). Mientras dura, caminar contra **cualquier** bomba la dispara.
   Sin la habilidad activa, una bomba vuelve a bloquear exactamente
   igual que una pared — se revirtió por completo el comportamiento
   automático de la entrada anterior.
2. **La ventana no se consume con el primer uso.** Se puede disparar
   más de una bomba mientras quede tiempo — solo el paso del tiempo
   (vía tick) la cierra, no el hecho de haber disparado.
3. **El jugador avanza** a la celda que la bomba deja libre (como en la
   versión anterior) — no es un golpe que lo deja quieto.
4. **La bomba viaja varias celdas**, no una — sigue en la misma
   dirección, sola, celda por celda, hasta que la siguiente no sea
   caminable o ya tenga otra bomba (mismo criterio fail-fast de
   siempre).
5. **Se frena si su camino cruza a otro jugador parado ahí** — único
   lugar del motor donde la posición de un jugador bloquea algo (nunca
   pasa en ningún otro caso: jugadores nunca se bloquean entre sí).
   Excepción acotada solo a la bomba disparada, no un cambio general de
   colisión jugador-jugador.
6. **El timer sigue corriendo mientras vuela.** Si llega a cero a mitad
   de camino, explota ahí donde esté en ese momento, no en la celda
   donde habría terminado de frenarse.
7. **Velocidad de vuelo configurable aparte** (`bomb_push_launch_ticks_per_cell`,
   default 5 — más rápido que los ~10 ticks/celda de un paso normal, se
   siente como un disparo), independiente de la velocidad del jugador
   que la disparó (a diferencia de la versión anterior, que reusaba la
   velocidad del jugador para que se movieran en sincronía — ya no hace
   falta esa sincronía porque ahora solo el primer segmento del vuelo
   coincide con el paso del jugador, el resto la bomba sigue sola).

**`PlayerSystem._try_start_move` vuelve a su forma original** (bloquear
si hay pared o bomba) **más** un nuevo camino condicional: si hay una
bomba y `player.bomb_push_active_ticks_remaining > 0`, intenta
`_launch_bomb()` antes de bloquear. `Player` gana
`bomb_push_active_ticks_remaining`/`bomb_push_cooldown_ticks_remaining`
— mismo patrón dual que Velocidad — y `try_activate_bomb_push()` (mismo
patrón que `try_activate_speed_boost`) para activarla.

**`BombSystem.try_push_bomb` se renombra a `try_launch_bomb`** — misma
forma (falla si `is_moving`/pared/bomba en el destino; si pasa,
`grid_pos` al instante + arranca `move_*`), pero ahora es solo el primer
segmento de un vuelo potencialmente largo. `_tick_bomb_movement()` deja
de simplemente "parar" al completar un segmento: calcula la siguiente
celda y decide si seguir (avanza `grid_pos` al instante otra vez, resetea
el contador de ticks del segmento, sigue `is_moving`) o frenarse ahí
(pared/bomba/jugador). La razón de por qué `grid_pos` tiene que ser
eager en **cada** segmento, no solo el primero, es la misma que ya
documentó la entrada anterior para el primer segmento (evitar la
ventana de inconsistencia entre `PlayerSystem.tick()` y
`BombSystem.tick()`) — generalizada: además resuelve gratis "explota
donde esté" (la explosión ya lee `bomb.grid_pos`, que siempre es la
posición real y actual).

**Cómo se chequea la colisión contra un jugador sin romper el
aislamiento `BombSystem`/`PlayerSystem`:** `BombSystem` no puede
depender de la clase `PlayerSystem` (violaría la decisión ya documentada
en Fase 4 sobre bomb_range/max_bombs_for_owner — evita el acoplamiento
circular). `BombSystem.tick(state, player_positions: Array[Vector2i] = [])`
gana un parámetro opcional (default `[]`, ningún test/caller existente
que no lo pasa se rompe); `GameManager.tick()` arma la lista desde
`player_system.players.values()` después de tickear el movimiento de
los jugadores, y se la pasa. Mismo criterio que ya usa `place_bomb()`
para `bomb_range`/`max_bombs_for_owner`: el caller resuelve el dato
derivado de jugadores, `BombSystem` solo recibe valores planos.

**Menú principal:** `ABILITY_NAMES`/`ABILITY_LABELS` en `main_menu.gd`
ganan una 4ta entrada, `"push"`/`"Empujar"` — asignable a cualquiera de
los 2 slots (Q o E), sin tocar los defaults (Q=Velocidad, E=Dash).
`GameRoot.try_ability_slot()` gana la rama `"push": try_bomb_push()`.
Red: `BombPushCommand`, `GameManager._apply_bomb_push`,
`ClientRoot.try_bomb_push()`/`submit_bomb_push`,
`ServerRoot.submit_bomb_push()` — espejo exacto del resto de las
habilidades.

**Probado:** 92/92 tests — reemplaza los 5 tests de la versión anterior
por 10 nuevos: bloqueo restaurado sin la habilidad activa, disparo que
cruza varias celdas hasta chocar con una pared, se frena al cruzar la
celda de otro jugador, se frena al cruzar la celda de otra bomba,
explota en la celda donde esté si el timer se acaba a mitad de vuelo (no
en la celda final — mapa ancho sin pared cerca para que la única causa
de frenado sea el timer), la ventana no se consume con un solo disparo,
cooldown bloquea y permite reactivar, Dash/Flash siguen sin disparar
bombas aunque la habilidad esté activa. Verificado en vivo en Sandbox
real (script temporal, descartado después): confirmado por captura que
sin la habilidad activa el jugador queda bloqueado contra la bomba en el
spawn, y que con la habilidad activa avanza varias celdas mientras la
bomba sale disparada mucho más lejos, frenándose sola contra el borde
del mapa.

## Composition root: GameRoot inyecta hacia Presentation por código, no por escena

**Decisión:** `player_node.gd` no usa `@export var game_root: GameRoot`
configurado a mano en el Inspector. En vez de eso, expone
`set_game_root(root)`, y `GameRoot._ready()` lo busca como nodo hermano
(`get_node_or_null("../Player")`, ruta relativa) y se inyecta a sí mismo.

**Por qué:** el spec prohíbe rutas absolutas (regla que el código viejo
violaba con `get_node("/root/Main/GridManager")`) y exige que las
dependencias se armen en la raíz de composición. Inyectar por código desde
`GameRoot` cumple ambas reglas sin depender de que alguien recuerde
conectar la referencia en el editor de Godot cada vez que se toque la
escena.

## Fase 7 (arranque): Matchmaking — solo emparejar

**Decisión:** primera pieza de Fase 7. A diferencia de todo lo hecho hasta
acá, vive **fuera de Godot** — `matchmaking/` es un servicio Python nuevo
en la raíz del repo, no una escena más del proyecto. Cuatro decisiones
confirmadas con el dueño del producto:

1. **Stack: Python.** El rol es 100% I/O-bound (cola, esperar procesos,
   más adelante DB) — nunca toca la simulación en tiempo real, que sigue
   enteramente en Godot/ENet. Además es lo que el dueño del proyecto ya
   conoce, relevante para un proyecto que mantiene solo/a durante años.
2. **Alcance: solo emparejar.** Sin cuentas, login, ni ranking
   (Elo/Glicko-2) todavía — cola anónima FIFO, empareja de a 2.
3. **El matchmaking lanza un `ServerRoot` headless nuevo por partida**
   encontrada, no apunta a uno ya corriendo a mano.
4. **Corre en la PC local** del dueño del proyecto por ahora.

**Protocolo cliente↔matchmaking:** WebSocket + JSON (`WebSocketPeer`
nativo de Godot del lado cliente, librería `websockets` de Python del
otro). Cliente → servidor: `{"type": "join_queue"}`. Servidor → cliente:
`{"type": "matched", "server_ip": ..., "server_port": ...}`.

**Por qué cada partida necesita un puerto distinto:**
`ServerRoot.DEFAULT_PORT` (8910) es una `const` — dos procesos no pueden
escuchar en el mismo puerto, y el matchmaking puede lanzar varias
partidas a la vez. `matchmaking/match_launcher.py` reserva un puerto
libre de un rango configurable (9000-9099 por defecto, separado del 8910
del flujo manual para no pisarse si se usan los dos a la vez) y se lo
pasa al proceso Godot después del separador `--`, que Godot no interpreta
como argumento propio del motor:
```
<godot_exe> --headless --path <project> scenes/server.tscn -- --port=9001
```
`ServerRoot._parse_port_override()` (nuevo) busca `--port=N` en
`OS.get_cmdline_user_args()`; sin ese argumento sigue usando
`DEFAULT_PORT` — el flujo manual de Fase 5/6 (botón "Servidor" del menú)
no cambia en absoluto. `ClientRoot` gana el mismo patrón del otro lado:
`_selected_server_port()` (mirror de `_selected_server_ip()`) lee una
meta `"server_port"` del root del árbol, default `ServerRoot.DEFAULT_PORT`
si no está seteada.

**`matchmaking/` — estructura, separando lógica pura de infraestructura**
(mismo criterio que ya sigue todo el proyecto Godot, ver
`Engine_Architecture_Specification_v1.0.md`, aplicado ahora también del
lado Python):
- `queue_manager.py`: cola FIFO pura (`add`/`remove`/`pop_pair`), sin
  `asyncio` ni sockets — 100% testeable con pytest normal.
- `match_launcher.py`: `allocate_port`/`release_port` sobre el rango
  configurado + `launch_match(port)` que arma el comando y hace
  `subprocess.Popen`. Puertos asignados en memoria (`_used_ports`), no
  se verifica contra el SO — alcanza para esta pasada de un solo proceso
  de matchmaking.
- `protocol.py`: encode/decode JSON + constantes de tipo de mensaje.
- `server.py`: el único módulo con `asyncio`/`websockets` — conecta las
  piezas puras de arriba con conexiones reales. Por cada mensaje
  `join_queue` mete al cliente en la cola; si `pop_pair()` da un par,
  reserva puerto, lanza el proceso, espera `SERVER_STARTUP_DELAY_SECONDS`
  (fijo, ~1.5s — no hay handshake real de "servidor listo" todavía, ver
  más abajo) y les manda `matched` a los dos.
- `config.py`: todo por variable de entorno. La única sin default
  razonable es `GODOT_EXECUTABLE` (la ruta al ejecutable varía por
  máquina) — se documenta en `matchmaking/README.md`.

**`scenes/matchmaking.tscn` + `scripts/tools/matchmaking_client.gd`:**
mismo patrón de "UI armada por código" que `main_menu.gd`. Se conecta al
matchmaking (dirección fija `127.0.0.1:8765` esta pasada, coherente con
"corre en la PC local"), manda `join_queue`, hace poll del `WebSocketPeer`
en `_process()`, y al recibir `matched` guarda `server_ip`/`server_port`
en meta del root (mismo mecanismo que `selected_map_path`/`server_ip` ya
usan) y cambia a `client.tscn` — reutiliza el 100% de `ClientRoot` sin
tocarlo más que el puerto dinámico ya descripto arriba. `main_menu.gd`
gana el botón "Buscar partida" (aplica la selección de habilidades igual
que Sandbox/Cliente antes de cambiar de escena).

**Probado:** 92/92 tests de Godot (esta pasada no toca Domain/Systems,
cero regresiones esperadas y confirmadas) + 11/11 tests nuevos de pytest
(`matchmaking/tests/`, cola/empareje y asignación de puertos con
`subprocess.Popen` mockeado). Verificado en vivo, dos veces, con dos
clientes Godot reales (procesos separados) y el servicio de matchmaking
corriendo en esta máquina: ambos se anotaron, matchearon, el backend
lanzó un `ServerRoot` dinámico (puerto 9000 la primera vez, 9001 la
segunda — confirma que el rango de puertos y la no-reutilización
funcionan), y los dos clientes se conectaron a la misma partida
automáticamente sin ninguna acción manual — capturas de pantalla y logs
confirmando ambos casos.

**Hallazgo real durante esta verificación, fuera del alcance de esta
pasada:** en la segunda corrida, dejando la partida corriendo ~30
segundos reales con chequeos periódicos, uno de los dos clientes
("B") dejó de ver al otro jugador a partir del segundo ~24 (su propio
`player_system.players` pasó de 2 a 1 entradas y no se recuperó), pese a
que el otro cliente ("A") siguió viendo a ambos sin problema todo el
tiempo y el servidor nunca reportó ninguna desconexión de "A" en ese
lapso. **No tiene relación con el código de esta pasada** — matchmaking
no toca `_broadcast_snapshot`/`SnapshotCodec`/ninguna lógica de red
existente; es un hallazgo sobre la capa de red base (Fase 4-6) que nunca
se había estresado con una sesión de más de unos pocos segundos entre 2
clientes reales simultáneos. Decisión explícita del dueño del producto:
cerrar matchmaking como está documentado acá, investigar esto por
separado — queda anotado como tarea propia, no bloquea esta entrega.

**Seguimiento — descartado como bug real:** se reprodujo el mismo
escenario (servidor headless + 2 clientes reales) pero por el flujo
**normal** (`godot --path . scenes/client.tscn`, sin el script temporal
`-s script.gd` extendiendo `SceneTree` que se usó en la verificación de
matchmaking), con instrumentación temporal (`print` cada 60 ticks del
lado servidor y de cada cliente, revertida después de confirmar) dejando
la partida corriendo **~4.7 minutos reales** — casi 10 veces más que el
punto donde había aparecido el problema. Los tres logs (servidor,
cliente A, cliente B) mantuvieron `players=2` de forma perfectamente
consistente todo el tiempo, sin un solo drop. Conclusión: no es un bug
de la capa de red — fue un artefacto del método de verificación anterior
(instanciar `ClientRoot` a mano dentro de un `SceneTree` custom vía
`-s`, en vez de la carga normal de escena), no algo que un jugador real
vaya a experimentar. No hace falta ninguna corrección de código.

**Fuera de alcance (explícito):** cuentas/login, ranking (Elo/Glicko-2),
hosting cloud, cerrar el proceso del `ServerRoot` cuando termina la
partida (queda corriendo — limitación conocida), handshake real de
"servidor listo" (espera fija en su lugar), reconexión/espectador (ya
fuera de alcance desde Fase 6), UI para elegir la dirección del
matchmaking (fija a `127.0.0.1` esta pasada).
