class_name MapDefinition
extends RefCounted

## Un mapa hecho a mano (editor) o guardado en disco. Distinto de
## GameBalance a propósito: esto es contenido (el diseño de un mapa
## concreto), no configuración numérica de balance. GameMap puede
## construirse a partir de esto (GameMap.from_definition) igual que se
## construye a partir de GameBalance (GameMap.from_balance) — son dos
## orígenes intercambiables para el mismo tipo de dato.

const MAPS_DIR := "res://maps/"

const CHAR_EMPTY := "."
const CHAR_INDESTRUCTIBLE := "#"
const CHAR_DESTRUCTIBLE := "x"

var map_name: String = "Sin nombre"
var width: int = 13
var height: int = 11
var cell_size: int = 32
var spawn_positions: Array[Vector2i] = []
var cells: Array = []  # Array[Array[int]], fila por fila (cells[y][x])


static func create_empty(map_width: int, map_height: int, map_cell_size: int = 32) -> MapDefinition:
	var def := MapDefinition.new()
	def.width = map_width
	def.height = map_height
	def.cell_size = map_cell_size
	def.cells = []

	for y in range(map_height):
		var row: Array[int] = []
		for x in range(map_width):
			var is_border := x == 0 or x == map_width - 1 or y == 0 or y == map_height - 1
			row.append(GameMap.CELL_INDESTRUCTIBLE if is_border else GameMap.CELL_EMPTY)
		def.cells.append(row)

	return def


func get_cell(x: int, y: int) -> int:
	if y < 0 or y >= cells.size() or x < 0 or x >= cells[y].size():
		return GameMap.CELL_INDESTRUCTIBLE
	return cells[y][x]


func set_cell(x: int, y: int, value: int) -> void:
	if y < 0 or y >= cells.size() or x < 0 or x >= cells[y].size():
		return
	cells[y][x] = value


func add_spawn(pos: Vector2i) -> void:
	if pos not in spawn_positions:
		spawn_positions.append(pos)


func remove_spawn(pos: Vector2i) -> void:
	spawn_positions.erase(pos)


func has_spawn_at(pos: Vector2i) -> bool:
	return pos in spawn_positions


func resize(new_width: int, new_height: int) -> void:
	"""Redimensiona anclado en (0,0): agrega/saca columnas por la derecha
	y filas por abajo. El contenido existente se copia tal cual — no se
	intenta adivinar qué celdas de borde eran automáticas vs. paredes
	puestas a propósito a mano, MapDefinition no guarda esa distinción.
	El nuevo perímetro siempre queda indestructible, igual que
	create_empty(). Los spawns que queden fuera de los nuevos límites, o
	justo sobre el borde nuevo, se eliminan (mismo criterio que ya aplica
	el editor al pintar una pared sobre un spawn existente)."""
	var old_width := width
	var old_height := height

	var new_cells: Array = []
	for y in range(new_height):
		var row: Array[int] = []
		for x in range(new_width):
			row.append(get_cell(x, y) if x < old_width and y < old_height else GameMap.CELL_EMPTY)
		new_cells.append(row)

	width = new_width
	height = new_height
	cells = new_cells

	for y in range(height):
		for x in range(width):
			if x == 0 or x == width - 1 or y == 0 or y == height - 1:
				set_cell(x, y, GameMap.CELL_INDESTRUCTIBLE)

	var kept_spawns: Array[Vector2i] = []
	for pos in spawn_positions:
		var in_bounds := pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height
		var on_border := pos.x == 0 or pos.x == width - 1 or pos.y == 0 or pos.y == height - 1
		if in_bounds and not on_border:
			kept_spawns.append(pos)
	spawn_positions = kept_spawns


# ============================================
# CARGA/GUARDADO (Infrastructure: única frontera con Godot en esta clase)
# ============================================

static func load_from_file(path: String) -> MapDefinition:
	if not FileAccess.file_exists(path):
		push_error("Mapa no encontrado: " + path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir el mapa: " + path)
		return null

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_error("Error al parsear mapa '%s': %s" % [path, json.get_error_message()])
		return null

	return _from_dict(json.data)


static func _from_dict(data: Dictionary) -> MapDefinition:
	var def := MapDefinition.new()
	def.map_name = data.get("name", "Sin nombre")
	def.width = data.get("width", 13)
	def.height = data.get("height", 11)
	def.cell_size = data.get("cell_size", 32)

	def.cells = []
	for row_string in data.get("cells", []):
		var row: Array[int] = []
		for ch in row_string:
			row.append(_char_to_cell(ch))
		def.cells.append(row)

	def.spawn_positions = []
	for pos in data.get("spawn_positions", []):
		def.spawn_positions.append(Vector2i(pos["x"], pos["y"]))

	return def


func save_to_file(path: String) -> bool:
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var data := {
		"name": map_name,
		"width": width,
		"height": height,
		"cell_size": cell_size,
		"cells": _cells_to_strings(),
		"spawn_positions": spawn_positions.map(func(p): return {"x": p.x, "y": p.y}),
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo guardar el mapa: " + path)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func _cells_to_strings() -> Array:
	var rows: Array = []
	for row in cells:
		var s := ""
		for value in row:
			s += _cell_to_char(value)
		rows.append(s)
	return rows


static func _char_to_cell(ch: String) -> int:
	match ch:
		CHAR_INDESTRUCTIBLE: return GameMap.CELL_INDESTRUCTIBLE
		CHAR_DESTRUCTIBLE: return GameMap.CELL_DESTRUCTIBLE
		_: return GameMap.CELL_EMPTY


static func _cell_to_char(value: int) -> String:
	match value:
		GameMap.CELL_INDESTRUCTIBLE: return CHAR_INDESTRUCTIBLE
		GameMap.CELL_DESTRUCTIBLE: return CHAR_DESTRUCTIBLE
		_: return CHAR_EMPTY


static func list_saved_maps() -> Array[String]:
	"""Nombres de archivo (sin ruta) de todos los mapas guardados en MAPS_DIR."""
	var result: Array[String] = []
	var dir := DirAccess.open(MAPS_DIR)

	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			result.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	result.sort()
	return result
