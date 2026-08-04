class_name PlayerSystem
extends RefCounted

var players: Dictionary = {}

var game_map: GameMap
var balance: GameBalance
var bomb_system: BombSystem


func _init(map: GameMap, game_balance: GameBalance, bombs: BombSystem) -> void:
	game_map = map
	balance = game_balance
	bomb_system = bombs


func add_player(player: Player) -> void:
	players[player.id] = player


func remove_player(player_id: int) -> void:
	players.erase(player_id)


func get_player(player_id: int) -> Player:
	return players.get(player_id)


func tick(_state: GameState) -> void:
	for player in players.values():
		_update_player(player)
		_tick_shield(player)


func _tick_shield(player: Player) -> void:
	if player.shield_ticks_remaining > 0:
		player.shield_ticks_remaining -= 1


func set_move_direction(player_id: int, direction: Vector2i) -> void:
	var player := get_player(player_id)

	if player == null or not player.alive:
		return

	var valid_dirs = [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT
	]

	if direction == Vector2i.ZERO:
		player.next_direction = Vector2i.ZERO
		player.has_pending_move = false
		return

	if direction not in valid_dirs:
		return

	player.facing_direction = direction

	if not player.is_moving:
		_try_start_move(player, direction)
	else:
		if direction != player.move_direction:
			player.next_direction = direction
			player.has_pending_move = true


func _is_cell_free(cell: Vector2i) -> bool:
	return game_map.is_walkable(cell.x, cell.y) and not bomb_system.is_cell_occupied_by_bomb(cell)


func _ticks_for_speed(speed: float) -> int:
	"""Convierte una velocidad en celdas/segundo a una cantidad entera de
	ticks para cruzar una celda. Se recalcula al iniciar cada movimiento
	(así un cambio de velocidad, ej. por powerup, aplica de inmediato)."""
	if speed <= 0.0:
		return 1
	return maxi(1, roundi(balance.tick_rate / speed))


func _try_start_move(player: Player, direction: Vector2i) -> void:
	"""Arranca el movimiento hacia direction solo si la celda destino es
	caminable y no tiene una bomba. Si no lo es, el jugador queda quieto
	mirando hacia esa dirección (facing_direction ya se seteó antes de
	llamar a esto)."""
	var target := player.grid_position + direction

	if not _is_cell_free(target):
		player.move_direction = Vector2i.ZERO
		player.next_direction = Vector2i.ZERO
		player.move_ticks_elapsed = 0
		player.is_moving = false
		player.has_pending_move = false
		return

	player.move_direction = direction
	player.next_direction = Vector2i.ZERO
	player.move_ticks_elapsed = 0
	player.move_ticks_total = _ticks_for_speed(get_effective_speed(player))
	player.is_moving = true
	player.has_pending_move = true


func clear_input(player_id: int) -> void:
	var player := get_player(player_id)

	if player == null:
		return

	player.next_direction = Vector2i.ZERO
	player.has_pending_move = false


func reset_to_position(player_id: int, grid_position: Vector2i) -> void:
	var player := get_player(player_id)

	if player == null:
		return

	player.grid_position = grid_position
	player.move_direction = Vector2i.ZERO
	player.next_direction = Vector2i.ZERO
	player.move_ticks_elapsed = 0
	player.is_moving = false
	player.has_pending_move = false


func reset_for_new_round(player_id: int, spawn_position: Vector2i) -> void:
	"""A diferencia de _respawn (muerte dentro de una ronda), esto también
	limpia los powerups acumulados: cada ronda arranca pareja."""
	var player := get_player(player_id)

	if player == null:
		return

	reset_to_position(player_id, spawn_position)
	player.alive = true
	player.respawn_at_tick = -1
	player.speed_powerup_stacks = 0
	player.bomb_range_powerup_stacks = 0
	player.extra_bomb_powerup_stacks = 0
	player.shield_ticks_remaining = 0


func get_effective_speed(player: Player) -> float:
	var bonus := player.speed_powerup_stacks * balance.powerups.speed_bonus_per_stack
	return balance.get_speed_for_character() * (1.0 + bonus)


func get_effective_bomb_range(player: Player) -> int:
	return balance.get_bomb_range() + player.bomb_range_powerup_stacks * balance.powerups.bomb_range_bonus_per_stack


func get_effective_max_bombs(player: Player) -> int:
	return balance.max_bombs_per_player + player.extra_bomb_powerup_stacks * balance.powerups.extra_bomb_bonus_per_stack


func is_shielded(player: Player) -> bool:
	return player.shield_ticks_remaining > 0


func apply_powerup(player_id: int, type: PowerUp.Type) -> void:
	var player := get_player(player_id)

	if player == null or not player.alive:
		return

	match type:
		PowerUp.Type.SPEED:
			var before := get_effective_speed(player)
			player.speed_powerup_stacks = mini(player.speed_powerup_stacks + 1, balance.powerups.speed_max_stacks)
			GameLogger.debug("Jugador %d recogió SPEED: velocidad %.2f -> %.2f (stacks %d/%d)" % [
				player_id, before, get_effective_speed(player),
				player.speed_powerup_stacks, balance.powerups.speed_max_stacks
			], "PlayerSystem")
		PowerUp.Type.BOMB_RANGE:
			var before := get_effective_bomb_range(player)
			player.bomb_range_powerup_stacks = mini(player.bomb_range_powerup_stacks + 1, balance.powerups.bomb_range_max_stacks)
			GameLogger.debug("Jugador %d recogió BOMB_RANGE: rango %d -> %d (stacks %d/%d)" % [
				player_id, before, get_effective_bomb_range(player),
				player.bomb_range_powerup_stacks, balance.powerups.bomb_range_max_stacks
			], "PlayerSystem")
		PowerUp.Type.EXTRA_BOMB:
			var before := get_effective_max_bombs(player)
			player.extra_bomb_powerup_stacks = mini(player.extra_bomb_powerup_stacks + 1, balance.powerups.extra_bomb_max_stacks)
			GameLogger.debug("Jugador %d recogió EXTRA_BOMB: bombas máx %d -> %d (stacks %d/%d)" % [
				player_id, before, get_effective_max_bombs(player),
				player.extra_bomb_powerup_stacks, balance.powerups.extra_bomb_max_stacks
			], "PlayerSystem")
		PowerUp.Type.SHIELD:
			player.shield_ticks_remaining = balance.powerups.shield_duration_ticks
			GameLogger.debug("Jugador %d recogió SHIELD: activo por %d ticks" % [
				player_id, player.shield_ticks_remaining
			], "PlayerSystem")
		_:
			GameLogger.warning("Tipo de powerup desconocido: " + str(type), "PlayerSystem")


func get_move_progress(player_id: int) -> float:
	"""Progreso visual (0..1) del movimiento en curso. Es la única
	conversión a float de move_ticks_elapsed/move_ticks_total — solo para
	Presentation, la simulación sigue siendo entera."""
	var player := get_player(player_id)

	if player == null or player.move_ticks_total <= 0:
		return 0.0

	return float(player.move_ticks_elapsed) / float(player.move_ticks_total)


func get_position_for_render(player_id: int, cell_size: int) -> Vector2:
	var player := get_player(player_id)

	if player == null:
		return Vector2.ZERO

	var half_cell := cell_size / 2.0
	var base_pos := Vector2(player.grid_position) * cell_size + Vector2(half_cell, half_cell)
	var offset := Vector2(player.move_direction) * (get_move_progress(player_id) * cell_size)
	return base_pos + offset


func apply_explosion_damage(danger_cells: Array[Vector2i], current_tick: int) -> void:
	for player in players.values():
		if not player.alive:
			if current_tick >= player.respawn_at_tick:
				_respawn(player)
			continue

		if is_shielded(player):
			continue

		if player.grid_position in danger_cells:
			_kill(player, current_tick)


func _kill(player: Player, current_tick: int) -> void:
	player.alive = false
	player.is_moving = false
	player.move_direction = Vector2i.ZERO
	player.next_direction = Vector2i.ZERO
	player.has_pending_move = false
	player.respawn_at_tick = current_tick + balance.respawn_ticks
	GameLogger.debug("Jugador %d murió, respawn en tick %d" % [player.id, player.respawn_at_tick], "PlayerSystem")


func _respawn(player: Player) -> void:
	reset_to_position(player.id, game_map.get_spawn_position(player.id))
	player.alive = true
	player.shield_ticks_remaining = balance.spawn_invulnerability_ticks
	GameLogger.debug("Jugador %d respawneó" % player.id, "PlayerSystem")


func _update_player(player: Player) -> void:

	if not player.alive:
		return

	if not player.is_moving:
		return

	if player.move_direction == Vector2i.ZERO:
		return

	player.move_ticks_elapsed += 1

	if player.move_ticks_elapsed < player.move_ticks_total:
		return

	var next_cell := player.grid_position + player.move_direction

	if _is_cell_free(next_cell):

		player.grid_position = next_cell
		player.move_ticks_elapsed = 0

		if player.next_direction != Vector2i.ZERO:
			_try_start_move(player, player.next_direction)
		else:
			player.is_moving = false
			player.has_pending_move = false

	else:

		player.move_direction = Vector2i.ZERO
		player.next_direction = Vector2i.ZERO
		player.move_ticks_elapsed = 0
		player.is_moving = false
		player.has_pending_move = false