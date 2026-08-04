class_name Player
extends RefCounted

var id: int
var grid_position: Vector2i

var alive: bool = true
var respawn_at_tick: int = -1

var speed: float = 6.0  # celdas/segundo (config); se traduce a ticks al iniciar cada movimiento

var move_direction: Vector2i = Vector2i.ZERO
var next_direction: Vector2i = Vector2i.ZERO

# Progreso del movimiento en curso, siempre en ticks enteros (determinismo
# para online: ver docs/Product_Vision_and_Roadmap.md). La interpolación a
# float para dibujar en pantalla ocurre solo en Presentation.
var move_ticks_total: int = 1
var move_ticks_elapsed: int = 0

var facing_direction: Vector2i = Vector2i.DOWN

var is_moving: bool = false
var has_pending_move: bool = false