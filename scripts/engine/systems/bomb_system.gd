class_name BombSystem
extends RefCounted

var game_map: GameMap
var balance: GameBalance

var bombs: Array[Bomb] = []
var explosions: Array[Explosion] = []
var destructible_blocks: Array[DestructibleBlock] = []

var _populate_from_balance_pattern: bool = true

signal bomb_placed(grid_pos: Vector2i, owner_id: int)
signal bomb_exploded(grid_pos: Vector2i, cells: Array)
signal block_destroyed(grid_pos: Vector2i)
signal explosion_started(cells: Array)
signal explosion_ended(cells: Array)


func _init(map: GameMap, game_balance: GameBalance, populate_from_balance_pattern: bool = true) -> void:
	"""populate_from_balance_pattern=false cuando el mapa viene de un
	MapDefinition (editor): ahí los bloques destructibles ya están
	pintados directamente en la grilla por el autor del mapa, así que no
	hay que además superponerle el patrón centrado de GameBalance encima
	(podría pintar sobre paredes que el usuario puso a propósito)."""
	game_map = map
	balance = game_balance
	_populate_from_balance_pattern = populate_from_balance_pattern

	if _populate_from_balance_pattern:
		_initialize_destructible_blocks()


func reset_round() -> void:
	"""Limpia bombas/explosiones/bloques. Asume que game_map.regenerate()
	ya se llamó antes. Con mapa procedural, vuelve a poblar el patrón de
	destructibles (regenerate() lo borró); con mapa custom, regenerate()
	ya restauró los bloques del mapa tal como los pintó su autor, así que
	no hay nada más que reponer acá."""
	bombs.clear()
	explosions.clear()
	destructible_blocks.clear()

	if _populate_from_balance_pattern:
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


func place_bomb(grid_pos: Vector2i, owner_id: int, bomb_range: int, max_bombs_for_owner: int) -> bool:
	"""
	Reglas:
	1. No puede haber dos bombas en la misma celda
	2. La celda debe ser caminable
	3. El jugador no puede tener más de max_bombs_for_owner bombas activas

	bomb_range y max_bombs_for_owner son responsabilidad del caller (valores
	efectivos del jugador, base + powerups) — BombSystem no sabe nada de
	jugadores ni de powerups, solo de bombas.
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

	if player_bombs >= max_bombs_for_owner:
		GameLogger.debug("Jugador %d tiene máximo de bombas (%d)" % [owner_id, max_bombs_for_owner], "BombSystem")
		return false

	var bomb := Bomb.new(grid_pos, owner_id, balance, bomb_range)
	bombs.append(bomb)

	GameLogger.debug("Bomba colocada en: %s | Dueño: %d | Timer: %d ticks" % [str(grid_pos), owner_id, bomb.timer], "BombSystem")
	bomb_placed.emit(grid_pos, owner_id)
	return true


func tick(_state: GameState, player_positions: Array[Vector2i] = []) -> void:
	_tick_bomb_movement(player_positions)
	_tick_bombs()
	_tick_explosions()


func _tick_bomb_movement(player_positions: Array[Vector2i]) -> void:
	"""Habilidad Empujar (ver docs/architecture/Implementation_Decisions.md):
	una bomba disparada sigue viajando sola, celda por celda, hasta chocar
	con algo colisionable — cada celda que cruza se resuelve al instante
	en cuanto termina sus ticks (grid_pos siempre es la posición lógica
	real y actual, nunca salta directo al destino final; ver
	try_launch_bomb para el porqué). player_positions es responsabilidad
	del caller (GameManager ya arma la lista desde PlayerSystem) —
	BombSystem no depende de la clase PlayerSystem, solo recibe datos
	planos, mismo criterio que bomb_range/max_bombs_for_owner en
	place_bomb()."""
	for bomb in bombs:
		if not bomb.is_moving:
			continue

		bomb.move_ticks_elapsed += 1

		if bomb.move_ticks_elapsed < bomb.move_ticks_total:
			continue

		var next := bomb.grid_pos + bomb.move_direction

		if not game_map.is_walkable(next.x, next.y) or is_cell_occupied_by_bomb(next) or next in player_positions:
			bomb.is_moving = false
			bomb.move_direction = Vector2i.ZERO
			continue

		bomb.grid_pos = next
		bomb.move_ticks_elapsed = 0


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


func get_bomb_at(pos: Vector2i) -> Bomb:
	for bomb in bombs:
		if bomb.grid_pos == pos and bomb.active:
			return bomb
	return null


func try_launch_bomb(bomb: Bomb, direction: Vector2i, ticks_per_cell: int) -> bool:
	"""Habilidad Empujar (ver docs/architecture/Implementation_Decisions.md):
	dispara la bomba en direction — arranca el primer segmento del vuelo
	acá; _tick_bomb_movement() la sigue moviendo sola, celda por celda,
	hasta chocar con algo colisionable (ver ahí).

	grid_pos se actualiza al instante acá, no al completar el segmento —
	es la posición lógica (choques, celda ocupada, cadenas de explosión,
	"explota donde esté si el timer se acaba a mitad de vuelo") la que
	manda, determinística en el mismo tick en que se decide el disparo.
	Los campos move_* que arranca esto son puramente cosméticos, para que
	game_renderer.gd interpole el deslizamiento visual desde la celda
	vieja hacia grid_pos (que ya es la nueva).

	Por qué no puede ser lazy como el jugador: jugador y bomba avanzan
	juntos en el primer segmento, la misma cantidad de ticks, pero
	PlayerSystem.tick() y BombSystem.tick() se llaman por separado desde
	GameManager — si grid_pos de la bomba solo se actualizara al
	completar su propio tick, el re-chequeo de _is_cell_free que hace el
	jugador al llegar vería la celda todavía "ocupada" un tick de más
	(orden de llamada entre los dos tick()), y el jugador se frenaría a
	último momento pese a que el disparo ya se había validado y
	comprometido al arrancar. Al ser eager, no hay ninguna ventana de
	inconsistencia posible entre las dos entidades.

	Falla fail-fast, sin mover nada, si la bomba ya se está moviendo o si
	la celda destino no es caminable o ya tiene otra bomba."""
	if bomb.is_moving:
		return false

	var target := bomb.grid_pos + direction

	if not game_map.is_walkable(target.x, target.y):
		return false

	if is_cell_occupied_by_bomb(target):
		return false

	bomb.grid_pos = target
	bomb.move_direction = direction
	bomb.move_ticks_total = ticks_per_cell
	bomb.move_ticks_elapsed = 0
	bomb.is_moving = true
	return true


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
