class_name GameMap
extends RefCounted

const CELL_EMPTY := 0
const CELL_DESTRUCTIBLE := 1
const CELL_INDESTRUCTIBLE := 2

var width: int
var height: int
var cell_size: int

var grid: Array[Array] = []

var _spawn_positions: Array[Vector2i] = []

# GameMap puede venir de dos orígenes intercambiables: la generación
# procedural de siempre (GameBalance) o un mapa hecho a mano (editor,
# MapDefinition). regenerate() recuerda cuál para poder reconstruir la
# grilla igual (usado al empezar una ronda nueva).
var _balance: GameBalance
var _definition: MapDefinition


static func from_balance(balance: GameBalance) -> GameMap:
	var map := GameMap.new()
	map._balance = balance
	map.width = balance.map_width
	map.height = balance.map_height
	map.cell_size = balance.cell_size
	map._spawn_positions.assign(balance.spawn_positions)
	map.regenerate()
	return map


static func from_definition(definition: MapDefinition) -> GameMap:
	var map := GameMap.new()
	map._definition = definition
	map.width = definition.width
	map.height = definition.height
	map.cell_size = definition.cell_size
	map._spawn_positions.assign(definition.spawn_positions)
	map.regenerate()
	return map


func regenerate() -> void:
	"""Vuelve la grilla a su estado original. Con balance: borde + vacío,
	sin bloques destructibles (quien los repone es
	BombSystem.reset_round()). Con un MapDefinition: la grilla completa tal
	como la pintó el autor del mapa, incluidos sus bloques destructibles."""
	if _definition != null:
		grid = _copy_cells(_definition.cells)
	else:
		_build_grid(_balance.indestructible_border)


func _build_grid(indestructible_border: bool) -> void:
	grid = []
	for y in range(height):
		var row: Array[int] = []
		for x in range(width):
			if indestructible_border and (x == 0 or x == width - 1 or y == 0 or y == height - 1):
				row.append(CELL_INDESTRUCTIBLE)
			else:
				row.append(CELL_EMPTY)
		grid.append(row)


func _copy_cells(source: Array) -> Array:
	var copy: Array[Array] = []
	for row in source:
		var row_copy: Array[int] = []
		row_copy.assign(row)
		copy.append(row_copy)
	return copy


func is_within_bounds(grid_x: int, grid_y: int) -> bool:
	return grid_x >= 0 and grid_x < width and grid_y >= 0 and grid_y < height


func is_walkable(grid_x: int, grid_y: int) -> bool:
	if not is_within_bounds(grid_x, grid_y):
		return false
	return grid[grid_y][grid_x] == CELL_EMPTY


func is_destructible(grid_x: int, grid_y: int) -> bool:
	if not is_within_bounds(grid_x, grid_y):
		return false
	return grid[grid_y][grid_x] == CELL_DESTRUCTIBLE


func is_indestructible(grid_x: int, grid_y: int) -> bool:
	if not is_within_bounds(grid_x, grid_y):
		return false
	return grid[grid_y][grid_x] == CELL_INDESTRUCTIBLE


func get_cell(grid_x: int, grid_y: int) -> int:
	if not is_within_bounds(grid_x, grid_y):
		return CELL_INDESTRUCTIBLE
	return grid[grid_y][grid_x]


func set_cell(grid_x: int, grid_y: int, value: int) -> void:
	if not is_within_bounds(grid_x, grid_y):
		return
	grid[grid_y][grid_x] = value


func grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	return Vector2(grid_x * cell_size + cell_size / 2.0, grid_y * cell_size + cell_size / 2.0)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / cell_size), floori(world_pos.y / cell_size))


func get_spawn_position(spawn_index: int) -> Vector2i:
	if spawn_index < _spawn_positions.size():
		return _spawn_positions[spawn_index]
	return Vector2i(1, 1)


func count_cells(value: int) -> int:
	var count := 0
	for y in range(height):
		for x in range(width):
			if grid[y][x] == value:
				count += 1
	return count
