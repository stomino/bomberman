class_name GameRoot
extends Node2D

## Composition root: único lugar donde se crean e inyectan las dependencias
## de gameplay (Golden Rule 8: "Dependencies are injected"). Extiende
## Node2D (no Node) porque es también la raíz visual de su escena — trae
## un transform propio (scale) para poder ajustar el zoom al tamaño del
## mapa cargado, ver _apply_map_zoom(). GameRenderer/Player cuelgan de
## acá como hijos directos, no como hermanos.

var balance: GameBalance
var game_map: GameMap
var player_system: PlayerSystem
var bomb_system: BombSystem
var powerup_system: PowerUpSystem
var game_manager: GameManager

## Var, no const: ClientRoot (Fase 4, ver
## docs/architecture/Implementation_Decisions.md) hereda de GameRoot y la
## sobreescribe con el peer id que el servidor le asigna al conectar, para
## poder reutilizar sin cambios todos los getters de más abajo.
var LOCAL_PLAYER_ID := 0

var _map_is_custom: bool = false
var _last_zoomed_width: int = -1
var _last_zoomed_height: int = -1


func _ready() -> void:
	balance = GameBalance.load_from_file()
	game_map = _create_game_map()
	bomb_system = BombSystem.new(game_map, balance, not _map_is_custom)
	player_system = PlayerSystem.new(game_map, balance, bomb_system)
	powerup_system = PowerUpSystem.new(balance)
	game_manager = GameManager.new(game_map, player_system, bomb_system, powerup_system, balance)

	_spawn_local_player()
	_connect_bomb_signals()
	_inject_into_player_node()
	_inject_into_game_renderer()
	_apply_map_zoom()
	game_manager.start_match()


func _physics_process(_delta: float) -> void:
	game_manager.tick()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		elif event.keycode == KEY_F1:
			GameLogger.toggle_enabled()
		elif event.keycode == KEY_F5 and GameLogger.enabled:
			balance.reload()
			GameLogger.info("Configuración recargada", "GameRoot")


func _create_game_map() -> GameMap:
	var map_path := _selected_map_path()

	if map_path != "":
		var definition := MapDefinition.load_from_file(map_path)
		if definition != null:
			_map_is_custom = true
			return GameMap.from_definition(definition)
		push_error("[GameRoot] No se pudo cargar el mapa '%s', uso el mapa por defecto." % map_path)

	_map_is_custom = false
	return GameMap.from_balance(balance)


func _selected_map_path() -> String:
	if get_tree().root.has_meta("selected_map_path"):
		return get_tree().root.get_meta("selected_map_path")
	return ""


func _spawn_local_player() -> void:
	var player := Player.new()
	player.id = LOCAL_PLAYER_ID
	player.grid_position = game_map.get_spawn_position(0)
	player_system.add_player(player)


func _connect_bomb_signals() -> void:
	bomb_system.block_destroyed.connect(func(pos): GameLogger.debug("Bloque destruido en: " + str(pos), "GameRoot"))
	bomb_system.bomb_exploded.connect(func(pos, _cells): GameLogger.debug("Bomba explotó en: " + str(pos), "GameRoot"))
	# Evento, no referencia directa entre systems (Golden Rule: "Prefer Events over direct system calls").
	bomb_system.block_destroyed.connect(powerup_system.maybe_spawn_from_destroyed_block)


func _inject_into_player_node() -> void:
	var player_node := get_node_or_null("Player")
	if player_node and player_node.has_method("set_game_root"):
		player_node.set_game_root(self, LOCAL_PLAYER_ID)
	else:
		push_error("[GameRoot] No se encontró el nodo hijo 'Player' para inyectar dependencias.")


func _inject_into_game_renderer() -> void:
	var renderer := get_node_or_null("GameRenderer")
	if renderer and renderer.has_method("set_game_root"):
		renderer.set_game_root(self)
	else:
		push_error("[GameRoot] No se encontró el nodo hijo 'GameRenderer' para inyectar dependencias.")


func _apply_map_zoom() -> void:
	"""Ajusta la escala de toda la escena (Golden Rule: el zoom vive en el
	transform del nodo raíz, GameRenderer/Player no necesitan saber que
	existe) para que el mapa completo entre en la ventana, sin importar su
	tamaño (hasta 30x30, tope que impone el editor). Con guard para no
	reasignar scale en cada llamada si el mapa no cambió de tamaño — en
	ClientRoot esto se llama en cada snapshot."""
	if game_map.width <= 0 or game_map.height <= 0:
		return
	if game_map.width == _last_zoomed_width and game_map.height == _last_zoomed_height:
		return

	var viewport_size := get_viewport_rect().size
	var map_pixel_size := Vector2(game_map.width, game_map.height) * game_map.cell_size
	var fit_zoom := minf(viewport_size.x / map_pixel_size.x, viewport_size.y / map_pixel_size.y)
	var zoom := minf(fit_zoom, 2.0)

	scale = Vector2(zoom, zoom)
	_last_zoomed_width = game_map.width
	_last_zoomed_height = game_map.height


# ============================================
# API PARA PRESENTATION (Player node, etc.)
# ============================================

func set_player_move_direction(direction: Vector2i) -> void:
	game_manager.queue_command(MoveCommand.new(LOCAL_PLAYER_ID, direction))


func clear_player_input() -> void:
	game_manager.queue_command(MoveCommand.new(LOCAL_PLAYER_ID, Vector2i.ZERO))


func try_place_bomb() -> void:
	game_manager.queue_command(PlaceBombCommand.new(LOCAL_PLAYER_ID))


func is_player_alive(player_id: int) -> bool:
	var player := player_system.get_player(player_id)
	return player != null and player.alive


func get_player_render_position(player_id: int) -> Vector2:
	return player_system.get_position_for_render(player_id, game_map.cell_size)


func is_player_moving(player_id: int) -> bool:
	var player := player_system.get_player(player_id)
	return player != null and player.is_moving


func get_player_facing_direction(player_id: int) -> Vector2i:
	var player := player_system.get_player(player_id)
	return player.facing_direction if player != null else Vector2i.DOWN


func get_player_speed(player_id: int) -> float:
	var player := player_system.get_player(player_id)
	return player_system.get_effective_speed(player) if player != null else 0.0


func is_player_shielded(player_id: int) -> bool:
	var player := player_system.get_player(player_id)
	return player != null and player_system.is_shielded(player)


func get_player_move_progress(player_id: int) -> float:
	return player_system.get_move_progress(player_id)
