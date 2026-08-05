class_name Player
extends RefCounted

var id: int
var grid_position: Vector2i

var alive: bool = true
var respawn_at_tick: int = -1
var rounds_won: int = 0

# Cuántos powerups de cada tipo acumuló. Nunca se guarda un valor final
# (velocidad, rango, etc.) — siempre se deriva de balance base + estos
# contadores (ver PlayerSystem.get_effective_*), así no hay estado "sucio".
var speed_powerup_stacks: int = 0
var bomb_range_powerup_stacks: int = 0
var extra_bomb_powerup_stacks: int = 0
var shield_ticks_remaining: int = 0

var move_direction: Vector2i = Vector2i.ZERO
var next_direction: Vector2i = Vector2i.ZERO

# Progreso del movimiento en curso, siempre en ticks enteros (determinismo
# para online: ver docs/Product_Vision_and_Roadmap.md). La interpolación a
# float para dibujar en pantalla ocurre solo en Presentation.
var move_ticks_total: int = 1
var move_ticks_elapsed: int = 0

# Cuántas celdas cubre el movimiento en curso — 1 en un paso normal, 2 en
# un dash. Generaliza _update_player() sin un camino de movimiento aparte
# para Dash (ver PlayerSystem.try_dash).
var move_distance_cells: int = 1

var facing_direction: Vector2i = Vector2i.DOWN

var is_moving: bool = false
var has_pending_move: bool = false

# Habilidades (ver docs/architecture/Implementation_Decisions.md): loadout
# fijo por ahora (Velocidad de entrada + Dash desbloqueable). Progreso de
# desbloqueo en ticks acumulados, no timestamp absoluto — mismo patrón que
# shield_ticks_remaining, evita depender de state.tick en donde se crean
# los jugadores.
var dash_unlocked: bool = false
var ability_unlock_progress_ticks: int = 0