# Implementation Decisions

Este documento registra decisiones de implementación tomadas al aplicar
`Engine_Architecture_Specification_v1.0.md` a casos concretos que el spec
no detalla. El spec define los principios permanentes; este documento
explica cómo se aterrizaron y por qué, para que se puedan revisar o
revertir con contexto si el juego evoluciona (por ejemplo, si se migra de
motor).

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
