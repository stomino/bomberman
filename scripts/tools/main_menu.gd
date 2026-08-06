extends Node2D

## Menú principal: elegir Sandbox (con mapa opcional) o Editor de Mapas.
## Pasa el mapa elegido a la siguiente escena vía metadata del root del
## árbol — no amerita un autoload solo para este dato puntual.

const ABILITY_NAMES := ["speed", "dash", "flash", "push"]
const ABILITY_LABELS := ["Velocidad", "Dash", "Flash", "Empujar"]

var _maps_option: OptionButton
var _ip_input: LineEdit
var _ability_slot_1_option: OptionButton
var _ability_slot_2_option: OptionButton


func _ready() -> void:
	var connection_error := _consume_connection_error()
	_build_ui(connection_error)


func _consume_connection_error() -> String:
	var root := get_tree().root
	if root.has_meta("connection_error"):
		var message: String = root.get_meta("connection_error")
		root.remove_meta("connection_error")
		return message
	return ""


func _build_ui(connection_error: String) -> void:
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(40, 40)
	ui_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Bomberman"
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var map_row := HBoxContainer.new()
	vbox.add_child(map_row)

	var map_label := Label.new()
	map_label.text = "Mapa:"
	map_row.add_child(map_label)

	_maps_option = OptionButton.new()
	_maps_option.custom_minimum_size = Vector2(200, 0)
	_maps_option.add_item("Mapa por defecto")
	for file_name in MapDefinition.list_saved_maps():
		_maps_option.add_item(file_name)
	map_row.add_child(_maps_option)

	var ability_row := HBoxContainer.new()
	vbox.add_child(ability_row)

	var ability_slot_1_label := Label.new()
	ability_slot_1_label.text = "Habilidad 1 (Q):"
	ability_row.add_child(ability_slot_1_label)

	_ability_slot_1_option = OptionButton.new()
	for label in ABILITY_LABELS:
		_ability_slot_1_option.add_item(label)
	_ability_slot_1_option.selected = 0  # Velocidad, mismo default que hoy
	ability_row.add_child(_ability_slot_1_option)

	var ability_slot_2_label := Label.new()
	ability_slot_2_label.text = "Habilidad 2 (E):"
	ability_row.add_child(ability_slot_2_label)

	_ability_slot_2_option = OptionButton.new()
	for label in ABILITY_LABELS:
		_ability_slot_2_option.add_item(label)
	_ability_slot_2_option.selected = 1  # Dash, mismo default que hoy
	ability_row.add_child(_ability_slot_2_option)

	var sandbox_button := Button.new()
	sandbox_button.text = "Jugar (Sandbox)"
	sandbox_button.pressed.connect(_on_sandbox_pressed)
	vbox.add_child(sandbox_button)

	var editor_button := Button.new()
	editor_button.text = "Editor de Mapas"
	editor_button.pressed.connect(_on_editor_pressed)
	vbox.add_child(editor_button)

	var server_button := Button.new()
	server_button.text = "Servidor (LAN / Internet con port forwarding)"
	server_button.pressed.connect(_on_server_pressed)
	vbox.add_child(server_button)

	if connection_error != "":
		var error_label := Label.new()
		error_label.text = connection_error
		error_label.add_theme_color_override("font_color", Color.RED)
		vbox.add_child(error_label)

	var client_row := HBoxContainer.new()
	vbox.add_child(client_row)

	var client_label := Label.new()
	client_label.text = "Cliente, IP:"
	client_row.add_child(client_label)

	_ip_input = LineEdit.new()
	_ip_input.text = "127.0.0.1"
	_ip_input.custom_minimum_size = Vector2(140, 0)
	client_row.add_child(_ip_input)

	var client_button := Button.new()
	client_button.text = "Conectar"
	client_button.pressed.connect(_on_client_pressed)
	client_row.add_child(client_button)


func _ability_slot_key(index: int) -> String:
	return ABILITY_NAMES[index]


func _apply_ability_slot_selection() -> void:
	"""Solo hace falta en los caminos donde el jugador local realmente usa
	teclado (Sandbox, Cliente) — el servidor no tiene input propio ni
	Presentation, ver docs/architecture/Implementation_Decisions.md."""
	get_tree().root.set_meta("ability_slot_1", _ability_slot_key(_ability_slot_1_option.selected))
	get_tree().root.set_meta("ability_slot_2", _ability_slot_key(_ability_slot_2_option.selected))


func _on_sandbox_pressed() -> void:
	if _maps_option.selected > 0:
		var file_name := _maps_option.get_item_text(_maps_option.selected)
		get_tree().root.set_meta("selected_map_path", MapDefinition.MAPS_DIR + file_name)
	else:
		get_tree().root.set_meta("selected_map_path", "")

	_apply_ability_slot_selection()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_editor_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map_editor.tscn")


func _on_server_pressed() -> void:
	if _maps_option.selected > 0:
		var file_name := _maps_option.get_item_text(_maps_option.selected)
		get_tree().root.set_meta("selected_map_path", MapDefinition.MAPS_DIR + file_name)
	else:
		get_tree().root.set_meta("selected_map_path", "")

	get_tree().change_scene_to_file("res://scenes/server.tscn")


func _on_client_pressed() -> void:
	var ip := _ip_input.text.strip_edges()
	get_tree().root.set_meta("server_ip", ip if ip != "" else "127.0.0.1")
	_apply_ability_slot_selection()
	get_tree().change_scene_to_file("res://scenes/client.tscn")
