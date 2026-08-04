extends TestCase


func test_loads_defaults_from_config_file() -> void:
	var powerups := PowerUpBalance.load_from_file()

	assert_true(powerups.speed_bonus_per_stack > 0.0)
	assert_true(powerups.speed_max_stacks > 0)
	assert_true(powerups.bomb_range_bonus_per_stack > 0)
	assert_true(powerups.bomb_range_max_stacks > 0)
	assert_true(powerups.extra_bomb_bonus_per_stack > 0)
	assert_true(powerups.extra_bomb_max_stacks > 0)
	assert_true(powerups.shield_duration_ticks > 0)


func test_instance_has_sane_defaults_without_loading() -> void:
	var powerups := PowerUpBalance.new()

	assert_true(powerups.speed_max_stacks >= 1)
	assert_true(powerups.bomb_range_max_stacks >= 1)
	assert_true(powerups.extra_bomb_max_stacks >= 1)


func test_game_balance_composes_powerup_balance_on_load() -> void:
	var balance := GameBalance.load_from_file()

	assert_not_null(balance.powerups)
	assert_true(balance.powerups.speed_max_stacks > 0)
