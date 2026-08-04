class_name GameMap
extends RefCounted

const CELL_EMPTY := 0
const CELL_DESTRUCTIBLE := 1
const CELL_INDESTRUCTIBLE := 2

var width: int
var height: int
var cell_size: int

var grid: Array[Array] = []

var _balance: GameBalance


func _init(balance: GameBalance) -> void:
	_balance = balance
	width = balance.map_width
	height = balance.map_height
	cell_size = balance.cell_size
	_build_grid(balance.indestructible_border)


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
	return _balance.get_spawn_position(spawn_index)


func count_cells(value: int) -> int:
	var count := 0
	for y in range(height):
		for x in range(width):
			if grid[y][x] == value:
				count += 1
	return count
