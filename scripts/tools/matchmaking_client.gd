extends Node2D

## Cliente de matchmaking (Fase 7, ver docs/architecture/Implementation_Decisions.md):
## se conecta al servicio de matchmaking (matchmaking/, Python, fuera de
## Godot) por WebSocket, se anota en la cola, y al recibir un
## emparejamiento pasa la IP/puerto del servidor de partida a client.tscn
## por el mismo mecanismo de metadata del root que ya usan
## selected_map_path/server_ip — no amerita un autoload solo para esto.

const MATCHMAKING_URL := "ws://127.0.0.1:8765"

var _socket: WebSocketPeer
var _status_label: Label
var _has_joined_queue: bool = false


func _ready() -> void:
	_build_ui()

	_socket = WebSocketPeer.new()
	var error := _socket.connect_to_url(MATCHMAKING_URL)
	if error != OK:
		_status_label.text = "No se pudo conectar al matchmaking (error %d)" % error
		set_process(false)


func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(40, 40)
	ui_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Buscar partida"
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Conectando al matchmaking..."
	vbox.add_child(_status_label)

	var cancel_button := Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	vbox.add_child(cancel_button)


func _process(_delta: float) -> void:
	_socket.poll()
	var state := _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not _has_joined_queue:
			_has_joined_queue = true
			_socket.send_text(JSON.stringify({"type": "join_queue"}))
			_status_label.text = "Buscando partida..."

		while _socket.get_available_packet_count() > 0:
			_handle_message(_socket.get_packet().get_string_from_utf8())

	elif state == WebSocketPeer.STATE_CLOSED:
		var code := _socket.get_close_code()
		_status_label.text = "Se cerró la conexión con el matchmaking (código %d)" % code
		set_process(false)


func _handle_message(raw_message: String) -> void:
	var data = JSON.parse_string(raw_message)
	if data == null or typeof(data) != TYPE_DICTIONARY or not data.has("type"):
		return

	if data["type"] == "matched":
		_status_label.text = "¡Partida encontrada! Conectando..."
		get_tree().root.set_meta("server_ip", data["server_ip"])
		get_tree().root.set_meta("server_port", int(data["server_port"]))
		get_tree().change_scene_to_file("res://scenes/client.tscn")


func _on_cancel_pressed() -> void:
	if _socket != null:
		_socket.close()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
