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
| 3 | PowerUps, reglas completas, sistema de rondas | 🔶 PowerUps hechos; sistema de rondas en curso |
| 3.5 | Editor de mapas | ✅ Primera versión (pintar/guardar/cargar/jugar) |
| 4 | Arquitectura Cliente-Servidor local (todo en una sola PC) | Pendiente |
| 5 | Multiplayer LAN | Pendiente |
| 6 | Servidor dedicado, juego por Internet | Pendiente |
| 7 | Matchmaking, ranking, colas competitivas | Pendiente |
| 8 | Bots, IA | Pendiente |
| 9 | Steam | Pendiente |
| 10 | Balance, beta cerrada, optimización, lanzamiento | Pendiente |

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
