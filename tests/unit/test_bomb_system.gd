extends TestCase


func _make_balance() -> GameBalance:
	var balance := GameBalance.new()
	balance.map_width = 7
	balance.map_height = 7
	balance.cell_size = 32
	balance.indestructible_border = true
	balance.spawn_positions = [Vector2i(1, 1)]
	balance.destructible_pattern_enabled = false
	balance.bomb_timer_base_ticks = 3
	balance.bomb_timer_min_ticks = 1
	balance.bomb_timer_max_ticks = 10
	balance.bomb_range_base = 2
	balance.bomb_range_min = 1
	balance.bomb_range_max = 5
	balance.max_bombs_per_player = 1
	balance.explosion_duration_base_ticks = 2
	balance.explosion_duration_min_ticks = 1
	balance.explosion_duration_max_ticks = 10
	balance.chain_explosions = true
	balance.chain_delay_ticks = 0
	return balance


func test_place_bomb_succeeds_on_walkable_cell() -> void:
	var balance := _make_balance()
	var map := GameMap.new(balance)
	var bombs := BombSystem.new(map, balance)

	var placed := bombs.place_bomb(Vector2i(3, 3), 0)

	assert_true(placed)
	assert_eq(bombs.get_active_bombs_count(), 1)


func test_cannot_place_two_bombs_same_cell() -> void:
	var balance := _make_balance()
	var map := GameMap.new(balance)
	var bombs := BombSystem.new(map, balance)

	bombs.place_bomb(Vector2i(3, 3), 0)
	var placed_again := bombs.place_bomb(Vector2i(3, 3), 0)

	assert_false(placed_again)
	assert_eq(bombs.get_active_bombs_count(), 1)


func test_respects_max_bombs_per_player() -> void:
	var balance := _make_balance()
	var map := GameMap.new(balance)
	var bombs := BombSystem.new(map, balance)

	bombs.place_bomb(Vector2i(2, 2), 0)
	var second := bombs.place_bomb(Vector2i(3, 3), 0)

	assert_false(second, "con max_bombs_per_player = 1 no debería poder colocar una segunda")


func test_cannot_place_on_indestructible_cell() -> void:
	var balance := _make_balance()
	var map := GameMap.new(balance)
	var bombs := BombSystem.new(map, balance)

	var placed := bombs.place_bomb(Vector2i(0, 0), 0)

	assert_false(placed)


func test_explosion_destroys_destructible_block_and_stops() -> void:
	var balance := _make_balance()
	balance.bomb_range_base = 3  # suficiente para llegar a (5,3) si no se detuviera en (4,3)
	var map := GameMap.new(balance)
	map.set_cell(4, 3, GameMap.CELL_DESTRUCTIBLE)
	map.set_cell(5, 3, GameMap.CELL_DESTRUCTIBLE)
	var bombs := BombSystem.new(map, balance)
	var state := GameState.new()

	bombs.place_bomb(Vector2i(3, 3), 0)  # range 3, timer 3

	for i in range(3):
		bombs.tick(state)

	assert_true(map.is_walkable(4, 3), "el primer bloque destructible debería haberse destruido")
	assert_true(map.is_destructible(5, 3), "el segundo bloque no debería tocarse: la explosión se detiene en el primero")
	assert_eq(bombs.get_active_bombs_count(), 0)


func test_explosion_stops_at_indestructible_border() -> void:
	var balance := _make_balance()
	var map := GameMap.new(balance)
	var bombs := BombSystem.new(map, balance)
	var state := GameState.new()

	bombs.place_bomb(Vector2i(1, 3), 0)  # pegado al borde izquierdo

	for i in range(3):
		bombs.tick(state)

	assert_true(map.is_indestructible(0, 3), "el borde indestructible no debería haberse roto")


func test_chain_explosion_detonates_nearby_bomb_before_its_natural_timer() -> void:
	var balance := _make_balance()
	balance.bomb_timer_base_ticks = 5
	var map := GameMap.new(balance)
	var bombs := BombSystem.new(map, balance)
	var state := GameState.new()

	bombs.place_bomb(Vector2i(3, 3), 0)  # range 2, timer 5

	for i in range(4):
		bombs.tick(state)  # bomb1: 5 -> 1, todavía no explota

	bombs.place_bomb(Vector2i(5, 3), 1)  # dentro del rango de bomb1, timer fresco = 5

	bombs.tick(state)  # tick 5: bomb1 explota y debería forzar timer=0 en bomb2
	assert_eq(bombs.get_active_bombs_count(), 1, "bomb1 debería haber explotado; bomb2 sigue activa con timer forzado a 0")

	bombs.tick(state)  # tick 6: bomb2 debería explotar ya, mucho antes de su timer natural (~5 ticks más)
	assert_eq(bombs.get_active_bombs_count(), 0, "bomb2 debería haber explotado por reacción en cadena")
