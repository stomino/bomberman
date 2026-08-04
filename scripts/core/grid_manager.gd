# ============================================
# scripts/core/grid_manager.gd
# ============================================

extends Node

var CELL_SIZE: int = 32
var GRID_WIDTH: int = 13
var GRID_HEIGHT: int = 11

var grid: Array[Array]
var tilemap_node: TileMapLayer

# ✅ Sistema de bombas
var bomb_system: BombSystem

# ✅ Temporizador para ticks
var tick_timer: Timer
var tick_rate: float = 1.0 / 60.0  # 60 ticks por segundo

func _ready() -> void:
	CELL_SIZE = GameBalance.cell_size
	GRID_WIDTH = GameBalance.map_width
	GRID_HEIGHT = GameBalance.map_height
	
	_initialize_grid()
	
	# ✅ Inicializar BombSystem
	initialize_bomb_system()
	
	# ✅ Configurar tick timer para bombas
	_setup_tick_timer()
	
	if GameBalance.debug_mode:
		print("[INFO] [GridManager] 📐 GridManager inicializado")

func _setup_tick_timer() -> void:
	"""Configura el timer para los ticks del juego"""
	tick_timer = Timer.new()
	tick_timer.wait_time = tick_rate
	tick_timer.timeout.connect(_on_tick)
	add_child(tick_timer)
	tick_timer.start()
	
	if GameBalance.debug_mode:
		print("[INFO] [GridManager] ⏱️ Tick timer configurado: ", tick_rate, " segundos")

func _on_tick() -> void:
	"""Se llama en cada tick del juego"""
	if bomb_system:
		bomb_system.tick_update()

func _initialize_grid() -> void:
	grid = []
	for y in range(GRID_HEIGHT):
		grid.append([])
		for x in range(GRID_WIDTH):
			if GameBalance.indestructible_border:
				if x == 0 or x == GRID_WIDTH - 1 or y == 0 or y == GRID_HEIGHT - 1:
					grid[y].append(2)
				else:
					grid[y].append(0)
			else:
				grid[y].append(0)

func grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	return Vector2(grid_x * CELL_SIZE + CELL_SIZE / 2.0, grid_y * CELL_SIZE + CELL_SIZE / 2.0)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var x: int = floor(world_pos.x / CELL_SIZE)
	var y: int = floor(world_pos.y / CELL_SIZE)
	return Vector2i(x, y)

func is_walkable(grid_x: int, grid_y: int) -> bool:
	if grid_x < 0 or grid_x >= GRID_WIDTH or grid_y < 0 or grid_y >= GRID_HEIGHT:
		return false
	return grid[grid_y][grid_x] == 0

func is_destructible(grid_x: int, grid_y: int) -> bool:
	"""Verifica si hay un bloque destructible en la posición"""
	if grid_x < 0 or grid_x >= GRID_WIDTH or grid_y < 0 or grid_y >= GRID_HEIGHT:
		return false
	return grid[grid_y][grid_x] == 1

func is_indestructible(grid_x: int, grid_y: int) -> bool:
	"""Verifica si hay un bloque indestructible en la posición"""
	if grid_x < 0 or grid_x >= GRID_WIDTH or grid_y < 0 or grid_y >= GRID_HEIGHT:
		return false
	return grid[grid_y][grid_x] == 2

func is_within_bounds(grid_x: int, grid_y: int) -> bool:
	"""Verifica si una posición está dentro de los límites de la grilla"""
	return grid_x >= 0 and grid_x < GRID_WIDTH and grid_y >= 0 and grid_y < GRID_HEIGHT

func set_cell_value(grid_x: int, grid_y: int, value: int) -> void:
	"""Establece el valor de una celda (0=vacío, 1=destructible, 2=indestructible)"""
	if grid_x < 0 or grid_x >= GRID_WIDTH or grid_y < 0 or grid_y >= GRID_HEIGHT:
		return
	grid[grid_y][grid_x] = value

func get_spawn_position(spawn_index: int) -> Vector2i:
	return GameBalance.get_spawn_position(spawn_index)

# ============================================
# INTEGRACIÓN CON BOMBSYSTEM
# ============================================

func initialize_bomb_system() -> void:
	"""Inicializa el sistema de bombas"""
	bomb_system = BombSystem.new(self)
	if GameBalance.debug_mode:
		print("[INFO] [GridManager] 🧨 BombSystem inicializado")

# ============================================
# CONTROLES DE TECLADO PARA DEBUG
# ============================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# ✅ F1: Alternar modo debug
		if event.keycode == KEY_F1:
			GameBalance.toggle_debug_mode()
		
		# ✅ F4: Mostrar estado del grid
		if event.keycode == KEY_F4 and GameBalance.debug_mode:
			_debug_print_grid()
		
		# ✅ F5: Recargar configuración
		if event.keycode == KEY_F5 and GameBalance.debug_mode:
			GameBalance.reload_config()
			print("🔄 Configuración recargada")

# ============================================
# MÉTODOS DE DEBUG
# ============================================

func _debug_print_grid() -> void:
	"""Imprime el estado actual de la grilla (solo para debug)"""
	print("=== ESTADO DE LA GRILLA ===")
	print("Tamaño: ", GRID_WIDTH, "x", GRID_HEIGHT)
	print("Celdas caminables: ", _count_cells(0))
	print("Celdas destructibles: ", _count_cells(1))
	print("Celdas indestructibles: ", _count_cells(2))
	if bomb_system:
		print("Bombas activas: ", bomb_system.get_active_bombs_count())
	print("===========================")

func _count_cells(value: int) -> int:
	"""Cuenta cuántas celdas tienen un valor específico"""
	var count = 0
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] == value:
				count += 1
	return count