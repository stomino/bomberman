extends TestCase


func _make_balance() -> GameBalance:
	var balance := GameBalance.new()
	balance.map_width = 7
	balance.map_height = 7
	balance.cell_size = 32
	balance.indestructible_border = true
	balance.spawn_positions = [Vector2i(1, 1), Vector2i(5, 5)]
	balance.destructible_pattern_enabled = false
	balance.base_speed_cells_per_second = 6.0
	balance.speed_multiplier_global = 1.0
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


func _make_player(id: int, pos: Vector2i, _balance: GameBalance) -> Player:
	var player := Player.new()
	player.id = id
	player.grid_position = pos
	return player


func test_player_moves_one_cell_after_ticks_for_speed() -> void:
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)
	var state := GameState.new()

	system.set_move_direction(0, Vector2i.RIGHT)

	# tick_rate=60, speed=6.0 -> 10 ticks exactos por celda
	for i in range(9):
		system.tick(state)
	assert_eq(player.grid_position, Vector2i(2, 2), "todavía no debería haber cruzado la celda")

	system.tick(state)
	assert_eq(player.grid_position, Vector2i(3, 2), "debería cruzar a la celda siguiente en el décimo tick")


func test_player_cannot_move_into_wall() -> void:
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(1, 1), balance)  # esquina: arriba/izquierda son borde
	system.add_player(player)

	system.set_move_direction(0, Vector2i.UP)

	assert_false(player.is_moving, "no debería empezar a moverse hacia una pared")
	assert_eq(player.facing_direction, Vector2i.UP, "debería quedar mirando hacia la pared igual")


func test_player_cannot_move_into_bomb_cell() -> void:
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)

	bombs.place_bomb(Vector2i(3, 2), 1, balance.get_bomb_range(), balance.max_bombs_per_player)

	system.set_move_direction(0, Vector2i.RIGHT)

	assert_false(player.is_moving, "no debería poder caminar sobre una celda con bomba")


func test_player_dies_when_standing_in_explosion() -> void:
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(3, 3), balance)
	system.add_player(player)
	var state := GameState.new()

	bombs.place_bomb(Vector2i(3, 3), 0, balance.get_bomb_range(), balance.max_bombs_per_player)

	for i in range(3):  # timer = 3
		state.tick += 1
		system.tick(state)
		bombs.tick(state)
		system.apply_explosion_damage(bombs.get_danger_cells(), state.tick)

	assert_false(player.alive, "debería haber muerto por su propia explosión")
	assert_true(player.respawn_at_tick > state.tick)


func test_player_respawns_after_respawn_ticks() -> void:
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(3, 3), balance)
	system.add_player(player)
	var state := GameState.new()

	bombs.place_bomb(Vector2i(3, 3), 0, balance.get_bomb_range(), balance.max_bombs_per_player)

	while player.alive:
		state.tick += 1
		system.tick(state)
		bombs.tick(state)
		system.apply_explosion_damage(bombs.get_danger_cells(), state.tick)

	while state.tick < player.respawn_at_tick:
		state.tick += 1
		system.apply_explosion_damage(bombs.get_danger_cells(), state.tick)

	assert_true(player.alive, "debería haber respawneado")
	assert_eq(player.grid_position, map.get_spawn_position(player.id))


func test_effective_speed_increases_with_speed_stacks() -> void:
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)

	var base_speed := system.get_effective_speed(player)

	system.apply_powerup(0, PowerUp.Type.SPEED)

	assert_true(system.get_effective_speed(player) > base_speed, "un powerup de velocidad debería aumentar la velocidad efectiva")


func test_powerup_stacks_are_capped_at_max_stacks() -> void:
	var balance := _make_balance()
	balance.powerups.speed_max_stacks = 2
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)

	for i in range(5):
		system.apply_powerup(0, PowerUp.Type.SPEED)

	assert_eq(player.speed_powerup_stacks, 2, "no debería poder acumular más del máximo configurado")


func test_effective_bomb_range_and_max_bombs_increase_with_powerups() -> void:
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)

	var base_range := system.get_effective_bomb_range(player)
	var base_max_bombs := system.get_effective_max_bombs(player)

	system.apply_powerup(0, PowerUp.Type.BOMB_RANGE)
	system.apply_powerup(0, PowerUp.Type.EXTRA_BOMB)

	assert_eq(system.get_effective_bomb_range(player), base_range + balance.powerups.bomb_range_bonus_per_stack)
	assert_eq(system.get_effective_max_bombs(player), base_max_bombs + balance.powerups.extra_bomb_bonus_per_stack)


func test_shield_prevents_death_from_explosion() -> void:
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(3, 3), balance)
	system.add_player(player)
	var state := GameState.new()

	system.apply_powerup(0, PowerUp.Type.SHIELD)
	bombs.place_bomb(Vector2i(3, 3), 0, balance.get_bomb_range(), balance.max_bombs_per_player)

	for i in range(3):
		state.tick += 1
		system.tick(state)
		bombs.tick(state)
		system.apply_explosion_damage(bombs.get_danger_cells(), state.tick)

	assert_true(player.alive, "el escudo debería haber evitado la muerte")


func test_shield_expires_after_its_duration() -> void:
	var balance := _make_balance()
	balance.powerups.shield_duration_ticks = 2
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(3, 3), balance)
	system.add_player(player)
	var state := GameState.new()

	system.apply_powerup(0, PowerUp.Type.SHIELD)

	for i in range(2):
		state.tick += 1
		system.tick(state)

	assert_false(system.is_shielded(player), "el escudo debería haberse agotado tras shield_duration_ticks")


func test_respawn_grants_temporary_invulnerability() -> void:
	var balance := _make_balance()
	balance.spawn_invulnerability_ticks = 999
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(3, 3), balance)
	system.add_player(player)
	var state := GameState.new()

	bombs.place_bomb(Vector2i(3, 3), 0, balance.get_bomb_range(), balance.max_bombs_per_player)

	while player.alive:
		state.tick += 1
		system.tick(state)
		bombs.tick(state)
		system.apply_explosion_damage(bombs.get_danger_cells(), state.tick)

	while state.tick < player.respawn_at_tick:
		state.tick += 1
		system.apply_explosion_damage(bombs.get_danger_cells(), state.tick)

	assert_true(player.alive)
	assert_true(system.is_shielded(player), "debería tener invulnerabilidad de spawn recién respawneado")
