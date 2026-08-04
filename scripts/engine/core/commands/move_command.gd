class_name MoveCommand
extends RefCounted

## Intent inmutable: "el jugador player_id quiere moverse hacia direction".
## Vector2i.ZERO significa "limpiar input" (mismo caso que ya maneja
## PlayerSystem.set_move_direction).

var player_id: int
var direction: Vector2i


func _init(id: int, dir: Vector2i) -> void:
	player_id = id
	direction = dir
