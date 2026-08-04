extends CharacterBody2D

## Presentation: solo lee estado del GameRoot y traduce input a comandos.
## No contiene lógica de gameplay (Golden Rule 4: Presentation never changes gameplay).

var game_root: GameRoot

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _holding_direction: bool = false
var _blocked_anim_progress: float = 0.0

const SHIELD_TINT := Color(0.6, 0.8, 1.0)


func set_game_root(root: GameRoot) -> void:
	game_root = root


func _physics_process(delta: float) -> void:
	if not game_root:
		return

	visible = game_root.is_player_alive()
	if not visible:
		return

	modulate = SHIELD_TINT if game_root.is_player_shielded() else Color.WHITE

	_handle_movement_input()

	var target_render_pos := game_root.get_player_render_position()
	var moving := game_root.is_player_moving()

	if moving:
		position = position.lerp(target_render_pos, 0.5)
	else:
		position = target_render_pos

	var facing := game_root.get_player_facing_direction()

	if moving:
		# Movimiento real: la animación sigue el progreso real de la celda.
		_blocked_anim_progress = 0.0
		_update_animation(true, facing, game_root.get_player_move_progress())
	elif _holding_direction:
		# Bloqueado contra algo pero con input activo: sigue "caminando"
		# en el lugar, con su propio ciclo de tiempo, para que el jugador
		# pueda girar libremente sin que la posición se mueva.
		_blocked_anim_progress = fmod(_blocked_anim_progress + game_root.get_player_speed() * delta, 1.0)
		_update_animation(true, facing, _blocked_anim_progress)
	else:
		_update_animation(false, facing, 0.0)


func _handle_movement_input() -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir == Vector2.ZERO:
		_holding_direction = false
		game_root.clear_player_input()
		return

	_holding_direction = true

	var dir: Vector2i = Vector2i.ZERO
	if abs(input_dir.x) > abs(input_dir.y):
		dir.x = sign(input_dir.x)
	else:
		dir.y = sign(input_dir.y)

	game_root.set_player_move_direction(dir)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("place_bomb"):
		game_root.try_place_bomb()


func _update_animation(moving: bool, facing_dir: Vector2i, progress: float) -> void:
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
