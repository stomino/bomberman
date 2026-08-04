class_name GameRoot
extends Node

## Composition root: único lugar donde se crean e inyectan las dependencias
## de gameplay (Golden Rule 8: "Dependencies are injected").

var balance: GameBalance
var game_map: GameMap
var player_system: PlayerSystem
var bomb_system: BombSystem
var game_manager: GameManager

const LOCAL_PLAYER_ID := 0


func _ready() -> void:
	balance = GameBalance.load_from_file()
	game_map = GameMap.new(balance)
	player_system = PlayerSystem.new(game_map)
	bomb_system = BombSystem.new(game_map, balance)
	game_manager = GameManager.new(game_map, player_system, bomb_system)

	_spawn_local_player()
	_connect_bomb_signals()
	_inject_into_player_node()


func _physics_process(delta: float) -> void:
	game_manager.tick(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			GameLogger.toggle_enabled()
		elif event.keycode == KEY_F5 and GameLogger.enabled:
			balance.reload()
			GameLogger.info("Configuración recargada", "GameRoot")


func _spawn_local_player() -> void:
	var player := Player.new()
	player.id = LOCAL_PLAYER_ID
	player.grid_position = game_map.get_spawn_position(0)
	player.speed = balance.get_speed_for_character()
	player_system.add_player(player)


func _connect_bomb_signals() -> void:
	bomb_system.block_destroyed.connect(func(pos): GameLogger.debug("Bloque destruido en: " + str(pos), "GameRoot"))
	bomb_system.bomb_exploded.connect(func(pos, _cells): GameLogger.debug("Bomba explotó en: " + str(pos), "GameRoot"))


func _inject_into_player_node() -> void:
	var player_node := get_node_or_null("../Player")
	if player_node and player_node.has_method("set_game_root"):
		player_node.set_game_root(self)
	else:
		push_error("[GameRoot] No se encontró el nodo 'Player' hermano para inyectar dependencias.")


# ============================================
# API PARA PRESENTATION (Player node, etc.)
# ============================================

func set_player_move_direction(direction: Vector2i) -> void:
	player_system.set_move_direction(LOCAL_PLAYER_ID, direction)


func clear_player_input() -> void:
	player_system.clear_input(LOCAL_PLAYER_ID)


func try_place_bomb() -> bool:
	var player := player_system.get_player(LOCAL_PLAYER_ID)
	if player == null:
		return false
	return bomb_system.place_bomb(player.grid_position, LOCAL_PLAYER_ID)


func get_player_render_position() -> Vector2:
	return player_system.get_position_for_render(LOCAL_PLAYER_ID, game_map.cell_size)


func is_player_moving() -> bool:
	var player := player_system.get_player(LOCAL_PLAYER_ID)
	return player != null and player.is_moving


func get_player_move_direction() -> Vector2i:
	var player := player_system.get_player(LOCAL_PLAYER_ID)
	return player.move_direction if player != null else Vector2i.ZERO


func get_player_move_progress() -> float:
	var player := player_system.get_player(LOCAL_PLAYER_ID)
	return player.move_progress if player != null else 0.0
