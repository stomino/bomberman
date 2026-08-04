class_name Player
extends RefCounted

var id: int
var grid_position: Vector2i

var alive: bool = true

var speed: float = 6.0

var move_direction: Vector2i = Vector2i.ZERO
var next_direction: Vector2i = Vector2i.ZERO

var move_progress: float = 0.0

var facing_direction: Vector2i = Vector2i.DOWN

var is_moving: bool = false
var has_pending_move: bool = false