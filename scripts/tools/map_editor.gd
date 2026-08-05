extends Node2D

## Editor de mapas: pintar piso/pared/bloque/spawn en una grilla y
## guardar/cargar como MapDefinition (maps/*.json). Herramienta de
## desarrollo — manipula datos de contenido, no gameplay.

const DEFAULT_ZOOM := 2.0
const MIN_ZOOM := 0.5
const MAX_ZOOM := 4.0
const ZOOM_STEP := 0.25
const PAN_SPEED := 500.0

const DEFAULT_WIDTH := 13
const DEFAULT_HEIGHT := 11
const MIN_MAP_SIZE := 3
const MAX_MAP_SIZE := 30

const TOOL_SPAWN := 99  # sentinel: no es un valor de celda de GameMap

const FLOOR_COLOR := Color(0.82, 0.82, 0.82)
const INDESTRUCTIBLE_COLOR := Color(0.35, 0.35, 0.4)
const DESTRUCTIBLE_COLOR := Color(0.6, 0.42, 0.2)
const GRID_LINE_COLOR := Color(0.5, 0.5, 0.5)
const SPAWN_COLOR := Color(0.2, 0.9, 0.3)

var _definition: MapDefinition
var _current_tool: int = GameMap.CELL_EMPTY

var _zoom: float = DEFAULT_ZOOM
var _pan_offset: Vector2 = Vector2.ZERO

var _name_edit: LineEdit
var _maps_option: OptionButton
var _status_label: Label
var _tool_buttons: Dictionary = {}
var _width_spin: SpinBox
var _height_spin: SpinBox

var _content_container: VBoxContainer
var _toggle_button: Button
var _panel_open: bool = true


func _ready() -> void:
	_definition = MapDefinition.create_empty(DEFAULT_WIDTH, DEFAULT_HEIGHT)
	_build_ui()
	_auto_fit()


func _process(delta: float) -> void:
	# Paneo con flechas — separado del zoom (rueda) y del pintado (click),
	# no hace falta que el panel de herramientas tenga foco.
	var pan_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		pan_dir.x += 1
	if Input.is_key_pressed(KEY_RIGHT):
		pan_dir.x -= 1
	if Input.is_key_pressed(KEY_UP):
		pan_dir.y += 1
	if Input.is_key_pressed(KEY_DOWN):
		pan_dir.y -= 1

	if pan_dir == Vector2.ZERO:
		return

	_pan_offset += pan_dir.normalized() * PAN_SPEED * delta
	_apply_transform()


func _apply_transform() -> void:
	scale = Vector2(_zoom, _zoom)
	position = _pan_offset


func _auto_fit() -> void:
	"""Encuadra el mapa completo en la ventana y resetea el paneo — se
	llama después de crear/cargar/redimensionar, así nunca hace falta
	salir a buscar el mapa a mano. Sin piso mínimo de zoom a propósito:
	un mapa gigante debe verse completo aunque quede chiquito, en vez de
	quedar cortado por un límite arbitrario."""
	var viewport_size := get_viewport_rect().size
	var map_pixel_size := Vector2(_definition.width, _definition.height) * _definition.cell_size
	var fit_zoom := minf(viewport_size.x / map_pixel_size.x, viewport_size.y / map_pixel_size.y)

	_zoom = minf(fit_zoom, DEFAULT_ZOOM)
	_pan_offset = Vector2.ZERO
	_apply_transform()
	queue_redraw()


func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	ui_layer.add_child(panel)

	var outer_vbox := VBoxContainer.new()
	panel.add_child(outer_vbox)

	_toggle_button = Button.new()
	_toggle_button.pressed.connect(_on_toggle_panel_pressed)
	outer_vbox.add_child(_toggle_button)

	_content_container = VBoxContainer.new()
	outer_vbox.add_child(_content_container)

	var tools_row := HBoxContainer.new()
	_content_container.add_child(tools_row)
	_add_tool_button(tools_row, "Borrar (Piso)", GameMap.CELL_EMPTY)
	_add_tool_button(tools_row, "Pared", GameMap.CELL_INDESTRUCTIBLE)
	_add_tool_button(tools_row, "Bloque", GameMap.CELL_DESTRUCTIBLE)
	_add_tool_button(tools_row, "Spawn", TOOL_SPAWN)

	var name_row := HBoxContainer.new()
	_content_container.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Nombre:"
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.text = _definition.map_name
	_name_edit.custom_minimum_size = Vector2(160, 0)
	name_row.add_child(_name_edit)

	var resize_row := HBoxContainer.new()
	_content_container.add_child(resize_row)
	var width_label := Label.new()
	width_label.text = "Ancho:"
	resize_row.add_child(width_label)
	_width_spin = SpinBox.new()
	_width_spin.min_value = MIN_MAP_SIZE
	_width_spin.max_value = MAX_MAP_SIZE
	_width_spin.value = _definition.width
	resize_row.add_child(_width_spin)
	var height_label := Label.new()
	height_label.text = "Alto:"
	resize_row.add_child(height_label)
	_height_spin = SpinBox.new()
	_height_spin.min_value = MIN_MAP_SIZE
	_height_spin.max_value = MAX_MAP_SIZE
	_height_spin.value = _definition.height
	resize_row.add_child(_height_spin)
	var resize_button := Button.new()
	resize_button.text = "Redimensionar"
	resize_button.pressed.connect(_on_resize_pressed)
	resize_row.add_child(resize_button)

	var actions_row := HBoxContainer.new()
	_content_container.add_child(actions_row)

	var save_button := Button.new()
	save_button.text = "Guardar"
	save_button.pressed.connect(_on_save_pressed)
	actions_row.add_child(save_button)

	_maps_option = OptionButton.new()
	_maps_option.custom_minimum_size = Vector2(160, 0)
	actions_row.add_child(_maps_option)
	_refresh_maps_list()

	var load_button := Button.new()
	load_button.text = "Cargar"
	load_button.pressed.connect(_on_load_pressed)
	actions_row.add_child(load_button)

	var new_button := Button.new()
	new_button.text = "Nuevo"
	new_button.pressed.connect(_on_new_pressed)
	actions_row.add_child(new_button)

	var menu_button := Button.new()
	menu_button.text = "Volver al Menú"
	menu_button.pressed.connect(_on_menu_pressed)
	actions_row.add_child(menu_button)

	_status_label = Label.new()
	_content_container.add_child(_status_label)

	_update_tool_buttons()
	_update_toggle_button()


func _add_tool_button(parent: Node, label: String, tool_value: int) -> void:
	var button := Button.new()
	button.text = label
	button.toggle_mode = true
	button.pressed.connect(func(): _set_tool(tool_value))
	parent.add_child(button)
	_tool_buttons[tool_value] = button


func _set_tool(tool_value: int) -> void:
	_current_tool = tool_value
	_update_tool_buttons()


func _update_tool_buttons() -> void:
	for tool_value in _tool_buttons:
		_tool_buttons[tool_value].button_pressed = (tool_value == _current_tool)


func _on_toggle_panel_pressed() -> void:
	_panel_open = not _panel_open
	_content_container.visible = _panel_open
	_update_toggle_button()


func _update_toggle_button() -> void:
	_toggle_button.text = "▾ Ocultar panel (Tab)" if _panel_open else "▸ Mostrar panel (Tab)"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_on_toggle_panel_pressed()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_paint_at_cursor()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_zoom(ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_zoom(-ZOOM_STEP)


func _adjust_zoom(delta_zoom: float) -> void:
	_zoom = clampf(_zoom + delta_zoom, MIN_ZOOM, MAX_ZOOM)
	_apply_transform()


func _paint_at_cursor() -> void:
	# get_local_mouse_position() ya hace la conversión inversa del
	# transform del propio nodo (paneo + zoom) — no hace falta recalcularla
	# a mano como cuando el escalado era una constante fija en _draw().
	var local_pos := get_local_mouse_position()
	var grid_x := floori(local_pos.x / _definition.cell_size)
	var grid_y := floori(local_pos.y / _definition.cell_size)

	if grid_x < 0 or grid_x >= _definition.width or grid_y < 0 or grid_y >= _definition.height:
		return

	if _current_tool == TOOL_SPAWN:
		var pos := Vector2i(grid_x, grid_y)
		if _definition.has_spawn_at(pos):
			_definition.remove_spawn(pos)
		else:
			_definition.set_cell(grid_x, grid_y, GameMap.CELL_EMPTY)
			_definition.add_spawn(pos)
	else:
		_definition.set_cell(grid_x, grid_y, _current_tool)
		_definition.remove_spawn(Vector2i(grid_x, grid_y))  # no tiene sentido un spawn sobre pared/bloque

	queue_redraw()


func _draw() -> void:
	var cs := _definition.cell_size

	for y in range(_definition.height):
		for x in range(_definition.width):
			var rect := Rect2(x * cs, y * cs, cs, cs)
			var color := FLOOR_COLOR

			match _definition.get_cell(x, y):
				GameMap.CELL_INDESTRUCTIBLE:
					color = INDESTRUCTIBLE_COLOR
				GameMap.CELL_DESTRUCTIBLE:
					color = DESTRUCTIBLE_COLOR

			draw_rect(rect, color)
			draw_rect(rect, GRID_LINE_COLOR, false, 1.0)

	for pos in _definition.spawn_positions:
		var center := Vector2(pos.x * cs + cs / 2.0, pos.y * cs + cs / 2.0)
		draw_circle(center, cs * 0.3, SPAWN_COLOR)


func _on_save_pressed() -> void:
	_definition.map_name = _name_edit.text if _name_edit.text != "" else "Sin nombre"
	var file_name: String = _definition.map_name.to_snake_case() + ".json"
	var path := MapDefinition.MAPS_DIR + file_name

	if _definition.save_to_file(path):
		_status_label.text = "Guardado: " + file_name
		_refresh_maps_list()
	else:
		_status_label.text = "Error al guardar"


func _on_load_pressed() -> void:
	if _maps_option.item_count == 0:
		_status_label.text = "No hay mapas guardados"
		return

	var file_name := _maps_option.get_item_text(_maps_option.selected)
	var loaded := MapDefinition.load_from_file(MapDefinition.MAPS_DIR + file_name)

	if loaded == null:
		_status_label.text = "Error al cargar " + file_name
		return

	_definition = loaded
	_name_edit.text = _definition.map_name
	_width_spin.value = _definition.width
	_height_spin.value = _definition.height
	_status_label.text = "Cargado: " + file_name
	_auto_fit()


func _on_new_pressed() -> void:
	_definition = MapDefinition.create_empty(DEFAULT_WIDTH, DEFAULT_HEIGHT)
	_name_edit.text = _definition.map_name
	_width_spin.value = _definition.width
	_height_spin.value = _definition.height
	_status_label.text = "Mapa nuevo"
	_auto_fit()


func _on_resize_pressed() -> void:
	_definition.resize(int(_width_spin.value), int(_height_spin.value))
	_status_label.text = "Redimensionado a %dx%d" % [_definition.width, _definition.height]
	_auto_fit()


func _refresh_maps_list() -> void:
	_maps_option.clear()
	for file_name in MapDefinition.list_saved_maps():
		_maps_option.add_item(file_name)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
