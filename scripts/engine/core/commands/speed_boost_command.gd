class_name SpeedBoostCommand
extends RefCounted

## Intent inmutable: "el jugador player_id quiere activar la ráfaga de
## Velocidad" (si no está en cooldown).

var player_id: int


func _init(id: int) -> void:
	player_id = id
