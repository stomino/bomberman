extends TestCase

## Valida que GameManager.queue_command() aplique los Commands al inicio
## del siguiente tick — es el pipeline que usan tanto GameRoot (sandbox
## local) como ServerRoot (servidor de red) para aplicar input.


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
	balance.max_bombs_per_player = 1
	balance.bomb_timer_base_ticks = 5
	balance.bomb_timer_min_ticks = 1
	balance.bomb_timer_max_ticks = 10
	balance.bomb_range_base = 2
	balance.bomb_range_min = 1
	balance.bomb_range_max = 5
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


func test_move_command_is_not_applied_until_next_tick() -> void:
	var balance := _make_balance()
	var manager := _make_manager(balance)
	manager.start_match()
	var player := _add_player(manager, 0, Vector2i(3, 3))

	manager.queue_command(MoveCommand.new(0, Vector2i.RIGHT))
	assert_false(player.is_moving, "el Command no debería aplicarse antes del próximo tick")

	manager.tick()

	assert_true(player.is_moving, "el Command encolado debería aplicarse al procesar el tick")
	assert_eq(player.move_direction, Vector2i.RIGHT)


func test_place_bomb_command_places_bomb_at_player_position() -> void:
	var balance := _make_balance()
	var manager := _make_manager(balance)
	manager.start_match()
	_add_player(manager, 0, Vector2i(3, 3))

	manager.queue_command(PlaceBombCommand.new(0))
	manager.tick()

	assert_eq(manager.bomb_system.get_active_bombs_count(), 1, "el PlaceBombCommand debería haber colocado una bomba")
	assert_eq(manager.bomb_system.bombs[0].grid_pos, Vector2i(3, 3))
	assert_eq(manager.bomb_system.bombs[0].owner_id, 0)


func test_place_bomb_command_ignores_dead_player() -> void:
	var balance := _make_balance()
	var manager := _make_manager(balance)
	manager.start_match()
	var player := _add_player(manager, 0, Vector2i(3, 3))
	player.alive = false

	manager.queue_command(PlaceBombCommand.new(0))
	manager.tick()

	assert_eq(manager.bomb_system.get_active_bombs_count(), 0, "no debería poder colocar bomba estando muerto")


func test_pending_commands_are_cleared_after_tick() -> void:
	var balance := _make_balance()
	var manager := _make_manager(balance)
	manager.start_match()
	_add_player(manager, 0, Vector2i(3, 3))

	manager.queue_command(PlaceBombCommand.new(0))
	manager.tick()
	manager.tick()  # sin nuevos commands encolados

	assert_eq(manager.bomb_system.get_active_bombs_count(), 1, "no debería duplicar la bomba en el segundo tick")
