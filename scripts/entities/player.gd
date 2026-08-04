extends CharacterBody2D

@export var move_speed: float = 200.0

var grid_pos: Vector2i
var target_pos: Vector2
var is_moving: bool = false
var grid_manager: Node
var facing_direction: String = "down"

func _ready() -> void:
	grid_manager = get_node("/root/Main/GridManager")
	if grid_manager:
		grid_pos = grid_manager.world_to_grid(position)
		target_pos = position

func _physics_process(delta: float) -> void:
	if not is_moving:
		_handle_movement_input()
	
	if is_moving:
		position = position.move_toward(target_pos, move_speed * delta)
		if position.distance_to(target_pos) < 1.0:
			position = target_pos
			is_moving = false
			grid_pos = grid_manager.world_to_grid(position)
			_update_animation(false)

func _handle_movement_input() -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_dir == Vector2.ZERO:
		if not is_moving:
			_update_animation(false)
		return
	
	var dir: Vector2i = Vector2i.ZERO
	if abs(input_dir.x) > abs(input_dir.y):
		dir.x = sign(input_dir.x)
	else:
		dir.y = sign(input_dir.y)
	
	var new_grid_pos: Vector2i = grid_pos + dir
	
	if grid_manager and grid_manager.is_walkable(new_grid_pos.x, new_grid_pos.y):
		grid_pos = new_grid_pos
		target_pos = grid_manager.grid_to_world(grid_pos.x, grid_pos.y)
		is_moving = true
		_update_animation(true, dir)

func _update_animation(moving: bool, dir: Vector2i = Vector2i.ZERO) -> void:
	var anim_sprite = get_node("AnimatedSprite2D")
	if not anim_sprite:
		return
	
	var animation_name: String = ""
	
	if not moving:
		animation_name = "walk_" + facing_direction
		if anim_sprite.sprite_frames.has_animation(animation_name):
			anim_sprite.stop()
			anim_sprite.set_frame(0)
		return
	
	if dir.y < 0:
		animation_name = "walk_up"
		facing_direction = "up"
	elif dir.y > 0:
		animation_name = "walk_down"
		facing_direction = "down"
	elif dir.x < 0:
		animation_name = "walk_left"
		facing_direction = "left"
	elif dir.x > 0:
		animation_name = "walk_right"
		facing_direction = "right"
	
	if anim_sprite.sprite_frames.has_animation(animation_name):
		anim_sprite.play(animation_name)