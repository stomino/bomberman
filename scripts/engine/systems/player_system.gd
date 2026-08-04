class_name PlayerSystem
extends RefCounted

var players: Dictionary = {}

var game_map: GameMap


func _init(map: GameMap) -> void:
	game_map = map


func add_player(player: Player) -> void:
	players[player.id] = player


func remove_player(player_id: int) -> void:
	players.erase(player_id)


func get_player(player_id: int) -> Player:
	return players.get(player_id)


func tick(_state: GameState, delta: float) -> void:
	for player in players.values():
		_update_player(player, delta)


func set_move_direction(player_id: int, direction: Vector2i) -> void:
	var player := get_player(player_id)

	if player == null:
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


func _try_start_move(player: Player, direction: Vector2i) -> void:
	"""Arranca el movimiento hacia direction solo si la celda destino es
	caminable. Si no lo es, el jugador queda quieto mirando hacia esa
	dirección (facing_direction ya se seteó antes de llamar a esto)."""
	var target := player.grid_position + direction

	if not game_map.is_walkable(target.x, target.y):
		player.move_direction = Vector2i.ZERO
		player.next_direction = Vector2i.ZERO
		player.move_progress = 0.0
		player.is_moving = false
		player.has_pending_move = false
		return

	player.move_direction = direction
	player.next_direction = Vector2i.ZERO
	player.move_progress = 0.0
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
	player.move_progress = 0.0
	player.is_moving = false
	player.has_pending_move = false


func apply_speed_multiplier(player_id: int, multiplier: float) -> void:
	var player := get_player(player_id)

	if player == null:
		return

	player.speed *= multiplier


func get_position_for_render(player_id: int, cell_size: int) -> Vector2:
	var player := get_player(player_id)

	if player == null:
		return Vector2.ZERO

	var half_cell := cell_size / 2.0
	var base_pos := Vector2(player.grid_position) * cell_size + Vector2(half_cell, half_cell)
	var offset := Vector2(player.move_direction) * (player.move_progress * cell_size)
	return base_pos + offset


func _update_player(player: Player, delta: float) -> void:

	if not player.is_moving:
		return

	if player.move_direction == Vector2i.ZERO:
		return

	player.move_progress += player.speed * delta

	if player.move_progress < 1.0:
		return

	var next_cell := player.grid_position + player.move_direction

	if game_map.is_walkable(next_cell.x, next_cell.y):

		player.grid_position = next_cell
		player.move_progress = 0.0

		if player.next_direction != Vector2i.ZERO:
			_try_start_move(player, player.next_direction)
		else:
			player.is_moving = false
			player.has_pending_move = false

	else:

		player.move_direction = Vector2i.ZERO
		player.next_direction = Vector2i.ZERO
		player.move_progress = 0.0
		player.is_moving = false
		player.has_pending_move = false