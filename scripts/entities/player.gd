# ============================================
# player.gd (Versión Cliente)
# ============================================

extends CharacterBody2D

@export var move_speed: float = 200.0

var player_logic: PlayerLogic
var grid_manager: Node
var grid_pos: Vector2i
var target_pos: Vector2
var is_moving: bool = false
var facing_direction: String = "down"

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if GameBalance.debug_mode:
		print("[INFO] [Player] 🎮 Jugador inicializado")
	
	grid_manager = get_node("/root/Main/GridManager")
	
	if grid_manager:
		var start_pos = grid_manager.world_to_grid(position)
		var speed = GameBalance.get_speed_for_character()
		player_logic = PlayerLogic.new(0, start_pos, speed)
		
		grid_pos = start_pos
		target_pos = position

func _physics_process(delta: float) -> void:
	if not player_logic:
		return
	
	_handle_movement_input()
	player_logic.tick_update(delta, grid_manager)
	
	# Posición visual
	var target_render_pos = player_logic.get_position_for_render()
	if player_logic.is_moving():
		position = position.lerp(target_render_pos, 0.5)
	else:
		position = target_render_pos
	
	# Logs de animación (solo en debug)
	if GameBalance.debug_mode and Engine.get_process_frames() % 30 == 0:
		print("[VERBOSE] [Player] 🎬 Animación - Moviendo: %s | Progreso: %.1f | Dir: %s" % [
			str(player_logic.is_moving()), 
			player_logic.get_move_progress(),
			str(player_logic.get_current_move_direction())
		])
	
	# Usar dirección actual de movimiento
	var current_dir = player_logic.get_current_move_direction()
	_update_animation(player_logic.is_moving(), current_dir)

func _handle_movement_input() -> void:
	if not grid_manager:
		return
	
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_dir == Vector2.ZERO:
		player_logic.clear_input()
		return
	
	var dir: Vector2i = Vector2i.ZERO
	if abs(input_dir.x) > abs(input_dir.y):
		dir.x = sign(input_dir.x)
	else:
		dir.y = sign(input_dir.y)
	
	player_logic.set_move_direction(dir)

func _update_animation(moving: bool, facing_dir: Vector2i) -> void:
	if not anim_sprite:
		return
	
	var dir_str: String = _vector_to_string(facing_dir)
	
	if not moving:
		var idle_name = "idle_" + dir_str
		if anim_sprite.sprite_frames.has_animation(idle_name):
			if anim_sprite.animation != idle_name:
				anim_sprite.play(idle_name)
			return
		else:
			if anim_sprite.is_playing():
				anim_sprite.stop()
				anim_sprite.set_frame(0)
			return
	
	var walk_name = "walk_" + dir_str
	
	if anim_sprite.sprite_frames.has_animation(walk_name):
		var progress = player_logic.get_move_progress()
		var total_frames = anim_sprite.sprite_frames.get_frame_count(walk_name)
		
		var frame_index = int(progress * (total_frames - 1))
		frame_index = clamp(frame_index, 0, total_frames - 1)
		
		if anim_sprite.animation != walk_name:
			anim_sprite.play(walk_name)
			anim_sprite.set_frame(frame_index)
			anim_sprite.pause()
		else:
			anim_sprite.set_frame(frame_index)
	else:
		var idle_name = "idle_" + dir_str
		if anim_sprite.sprite_frames.has_animation(idle_name):
			if anim_sprite.animation != idle_name:
				anim_sprite.play(idle_name)

func _vector_to_string(dir: Vector2i) -> String:
	if dir == Vector2i.UP:
		return "up"
	elif dir == Vector2i.DOWN:
		return "down"
	elif dir == Vector2i.LEFT:
		return "left"
	elif dir == Vector2i.RIGHT:
		return "right"
	return "down"

# ============================================
# INPUT PARA BOMBAS
# ============================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# ✅ Espacio: Colocar bomba
		if event.keycode == KEY_SPACE:
			_try_place_bomb()

func _try_place_bomb() -> void:
	"""Intenta colocar una bomba en la posición actual del jugador"""
	if not grid_manager:
		if GameBalance.debug_mode:
			print("[DEBUG] [Player] ❌ GridManager no disponible")
		return
	
	if not grid_manager.bomb_system:
		if GameBalance.debug_mode:
			print("[DEBUG] [Player] ❌ BombSystem no inicializado")
		return
	
	var pos = player_logic.get_current_cell()
	var success = grid_manager.bomb_system.place_bomb(pos, 0)  # owner_id = 0 (jugador local)
	
	if not success and GameBalance.debug_mode:
		print("[DEBUG] [Player] ❌ No se pudo colocar bomba en: ", str(pos))

# ============================================
# FUNCIONES PARA INTEGRACIÓN
# ============================================

func get_grid_position() -> Vector2i:
	return player_logic.get_current_cell() if player_logic else Vector2i.ZERO

func is_player_moving() -> bool:
	return player_logic.is_moving() if player_logic else false