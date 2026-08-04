extends Node

const CELL_SIZE: int = 32
const GRID_WIDTH: int = 13
const GRID_HEIGHT: int = 11

var grid: Array[Array]
var tilemap_node: TileMapLayer

func _ready() -> void:
	_initialize_grid()

func _initialize_grid() -> void:
	grid = []
	for y in range(GRID_HEIGHT):
		grid.append([])
		for x in range(GRID_WIDTH):
			grid[y].append(0)

func grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	return Vector2(grid_x * CELL_SIZE + CELL_SIZE / 2, grid_y * CELL_SIZE + CELL_SIZE / 2)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var x: int = floor(world_pos.x / CELL_SIZE)
	var y: int = floor(world_pos.y / CELL_SIZE)
	return Vector2i(x, y)

func is_walkable(grid_x: int, grid_y: int) -> bool:
	if grid_x < 0 or grid_x >= GRID_WIDTH or grid_y < 0 or grid_y >= GRID_HEIGHT:
		return false
	return grid[grid_y][grid_x] == 0

func get_spawn_position(spawn_index: int) -> Vector2i:
	var spawns: Array[Vector2i] = [
		Vector2i(1, 1),
		Vector2i(GRID_WIDTH - 2, 1),
		Vector2i(1, GRID_HEIGHT - 2),
		Vector2i(GRID_WIDTH - 2, GRID_HEIGHT - 2)
	]
	if spawn_index < spawns.size():
		return spawns[spawn_index]
	return Vector2i(1, 1)