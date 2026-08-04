class_name PowerUp
extends RefCounted

enum Type {
	NONE = -1,
	SPEED,
	BOMB_RANGE,
	EXTRA_BOMB,
	SHIELD,
}

var grid_pos: Vector2i
var type: Type


func _init(pos: Vector2i, powerup_type: Type) -> void:
	grid_pos = pos
	type = powerup_type


static func type_from_key(key: String) -> Type:
	match key:
		"speed": return Type.SPEED
		"bomb_range": return Type.BOMB_RANGE
		"extra_bomb": return Type.EXTRA_BOMB
		"shield": return Type.SHIELD
		_: return Type.NONE


static func type_to_string(type: Type) -> String:
	match type:
		Type.SPEED: return "SPEED"
		Type.BOMB_RANGE: return "BOMB_RANGE"
		Type.EXTRA_BOMB: return "EXTRA_BOMB"
		Type.SHIELD: return "SHIELD"
		_: return "NONE"
