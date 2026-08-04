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
	var powerups := PowerUpSystem.new(balance)
	var manager := GameManager.new(map, players, bombs, powerups)

	var player := Player.new()
	player.id = 0
	player.grid_position = Vector2i(3, 3)
	players.add_player(player)

	bombs.place_bomb(Vector2i(3, 3), 0, balance.get_bomb_range(), balance.max_bombs_per_player)

	for i in range(3):
		manager.tick()

	assert_false(player.alive, "GameManager.tick() debería coordinar bomba->explosión->daño en un solo paso")

	for i in range(balance.respawn_ticks):
		manager.tick()

	assert_true(player.alive, "debería haber respawneado tras respawn_ticks")
	assert_eq(manager.state.tick, 3 + balance.respawn_ticks)


func test_player_picks_up_powerup_via_full_tick_pipeline() -> void:
	var balance := _make_balance()
	balance.destructible_drop_chance = 1.0
	balance.powerup_distribution = {"bomb_range": 1.0}  # determinístico: siempre bomb_range
	var map := GameMap.new(balance)
	var bombs := BombSystem.new(map, balance)
	var players := PlayerSystem.new(map, balance, bombs)
	var powerups := PowerUpSystem.new(balance)
	var manager := GameManager.new(map, players, bombs, powerups)

	var player := Player.new()
	player.id = 0
	player.grid_position = Vector2i(3, 3)
	players.add_player(player)

	var base_range := players.get_effective_bomb_range(player)

	powerups.maybe_spawn_from_destroyed_block(Vector2i(3, 3))  # simula un powerup ya en la celda del jugador
	assert_eq(powerups.powerups.size(), 1)

	manager.tick()

	assert_eq(powerups.powerups.size(), 0, "el powerup debería haberse recolectado en el tick")
	assert_eq(
		players.get_effective_bomb_range(player),
		base_range + balance.powerups.bomb_range_bonus_per_stack,
		"el efecto del powerup debería haberse aplicado al jugador"
	)
