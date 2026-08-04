extends CharacterBody2D

## Presentation: solo lee estado del GameRoot y traduce input a comandos.
## No contiene lógica de gameplay (Golden Rule 4: Presentation never changes gameplay).

var game_root: GameRoot

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D


func set_game_root(root: GameRoot) -> void:
	game_root = root


func _physics_process(_delta: float) -> void:
	if not game_root:
		return

	_handle_movement_input()

	var target_render_pos := game_root.get_player_render_position()
	if game_root.is_player_moving():
		position = position.lerp(target_render_pos, 0.5)
	else:
		position = target_render_pos

	_update_animation(game_root.is_player_moving(), game_root.get_player_facing_direction())


func _handle_movement_input() -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir == Vector2.ZERO:
		game_root.clear_player_input()
		return

	var dir: Vector2i = Vector2i.ZERO
	if abs(input_dir.x) > abs(input_dir.y):
		dir.x = sign(input_dir.x)
	else:
		dir.y = sign(input_dir.y)

	game_root.set_player_move_direction(dir)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("place_bomb"):
		game_root.try_place_bomb()


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
		var progress = game_root.get_player_move_progress()
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
