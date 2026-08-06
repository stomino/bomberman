class_name BombPushCommand
extends RefCounted

## Intent inmutable: "el jugador player_id quiere activar la habilidad
## Empujar" (si no está en cooldown).

var player_id: int


func _init(id: int) -> void:
	player_id = id
