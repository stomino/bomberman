extends TestCase


func test_loads_defaults_from_config_file() -> void:
	var abilities := AbilityBalance.load_from_file()

	assert_true(abilities.speed_ability_bonus > 0.0)
	# dash_unlock_ticks = 0 en config/ability_balance.json a propósito: por
	# ahora todas las habilidades están disponibles desde el arranque de la
	# partida (ver docs/architecture/Implementation_Decisions.md) — el
	# mecanismo de desbloqueo por tiempo sigue existiendo, solo neutralizado.
	assert_eq(abilities.dash_unlock_ticks, 0)
	assert_true(abilities.flash_range > 0)
	assert_true(abilities.flash_cooldown_ticks > 0)


func test_instance_has_sane_defaults_without_loading() -> void:
	var abilities := AbilityBalance.new()

	assert_true(abilities.speed_ability_bonus >= 0.0)
	# A diferencia de la config del juego (ver arriba), el default en
	# GDScript sin cargar archivo sigue siendo > 0 — es el mecanismo
	# original, no lo tocamos, solo lo neutralizamos vía config.
	assert_true(abilities.dash_unlock_ticks > 0)
	assert_true(abilities.flash_range > 0)
	assert_true(abilities.flash_cooldown_ticks > 0)


func test_game_balance_composes_ability_balance_on_load() -> void:
	var balance := GameBalance.load_from_file()

	assert_not_null(balance.abilities)
	assert_eq(balance.abilities.dash_unlock_ticks, 0)
