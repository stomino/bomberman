extends TestCase

## Test de integración: valida que GameManager orqueste correctamente
## Player/Bomb/Explosion a través de los tres systems, no solo que cada
## pieza funcione aislada.


func _make_balance() -> GameBalance:
	var balance := GameBalance.new()
	balance.map_width = 7
	balance.map_height = 7
	balance.cell_size = 32
	balance.indestructible_border = true
	balance.spawn_positions = [Vector2i(1, 1)]
	balance.destructible_pattern_enabled = false
	balance.base_speed_cells_per_second = 6.0
	balance.tick_rate = 60
	balance.respawn_ticks = 5
	balance.max_bombs_per_player = 1
	balance.bomb_timer_base_ticks = 3
	balance.bomb_timer_min_ticks = 1
	balance.bomb_timer_max_ticks = 10
	balance.bomb_range_base = 2
	balance.bomb_range_min = 1
	balance.bomb_range_max = 5
	balance.explosion_duration_base_ticks = 2
	balance.explosion_duration_min_ticks = 1
	balance.explosion_duration_max_ticks = 10
	return balance


func test_full_tick_pipeline_kills_and_respawns_player() -> void:
	var balance := _make_balance()
	var map := GameMap.new(balance)
	var bombs := BombSystem.new(map, balance)
	var players := PlayerSystem.new(map, balance, bombs)
	var manager := GameManager.new(map, players, bombs)

	var player := Player.new()
	player.id = 0
	player.grid_position = Vector2i(3, 3)
	player.speed = balance.get_speed_for_character()
	players.add_player(player)

	bombs.place_bomb(Vector2i(3, 3), 0)

	for i in range(3):
		manager.tick()

	assert_false(player.alive, "GameManager.tick() debería coordinar bomba->explosión->daño en un solo paso")

	for i in range(balance.respawn_ticks):
		manager.tick()

	assert_true(player.alive, "debería haber respawneado tras respawn_ticks")
	assert_eq(manager.state.tick, 3 + balance.respawn_ticks)
