extends TestCase

## Test de integración: valida que GameManager orqueste correctamente
## Player/Bomb/Explosion/PowerUp/Rondas a través de todos los systems, no
## solo que cada pieza funcione aislada.


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


func _make_manager(balance: GameBalance) -> GameManager:
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var players := PlayerSystem.new(map, balance, bombs)
	var powerups := PowerUpSystem.new(balance)
	return GameManager.new(map, players, bombs, powerups, balance)


func _add_player(manager: GameManager, id: int, pos: Vector2i) -> Player:
	var player := Player.new()
	player.id = id
	player.grid_position = pos
	manager.player_system.add_player(player)
	return player


func test_full_tick_pipeline_kills_and_respawns_player() -> void:
	var balance := _make_balance()
	var manager := _make_manager(balance)
	manager.start_match()

	var player := _add_player(manager, 0, Vector2i(3, 3))
	manager.bomb_system.place_bomb(Vector2i(3, 3), 0, balance.get_bomb_range(), balance.max_bombs_per_player)

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
	var manager := _make_manager(balance)
	manager.start_match()

	var player := _add_player(manager, 0, Vector2i(3, 3))
	var base_range := manager.player_system.get_effective_bomb_range(player)

	manager.powerup_system.maybe_spawn_from_destroyed_block(Vector2i(3, 3))  # simula un powerup ya en la celda del jugador
	assert_eq(manager.powerup_system.powerups.size(), 1)

	manager.tick()

	assert_eq(manager.powerup_system.powerups.size(), 0, "el powerup debería haberse recolectado en el tick")
	assert_eq(
		manager.player_system.get_effective_bomb_range(player),
		base_range + balance.powerups.bomb_range_bonus_per_stack,
		"el efecto del powerup debería haberse aplicado al jugador"
	)


func test_round_ends_when_one_player_remains_and_resets_state() -> void:
	var balance := _make_balance()
	balance.spawn_positions = [Vector2i(1, 1), Vector2i(5, 5)]
	var manager := _make_manager(balance)
	manager.start_match()

	var p0 := _add_player(manager, 0, Vector2i(3, 3))
	var p1 := _add_player(manager, 1, Vector2i(5, 5))

	manager.bomb_system.place_bomb(Vector2i(3, 3), 0, balance.get_bomb_range(), balance.max_bombs_per_player)  # p0 se autodestruye

	for i in range(3):  # timer = 3
		manager.tick()

	assert_true(p1.alive, "el jugador que no murió debería seguir vivo")
	assert_true(p0.alive, "debería haber revivido por el reset de ronda")
	assert_eq(p1.rounds_won, 1, "el sobreviviente gana la ronda")
	assert_eq(p0.rounds_won, 0)
	assert_eq(manager.state.round, 2, "debería haber avanzado a la ronda 2")
	assert_eq(p0.grid_position, manager.map.get_spawn_position(0))
	assert_eq(p1.grid_position, manager.map.get_spawn_position(1))
	assert_eq(manager.bomb_system.get_active_bombs_count(), 0, "las bombas deberían haberse limpiado al resetear la ronda")


func test_round_ends_in_draw_when_all_players_die_simultaneously() -> void:
	var balance := _make_balance()
	balance.bomb_range_base = 3
	balance.spawn_positions = [Vector2i(1, 1), Vector2i(5, 5)]
	var manager := _make_manager(balance)
	manager.start_match()

	var p0 := _add_player(manager, 0, Vector2i(3, 3))
	var p1 := _add_player(manager, 1, Vector2i(4, 3))  # dentro del rango de la bomba de p0

	manager.bomb_system.place_bomb(Vector2i(3, 3), 0, balance.get_bomb_range(), balance.max_bombs_per_player)

	for i in range(3):
		manager.tick()

	assert_true(p0.alive, "debería haber revivido por el reset de ronda")
	assert_true(p1.alive, "debería haber revivido por el reset de ronda")
	assert_eq(p0.rounds_won, 0, "empate técnico: nadie suma")
	assert_eq(p1.rounds_won, 0, "empate técnico: nadie suma")
	assert_eq(manager.state.round, 2, "la ronda debería haber avanzado igual")


func test_single_player_never_triggers_round_end() -> void:
	var balance := _make_balance()
	var manager := _make_manager(balance)
	manager.start_match()

	var p0 := _add_player(manager, 0, Vector2i(3, 3))
	manager.bomb_system.place_bomb(Vector2i(3, 3), 0, balance.get_bomb_range(), balance.max_bombs_per_player)

	for i in range(3):
		manager.tick()

	assert_false(p0.alive, "con un solo jugador, la muerte sigue el flujo individual (respawn_ticks), no un reset de ronda")
	assert_eq(p0.rounds_won, 0)
	assert_eq(manager.state.round, 1, "no debería haber avanzado de ronda con un solo jugador")


func test_match_ends_when_time_runs_out_and_declares_winner() -> void:
	var balance := _make_balance()
	balance.match_duration_seconds = 1
	balance.tick_rate = 10
	var manager := _make_manager(balance)
	manager.start_match()

	var p0 := _add_player(manager, 0, Vector2i(3, 3))
	var p1 := _add_player(manager, 1, Vector2i(5, 5))
	p0.rounds_won = 2
	p1.rounds_won = 1

	for i in range(10):
		manager.tick()

	assert_false(manager.state.running, "la partida debería haber terminado")
	assert_eq(manager.state.winner_id, 0, "debería ganar quien tenga más rondas")


func test_match_ends_in_tie_when_scores_are_equal() -> void:
	var balance := _make_balance()
	balance.match_duration_seconds = 1
	balance.tick_rate = 10
	var manager := _make_manager(balance)
	manager.start_match()

	var p0 := _add_player(manager, 0, Vector2i(3, 3))
	var p1 := _add_player(manager, 1, Vector2i(5, 5))
	p0.rounds_won = 1
	p1.rounds_won = 1

	for i in range(10):
		manager.tick()

	assert_false(manager.state.running)
	assert_eq(manager.state.winner_id, -1, "empate: sin ganador")


func test_tick_does_nothing_after_match_ended() -> void:
	var balance := _make_balance()
	balance.match_duration_seconds = 1
	balance.tick_rate = 10
	var manager := _make_manager(balance)
	manager.start_match()

	_add_player(manager, 0, Vector2i(3, 3))
	_add_player(manager, 1, Vector2i(5, 5))

	for i in range(10):
		manager.tick()

	assert_false(manager.state.running)
	var tick_at_end := manager.state.tick

	manager.tick()

	assert_eq(manager.state.tick, tick_at_end, "tick() no debería hacer nada una vez terminada la partida")


func test_tick_does_nothing_before_start_match() -> void:
	var balance := _make_balance()
	var manager := _make_manager(balance)
	_add_player(manager, 0, Vector2i(3, 3))

	manager.tick()

	assert_eq(manager.state.tick, 0, "tick() no debería avanzar antes de start_match()")
