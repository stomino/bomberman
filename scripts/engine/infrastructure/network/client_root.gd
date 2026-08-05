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

var _last_sent_direction: Vector2i = Vector2i.ZERO
var _has_sent_direction: bool = false
var _player_nodes: Dictionary = {}  # player_id -> Node, ver _sync_player_nodes()


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


func _inject_into_game_renderer() -> void:
	var renderer := get_node_or_null("GameRenderer")
	if renderer and renderer.has_method("set_game_root"):
		renderer.set_game_root(self)
	else:
		push_error("[ClientRoot] No se encontró el nodo hijo 'GameRenderer' para inyectar dependencias.")


func _connect_to_server() -> void:
	var ip := _selected_server_ip()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, ServerRoot.DEFAULT_PORT)
	if error != OK:
		push_error("[ClientRoot] No se pudo conectar a %s:%d (error %d)" % [ip, ServerRoot.DEFAULT_PORT, error])
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)


func _selected_server_ip() -> String:
	if get_tree().root.has_meta("server_ip"):
		return get_tree().root.get_meta("server_ip")
	return "127.0.0.1"


func _on_connected_to_server() -> void:
	LOCAL_PLAYER_ID = multiplayer.get_unique_id()
	GameLogger.info("Conectado al servidor, id de jugador: %d" % LOCAL_PLAYER_ID, "ClientRoot")


func _on_connection_failed() -> void:
	push_error("[ClientRoot] No se pudo conectar al servidor")


# ============================================
# API PARA PRESENTATION: acá el input no se aplica localmente, viaja al
# servidor por RPC — el servidor es el único que decide si es válido.
# ============================================

func set_player_move_direction(direction: Vector2i) -> void:
	if _has_sent_direction and direction == _last_sent_direction:
		return
	_last_sent_direction = direction
	_has_sent_direction = true
	submit_move.rpc_id(1, direction)


func clear_player_input() -> void:
	set_player_move_direction(Vector2i.ZERO)


func try_place_bomb() -> void:
	submit_place_bomb.rpc_id(1)


# ============================================
# RPC: recibido de verdad acá — aplica el estado autoritativo del servidor
# sobre los mismos contenedores que los getters heredados de GameRoot ya
# saben leer.
# ============================================

@rpc("authority", "call_remote", "reliable")
func receive_snapshot(data: Dictionary) -> void:
	SnapshotCodec.apply(data, game_manager.state, player_system, bomb_system, powerup_system, game_map)
	_sync_player_nodes()


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
