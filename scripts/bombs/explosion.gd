# ============================================
# scripts/bombs/explosion.gd
# ============================================
# REPRESENTA UNA EXPLOSIÓN EN EL JUEGO
# ============================================

class_name Explosion
extends RefCounted

var cells: Array[Vector2i] = []
var remaining_ticks: int
var damage: int

func _init(affected_cells: Array[Vector2i]) -> void:
	cells = affected_cells
	remaining_ticks = GameBalance.get_explosion_duration()
	damage = GameBalance.explosion_damage

func tick_update() -> bool:
	"""Actualiza la duración de la explosión. Retorna true si terminó."""
	remaining_ticks -= 1
	return remaining_ticks <= 0