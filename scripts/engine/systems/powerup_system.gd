class_name PowerUpSystem
extends RefCounted

var balance: GameBalance

var powerups: Array[PowerUp] = []

signal powerup_spawned(pos: Vector2i, type: PowerUp.Type)
signal powerup_collected(player_id: int, pos: Vector2i, type: PowerUp.Type)


func _init(game_balance: GameBalance) -> void:
	balance = game_balance


func maybe_spawn_from_destroyed_block(pos: Vector2i) -> void:
	"""Se conecta a BombSystem.block_destroyed desde GameRoot (evento, no
	referencia directa entre systems). Tira los dados con la config base
	de GameBalance (drop_chance, distribución) — el balance de qué hace
	cada tipo vive aparte, en PowerUpBalance."""
	if randf() > balance.destructible_drop_chance:
		return

	var type := PowerUp.type_from_key(balance.get_random_powerup_type())
	if type == PowerUp.Type.NONE:
		return

	var powerup := PowerUp.new(pos, type)
	powerups.append(powerup)
	powerup_spawned.emit(pos, type)
	GameLogger.debug("PowerUp %s apareció en %s" % [PowerUp.type_to_string(type), str(pos)], "PowerUpSystem")


func get_powerup_at(pos: Vector2i) -> PowerUp:
	for p in powerups:
		if p.grid_pos == pos:
			return p
	return null


func collect(player_id: int, powerup: PowerUp) -> void:
	powerups.erase(powerup)
	powerup_collected.emit(player_id, powerup.grid_pos, powerup.type)
