extends Node2D

## Menú principal: elegir Sandbox (con mapa opcional) o Editor de Mapas.
## Pasa el mapa elegido a la siguiente escena vía metadata del root del
## árbol — no amerita un autoload solo para este dato puntual.

var _maps_option: OptionButton


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
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

	var sandbox_button := Button.new()
	sandbox_button.text = "Jugar (Sandbox)"
	sandbox_button.pressed.connect(_on_sandbox_pressed)
	vbox.add_child(sandbox_button)

	var editor_button := Button.new()
	editor_button.text = "Editor de Mapas"
	editor_button.pressed.connect(_on_editor_pressed)
	vbox.add_child(editor_button)


func _on_sandbox_pressed() -> void:
	if _maps_option.selected > 0:
		var file_name := _maps_option.get_item_text(_maps_option.selected)
		get_tree().root.set_meta("selected_map_path", MapDefinition.MAPS_DIR + file_name)
	else:
		get_tree().root.set_meta("selected_map_path", "")

	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_editor_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map_editor.tscn")
