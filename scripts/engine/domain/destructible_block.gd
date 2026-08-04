class_name DestructibleBlock
extends RefCounted

var grid_pos: Vector2i
var alive: bool = true


func _init(pos: Vector2i) -> void:
	grid_pos = pos


func destroy() -> void:
	alive = false
