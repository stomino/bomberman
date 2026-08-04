extends TestCase


func _make_balance() -> GameBalance:
	var balance := GameBalance.new()
	balance.bomb_timer_base_ticks = 10
	balance.bomb_timer_min_ticks = 5
	balance.bomb_timer_max_ticks = 20
	balance.bomb_range_base = 2
	balance.bomb_range_min = 1
	balance.bomb_range_max = 5
	balance.explosion_duration_base_ticks = 3
	balance.explosion_duration_min_ticks = 1
	balance.explosion_duration_max_ticks = 10
	balance.explosion_damage = 1
	return balance


func test_bomb_explodes_after_configured_ticks() -> void:
	var bomb := Bomb.new(Vector2i(1, 1), 0, _make_balance())
	assert_eq(bomb.timer, 10)

	var exploded := false
	for i in range(10):
		exploded = bomb.tick_update()

	assert_true(exploded, "la bomba debería explotar en el décimo tick_update")
	assert_false(bomb.active)


func test_bomb_uses_custom_range_when_given() -> void:
	var bomb := Bomb.new(Vector2i(1, 1), 0, _make_balance(), 7)
	assert_eq(bomb.range, 7)


func test_bomb_uses_balance_range_when_no_custom_given() -> void:
	var bomb := Bomb.new(Vector2i(1, 1), 0, _make_balance())
	assert_eq(bomb.range, 2)


func test_explosion_ends_after_configured_ticks() -> void:
	var explosion := Explosion.new([Vector2i(1, 1)], _make_balance())
	assert_eq(explosion.remaining_ticks, 3)

	var ended := false
	for i in range(3):
		ended = explosion.tick_update()

	assert_true(ended)
