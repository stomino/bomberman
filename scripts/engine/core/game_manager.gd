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


func tick(delta: float) -> void:
	state.tick += 1

	player_system.tick(state, delta)
	bomb_system.tick(state, delta)
