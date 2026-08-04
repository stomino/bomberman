extends TestCase


func _make_balance(drop_chance: float, distribution: Dictionary) -> GameBalance:
	var balance := GameBalance.new()
	balance.destructible_drop_chance = drop_chance
	balance.powerup_distribution = distribution
	return balance


func test_never_spawns_when_drop_chance_is_zero() -> void:
	var balance := _make_balance(0.0, {"speed": 1.0})
	var system := PowerUpSystem.new(balance)

	system.maybe_spawn_from_destroyed_block(Vector2i(2, 2))

	assert_eq(system.powerups.size(), 0)


func test_always_spawns_configured_type_when_drop_chance_is_one() -> void:
	var balance := _make_balance(1.0, {"bomb_range": 1.0})
	var system := PowerUpSystem.new(balance)

	system.maybe_spawn_from_destroyed_block(Vector2i(2, 2))

	assert_eq(system.powerups.size(), 1)
	assert_eq(system.powerups[0].type, PowerUp.Type.BOMB_RANGE)
	assert_eq(system.powerups[0].grid_pos, Vector2i(2, 2))


func test_get_powerup_at_finds_by_position() -> void:
	var balance := _make_balance(1.0, {"shield": 1.0})
	var system := PowerUpSystem.new(balance)
	system.maybe_spawn_from_destroyed_block(Vector2i(4, 4))

	assert_not_null(system.get_powerup_at(Vector2i(4, 4)))
	assert_null(system.get_powerup_at(Vector2i(0, 0)))


func test_collect_removes_powerup() -> void:
	var balance := _make_balance(1.0, {"extra_bomb": 1.0})
	var system := PowerUpSystem.new(balance)
	system.maybe_spawn_from_destroyed_block(Vector2i(1, 1))
	var powerup := system.get_powerup_at(Vector2i(1, 1))

	system.collect(0, powerup)

	assert_eq(system.powerups.size(), 0)
	assert_null(system.get_powerup_at(Vector2i(1, 1)))
