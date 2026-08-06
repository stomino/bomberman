class_name GameManager
extends RefCounted

var state: GameState
var map: GameMap
var player_system: PlayerSystem
var bomb_system: BombSystem
var powerup_system: PowerUpSystem
var balance: GameBalance

var _pending_commands: Array = []

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


func queue_command(command) -> void:
	"""Encola un Command (intent inmutable) para aplicarse en el próximo
	tick. Es el único punto de entrada de input hacia la simulación —
	tanto GameRoot (sandbox local) como ServerRoot (servidor de red) pasan
	por acá, así que ambos caminos aplican exactamente las mismas reglas."""
	_pending_commands.append(command)


func tick() -> void:
	"""Un tick = una unidad discreta de simulación. Sin float de por medio:
	determinismo requerido para servidor autoritativo (ver
	docs/Product_Vision_and_Roadmap.md)."""
	if not state.running:
		return

	state.tick += 1

	_apply_pending_commands()
	player_system.tick(state)

	var player_positions: Array[Vector2i] = []
	for player in player_system.players.values():
		player_positions.append(player.grid_position)
	bomb_system.tick(state, player_positions)

	player_system.apply_explosion_damage(bomb_system.get_danger_cells(), state.tick)
	_resolve_powerup_pickups()
	_check_round_end()
	_check_match_end()


func _apply_pending_commands() -> void:
	for command in _pending_commands:
		if command is MoveCommand:
			player_system.set_move_direction(command.player_id, command.direction)
		elif command is PlaceBombCommand:
			_apply_place_bomb(command.player_id)
		elif command is DashCommand:
			_apply_dash(command.player_id)
		elif command is SpeedBoostCommand:
			_apply_speed_boost(command.player_id)
		elif command is FlashCommand:
			_apply_flash(command.player_id)
		elif command is BombPushCommand:
			_apply_bomb_push(command.player_id)

	_pending_commands.clear()


func _apply_place_bomb(player_id: int) -> void:
	var player := player_system.get_player(player_id)
	if player == null or not player.alive:
		return

	var bomb_range := player_system.get_effective_bomb_range(player)
	var max_bombs := player_system.get_effective_max_bombs(player)
	bomb_system.place_bomb(player.grid_position, player_id, bomb_range, max_bombs)


func _apply_dash(player_id: int) -> void:
	var player := player_system.get_player(player_id)
	if player == null or not player.alive:
		return

	player_system.try_dash(player_id)


func _apply_speed_boost(player_id: int) -> void:
	var player := player_system.get_player(player_id)
	if player == null or not player.alive:
		return

	player_system.try_activate_speed_boost(player_id)


func _apply_flash(player_id: int) -> void:
	var player := player_system.get_player(player_id)
	if player == null or not player.alive:
		return

	player_system.try_flash(player_id)


func _apply_bomb_push(player_id: int) -> void:
	var player := player_system.get_player(player_id)
	if player == null or not player.alive:
		return

	player_system.try_activate_bomb_push(player_id)


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
