class_name SnapshotCodec
extends RefCounted

## Infrastructure/Serialization (ver Engine_Architecture_Specification_v1.0.md):
## traduce el estado autoritativo del servidor a un Dictionary listo para
## viajar por RPC, y aplica ese Dictionary sobre los mismos contenedores
## Domain/Systems que ya existen del lado del cliente — sin DTOs nuevos.
## Primer corte deliberadamente simple: snapshot completo por tick, sin
## delta-compression (esa es una optimización de Fase 10, no de acá).


static func serialize(state: GameState, player_system: PlayerSystem, bomb_system: BombSystem, powerup_system: PowerUpSystem, game_map: GameMap) -> Dictionary:
	var players_data: Array = []
	for player in player_system.players.values():
		players_data.append({
			"id": player.id,
			"grid_position": player.grid_position,
			"alive": player.alive,
			"move_direction": player.move_direction,
			"move_ticks_elapsed": player.move_ticks_elapsed,
			"move_ticks_total": player.move_ticks_total,
			"facing_direction": player.facing_direction,
			"shield_ticks_remaining": player.shield_ticks_remaining,
			"rounds_won": player.rounds_won,
		})

	var bombs_data: Array = []
	for bomb in bomb_system.bombs:
		bombs_data.append({
			"grid_pos": bomb.grid_pos,
			"owner_id": bomb.owner_id,
			"timer": bomb.timer,
			"range": bomb.range,
		})

	var explosions_data: Array = []
	for explosion in bomb_system.explosions:
		explosions_data.append({
			"cells": explosion.cells,
			"remaining_ticks": explosion.remaining_ticks,
		})

	var powerups_data: Array = []
	for powerup in powerup_system.powerups:
		powerups_data.append({
			"grid_pos": powerup.grid_pos,
			"type": powerup.type,
		})

	return {
		"tick": state.tick,
		"running": state.running,
		"round": state.round,
		"winner_id": state.winner_id,
		"players": players_data,
		"bombs": bombs_data,
		"explosions": explosions_data,
		"powerups": powerups_data,
		"map_width": game_map.width,
		"map_height": game_map.height,
		"map_cell_size": game_map.cell_size,
		"map_grid": game_map.grid,
	}


static func apply(data: Dictionary, state: GameState, player_system: PlayerSystem, bomb_system: BombSystem, powerup_system: PowerUpSystem, game_map: GameMap) -> void:
	state.tick = data["tick"]
	state.running = data["running"]
	state.round = data["round"]
	state.winner_id = data["winner_id"]

	_apply_players(data["players"], player_system)
	_apply_bombs(data["bombs"], bomb_system)
	_apply_explosions(data["explosions"], bomb_system)
	_apply_powerups(data["powerups"], powerup_system)
	_apply_map(data, game_map)


static func _apply_players(players_data: Array, player_system: PlayerSystem) -> void:
	var seen_ids: Dictionary = {}

	for pdata in players_data:
		var id: int = pdata["id"]
		seen_ids[id] = true

		var player := player_system.get_player(id)
		if player == null:
			player = Player.new()
			player.id = id
			player_system.add_player(player)

		player.grid_position = pdata["grid_position"]
		player.alive = pdata["alive"]
		player.move_direction = pdata["move_direction"]
		player.move_ticks_elapsed = pdata["move_ticks_elapsed"]
		player.move_ticks_total = pdata["move_ticks_total"]
		player.facing_direction = pdata["facing_direction"]
		player.shield_ticks_remaining = pdata["shield_ticks_remaining"]
		player.rounds_won = pdata["rounds_won"]

	for id in player_system.players.keys():
		if not seen_ids.has(id):
			player_system.remove_player(id)


static func _apply_bombs(bombs_data: Array, bomb_system: BombSystem) -> void:
	var bombs: Array[Bomb] = []
	for bdata in bombs_data:
		var bomb := Bomb.new(bdata["grid_pos"], bdata["owner_id"], bomb_system.balance, bdata["range"])
		bomb.timer = bdata["timer"]
		bombs.append(bomb)
	bomb_system.bombs = bombs


static func _apply_explosions(explosions_data: Array, bomb_system: BombSystem) -> void:
	var explosions: Array[Explosion] = []
	for edata in explosions_data:
		var cells: Array[Vector2i] = []
		cells.assign(edata["cells"])
		var explosion := Explosion.new(cells, bomb_system.balance)
		explosion.remaining_ticks = edata["remaining_ticks"]
		explosions.append(explosion)
	bomb_system.explosions = explosions


static func _apply_powerups(powerups_data: Array, powerup_system: PowerUpSystem) -> void:
	var powerups: Array[PowerUp] = []
	for pdata in powerups_data:
		powerups.append(PowerUp.new(pdata["grid_pos"], pdata["type"]))
	powerup_system.powerups = powerups


static func _apply_map(data: Dictionary, game_map: GameMap) -> void:
	game_map.width = data["map_width"]
	game_map.height = data["map_height"]
	game_map.cell_size = data["map_cell_size"]

	var grid: Array[Array] = []
	for row in data["map_grid"]:
		var typed_row: Array[int] = []
		typed_row.assign(row)
		grid.append(typed_row)
	game_map.grid = grid
