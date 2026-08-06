class_name ServerRoot
extends Node

## Composition root del servidor autoritativo (Fase 4: cliente-servidor en
## una sola PC, ver docs/architecture/Implementation_Decisions.md). Arma la
## misma simulación que GameRoot arma para el sandbox local, pero para N
## jugadores remotos conectados por red en vez de 1 jugador local. No tiene
## nodos de Presentation que inyectar — el servidor no dibuja nada.

const DEFAULT_PORT := 8910
const MATCH_END_MAX_WAIT_SECONDS := 8.0

var balance: GameBalance
var game_map: GameMap
var player_system: PlayerSystem
var bomb_system: BombSystem
var powerup_system: PowerUpSystem
var game_manager: GameManager

var _map_is_custom: bool = false
var _next_spawn_index: int = 0
var _status_label: Label
var _is_headless: bool = false
var _port: int = DEFAULT_PORT
var _match_ending: bool = false
var _quitting: bool = false


func _ready() -> void:
	_is_headless = DisplayServer.get_name() == "headless"
	_port = _parse_port_override()
	balance = GameBalance.load_from_file()
	game_map = _create_game_map()
	bomb_system = BombSystem.new(game_map, balance, not _map_is_custom)
	player_system = PlayerSystem.new(game_map, balance, bomb_system)
	powerup_system = PowerUpSystem.new(balance)
	game_manager = GameManager.new(game_map, player_system, bomb_system, powerup_system, balance)

	_connect_bomb_signals()
	_build_status_ui()
	_start_server()
	game_manager.match_ended.connect(_on_match_ended)
	game_manager.start_match()


func _physics_process(_delta: float) -> void:
	game_manager.tick()
	_broadcast_snapshot()


func _create_game_map() -> GameMap:
	"""Mismo patrón que GameRoot._create_game_map — se duplica a propósito
	(es poco código); ServerRoot no depende de GameRoot porque sus
	responsabilidades son distintas (N jugadores remotos, sin Presentation)."""
	var map_path := _selected_map_path()

	if map_path != "":
		var definition := MapDefinition.load_from_file(map_path)
		if definition != null:
			_map_is_custom = true
			return GameMap.from_definition(definition)
		push_error("[ServerRoot] No se pudo cargar el mapa '%s', uso el mapa por defecto." % map_path)

	_map_is_custom = false
	return GameMap.from_balance(balance)


func _selected_map_path() -> String:
	if get_tree().root.has_meta("selected_map_path"):
		return get_tree().root.get_meta("selected_map_path")
	return ""


func _parse_port_override() -> int:
	"""Matchmaking (Fase 7, ver docs/architecture/Implementation_Decisions.md)
	lanza un ServerRoot por partida y necesita que cada uno escuche en un
	puerto distinto — se lo pasa como `--port=N` después del separador
	`--`, que Godot no interpreta como argumento propio del motor
	(OS.get_cmdline_user_args() son solo los que están después de ese
	separador). Sin ese argumento, sigue usando DEFAULT_PORT — el flujo
	manual de hosteo (Fase 5/6) no cambia."""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			var value := arg.substr(len("--port=")).to_int()
			if value > 0:
				return value
	return DEFAULT_PORT


func _connect_bomb_signals() -> void:
	bomb_system.block_destroyed.connect(func(pos): GameLogger.debug("Bloque destruido en: " + str(pos), "ServerRoot"))
	bomb_system.bomb_exploded.connect(func(pos, _cells): GameLogger.debug("Bomba explotó en: " + str(pos), "ServerRoot"))
	# Evento, no referencia directa entre systems (Golden Rule: "Prefer Events over direct system calls").
	bomb_system.block_destroyed.connect(powerup_system.maybe_spawn_from_destroyed_block)


func _on_match_ended(winner_id: int) -> void:
	"""Cierra el proceso del servidor solo (ver
	docs/architecture/Implementation_Decisions.md) — matchmaking (Fase 7)
	lanza un ServerRoot nuevo por partida y necesita que el proceso
	efectivamente termine para poder liberar su puerto.

	No cierra con un timer fijo corto: probado en vivo que un margen fijo
	de 3s no siempre alcanza (un cliente real llegó a quedarse afuera de
	la ventana y vio "se perdió la conexión" en vez del mensaje de fin de
	partida — condición de carrera real, no de laboratorio). En cambio,
	espera a que los clientes se vayan solos: cada uno recibe
	state.running=false en el snapshot (ya viaja sin cambios), cierra su
	propio peer (ClientRoot._on_match_ended) y eso dispara
	_on_peer_disconnected acá — cuando ya no queda ninguno registrado,
	cierra al toque, sin esperar nada de tiempo fijo. MATCH_END_MAX_WAIT_SECONDS
	es solo la red de seguridad, para el caso de que algún cliente no se
	vaya solo (crash, etc.)."""
	_match_ending = true
	var message := "Partida terminada. Ganador: %d — esperando que los clientes se desconecten (máx %.0fs)" % [winner_id, MATCH_END_MAX_WAIT_SECONDS]
	GameLogger.info(message, "ServerRoot")
	if _is_headless:
		print("[ServerRoot] " + message)

	await get_tree().create_timer(MATCH_END_MAX_WAIT_SECONDS).timeout
	_quit_server("tiempo máximo alcanzado, algún cliente no se desconectó solo")


func _quit_server(reason: String) -> void:
	if _quitting:
		return
	_quitting = true
	GameLogger.info("Cerrando servidor: " + reason, "ServerRoot")
	if _is_headless:
		print("[ServerRoot] Cerrando servidor: " + reason)
	get_tree().quit()


func _start_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	# create_server() sin bind_address escucha en todas las interfaces de
	# red de la máquina (no solo loopback) — es lo que ya permite Fase 5
	# (LAN) sin cambiar el protocolo, ver
	# docs/architecture/Implementation_Decisions.md.
	var error := peer.create_server(_port, balance.max_players)
	if error != OK:
		push_error("[ServerRoot] No se pudo iniciar el servidor en el puerto %d (error %d)" % [_port, error])
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	var lan_ip := _get_lan_ip()
	GameLogger.info("Servidor escuchando en %s:%d" % [lan_ip, _port], "ServerRoot")
	_update_status_ui()


func _on_peer_connected(id: int) -> void:
	if _next_spawn_index >= balance.max_players:
		GameLogger.warning("Jugador %d rechazado: servidor lleno" % id, "ServerRoot")
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return

	var player := Player.new()
	player.id = id
	player.grid_position = game_map.get_spawn_position(_next_spawn_index)
	_next_spawn_index += 1

	player_system.add_player(player)
	GameLogger.info("Jugador %d conectado, spawn en %s" % [id, str(player.grid_position)], "ServerRoot")
	_update_status_ui()


func _on_peer_disconnected(id: int) -> void:
	# Sin reconexión ni espectador todavía (fuera de alcance de esta fase,
	# ver docs/architecture/Implementation_Decisions.md).
	player_system.remove_player(id)
	GameLogger.info("Jugador %d desconectado" % id, "ServerRoot")
	_update_status_ui()

	if _match_ending and player_system.players.is_empty():
		_quit_server("todos los jugadores se desconectaron solos tras terminar la partida")


func _get_lan_ip() -> String:
	"""Mejor esfuerzo para mostrarle al que hostea qué IP pasarle al otro
	jugador — sin esto, tendría que buscarla a mano (ipconfig / Ajustes de
	red). Prioriza IPv4 de rango privado típico de LAN casera/de oficina;
	si no encuentra ninguna, devuelve la primera IPv4 no-loopback que
	haya (mejor un dato aproximado que nada)."""
	var candidates: Array[String] = []

	for address in IP.get_local_addresses():
		if ":" in address or address.begins_with("127."):
			continue
		candidates.append(address)

	for address in candidates:
		if address.begins_with("192.168.") or address.begins_with("10."):
			return address

	for address in candidates:
		var second_octet := address.get_slice(".", 1).to_int()
		if address.begins_with("172.") and second_octet >= 16 and second_octet <= 31:
			return address

	return candidates[0] if not candidates.is_empty() else "127.0.0.1"


func _build_status_ui() -> void:
	"""El servidor no tenía ningún nodo de Presentation (Fase 4 original:
	'no dibuja nada'). Para Fase 5 (LAN) hace falta que quien hostea pueda
	leer la IP:puerto sin ir a buscar la consola — un Label mínimo alcanza,
	no amerita más que eso."""
	if _is_headless:
		return

	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)

	_status_label = Label.new()
	_status_label.position = Vector2(16, 16)
	_status_label.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(_status_label)

	_update_status_ui()


func _update_status_ui() -> void:
	if _is_headless:
		_print_status()
		return

	if not _status_label:
		return

	var lan_ip := _get_lan_ip()
	_status_label.text = "Servidor: %s:%d\nJugadores: %d/%d" % [
		lan_ip, _port, player_system.players.size(), balance.max_players
	]


func _print_status() -> void:
	"""Servidor headless (Fase 6, ver docs/architecture/Implementation_Decisions.md):
	sin pantalla no hay Label posible, así que esta es la única forma de que
	quien opera el servidor vea su estado. Print plano, no GameLogger — la
	visibilidad operativa de un servidor real no debe depender de un flag de
	debug apagado por default."""
	var lan_ip := _get_lan_ip()
	print("[ServerRoot] %s:%d — Jugadores: %d/%d" % [
		lan_ip, _port, player_system.players.size(), balance.max_players
	])


func _broadcast_snapshot() -> void:
	if player_system.players.is_empty():
		return

	var snapshot := SnapshotCodec.serialize(game_manager.state, player_system, bomb_system, powerup_system, game_map)
	for peer_id in player_system.players.keys():
		receive_snapshot.rpc_id(peer_id, snapshot)


# ============================================
# RPC recibidos de los clientes
# ============================================

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_move(direction: Vector2i) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	game_manager.queue_command(MoveCommand.new(sender_id, direction))


@rpc("any_peer", "call_remote", "reliable")
func submit_place_bomb() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	game_manager.queue_command(PlaceBombCommand.new(sender_id))


@rpc("any_peer", "call_remote", "reliable")
func submit_dash() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	game_manager.queue_command(DashCommand.new(sender_id))


@rpc("any_peer", "call_remote", "reliable")
func submit_speed_boost() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	game_manager.queue_command(SpeedBoostCommand.new(sender_id))


@rpc("any_peer", "call_remote", "reliable")
func submit_flash() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	game_manager.queue_command(FlashCommand.new(sender_id))


@rpc("any_peer", "call_remote", "reliable")
func submit_bomb_push() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	game_manager.queue_command(BombPushCommand.new(sender_id))


# ============================================
# Stub vacío: Godot solo rutea un RPC si el nodo receptor existe en el
# MISMO NodePath en ambos peers y declara el método con la MISMA
# anotación @rpc. El servidor nunca ejecuta este cuerpo (nunca se llama a
# sí mismo) — existe solo para que el path/anotación matcheen con
# ClientRoot.receive_snapshot, que sí lo implementa de verdad.
#
# "reliable" y no "unreliable": probado en vivo (servidor + cliente reales
# sobre loopback) que el snapshot completo (mapa + entidades) supera el
# MTU de ENet (~1392 bytes) fácilmente — mandarlo unreliable tira el
# warning "above the MTU... higher packet loss" de ENet. "reliable" sí
# fragmenta paquetes grandes en varios paquetes chicos automáticamente.
# ============================================

@rpc("authority", "call_remote", "reliable")
func receive_snapshot(_data: Dictionary) -> void:
	pass
