# Proyecto: Bomberman Competitivo Online

> Transcripción de `Proyecto Bomberman Competitivo Online.pdf` (aportado por
> el dueño del proyecto), versionada en el repo para que cualquier chat o
> colaborador futuro tenga este contexto sin depender de que se resuba el
> PDF. Es el documento rector de producto/roadmap; `docs/architecture/`
> contiene las decisiones técnicas derivadas de él.

## Objetivo del proyecto

Desarrollar un videojuego inspirado en Bomberman, orientado exclusivamente
al juego competitivo online, con lanzamiento comercial en Steam.

El objetivo no es recrear el Bomberman clásico, sino construir un juego
competitivo moderno donde la calidad del gameplay, el rendimiento y la
estabilidad del online sean las prioridades absolutas.

El proyecto debe desarrollarse con una arquitectura profesional desde el
primer día, evitando soluciones temporales que luego obliguen a reescribir
grandes partes del código.

## Filosofía del desarrollo

Las prioridades del proyecto serán siempre:

1. Gameplay sólido y consistente.
2. Arquitectura limpia y mantenible.
3. Online robusto.
4. Excelente rendimiento.
5. Arte y contenido.

No se agregará contenido innecesario hasta que la base del juego esté
completamente terminada. El objetivo es construir un juego que pueda
sostener un entorno competitivo.

## Características principales

**Estilo gráfico:** 2D, Pixel Art, vista superior (Top Down).

**Movimiento:** únicamente en cuatro direcciones (arriba/abajo/izquierda/
derecha). No existen movimientos diagonales. El juego se desarrolla
completamente sobre una grilla.

**Modos de juego iniciales:**
- Ranked 1 vs 1 — modo principal del juego.
- Free For All (1v1v1v1) — cuatro jugadores compitiendo entre sí.
- Partida personalizada — jugar con amigos, agregar Bots, configurar
  parámetros de la partida.

**Plataforma:** Steam (Windows inicialmente).

## Motor y lenguaje

**Motor:** Godot — rendimiento en 2D, liviano, open source, exportación
sencilla, buen soporte de pixel art, integración con Steam posible,
comunidad activa.

**Lenguaje:** GDScript (sintaxis similar a Python). C# solo si hiciera
falta una optimización puntual.

## Arquitectura general

El proyecto debe dividirse en módulos independientes:

```
Cliente
   ↓
Servidor de Login
   ↓
Servidor de Matchmaking
   ↓
Servidor de Partidas
```

Cada módulo debe tener responsabilidades claras.

## Filosofía del servidor

Modelo **Servidor Autoritativo**. Nunca Peer-to-Peer. Toda decisión
importante la toma el servidor: movimiento válido, explosiones, muerte,
powerups, ganador. El cliente únicamente envía acciones del jugador; el
servidor responde con el estado oficial del juego. Es el mismo enfoque de
Valorant, League of Legends, Counter-Strike o Rocket League.

**Matchmaking:** servidor central para login, cola competitiva, creación
de partidas y asignación de servidores. Sin conexiones directas entre
jugadores.

**Ranking:** no se inventa un algoritmo propio — Elo o Glicko-2 (sistemas
ampliamente probados). La elección definitiva se toma más adelante.

## Filosofía del Game Engine

La lógica del juego debe estar completamente separada del render. La
lógica debe poder ejecutarse incluso sin mostrar gráficos.

```
GameState
├── Players
├── Bombs
├── Explosions
├── PowerUps
├── Map
└── Round
```

El render únicamente consulta el estado actual del juego para dibujarlo.
Nunca modifica la lógica.

**Mapa:** todo el juego sobre una grilla, celdas de tamaño fijo (16x16 o
32x32 por ejemplo). Todas las entidades ocupan posiciones de la grilla.

**Movimiento:** la lógica trabaja únicamente con coordenadas enteras
(ej. `(5,7)`) — **no se usan posiciones flotantes para la simulación**.
Esto simplifica sincronización online, reproducibilidad, determinismo y
depuración. Las animaciones sí pueden interpolarse visualmente.

**Tick del juego:** sistema de ticks (ej. 60 por segundo). En cada tick se
actualiza movimiento, bombas, explosiones, powerups, temporizadores y
condiciones de victoria. No depender de físicas del motor.

**Bombas:** cada bomba almacena solo lo necesario — posición, propietario,
tiempo restante, alcance. Al llegar el temporizador a cero: calcular
explosión, eliminar bomba.

**Explosiones:** sin física — recorren la grilla en las 4 direcciones
hasta encontrar un obstáculo. Sistema extremadamente eficiente.

## Inteligencia Artificial

No forma parte de la primera etapa. Orden correcto: Gameplay → Multiplayer
→ Balance → IA.

## Integración con Steam

Etapa avanzada: Steamworks, Steam Cloud, Friends, Invitaciones, Overlay,
Logros. No debe desarrollarse durante las primeras fases.

## Editor de mapas (Fase 3.5)

**Por qué existe esta fase:** todavía no se sabe qué prefieren los
jugadores en cuanto a mapas — pasillos vs. huecos, grandes vs. chicos,
estáticos (memorizables) vs. procedurales (patrones reconocibles pero
ubicación impredecible). En vez de adivinar, el plan es ofrecer variedad
desde el arranque y aprender del feedback real de los jugadores. Para eso
hace falta poder crear mapas rápido, a mano — sin ella, cada mapa nuevo
significa tocar código.

**Qué es:** un editor de mapas simple, al estilo del World Editor de
Warcraft 3 — un espacio en blanco donde pintar celdas (piso, pared
indestructible, bloque destructible, spawn) y guardar el resultado. Es
factible de forma directa en este proyecto porque `GameMap` ya es una
estructura de datos pura, completamente separada del render — el editor
es, en esencia, otra pieza de Presentation que lee/escribe esa misma
estructura, sin tocar Domain/Systems.

**Doble propósito:** la misma herramienta sirve primero para el propio
desarrollo (probar teorías de diseño de mapa antes de tener jugadores) y
después, sin cambios de arquitectura, para la comunidad — si no se
encuentra la respuesta a qué mapa funciona mejor, que la generen los
propios jugadores. Compartir esos mapas con otros (workshop) depende de
tener Steam integrado, así que esa parte llega naturalmente en la Fase 9;
el editor y los mapas locales no dependen de eso para nada.

**Cuándo:** después de cerrar Fase 3 (con el sistema de rondas
funcionando) y antes de Fase 4 (cliente-servidor) — es una herramienta de
iteración de gameplay, prioridad #1 según la filosofía del proyecto, y
conviene tenerla antes de meterse en la complejidad de red.

## Principio fundamental

El proyecto debe construirse como un juego competitivo online desde el
primer día. No debe diseñarse primero un juego offline para luego intentar
agregar multiplayer. Toda la arquitectura debe contemplar el juego en red
desde el inicio.

## Roadmap general

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Movimiento, colisiones, grilla | ✅ Hecho |
| 2 | Bombas, explosiones, bloques destructibles | ✅ Hecho |
| 3 | PowerUps, reglas completas, sistema de rondas | ✅ Hecho |
| 3.5 | Editor de mapas | ✅ Hecho (pintar/guardar/cargar/jugar + redimensionar + scroll/zoom). Pendiente real: guardar en `user://` (recién hace falta al exportar) |
| 4 | Arquitectura Cliente-Servidor local (todo en una sola PC) | ✅ Hecho (ENet real sobre loopback, N jugadores conectados y renderizados por cliente) |
| 5 | Multiplayer LAN | ⚠️ Código listo (el servidor ya escucha en todas las interfaces, no solo loopback; muestra su IP de LAN en pantalla) — falta probarlo con una segunda PC física en la misma red |
| 6 | Servidor dedicado, juego por Internet | Pendiente |
| 7 | Matchmaking, ranking, colas competitivas | Pendiente |
| 8 | Bots, IA | Pendiente |
| 9 | Steam | Pendiente |
| 10 | Balance, beta cerrada, optimización, lanzamiento | Pendiente |

## Ideas futuras (backlog, no implementar todavía)

Registradas para no perderlas entre sesiones de chat. Ninguna de estas
requiere replantear la arquitectura actual — encajan sobre lo que ya
existe siguiendo los mismos patrones ya establecidos (config separada por
concern, systems nuevos coordinados por GameManager, orígenes
intercambiables para datos como GameMap). Se listan con una nota de qué
tan grande es cada una y qué decisiones de diseño van a hacer falta
cuando se construyan.

### Partidas

**Categorías:** Competitivo (balance ajustado según preferencia de
jugadores), Casual, Personalizada (Bot/IA, modo, balance modificable,
mapa específico o procedural).

**Modos:** 1v1, 1v1v1v1 (FFA), Duos 2v2, Equipo 3v3.

- Multi-jugador (FFA): ya soportado — `PlayerSystem` es un diccionario
  por id, no asume un solo jugador, ya probado con 2 en los tests de
  rondas.
- Balance por categoría: ya soportado — `GameBalance`/`PowerUpBalance`
  ya reciben la ruta del JSON como parámetro; solo hace falta tener
  varios archivos de config (`balance_competitivo.json`, etc.) y elegir
  cuál cargar.
- Mapa específico en personalizada: ya soportado, es lo que ya
  construimos en el editor de mapas (Fase 3.5).
- Bots/IA: arquitectónicamente "otro Player controlado por un módulo de
  decisión en vez de por input humano" — llamaría a la misma API de
  `GameRoot`. Coincide con el orden ya planeado (Fase 8, después de
  Multiplayer y Balance).
- Equipos (Duos/Equipo): necesita `team_id` en `Player` y cambiar la
  condición de victoria de ronda ("queda 1 jugador vivo") a ("queda 1
  equipo con algún jugador vivo") — extensión acotada de
  `GameManager._check_round_end()`.
- Mapas procedurales de verdad (aleatorios, no el único patrón fijo de
  hoy): sería un tercer origen de `GameMap`, ej.
  `GameMap.from_procedural_generation(seed, params)` — mismo patrón que
  `from_balance`/`from_definition`.
- Sistema de ELO/matchmaking/preferencia de jugadores: vive fuera del
  cliente Godot a propósito (es el "Servidor de Matchmaking" del propio
  documento, Fase 6/7). El cliente solo necesitaría reportar resultados
  — `GameManager.match_ended` y `Player.rounds_won` ya son el tipo de
  dato que un backend de stats querría recibir. No hace falta telemetría
  automatizada antes de tener jugadores reales; una encuesta manual
  alcanza para empezar.

### Habilidades (loadout pre-partida)

✅ **Primera pasada hecha:** Velocidad (ráfaga temporal con cooldown,
tecla **Q**, disponible de entrada) + Dash (tecla **E**, se desbloquea a
los 30s, alcance configurable — 3 celdas por defecto). Loadout fijo para
todos los jugadores — sin pantalla de selección todavía. Todo lo
balanceable de cada habilidad (bonus, duración, cooldown, alcance,
tiempo de desbloqueo) vive en `config/ability_balance.json`, no
hardcodeado — un solo lugar para ajustar números. Ver
`docs/architecture/Implementation_Decisions.md`. Sigue pendiente todo lo
demás de esta sección: Empujar bombas, Flash, selección real de
loadout, objetivos de desbloqueo por ubicación/estructura.

**Diseño del sistema de slots (documentado, todavía sin implementar):**
cada jugador tiene 2 slots de habilidad — **Q** (slot 1) y **E** (slot
2). El jugador elige qué habilidad va en cada slot; según dónde la
ponga, la tiene disponible desde el arranque de la ronda (slot Q) o
recién al cumplir la condición de desbloqueo de ese slot (slot E) — la
habilidad en sí no está atada a un slot fijo, es el jugador quien decide
el orden. Flujo previo a la partida imaginado: cola competitiva → se
encuentra un rival → se elige/vetea el mapa → cada jugador elige
personaje (por ahora solo estético) → cada jugador elige sus 2
habilidades y en qué slot va cada una. Esto es un feature del tamaño de
"Partidas" (matchmaking, veto de mapa, selección) — no se construye de
una, queda como diseño de referencia para cuando se aborde esa fase.

**Feedback visual de habilidades — pendiente:** hoy es difícil notar si
una habilidad se activó (Dash es obvio porque se ve al personaje
desplazarse distinto; la ráfaga de Velocidad casi no se percibe a
simple vista). Falta pensar una forma visual consistente de mostrar, por
habilidad: si está disponible, en cooldown, o si acaba de activarse.

Cada jugador elige 2 habilidades antes de entrar: una disponible de
entrada, la segunda se desbloquea al cumplir un objetivo en la ronda
(llegar a un lugar, destruir una estructura especial, o un tiempo fijo
como 30 segundos). Es la pieza que más le da identidad competitiva
propia al juego (a diferencia de Bomberman clásico). Lista inicial a
seguir expandiendo: empujar bombas, multiplicador de velocidad inicial,
flash hacia adelante (salta 1 casilla, ignora colisión), dash hacia
adelante (respeta colisión).

Es un feature de tamaño comparable a powerups + rondas juntos — no un
agregado chico. Encaja con el mismo patrón ya usado para separar
`PowerUpBalance` de `GameBalance`: un dominio nuevo (`Ability`), un
balance propio, un system (o extensión de `PlayerSystem`) para
desbloqueo y activación.

Decisiones de diseño reales que van a aparecer (no resueltas todavía):

- **Empujar bombas** rompe la regla actual de "nunca se puede pisar una
  bomba" — necesita una rama de lógica nueva (desplazar la bomba en vez
  de bloquear el movimiento) y resolver qué pasa si la bomba empujada
  choca contra otra bomba, una pared, o un jugador.
- **Flash** es una primitiva de movimiento nueva, no una extensión de la
  actual: el movimiento por tick asume siempre una celda adyacente
  validada. Falta decidir si valida solo la celda de aterrizaje (no la
  de en medio) y qué pasa si esa celda tiene una bomba o está fuera del
  mapa.
- Los objetivos de desbloqueo por ubicación o estructura especial
  encajan extendiendo `MapDefinition` (posiciones de objetivo, mismo
  patrón que `spawn_positions`, incluso pintable en el editor) y
  `DestructibleBlock` (una variante especial), respectivamente. El
  desbloqueo por tiempo ya es trivial con `state.tick`.

## Forma de trabajo para los futuros chats

Los futuros chats deben actuar como arquitectos de software especializados
en desarrollo de videojuegos competitivos. Se priorizan siempre: buenas
prácticas, arquitectura escalable, rendimiento, mantenibilidad,
simplicidad.

Antes de implementar cualquier sistema importante debe analizarse si la
decisión afectará negativamente el desarrollo futuro. No se busca
únicamente "hacer que funcione", sino construir una base sólida sobre la
que el proyecto pueda crecer durante varios años.

Toda decisión técnica debe justificarse considerando: rendimiento,
escalabilidad, facilidad de mantenimiento, compatibilidad con el modelo de
servidor autoritativo, y experiencia competitiva del jugador.

El objetivo final es un juego comercial competitivo, estable, de alto
rendimiento y preparado para publicarse en Steam.
