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
