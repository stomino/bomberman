extends Node2D

## Presentation: dibuja la grilla, bombas y explosiones leyendo el estado de
## GameRoot (solo lectura, no contiene lógica de gameplay). Arte de
## programador (rectángulos/círculos de color) hasta que existan tiles y
## sprites definitivos — se puede reemplazar sin tocar Domain/Systems.

var game_root: GameRoot

const FLOOR_COLOR := Color(0.82, 0.82, 0.82)
const INDESTRUCTIBLE_COLOR := Color(0.35, 0.35, 0.4)
const DESTRUCTIBLE_COLOR := Color(0.6, 0.42, 0.2)
const GRID_LINE_COLOR := Color(0.6, 0.6, 0.6)
const BOMB_COLOR := Color(0.1, 0.1, 0.1)
const BOMB_FUSE_COLOR := Color(0.9, 0.2, 0.1)
const EXPLOSION_COLOR := Color(1.0, 0.55, 0.1, 0.85)


func set_game_root(root: GameRoot) -> void:
	game_root = root


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not game_root:
		return

	_draw_grid()
	_draw_explosions()
	_draw_bombs()


func _draw_grid() -> void:
	var map := game_root.game_map
	var cs := map.cell_size

	for y in range(map.height):
		for x in range(map.width):
			var rect := Rect2(x * cs, y * cs, cs, cs)
			var color := FLOOR_COLOR

			match map.get_cell(x, y):
				GameMap.CELL_INDESTRUCTIBLE:
					color = INDESTRUCTIBLE_COLOR
				GameMap.CELL_DESTRUCTIBLE:
					color = DESTRUCTIBLE_COLOR

			draw_rect(rect, color)
			draw_rect(rect, GRID_LINE_COLOR, false, 1.0)


func _draw_bombs() -> void:
	var map := game_root.game_map
	var cs := map.cell_size

	for bomb in game_root.bomb_system.bombs:
		var center := map.grid_to_world(bomb.grid_pos.x, bomb.grid_pos.y)
		draw_circle(center, cs * 0.32, BOMB_COLOR)

		# Mecha: se pone más roja cuanto más cerca está de explotar.
		var urgency := 1.0 - clampf(float(bomb.timer) / float(game_root.balance.get_bomb_timer()), 0.0, 1.0)
		draw_circle(center, cs * 0.32 * urgency, BOMB_FUSE_COLOR)


func _draw_explosions() -> void:
	var map := game_root.game_map
	var cs := map.cell_size

	for explosion in game_root.bomb_system.explosions:
		for cell in explosion.cells:
			var rect := Rect2(cell.x * cs, cell.y * cs, cs, cs)
			draw_rect(rect, EXPLOSION_COLOR)
