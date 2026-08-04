class_name PlaceBombCommand
extends RefCounted

## Intent inmutable: "el jugador player_id quiere colocar una bomba en su
## posición actual".

var player_id: int


func _init(id: int) -> void:
	player_id = id
