class_name GameManager
extends RefCounted

var state: GameState
var map: GameMap
var player_system: PlayerSystem
var bomb_system: BombSystem


func _init(game_map: GameMap, players: PlayerSystem, bombs: BombSystem, game_state: GameState = GameState.new()) -> void:
	map = game_map
	player_system = players
	bomb_system = bombs
	state = game_state


func tick() -> void:
	"""Un tick = una unidad discreta de simulación. Sin float de por medio:
	determinismo requerido para servidor autoritativo (ver
	docs/Product_Vision_and_Roadmap.md)."""
	state.tick += 1

	player_system.tick(state)
	bomb_system.tick(state)
	player_system.apply_explosion_damage(bomb_system.get_danger_cells(), state.tick)
