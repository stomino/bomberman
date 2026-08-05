class_name DashCommand
extends RefCounted

## Intent inmutable: "el jugador player_id quiere usar la habilidad Dash"
## (2 celdas en la dirección en la que está mirando, si ya la desbloqueó).

var player_id: int


func _init(id: int) -> void:
	player_id = id
