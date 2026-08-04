# Implementation Decisions

Este documento registra decisiones de implementación tomadas al aplicar
`Engine_Architecture_Specification_v1.0.md` a casos concretos que el spec
no detalla. El spec define los principios permanentes; este documento
explica cómo se aterrizaron y por qué, para que se puedan revisar o
revertir con contexto si el juego evoluciona (por ejemplo, si se migra de
motor).

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
