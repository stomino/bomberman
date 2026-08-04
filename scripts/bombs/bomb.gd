# ============================================
# scripts/bombs/bomb.gd
# ============================================
# REPRESENTA UNA BOMBA EN EL JUEGO
# ============================================

class_name Bomb
extends RefCounted

var grid_pos: Vector2i
var owner_id: int
var timer: int
var range: int
var active: bool = true

func _init(pos: Vector2i, owner: int, custom_range: int = -1) -> void:
	grid_pos = pos
	owner_id = owner
	
	# Usar valores de GameBalance
	timer = GameBalance.get_bomb_timer()
	range = custom_range if custom_range > 0 else GameBalance.get_bomb_range()

func tick_update() -> bool:
	"""Actualiza el temporizador de la bomba. Retorna true si explotó."""
	if not active:
		return false
	
	timer -= 1
	
	if timer <= 0:
		active = false
		return true  # Explotó
	
	return false  # Sigue activa