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


func test_player_keeps_moving_across_multiple_cells_when_direction_resent_every_tick() -> void:
	"""Simula lo que hace la Presentation local (player_node.gd) y, desde
	el fix de Fase 6, también ClientRoot: reenviar la misma dirección en
	cada tick mientras la tecla sigue apretada. Cubre una regresión real
	encontrada en client_root.gd, que deduplicaba el envío del RPC y
	dejaba al jugador frenado después de cruzar una sola celda aunque
	siguiera con la tecla apretada — set_move_direction no vuelve a
	arrancar el movimiento si ya está en curso hacia la misma dirección
	(ver PlayerSystem.set_move_direction), así que hace falta que quien
	llama insista tick a tick, no una sola vez."""
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)
	var state := GameState.new()

	# tick_rate=60, speed=6.0 -> 10 ticks exactos por celda; 20 ticks
	# alcanzan para cruzar exactamente 2 celdas si el movimiento continúa.
	for i in range(20):
		system.set_move_direction(0, Vector2i.RIGHT)
		system.tick(state)

	assert_eq(player.grid_position, Vector2i(4, 2), "debería haber cruzado 2 celdas, no frenarse después de la primera")


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


func test_walking_into_bomb_without_push_ability_blocks() -> void:
	"""Empujar bombas es una habilidad, no una mecánica automática de
	movimiento (ver docs/architecture/Implementation_Decisions.md) —
	restaura el comportamiento original: sin la habilidad activa, una
	bomba bloquea exactamente igual que una pared."""
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)

	bombs.place_bomb(Vector2i(3, 2), 1, balance.get_bomb_range(), balance.max_bombs_per_player)

	system.set_move_direction(0, Vector2i.RIGHT)

	assert_false(player.is_moving, "sin la habilidad activa, una bomba debería bloquear igual que una pared")
	assert_eq(bombs.bombs[0].grid_pos, Vector2i(3, 2), "la bomba no debería haberse movido")


func test_bomb_push_ability_launches_bomb_until_it_hits_a_wall() -> void:
	"""Con la habilidad activa, caminar contra una bomba la dispara: el
	jugador avanza a la celda que deja libre, y la bomba sigue viajando
	sola varias celdas (no solo una) hasta chocar con algo colisionable."""
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)
	var state := GameState.new()

	bombs.place_bomb(Vector2i(3, 2), 1, balance.get_bomb_range(), balance.max_bombs_per_player)
	bombs.bombs[0].timer = 1000  # que no explote durante el vuelo

	assert_true(system.try_activate_bomb_push(0))
	system.set_move_direction(0, Vector2i.RIGHT)

	# tick_rate=60, speed=6.0 -> 10 ticks el paso del jugador;
	# bomb_push_launch_ticks_per_cell=5 (default) -> la bomba cruza 2
	# celdas en esos mismos 10 ticks y se frena contra el borde (mapa
	# 7x7, borde en x=6) al intentar cruzar una tercera.
	for i in range(10):
		system.tick(state)
		bombs.tick(state)

	assert_eq(player.grid_position, Vector2i(3, 2), "el jugador debería haber avanzado a la celda que ocupaba la bomba")
	assert_eq(bombs.bombs[0].grid_pos, Vector2i(5, 2), "la bomba debería haber viajado varias celdas, no solo una, hasta chocar con el borde")
	assert_false(bombs.bombs[0].is_moving, "debería haberse frenado al chocar con la pared")


func test_bomb_push_stops_when_flight_path_crosses_another_player() -> void:
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var shooter := _make_player(0, Vector2i(2, 2), balance)
	var bystander := _make_player(1, Vector2i(5, 2), balance)
	system.add_player(shooter)
	system.add_player(bystander)
	var state := GameState.new()

	bombs.place_bomb(Vector2i(3, 2), 2, balance.get_bomb_range(), balance.max_bombs_per_player)
	bombs.bombs[0].timer = 1000

	assert_true(system.try_activate_bomb_push(0))
	system.set_move_direction(0, Vector2i.RIGHT)

	for i in range(10):
		system.tick(state)
		var player_positions: Array[Vector2i] = [bystander.grid_position]
		bombs.tick(state, player_positions)

	assert_eq(bombs.bombs[0].grid_pos, Vector2i(4, 2), "debería frenarse antes de la celda donde está parado el otro jugador")


func test_bomb_push_stops_when_flight_path_crosses_another_bomb() -> void:
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)
	var state := GameState.new()

	bombs.place_bomb(Vector2i(3, 2), 1, balance.get_bomb_range(), balance.max_bombs_per_player)
	bombs.bombs[0].timer = 1000
	bombs.place_bomb(Vector2i(5, 2), 2, balance.get_bomb_range(), balance.max_bombs_per_player)
	bombs.bombs[1].timer = 1000

	assert_true(system.try_activate_bomb_push(0))
	system.set_move_direction(0, Vector2i.RIGHT)

	for i in range(10):
		system.tick(state)
		bombs.tick(state)

	assert_eq(bombs.bombs[0].grid_pos, Vector2i(4, 2), "debería frenarse antes de la celda con la otra bomba")
	assert_eq(bombs.bombs[1].grid_pos, Vector2i(5, 2), "la bomba quieta no debería haberse movido")


func test_bomb_explodes_at_current_position_if_timer_expires_mid_flight() -> void:
	var balance := _make_balance()
	balance.map_width = 15  # sin borde cerca: la única razón de frenarse es el timer
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)
	var state := GameState.new()

	bombs.place_bomb(Vector2i(3, 2), 1, balance.get_bomb_range(), balance.max_bombs_per_player)
	var bomb := bombs.bombs[0]
	bomb.timer = 7  # explota a mitad de vuelo

	assert_true(system.try_activate_bomb_push(0))
	system.set_move_direction(0, Vector2i.RIGHT)

	for i in range(10):
		system.tick(state)
		bombs.tick(state)

	assert_eq(bombs.get_active_bombs_count(), 0, "debería haber explotado")
	assert_eq(bomb.grid_pos, Vector2i(5, 2), "debería haber explotado en la celda donde estaba al llegar el timer a 0, no en una celda más lejana")


func test_bomb_push_window_is_not_consumed_by_a_single_launch() -> void:
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)

	bombs.place_bomb(Vector2i(3, 2), 1, balance.get_bomb_range(), balance.max_bombs_per_player)
	bombs.bombs[0].timer = 1000

	assert_true(system.try_activate_bomb_push(0))
	var ticks_before_launch := player.bomb_push_active_ticks_remaining

	system.set_move_direction(0, Vector2i.RIGHT)  # dispara la bomba

	assert_true(player.bomb_push_active_ticks_remaining > 0, "la ventana no debería cerrarse por haber disparado una bomba")
	assert_eq(player.bomb_push_active_ticks_remaining, ticks_before_launch, "disparar en sí no debería consumir la ventana, solo el paso del tiempo (vía tick)")


func test_bomb_push_cannot_reactivate_during_cooldown() -> void:
	var balance := _make_balance()
	balance.abilities.bomb_push_cooldown_ticks = 5
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)

	assert_true(system.try_activate_bomb_push(0))
	assert_false(system.try_activate_bomb_push(0), "no debería poder reactivarse durante el cooldown")


func test_bomb_push_can_reactivate_after_cooldown_expires() -> void:
	var balance := _make_balance()
	balance.abilities.bomb_push_window_ticks = 1
	balance.abilities.bomb_push_cooldown_ticks = 3
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)
	var state := GameState.new()

	assert_true(system.try_activate_bomb_push(0))

	for i in range(3):
		system.tick(state)

	assert_true(system.try_activate_bomb_push(0), "debería poder reactivarse una vez que el cooldown terminó")


func test_dash_does_not_launch_bombs_even_with_push_ability_active() -> void:
	var balance := _make_balance()
	balance.abilities.dash_range = 2
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	player.facing_direction = Vector2i.RIGHT
	player.dash_unlocked = true
	system.add_player(player)

	bombs.place_bomb(Vector2i(4, 2), 1, balance.get_bomb_range(), balance.max_bombs_per_player)  # celda destino del dash
	assert_true(system.try_activate_bomb_push(0))

	assert_false(system.try_dash(0), "el dash no debería disparar bombas ni con la habilidad Empujar activa, solo fallar como con cualquier obstáculo")
	assert_eq(player.grid_position, Vector2i(2, 2))
	assert_eq(bombs.bombs[0].grid_pos, Vector2i(4, 2), "la bomba no debería haberse movido")


func test_flash_does_not_launch_bombs_even_with_push_ability_active() -> void:
	var balance := _make_balance()
	balance.abilities.flash_range = 2
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	player.facing_direction = Vector2i.RIGHT
	system.add_player(player)

	bombs.place_bomb(Vector2i(4, 2), 1, balance.get_bomb_range(), balance.max_bombs_per_player)  # celda de aterrizaje
	assert_true(system.try_activate_bomb_push(0))

	assert_false(system.try_flash(0), "el flash no debería disparar bombas ni con la habilidad Empujar activa, solo fallar si la celda de aterrizaje está ocupada")
	assert_eq(player.grid_position, Vector2i(2, 2))
	assert_eq(bombs.bombs[0].grid_pos, Vector2i(4, 2))


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


func test_dash_moves_dash_range_cells_when_unlocked_and_path_clear() -> void:
	var balance := _make_balance()
	balance.abilities.dash_range = 2
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	player.facing_direction = Vector2i.RIGHT
	player.dash_unlocked = true
	system.add_player(player)
	var state := GameState.new()

	assert_true(system.try_dash(0), "el dash debería activarse con el camino libre y ya desbloqueado")

	for i in range(10):  # misma duración que un paso normal, ver _make_balance
		system.tick(state)

	assert_eq(player.grid_position, Vector2i(4, 2), "el dash debería cubrir dash_range celdas, no 1")


func test_dash_fails_when_not_unlocked() -> void:
	var balance := _make_balance()
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	player.facing_direction = Vector2i.RIGHT
	system.add_player(player)

	assert_false(system.try_dash(0), "no debería poder dashear antes de desbloquearlo")
	assert_false(player.is_moving)
	assert_eq(player.grid_position, Vector2i(2, 2))


func test_dash_respects_collision_on_intermediate_cell() -> void:
	var balance := _make_balance()
	balance.abilities.dash_range = 2
	var map := GameMap.from_balance(balance)
	map.set_cell(3, 2, GameMap.CELL_INDESTRUCTIBLE)  # celda intermedia bloqueada
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	player.facing_direction = Vector2i.RIGHT
	player.dash_unlocked = true
	system.add_player(player)

	assert_false(system.try_dash(0), "no debería dashear si la celda intermedia está bloqueada")
	assert_eq(player.grid_position, Vector2i(2, 2))


func test_dash_respects_collision_on_destination_cell() -> void:
	var balance := _make_balance()
	balance.abilities.dash_range = 2
	var map := GameMap.from_balance(balance)
	map.set_cell(4, 2, GameMap.CELL_INDESTRUCTIBLE)  # celda destino bloqueada
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	player.facing_direction = Vector2i.RIGHT
	player.dash_unlocked = true
	system.add_player(player)

	assert_false(system.try_dash(0), "no debería dashear si la celda destino está bloqueada")
	assert_eq(player.grid_position, Vector2i(2, 2))


func test_dash_range_is_configurable_and_checks_the_whole_path() -> void:
	"""dash_range es un valor de balance (config/ability_balance.json),
	no una constante hardcodeada — este test prueba explícitamente un
	rango distinto al default y confirma que se valida CADA celda del
	camino, no solo la primera y la última."""
	var balance := _make_balance()
	balance.abilities.dash_range = 4
	balance.map_width = 10  # mapa más ancho que el default: que el destino (celda 4) no coincida con el borde
	var map := GameMap.from_balance(balance)
	map.set_cell(4, 2, GameMap.CELL_INDESTRUCTIBLE)  # tercera celda del camino (de 4), ni intermedia ni destino
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	player.facing_direction = Vector2i.RIGHT
	player.dash_unlocked = true
	system.add_player(player)

	assert_false(system.try_dash(0), "debería bloquearse por una celda bloqueada en el medio del camino, no solo al inicio/fin")


func test_flash_moves_flash_range_cells_ignoring_intermediate_obstacles() -> void:
	var balance := _make_balance()
	balance.abilities.flash_range = 3
	var map := GameMap.from_balance(balance)
	map.set_cell(3, 2, GameMap.CELL_INDESTRUCTIBLE)  # celda intermedia bloqueada
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	player.facing_direction = Vector2i.RIGHT
	system.add_player(player)

	assert_true(system.try_flash(0), "el flash debería ignorar obstáculos en el camino, solo importa la celda de aterrizaje")
	assert_eq(player.grid_position, Vector2i(5, 2), "debería aterrizar exactamente a flash_range celdas, saltando la celda bloqueada del medio")


func test_flash_fails_when_landing_cell_is_blocked() -> void:
	var balance := _make_balance()
	balance.abilities.flash_range = 3
	var map := GameMap.from_balance(balance)
	map.set_cell(5, 2, GameMap.CELL_INDESTRUCTIBLE)  # celda de aterrizaje bloqueada
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	player.facing_direction = Vector2i.RIGHT
	system.add_player(player)

	assert_false(system.try_flash(0), "no debería activarse si la celda de aterrizaje está bloqueada")
	assert_eq(player.grid_position, Vector2i(2, 2))


func test_flash_fails_when_landing_cell_is_out_of_bounds() -> void:
	var balance := _make_balance()
	balance.abilities.flash_range = 10  # mapa de 7x7: se va bien afuera
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	player.facing_direction = Vector2i.RIGHT
	system.add_player(player)

	assert_false(system.try_flash(0), "no debería activarse si la celda de aterrizaje cae fuera del mapa")
	assert_eq(player.grid_position, Vector2i(2, 2))


func test_flash_is_instant_not_animated() -> void:
	var balance := _make_balance()
	balance.abilities.flash_range = 2  # mapa de 7x7: aterriza en (4,2), lejos del borde
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	player.facing_direction = Vector2i.RIGHT
	system.add_player(player)

	assert_true(system.try_flash(0))
	assert_eq(player.grid_position, Vector2i(2 + balance.abilities.flash_range, 2), "grid_position debería cambiar en el mismo tick de la llamada, sin esperar ticks de movimiento")
	assert_false(player.is_moving, "el flash no debería dejar al jugador en estado is_moving, a diferencia de Dash")


func test_flash_cannot_reactivate_during_cooldown() -> void:
	var balance := _make_balance()
	balance.abilities.flash_range = 2  # mapa de 7x7: aterriza lejos del borde
	balance.abilities.flash_cooldown_ticks = 5
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	player.facing_direction = Vector2i.RIGHT
	system.add_player(player)

	assert_true(system.try_flash(0))
	assert_false(system.try_flash(0), "no debería poder reactivarse durante el cooldown")


func test_flash_can_reactivate_after_cooldown_expires() -> void:
	var balance := _make_balance()
	balance.abilities.flash_range = 1  # mapa de 7x7: dos flashes seguidos sin salir de los límites
	balance.abilities.flash_cooldown_ticks = 3
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	player.facing_direction = Vector2i.RIGHT
	system.add_player(player)
	var state := GameState.new()

	assert_true(system.try_flash(0))

	for i in range(3):
		system.tick(state)

	assert_true(system.try_flash(0), "debería poder reactivarse una vez que el cooldown terminó")


func test_ability_unlock_progress_marks_dash_unlocked_at_configured_tick() -> void:
	var balance := _make_balance()
	balance.abilities.dash_unlock_ticks = 3
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)
	var state := GameState.new()

	for i in range(2):
		system.tick(state)
	assert_false(player.dash_unlocked, "todavía no debería estar desbloqueado")

	system.tick(state)
	assert_true(player.dash_unlocked, "debería desbloquearse exactamente al llegar a dash_unlock_ticks")


func test_effective_speed_unaffected_by_ability_bonus_until_activated() -> void:
	var balance := _make_balance()
	balance.abilities.speed_ability_bonus = 0.5
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)

	assert_eq(system.get_effective_speed(player), 6.0, "sin activar la ráfaga, la velocidad es solo la base")


func test_speed_boost_applies_bonus_while_active_and_expires() -> void:
	var balance := _make_balance()
	balance.abilities.speed_ability_bonus = 0.5
	balance.abilities.speed_boost_duration_ticks = 2
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)
	var state := GameState.new()

	assert_true(system.try_activate_speed_boost(0))
	assert_eq(system.get_effective_speed(player), 9.0, "6.0 base * (1 + 0.5 de la habilidad) = 9.0 mientras está activa")

	system.tick(state)
	system.tick(state)

	assert_eq(system.get_effective_speed(player), 6.0, "debería haber vuelto a la base tras speed_boost_duration_ticks")


func test_speed_boost_cannot_reactivate_during_cooldown() -> void:
	var balance := _make_balance()
	balance.abilities.speed_boost_duration_ticks = 1
	balance.abilities.speed_boost_cooldown_ticks = 5
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)
	var state := GameState.new()

	assert_true(system.try_activate_speed_boost(0))
	system.tick(state)  # termina la duración, el cooldown sigue corriendo

	assert_false(system.try_activate_speed_boost(0), "no debería poder reactivarse durante el cooldown")


func test_speed_boost_can_reactivate_after_cooldown_expires() -> void:
	var balance := _make_balance()
	balance.abilities.speed_boost_duration_ticks = 1
	balance.abilities.speed_boost_cooldown_ticks = 3
	var map := GameMap.from_balance(balance)
	var bombs := BombSystem.new(map, balance)
	var system := PlayerSystem.new(map, balance, bombs)
	var player := _make_player(0, Vector2i(2, 2), balance)
	system.add_player(player)
	var state := GameState.new()

	assert_true(system.try_activate_speed_boost(0))

	for i in range(3):
		system.tick(state)

	assert_true(system.try_activate_speed_boost(0), "debería poder reactivarse una vez que el cooldown terminó")
