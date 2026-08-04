class_name PowerUpBalance
extends RefCounted

## Cuánto vale cada powerup, separado a propósito de GameBalance.
## GameBalance define la base del juego (igual para todos los jugadores);
## esto define cuánto suma cada powerup por encima de esa base. Balancear
## un powerup se hace acá, sin tocar la base del juego. Ver
## docs/architecture/Implementation_Decisions.md.

const DEFAULT_CONFIG_PATH := "res://config/powerup_balance.json"

var speed_bonus_per_stack: float = 0.25
var speed_max_stacks: int = 3

var bomb_range_bonus_per_stack: int = 1
var bomb_range_max_stacks: int = 4

var extra_bomb_bonus_per_stack: int = 1
var extra_bomb_max_stacks: int = 4

var shield_duration_ticks: int = 300


static func load_from_file(path: String = DEFAULT_CONFIG_PATH) -> PowerUpBalance:
	var powerups := PowerUpBalance.new()
	powerups.load_config(path)
	return powerups


func load_config(path: String = DEFAULT_CONFIG_PATH) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Archivo de configuración no encontrado: " + path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir el archivo: " + path)
		return false

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)

	if error != OK:
		push_error("Error al parsear JSON: " + json.get_error_message())
		return false

	_apply_config(json.data)
	return true


func _apply_config(data: Dictionary) -> void:
	if data.has("speed"):
		var s = data["speed"]
		if s.has("bonus_per_stack"): speed_bonus_per_stack = s["bonus_per_stack"]
		if s.has("max_stacks"): speed_max_stacks = s["max_stacks"]

	if data.has("bomb_range"):
		var b = data["bomb_range"]
		if b.has("bonus_per_stack"): bomb_range_bonus_per_stack = b["bonus_per_stack"]
		if b.has("max_stacks"): bomb_range_max_stacks = b["max_stacks"]

	if data.has("extra_bomb"):
		var e = data["extra_bomb"]
		if e.has("bonus_per_stack"): extra_bomb_bonus_per_stack = e["bonus_per_stack"]
		if e.has("max_stacks"): extra_bomb_max_stacks = e["max_stacks"]

	if data.has("shield"):
		var sh = data["shield"]
		if sh.has("duration_ticks"): shield_duration_ticks = sh["duration_ticks"]
