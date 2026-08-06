class_name Bomb
extends RefCounted

var grid_pos: Vector2i
var owner_id: int
var timer: int
var range: int
var active: bool = true

# Empujar bombas (ver docs/architecture/Implementation_Decisions.md):
# mismo patrón que el movimiento del jugador — grid_pos solo cambia al
# completar el deslizamiento, no al arrancarlo (BombSystem.try_push_bomb).
var move_direction: Vector2i = Vector2i.ZERO
var move_ticks_total: int = 1
var move_ticks_elapsed: int = 0
var is_moving: bool = false


func _init(pos: Vector2i, owner: int, balance: GameBalance, custom_range: int = -1) -> void:
	grid_pos = pos
	owner_id = owner
	timer = balance.get_bomb_timer()
	range = custom_range if custom_range > 0 else balance.get_bomb_range()


func tick_update() -> bool:
	"""Actualiza el temporizador de la bomba. Retorna true si explotó."""
	if not active:
		return false

	timer -= 1

	if timer <= 0:
		active = false
		return true

	return false


func get_move_progress() -> float:
	if move_ticks_total <= 0:
		return 0.0
	return float(move_ticks_elapsed) / float(move_ticks_total)
