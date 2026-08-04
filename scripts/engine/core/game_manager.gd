class_name GameManager
extends RefCounted

var state: GameState
var map: GameMap
var player_system: PlayerSystem
var bomb_system: BombSystem
var powerup_system: PowerUpSystem
var balance: GameBalance

## Emitidos para que Presentation pueda reaccionar (UI de "ganaste la
## ronda", pantalla de fin de partida, etc.) sin que GameManager sepa nada
## de cómo se muestra. winner_id == -1 significa empate técnico.
signal round_ended(winner_id: int)
signal match_ended(winner_id: int)


func _init(game_map: GameMap, players: PlayerSystem, bombs: BombSystem, powerups: PowerUpSystem, game_balance: GameBalance, game_state: GameState = GameState.new()) -> void:
	map = game_map
	player_system = players
	bomb_system = bombs
	powerup_system = powerups
	balance = game_balance
	state = game_state


func start_match() -> void:
	state.running = true


func tick() -> void:
	"""Un tick = una unidad discreta de simulación. Sin float de por medio:
	determinismo requerido para servidor autoritativo (ver
	docs/Product_Vision_and_Roadmap.md)."""
	if not state.running:
		return

	state.tick += 1

	player_system.tick(state)
	bomb_system.tick(state)
	player_system.apply_explosion_damage(bomb_system.get_danger_cells(), state.tick)
	_resolve_powerup_pickups()
	_check_round_end()
	_check_match_end()


func _resolve_powerup_pickups() -> void:
	for player in player_system.players.values():
		if not player.alive:
			continue

		var powerup := powerup_system.get_powerup_at(player.grid_position)
		if powerup:
			player_system.apply_powerup(player.id, powerup.type)
			powerup_system.collect(player.id, powerup)


func _check_round_end() -> void:
	# Con un solo jugador registrado no hay "ronda" que ganar o perder —
	# preserva el modo sandbox de supervivencia actual sin cambios.
	if not state.running or player_system.players.size() < 2:
		return

	var alive_players: Array[Player] = []
	for player in player_system.players.values():
		if player.alive:
			alive_players.append(player)

	if alive_players.size() > 1:
		return

	var winner_id := -1

	if alive_players.size() == 1:
		var winner: Player = alive_players[0]
		winner.rounds_won += 1
		winner_id = winner.id
		GameLogger.info("Jugador %d ganó la ronda %d (marcador: %d)" % [winner.id, state.round, winner.rounds_won], "GameManager")
	else:
		GameLogger.info("Ronda %d terminó en empate técnico" % state.round, "GameManager")

	round_ended.emit(winner_id)
	_start_new_round()


func _start_new_round() -> void:
	state.round += 1

	map.regenerate()
	bomb_system.reset_round()
	powerup_system.clear_all()

	for player in player_system.players.values():
		player_system.reset_for_new_round(player.id, map.get_spawn_position(player.id))


func _check_match_end() -> void:
	if not state.running or player_system.players.size() < 2:
		return

	var match_duration_ticks := balance.match_duration_seconds * balance.tick_rate
	if state.tick < match_duration_ticks:
		return

	state.running = false
	state.winner_id = _determine_match_winner()
	match_ended.emit(state.winner_id)
	GameLogger.info("Partida terminada. Ganador: %d" % state.winner_id, "GameManager")


func _determine_match_winner() -> int:
	var best_id := -1
	var best_score := -1
	var tie := false

	for player in player_system.players.values():
		if player.rounds_won > best_score:
			best_score = player.rounds_won
			best_id = player.id
			tie = false
		elif player.rounds_won == best_score:
			tie = true

	return -1 if tie else best_id
