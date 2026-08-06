class_name FlashCommand
extends RefCounted

## Intent inmutable: "el jugador player_id quiere usar la habilidad Flash"
## (teletransporte instantáneo en la dirección en la que está mirando).

var player_id: int


func _init(id: int) -> void:
	player_id = id
