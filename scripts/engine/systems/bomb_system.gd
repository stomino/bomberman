class_name BombSystem
extends RefCounted

var game_map: GameMap
var balance: GameBalance

var bombs: Array[Bomb] = []
var explosions: Array[Explosion] = []
var destructible_blocks: Array[DestructibleBlock] = []

signal bomb_placed(grid_pos: Vector2i, owner_id: int)
signal bomb_exploded(grid_pos: Vector2i, cells: Array)
signal block_destroyed(grid_pos: Vector2i)
signal explosion_started(cells: Array)
signal explosion_ended(cells: Array)


func _init(map: GameMap, game_balance: GameBalance) -> void:
	game_map = map
	balance = game_balance
	_initialize_destructible_blocks()


func _initialize_destructible_blocks() -> void:
	if not balance.destructible_pattern_enabled:
		return

	var pattern = balance.destructible_pattern
	if pattern.is_empty():
		return

	var pattern_height = pattern.size()
	var pattern_width = pattern[0].size() if pattern_height > 0 else 0

	var offset_x = (game_map.width - pattern_width) / 2
	var offset_y = (game_map.height - pattern_height) / 2

	for y in range(pattern_height):
		for x in range(pattern_width):
			var grid_x = offset_x + x
			var grid_y = offset_y + y

			if not game_map.is_within_bounds(grid_x, grid_y):
				continue

			if _is_spawn_position(grid_x, grid_y):
				continue

			if pattern[y][x] == true:
				var block = DestructibleBlock.new(Vector2i(grid_x, grid_y))
				destructible_blocks.append(block)
				game_map.set_cell(grid_x, grid_y, GameMap.CELL_DESTRUCTIBLE)


func _is_spawn_position(x: int, y: int) -> bool:
	for spawn in balance.spawn_positions:
		if spawn.x == x and spawn.y == y:
			return true

		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if spawn.x + dx == x and spawn.y + dy == y:
					return true

	return false


func place_bomb(grid_pos: Vector2i, owner_id: int, custom_range: int = -1) -> bool:
	"""
	Reglas:
	1. No puede haber dos bombas en la misma celda
	2. La celda debe ser caminable
	3. El jugador no puede tener más de max_bombs_per_player bombas activas
	"""
	for bomb in bombs:
		if bomb.grid_pos == grid_pos and bomb.active:
			GameLogger.debug("Ya hay una bomba en: " + str(grid_pos), "BombSystem")
			return false

	if not game_map.is_walkable(grid_pos.x, grid_pos.y):
		GameLogger.debug("Celda no caminable: " + str(grid_pos), "BombSystem")
		return false

	var player_bombs := 0
	for bomb in bombs:
		if bomb.owner_id == owner_id and bomb.active:
			player_bombs += 1

	var max_bombs := balance.max_bombs_per_player
	if player_bombs >= max_bombs:
		GameLogger.debug("Jugador %d tiene máximo de bombas (%d)" % [owner_id, max_bombs], "BombSystem")
		return false

	var bomb := Bomb.new(grid_pos, owner_id, balance, custom_range)
	bombs.append(bomb)

	GameLogger.debug("Bomba colocada en: %s | Dueño: %d | Timer: %d ticks" % [str(grid_pos), owner_id, bomb.timer], "BombSystem")
	bomb_placed.emit(grid_pos, owner_id)
	return true


func tick(_state: GameState) -> void:
	_tick_bombs()
	_tick_explosions()


func _tick_bombs() -> void:
	var bombs_to_explode: Array[Bomb] = []

	for bomb in bombs:
		if not bomb.active:
			continue
		if bomb.tick_update():
			bombs_to_explode.append(bomb)

	for bomb in bombs_to_explode:
		_generate_explosion(bomb)
		bomb.active = false
		GameLogger.debug("Bomba explotó en: " + str(bomb.grid_pos), "BombSystem")

	bombs = bombs.filter(func(b): return b.active)


func _tick_explosions() -> void:
	for i in range(explosions.size() - 1, -1, -1):
		var explosion = explosions[i]
		if explosion.tick_update():
			explosion_ended.emit(explosion.cells)
			explosions.remove_at(i)


func _generate_explosion(bomb: Bomb) -> void:
	var affected_cells: Array[Vector2i] = []
	affected_cells.append(bomb.grid_pos)

	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	for dir in directions:
		for i in range(1, bomb.range + 1):
			var check_pos = bomb.grid_pos + (dir * i)

			if not game_map.is_within_bounds(check_pos.x, check_pos.y):
				break

			if game_map.is_indestructible(check_pos.x, check_pos.y):
				break

			if game_map.is_destructible(check_pos.x, check_pos.y):
				# GameMap es la única fuente de verdad de qué celda es
				# destructible; destructible_blocks es solo el índice para
				# encontrar el objeto DestructibleBlock asociado (si existe).
				var block := _get_block_at(check_pos)
				if block:
					block.destroy()
				game_map.set_cell(check_pos.x, check_pos.y, GameMap.CELL_EMPTY)
				block_destroyed.emit(check_pos)
				affected_cells.append(check_pos)
				break

			affected_cells.append(check_pos)

	var explosion := Explosion.new(affected_cells, balance)
	explosions.append(explosion)

	bomb_exploded.emit(bomb.grid_pos, affected_cells)
	explosion_started.emit(affected_cells)

	if balance.chain_explosions:
		_check_chain_explosions(affected_cells)


func _check_chain_explosions(cells: Array[Vector2i]) -> void:
	for cell in cells:
		for bomb in bombs:
			if not bomb.active:
				continue
			if bomb.grid_pos == cell:
				if balance.chain_delay_ticks > 0:
					bomb.timer = min(bomb.timer, balance.chain_delay_ticks)
				else:
					bomb.timer = 0


func _get_block_at(pos: Vector2i) -> DestructibleBlock:
	for block in destructible_blocks:
		if block.grid_pos == pos and block.alive:
			return block
	return null


func get_danger_cells() -> Array[Vector2i]:
	"""Todas las celdas cubiertas por una explosión activa este tick."""
	var cells: Array[Vector2i] = []
	for explosion in explosions:
		cells.append_array(explosion.cells)
	return cells


func is_cell_occupied_by_bomb(pos: Vector2i) -> bool:
	for bomb in bombs:
		if bomb.grid_pos == pos and bomb.active:
			return true
	return false


func get_bombs_by_player(player_id: int) -> Array[Bomb]:
	var result: Array[Bomb] = []
	for bomb in bombs:
		if bomb.owner_id == player_id and bomb.active:
			result.append(bomb)
	return result


func get_active_bombs_count() -> int:
	var count := 0
	for bomb in bombs:
		if bomb.active:
			count += 1
	return count


func get_player_bomb_count(player_id: int) -> int:
	return get_bombs_by_player(player_id).size()
