class_name ClientRoot
extends GameRoot

## Composition root del cliente (Fase 4: cliente-servidor en una sola PC,
## ver docs/architecture/Implementation_Decisions.md). Hereda de GameRoot
## para reutilizar sin cambios toda su superficie de lectura
## (is_player_alive, get_player_render_position, etc.) — esos métodos ya
## solo leen player_system/bomb_system/powerup_system/game_map, que acá
## están poblados por snapshots del servidor en vez de simulados
## localmente. Solo se sobreescribe lo que de verdad cambia: cómo se arma
## todo, cómo viaja el input y que nunca se corre game_manager.tick() acá
## (el cliente nunca es autoritativo).

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _player_nodes: Dictionary = {}  # player_id -> Node, ver _sync_player_nodes()
var _was_running: bool = false  # ver receive_snapshot() / _on_match_ended()


func _ready() -> void:
	# balance/game_map acá son cosméticos, no autoritativos: balance se
	# carga localmente (mismo archivo que usa el servidor) solo para
	# constantes visuales (ej. degradé de mecha de bomba en
	# game_renderer.gd); game_map arranca vacío y sus dimensiones/celdas
	# las define el primer snapshot que llegue del servidor.
	balance = GameBalance.load_from_file()
	game_map = GameMap.new()
	bomb_system = BombSystem.new(game_map, balance, false)
	player_system = PlayerSystem.new(game_map, balance, bomb_system)
	powerup_system = PowerUpSystem.new(balance)
	game_manager = GameManager.new(game_map, player_system, bomb_system, powerup_system, balance)

	# A diferencia de GameRoot (sandbox, 1 Player estático en la escena),
	# acá no se sabe de antemano cuántos jugadores va a haber ni quién es
	# "el mío" hasta conectarse — los nodos Player se spawnean en runtime,
	# ver _sync_player_nodes().
	_inject_into_game_renderer()
	_connect_to_server()


func _physics_process(_delta: float) -> void:
	# No simula: la única fuente de verdad es el snapshot que llega por
	# receive_snapshot(), fuera del loop de frames.
	pass


func _sync_player_nodes() -> void:
	"""Instancia/destruye nodos Player para que coincidan exactamente con
	los jugadores presentes en el último snapshot — cubre tanto al
	jugador local como a los rivales, con el mismo mecanismo."""
	var current_ids := player_system.players.keys()

	for id in current_ids:
		if not _player_nodes.has(id):
			_spawn_player_node(id)

	for id in _player_nodes.keys():
		if id not in current_ids:
			_despawn_player_node(id)


func _spawn_player_node(id: int) -> void:
	var node := PLAYER_SCENE.instantiate()
	add_child(node)
	node.set_game_root(self, id)
	_player_nodes[id] = node


func _despawn_player_node(id: int) -> void:
	_player_nodes[id].queue_free()
	_player_nodes.erase(id)


func _connect_to_server() -> void:
	var ip := _selected_server_ip()
	var port := _selected_server_port()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, port)
	if error != OK:
		push_error("[ClientRoot] No se pudo conectar a %s:%d (error %d)" % [ip, port, error])
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _selected_server_ip() -> String:
	if get_tree().root.has_meta("server_ip"):
		return get_tree().root.get_meta("server_ip")
	return "127.0.0.1"


func _selected_server_port() -> int:
	"""Matchmaking (Fase 7) pasa un puerto dinámico vía meta
	"server_port" — mismo patrón que "server_ip". Sin esa meta (flujo
	manual de Fase 5/6, tipear una IP y conectar), sigue usando
	ServerRoot.DEFAULT_PORT como siempre."""
	if get_tree().root.has_meta("server_port"):
		return get_tree().root.get_meta("server_port")
	return ServerRoot.DEFAULT_PORT


func _on_connected_to_server() -> void:
	LOCAL_PLAYER_ID = multiplayer.get_unique_id()
	GameLogger.info("Conectado al servidor, id de jugador: %d" % LOCAL_PLAYER_ID, "ClientRoot")


func _on_connection_failed() -> void:
	_fail_and_return_to_menu("No se pudo conectar al servidor.")


func _on_server_disconnected() -> void:
	_fail_and_return_to_menu("Se perdió la conexión con el servidor.")


func _fail_and_return_to_menu(message: String) -> void:
	"""Fase 6 (ver docs/architecture/Implementation_Decisions.md): detección
	básica de desconexión, sin reconexión ni resync de estado — el jugador
	vuelve al menú con un mensaje. close() antes de = null para que un
	segundo intento de conexión desde el menú arranque con un multiplayer
	limpio, no con un peer cerrado colgado."""
	GameLogger.warning(message, "ClientRoot")
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	get_tree().root.set_meta("connection_error", message)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_match_ended() -> void:
	"""GameManager.state.running pasó de true a false (ver receive_snapshot):
	la partida terminó normalmente, no es una desconexión — mensaje y
	meta propios (match_result_message, no connection_error) para que el
	menú lo muestre distinto (no como un error). Mismo cierre de peer que
	_fail_and_return_to_menu, sin reusar esa función porque el mensaje no
	es un fallo."""
	var message := _match_result_message()
	GameLogger.info(message, "ClientRoot")
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	get_tree().root.set_meta("match_result_message", message)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _match_result_message() -> String:
	var winner_id: int = game_manager.state.winner_id
	if winner_id == -1:
		return "Partida terminada: empate."
	elif winner_id == LOCAL_PLAYER_ID:
		return "¡Ganaste la partida!"
	else:
		return "Partida terminada. Ganó el otro jugador."


# ============================================
# API PARA PRESENTATION: acá el input no se aplica localmente, viaja al
# servidor por RPC — el servidor es el único que decide si es válido.
# ============================================

func set_player_move_direction(direction: Vector2i) -> void:
	"""Se manda en cada frame que la tecla sigue apretada (sin deduplicar
	por dirección), igual que GameRoot hace localmente — PlayerSystem
	necesita recibir la dirección de nuevo cada vez que el jugador termina
	de cruzar una celda para seguir moviéndose (ver
	docs/architecture/Implementation_Decisions.md, Fase 6). Una versión
	anterior deduplicaba por ancho de banda, pero eso hacía que el jugador
	solo avanzara una celda por tecla apretada en red — rompía la paridad
	sandbox/red que el pipeline de Commands busca garantizar."""
	submit_move.rpc_id(1, direction)


func clear_player_input() -> void:
	set_player_move_direction(Vector2i.ZERO)


func try_place_bomb() -> void:
	submit_place_bomb.rpc_id(1)


func try_dash() -> void:
	submit_dash.rpc_id(1)


func try_speed_boost() -> void:
	submit_speed_boost.rpc_id(1)


func try_flash() -> void:
	submit_flash.rpc_id(1)


func try_bomb_push() -> void:
	submit_bomb_push.rpc_id(1)


# ============================================
# RPC: recibido de verdad acá — aplica el estado autoritativo del servidor
# sobre los mismos contenedores que los getters heredados de GameRoot ya
# saben leer.
# ============================================

@rpc("authority", "call_remote", "reliable")
func receive_snapshot(data: Dictionary) -> void:
	SnapshotCodec.apply(data, game_manager.state, player_system, bomb_system, powerup_system, game_map)
	_apply_map_zoom()
	_sync_player_nodes()

	if _was_running and not game_manager.state.running:
		_on_match_ended()
		return
	_was_running = game_manager.state.running


# ============================================
# Stubs vacíos: Godot solo rutea un RPC si el nodo receptor existe en el
# MISMO NodePath en ambos peers y declara el método con la MISMA
# anotación @rpc. El cliente nunca ejecuta estos cuerpos (nunca se llama a
# sí mismo) — existen solo para que el path/anotación matcheen con
# ServerRoot.submit_move/submit_place_bomb, que sí los implementan de verdad.
# ============================================

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_move(_direction: Vector2i) -> void:
	pass


@rpc("any_peer", "call_remote", "reliable")
func submit_place_bomb() -> void:
	pass


@rpc("any_peer", "call_remote", "reliable")
func submit_dash() -> void:
	pass


@rpc("any_peer", "call_remote", "reliable")
func submit_speed_boost() -> void:
	pass


@rpc("any_peer", "call_remote", "reliable")
func submit_flash() -> void:
	pass


@rpc("any_peer", "call_remote", "reliable")
func submit_bomb_push() -> void:
	pass
