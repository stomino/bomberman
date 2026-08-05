class_name AbilityBalance
extends RefCounted

## Cuánto vale cada habilidad, separado a propósito de GameBalance —
## mismo criterio que PowerUpBalance (ver
## docs/architecture/Implementation_Decisions.md). Primera pasada: loadout
## fijo para todos los jugadores (Velocidad de entrada + Dash
## desbloqueable por tiempo); "quién tiene esta habilidad" todavía no es
## un dato de Player, así que estos valores aplican igual para todos.

const DEFAULT_CONFIG_PATH := "res://config/ability_balance.json"

var speed_ability_bonus: float = 0.2
var dash_unlock_ticks: int = 1800  # 30s a 60 ticks/seg


static func load_from_file(path: String = DEFAULT_CONFIG_PATH) -> AbilityBalance:
	var abilities := AbilityBalance.new()
	abilities.load_config(path)
	return abilities


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
		if s.has("bonus"): speed_ability_bonus = s["bonus"]

	if data.has("dash"):
		var d = data["dash"]
		if d.has("unlock_ticks"): dash_unlock_ticks = d["unlock_ticks"]
