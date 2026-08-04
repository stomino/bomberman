# ============================================
# scripts/bombs/bomb_system.gd
# ============================================
# MANAGER CENTRAL DE BOMBAS, EXPLOSIONES Y BLOQUES
# ============================================

class_name BombSystem
extends RefCounted

# Referencias
var grid_manager

# Listas
var bombs: Array[Bomb] = []
var explosions: Array[Explosion] = []
var destructible_blocks: Array[DestructibleBlock] = []

# Señales
signal bomb_placed(grid_pos: Vector2i, owner_id: int)
signal bomb_exploded(grid_pos: Vector2i, cells: Array)
signal block_destroyed(grid_pos: Vector2i)
signal explosion_started(cells: Array)
signal explosion_ended(cells: Array)

func _init(grid_mgr) -> void:
	grid_manager = grid_mgr
	_initialize_destructible_blocks()

# ============================================
# INICIALIZACIÓN DE BLOQUES
# ============================================

func _initialize_destructible_blocks() -> void:
	"""Coloca bloques destructibles en el mapa según el patrón"""
	if not GameBalance.destructible_pattern_enabled:
		return
	
	var pattern = GameBalance.destructible_pattern
	if pattern.is_empty():
		return
	
	var pattern_height = pattern.size()
	var pattern_width = pattern[0].size() if pattern_height > 0 else 0
	
	var offset_x = (GameBalance.map_width - pattern_width) / 2
	var offset_y = (GameBalance.map_height - pattern_height) / 2
	
	for y in range(pattern_height):
		for x in range(pattern_width):
			var grid_x = offset_x + x
			var grid_y = offset_y + y
			
			if grid_x < 0 or grid_x >= GameBalance.map_width or grid_y < 0 or grid_y >= GameBalance.map_height:
				continue
			
			if _is_spawn_position(grid_x, grid_y):
				continue
			
			if pattern[y][x] == true:
				var block = DestructibleBlock.new(Vector2i(grid_x, grid_y))
				destructible_blocks.append(block)
				grid_manager.grid[grid_y][grid_x] = 1

func _is_spawn_position(x: int, y: int) -> bool:
	"""Verifica si una posición es spawn de algún jugador"""
	for spawn in GameBalance.spawn_positions:
		if spawn.x == x and spawn.y == y:
			return true
		
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if spawn.x + dx == x and spawn.y + dy == y:
					return true
	
	return false

# ============================================
# BOMBAS
# ============================================

func place_bomb(grid_pos: Vector2i, owner_id: int, custom_range: int = -1) -> bool:
	"""
	Coloca una bomba en la posición si es posible.
	
	Reglas:
	1. No puede haber dos bombas en la misma celda
	2. La celda debe ser caminable
	3. El jugador no puede tener más de max_bombs_per_player bombas activas
	"""
	
	# ✅ REGLA 1: No puede haber dos bombas en la misma celda
	for bomb in bombs:
		if bomb.grid_pos == grid_pos and bomb.active:
			if GameBalance.debug_mode:
				print("[DEBUG] [BombSystem] 🚫 Ya hay una bomba en: ", str(grid_pos))
			return false
	
	# ✅ REGLA 2: La celda debe ser caminable
	if not grid_manager.is_walkable(grid_pos.x, grid_pos.y):
		if GameBalance.debug_mode:
			print("[DEBUG] [BombSystem] 🚫 Celda no caminable: ", str(grid_pos))
		return false
	
	# ✅ REGLA 3: Límite de bombas por jugador
	var player_bombs = 0
	for bomb in bombs:
		if bomb.owner_id == owner_id and bomb.active:
			player_bombs += 1
	
	var max_bombs = GameBalance.max_bombs_per_player
	if player_bombs >= max_bombs:
		if GameBalance.debug_mode:
			print("[DEBUG] [BombSystem] 🚫 Jugador ", owner_id, " tiene máximo de bombas (", max_bombs, ")")
		return false
	
	# Crear y agregar la bomba
	var bomb = Bomb.new(grid_pos, owner_id, custom_range)
	bombs.append(bomb)
	
	if GameBalance.debug_mode:
		print("[DEBUG] [BombSystem] 💣 Bomba colocada en: ", str(grid_pos), " | Dueño: ", owner_id, " | Timer: ", bomb.timer, " ticks | Bombas activas: ", get_active_bombs_count())
	
	bomb_placed.emit(grid_pos, owner_id)
	return true

# ============================================
# ACTUALIZACIÓN POR TICK
# ============================================

func tick_update() -> void:
	"""Actualiza todas las bombas, explosiones y efectos"""
	
	# 1. Actualizar bombas
	var bombs_to_explode: Array[Bomb] = []
	
	for bomb in bombs:
		if not bomb.active:
			continue
		
		if bomb.tick_update():
			bombs_to_explode.append(bomb)
	
	# 2. Procesar explosiones de bombas
	for bomb in bombs_to_explode:
		_generate_explosion(bomb)
		# ✅ La bomba se marca como inactiva
		bomb.active = false
		if GameBalance.debug_mode:
			print("[DEBUG] [BombSystem] 💥 Bomba explotó en: ", str(bomb.grid_pos))
	
	# 3. ✅ Limpiar bombas inactivas (se eliminan de la lista)
	bombs = bombs.filter(func(b): return b.active)
	
	# 4. Actualizar explosiones
	for i in range(explosions.size() - 1, -1, -1):
		var explosion = explosions[i]
		if explosion.tick_update():
			if GameBalance.debug_mode:
				print("[DEBUG] [BombSystem] 💥 Explosión terminada en: ", str(explosion.cells))
			explosion_ended.emit(explosion.cells)
			explosions.remove_at(i)

# ============================================
# EXPLOSIONES
# ============================================

func _generate_explosion(bomb: Bomb) -> void:
	"""Genera una explosión a partir de una bomba"""
	var affected_cells: Array[Vector2i] = []
	
	# Centro de la explosión
	affected_cells.append(bomb.grid_pos)
	
	# 4 direcciones
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for dir in directions:
		for i in range(1, bomb.range + 1):
			var check_pos = bomb.grid_pos + (dir * i)
			
			if not grid_manager.is_within_bounds(check_pos.x, check_pos.y):
				break
			
			if grid_manager.grid[check_pos.y][check_pos.x] == 2:
				if GameBalance.debug_mode:
					print("[DEBUG] [BombSystem] 🧱 Bloque indestructible en: ", str(check_pos))
				break
			
			var block = _get_block_at(check_pos)
			if block and block.alive:
				block.destroy()
				grid_manager.grid[check_pos.y][check_pos.x] = 0
				if GameBalance.debug_mode:
					print("[DEBUG] [BombSystem] 💥 Bloque destructible roto en: ", str(check_pos))
				block_destroyed.emit(check_pos)
				affected_cells.append(check_pos)
				break
			
			affected_cells.append(check_pos)
	
	var explosion = Explosion.new(affected_cells)
	explosions.append(explosion)
	
	if GameBalance.debug_mode:
		print("[DEBUG] [BombSystem] 💥 Explosión creada en: ", str(affected_cells), " | Duración: ", explosion.remaining_ticks, " ticks")
	
	bomb_exploded.emit(bomb.grid_pos, affected_cells)
	explosion_started.emit(affected_cells)
	
	if GameBalance.chain_explosions:
		_check_chain_explosions(affected_cells)

func _check_chain_explosions(cells: Array[Vector2i]) -> void:
	"""Verifica si alguna bomba está dentro de las celdas de la explosión"""
	for cell in cells:
		for bomb in bombs:
			if not bomb.active:
				continue
			if bomb.grid_pos == cell:
				if GameBalance.debug_mode:
					print("[DEBUG] [BombSystem] 🔗 Explosión en cadena detectada en: ", str(cell))
				if GameBalance.chain_delay_ticks > 0:
					bomb.timer = min(bomb.timer, GameBalance.chain_delay_ticks)
				else:
					bomb.timer = 0

# ============================================
# MÉTODOS DE CONSULTA
# ============================================

func _get_block_at(pos: Vector2i):
	"""Retorna el bloque destructible en la posición, si existe"""
	for block in destructible_blocks:
		if block.grid_pos == pos and block.alive:
			return block
	return null

func is_cell_occupied_by_bomb(pos: Vector2i) -> bool:
	"""Verifica si hay una bomba activa en la posición"""
	for bomb in bombs:
		if bomb.grid_pos == pos and bomb.active:
			return true
	return false

func get_bombs_by_player(player_id: int) -> Array[Bomb]:
	"""Retorna todas las bombas activas de un jugador"""
	var result: Array[Bomb] = []
	for bomb in bombs:
		if bomb.owner_id == player_id and bomb.active:
			result.append(bomb)
	return result

func get_active_bombs_count() -> int:
	"""Retorna el número total de bombas activas"""
	var count = 0
	for bomb in bombs:
		if bomb.active:
			count += 1
	return count

func get_player_bomb_count(player_id: int) -> int:
	"""Retorna el número de bombas activas de un jugador"""
	var count = 0
	for bomb in bombs:
		if bomb.owner_id == player_id and bomb.active:
			count += 1
	return count