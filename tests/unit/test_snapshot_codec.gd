extends TestCase

## Round-trip: serializar un estado con jugador/bomba/explosión/powerup/
## mapa y aplicarlo sobre contenedores vacíos debería reproducir los
## mismos valores — es exactamente lo que ClientRoot hace en cada
## snapshot recibido del servidor.

var balance: GameBalance

var source_map: GameMap
var source_players: PlayerSystem
var source_bombs: BombSystem
var source_powerups: PowerUpSystem
var source_state: GameState

var target_map: GameMap
var target_players: PlayerSystem
var target_bombs: BombSystem
var target_powerups: PowerUpSystem
var target_state: GameState


func before_each() -> void:
	balance = GameBalance.new()
	balance.map_width = 5
	balance.map_height = 5
	balance.cell_size = 32
	balance.indestructible_border = true
	balance.spawn_positions = [Vector2i(1, 1)]
	balance.destructible_pattern_enabled = false

	source_map = GameMap.from_balance(balance)
	source_map.set_cell(2, 2, GameMap.CELL_DESTRUCTIBLE)
	source_bombs = BombSystem.new(source_map, balance, false)
	source_players = PlayerSystem.new(source_map, balance, source_bombs)
	source_powerups = PowerUpSystem.new(balance)
	source_state = GameState.new()
	source_state.tick = 42
	source_state.running = true
	source_state.round = 2
	source_state.winner_id = -1

	var player := Player.new()
	player.id = 7
	player.grid_position = Vector2i(3, 3)
	player.alive = true
	player.move_direction = Vector2i.RIGHT
	player.move_ticks_elapsed = 4
	player.move_ticks_total = 10
	player.facing_direction = Vector2i.RIGHT
	player.shield_ticks_remaining = 12
	player.rounds_won = 1
	source_players.add_player(player)

	var explosion_cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2)]
	var bomb := Bomb.new(Vector2i(2, 2), 7, balance, 3)
	# Empujar bombas: mid-empuje, mismo patrón que el jugador de arriba —
	# confirma que el round-trip también reproduce una bomba a mitad de
	# deslizamiento, no solo el caso estático.
	bomb.move_direction = Vector2i.DOWN
	bomb.move_ticks_total = 10
	bomb.move_ticks_elapsed = 6
	bomb.is_moving = true
	source_bombs.bombs.append(bomb)
	source_bombs.explosions.append(Explosion.new(explosion_cells, balance))
	source_powerups.powerups.append(PowerUp.new(Vector2i(4, 4), PowerUp.Type.SHIELD))

	target_map = GameMap.new()
	target_bombs = BombSystem.new(target_map, balance, false)
	target_players = PlayerSystem.new(target_map, balance, target_bombs)
	target_powerups = PowerUpSystem.new(balance)
	target_state = GameState.new()


func _apply_snapshot() -> void:
	var data := SnapshotCodec.serialize(source_state, source_players, source_bombs, source_powerups, source_map)
	SnapshotCodec.apply(data, target_state, target_players, target_bombs, target_powerups, target_map)


func test_round_trip_reproduces_match_state() -> void:
	_apply_snapshot()

	assert_eq(target_state.tick, 42)
	assert_eq(target_state.running, true)
	assert_eq(target_state.round, 2)
	assert_eq(target_state.winner_id, -1)


func test_round_trip_reproduces_player_fields() -> void:
	_apply_snapshot()

	var player: Player = target_players.get_player(7)
	assert_not_null(player, "el jugador 7 debería existir del lado del cliente tras aplicar el snapshot")
	assert_eq(player.grid_position, Vector2i(3, 3))
	assert_eq(player.move_direction, Vector2i.RIGHT)
	assert_eq(player.move_ticks_elapsed, 4)
	assert_eq(player.move_ticks_total, 10)
	assert_eq(player.shield_ticks_remaining, 12)
	assert_eq(player.rounds_won, 1)


func test_round_trip_reproduces_bombs_explosions_and_powerups() -> void:
	_apply_snapshot()

	assert_eq(target_bombs.bombs.size(), 1)
	assert_eq(target_bombs.bombs[0].grid_pos, Vector2i(2, 2))
	assert_eq(target_bombs.bombs[0].owner_id, 7)
	assert_eq(target_bombs.bombs[0].range, 3)
	assert_eq(target_bombs.bombs[0].move_direction, Vector2i.DOWN)
	assert_eq(target_bombs.bombs[0].move_ticks_total, 10)
	assert_eq(target_bombs.bombs[0].move_ticks_elapsed, 6)
	assert_eq(target_bombs.bombs[0].is_moving, true)

	assert_eq(target_bombs.explosions.size(), 1)
	assert_eq(target_bombs.explosions[0].cells, [Vector2i(1, 1), Vector2i(1, 2)] as Array[Vector2i])

	assert_eq(target_powerups.powerups.size(), 1)
	assert_eq(target_powerups.powerups[0].type, PowerUp.Type.SHIELD)


func test_round_trip_reproduces_map_dimensions_and_grid() -> void:
	_apply_snapshot()

	assert_eq(target_map.width, 5)
	assert_eq(target_map.height, 5)
	assert_eq(target_map.cell_size, 32)
	assert_eq(target_map.get_cell(2, 2), GameMap.CELL_DESTRUCTIBLE)


func test_apply_removes_players_no_longer_in_snapshot() -> void:
	var stale_player := Player.new()
	stale_player.id = 99
	target_players.add_player(stale_player)

	_apply_snapshot()

	assert_null(target_players.get_player(99), "un jugador que ya no está en el snapshot debería sacarse del espejo del cliente")
	assert_not_null(target_players.get_player(7))
