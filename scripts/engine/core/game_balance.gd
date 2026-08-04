class_name GameBalance
extends RefCounted

## Configuración de balance del juego, centralizada y cargada desde JSON.
## Vive en Core (ver Engine_Architecture_Specification_v1.0.md) como un
## objeto de datos plano: no depende del árbol de escena de Godot y se crea
## una única vez en GameRoot (composition root), que la inyecta en
## GameMap/PlayerSystem/BombSystem. `load_from_file` es la única función
## que toca una API específica de Godot (FileAccess): si el juego migrara
## de motor, es el único punto a reemplazar.

const DEFAULT_CONFIG_PATH := "res://config/game_balance.json"

var base_speed_cells_per_second: float = 4.0
var speed_multiplier_global: float = 1.0
var character_speeds: Dictionary = {
	"normal": 1.0,
	"fast": 1.25,
	"tank": 0.8
}

var bomb_timer_base_ticks: int = 150
var bomb_timer_min_ticks: int = 30
var bomb_timer_max_ticks: int = 300
var bomb_range_base: int = 3
var bomb_range_min: int = 1
var bomb_range_max: int = 7
var max_bombs_per_player: int = 1

var explosion_duration_base_ticks: int = 30
var explosion_duration_min_ticks: int = 5
var explosion_duration_max_ticks: int = 90
var explosion_damage: int = 1
var chain_explosions: bool = true
var chain_delay_ticks: int = 5

var destructible_drop_chance: float = 0.3
var powerup_distribution: Dictionary = {
	"speed": 0.25,
	"bomb_range": 0.25,
	"extra_bomb": 0.20,
	"shield": 0.10,
	"none": 0.20
}

var map_width: int = 13
var map_height: int = 11
var cell_size: int = 32
var spawn_positions: Array = []
var indestructible_border: bool = true
var destructible_pattern_enabled: bool = true
var destructible_pattern: Array = []

var spawn_invulnerability_ticks: int = 60
var max_players: int = 4
var respawn_ticks: int = 120

var tick_rate: int = 60
var round_time_seconds: int = 120
var overtime_seconds: int = 30

var authoritative: bool = true
var prediction_enabled: bool = false
var reconciliation_enabled: bool = false

var current_config_file: String = DEFAULT_CONFIG_PATH

enum CharacterType {
	NORMAL,
	FAST,
	TANK
}


# ============================================
# CARGA (Infrastructure: única frontera con Godot)
# ============================================

static func load_from_file(path: String = DEFAULT_CONFIG_PATH) -> GameBalance:
	var balance := GameBalance.new()
	balance.load_config(path)
	return balance


func load_config(path: String = DEFAULT_CONFIG_PATH) -> bool:
	current_config_file = path

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
	print("✅ Configuración cargada desde: ", path)
	_print_config_summary()
	return true


func reload() -> bool:
	return load_config(current_config_file)


func switch_to(profile: String) -> bool:
	return load_config("res://config/game_balance_" + profile + ".json")


func _apply_config(data: Dictionary) -> void:
	if data.has("movement"):
		var m = data["movement"]
		if m.has("base_speed_cells_per_second"): base_speed_cells_per_second = m["base_speed_cells_per_second"]
		if m.has("speed_multiplier_global"): speed_multiplier_global = m["speed_multiplier_global"]
		if m.has("character_speeds"): character_speeds = m["character_speeds"]

	if data.has("bombs"):
		var b = data["bombs"]
		if b.has("timer_base_ticks"): bomb_timer_base_ticks = b["timer_base_ticks"]
		if b.has("timer_min_ticks"): bomb_timer_min_ticks = b["timer_min_ticks"]
		if b.has("timer_max_ticks"): bomb_timer_max_ticks = b["timer_max_ticks"]
		if b.has("range_base"): bomb_range_base = b["range_base"]
		if b.has("range_min"): bomb_range_min = b["range_min"]
		if b.has("range_max"): bomb_range_max = b["range_max"]
		if b.has("max_bombs_per_player"): max_bombs_per_player = b["max_bombs_per_player"]

	if data.has("explosions"):
		var e = data["explosions"]
		if e.has("duration_base_ticks"): explosion_duration_base_ticks = e["duration_base_ticks"]
		if e.has("duration_min_ticks"): explosion_duration_min_ticks = e["duration_min_ticks"]
		if e.has("duration_max_ticks"): explosion_duration_max_ticks = e["duration_max_ticks"]
		if e.has("damage"): explosion_damage = e["damage"]
		if e.has("chain_explosions"): chain_explosions = e["chain_explosions"]
		if e.has("chain_delay_ticks"): chain_delay_ticks = e["chain_delay_ticks"]

	if data.has("destructible_blocks"):
		var d = data["destructible_blocks"]
		if d.has("drop_chance"): destructible_drop_chance = d["drop_chance"]
		if d.has("powerup_distribution"): powerup_distribution = d["powerup_distribution"]

	if data.has("map"):
		var m = data["map"]
		if m.has("width"): map_width = m["width"]
		if m.has("height"): map_height = m["height"]
		if m.has("cell_size"): cell_size = m["cell_size"]
		if m.has("spawn_positions"):
			spawn_positions = []
			for pos in m["spawn_positions"]:
				spawn_positions.append(Vector2i(pos["x"], pos["y"]))
		if m.has("indestructible_border"): indestructible_border = m["indestructible_border"]
		if m.has("destructible_pattern"):
			var dp = m["destructible_pattern"]
			if dp.has("enabled"): destructible_pattern_enabled = dp["enabled"]
			if dp.has("pattern"): destructible_pattern = dp["pattern"]

	if data.has("player"):
		var p = data["player"]
		if p.has("spawn_invulnerability_ticks"): spawn_invulnerability_ticks = p["spawn_invulnerability_ticks"]
		if p.has("max_players"): max_players = p["max_players"]
		if p.has("respawn_ticks"): respawn_ticks = p["respawn_ticks"]

	if data.has("game"):
		var g = data["game"]
		if g.has("tick_rate"): tick_rate = g["tick_rate"]
		if g.has("round_time_seconds"): round_time_seconds = g["round_time_seconds"]
		if g.has("overtime_seconds"): overtime_seconds = g["overtime_seconds"]

	if data.has("server"):
		var s = data["server"]
		if s.has("authoritative"): authoritative = s["authoritative"]
		if s.has("prediction_enabled"): prediction_enabled = s["prediction_enabled"]
		if s.has("reconciliation_enabled"): reconciliation_enabled = s["reconciliation_enabled"]


# ============================================
# GETTERS DERIVADOS
# ============================================

func get_speed_for_character(type: CharacterType = CharacterType.NORMAL) -> float:
	var multiplier = 1.0

	match type:
		CharacterType.NORMAL:
			multiplier = character_speeds.get("normal", 1.0)
		CharacterType.FAST:
			multiplier = character_speeds.get("fast", 1.25)
		CharacterType.TANK:
			multiplier = character_speeds.get("tank", 0.8)

	return base_speed_cells_per_second * multiplier * speed_multiplier_global


func get_bomb_timer() -> int:
	return clamp(bomb_timer_base_ticks, bomb_timer_min_ticks, bomb_timer_max_ticks)


func get_bomb_range() -> int:
	return clamp(bomb_range_base, bomb_range_min, bomb_range_max)


func get_explosion_duration() -> int:
	return clamp(explosion_duration_base_ticks, explosion_duration_min_ticks, explosion_duration_max_ticks)


func get_spawn_position(index: int) -> Vector2i:
	if index < spawn_positions.size():
		return spawn_positions[index]
	return Vector2i(1, 1)


func get_random_powerup_type() -> String:
	var random = randf()
	var cumulative = 0.0

	for type in powerup_distribution.keys():
		cumulative += powerup_distribution[type]
		if random <= cumulative:
			return type

	return "none"


# ============================================
# EXPORTAR CONFIGURACIÓN ACTUAL
# ============================================

func save_to(path: String = "res://config/game_balance_exported.json") -> bool:
	var data = {
		"movement": {
			"base_speed_cells_per_second": base_speed_cells_per_second,
			"speed_multiplier_global": speed_multiplier_global,
			"character_speeds": character_speeds
		},
		"bombs": {
			"timer_base_ticks": bomb_timer_base_ticks,
			"timer_min_ticks": bomb_timer_min_ticks,
			"timer_max_ticks": bomb_timer_max_ticks,
			"range_base": bomb_range_base,
			"range_min": bomb_range_min,
			"range_max": bomb_range_max,
			"max_bombs_per_player": max_bombs_per_player
		},
		"explosions": {
			"duration_base_ticks": explosion_duration_base_ticks,
			"duration_min_ticks": explosion_duration_min_ticks,
			"duration_max_ticks": explosion_duration_max_ticks,
			"damage": explosion_damage,
			"chain_explosions": chain_explosions,
			"chain_delay_ticks": chain_delay_ticks
		},
		"destructible_blocks": {
			"drop_chance": destructible_drop_chance,
			"powerup_distribution": powerup_distribution
		},
		"map": {
			"width": map_width,
			"height": map_height,
			"cell_size": cell_size,
			"spawn_positions": spawn_positions,
			"indestructible_border": indestructible_border,
			"destructible_pattern": {
				"enabled": destructible_pattern_enabled,
				"pattern": destructible_pattern
			}
		},
		"player": {
			"spawn_invulnerability_ticks": spawn_invulnerability_ticks,
			"max_players": max_players,
			"respawn_ticks": respawn_ticks
		},
		"game": {
			"tick_rate": tick_rate,
			"round_time_seconds": round_time_seconds,
			"overtime_seconds": overtime_seconds
		},
		"server": {
			"authoritative": authoritative,
			"prediction_enabled": prediction_enabled,
			"reconciliation_enabled": reconciliation_enabled
		}
	}

	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo guardar el archivo: " + path)
		return false

	file.store_string(json_string)
	file.close()

	print("✅ Configuración guardada en: ", path)
	return true


func _print_config_summary() -> void:
	print("📊 Resumen de configuración:")
	print("  Velocidad base: ", base_speed_cells_per_second, " celdas/seg")
	print("  Tiempo de bomba: ", get_bomb_timer(), " ticks")
	print("  Rango de bomba: ", get_bomb_range(), " celdas")
	print("  Duración explosión: ", get_explosion_duration(), " ticks")
	print("  Drop chance: ", destructible_drop_chance)
	print("  Tamaño mapa: ", map_width, "x", map_height)
