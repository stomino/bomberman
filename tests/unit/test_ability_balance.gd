extends TestCase


func test_loads_defaults_from_config_file() -> void:
	var abilities := AbilityBalance.load_from_file()

	assert_true(abilities.speed_ability_bonus > 0.0)
	assert_true(abilities.dash_unlock_ticks > 0)


func test_instance_has_sane_defaults_without_loading() -> void:
	var abilities := AbilityBalance.new()

	assert_true(abilities.speed_ability_bonus >= 0.0)
	assert_true(abilities.dash_unlock_ticks > 0)


func test_game_balance_composes_ability_balance_on_load() -> void:
	var balance := GameBalance.load_from_file()

	assert_not_null(balance.abilities)
	assert_true(balance.abilities.dash_unlock_ticks > 0)
