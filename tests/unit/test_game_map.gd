extends TestCase


func _make_balance() -> GameBalance:
	var balance := GameBalance.new()
	balance.map_width = 5
	balance.map_height = 5
	balance.cell_size = 32
	balance.indestructible_border = true
	balance.spawn_positions = [Vector2i(1, 1)]
	return balance


func test_border_is_indestructible_when_enabled() -> void:
	var map := GameMap.from_balance(_make_balance())
	assert_true(map.is_indestructible(0, 0), "esquina debería ser indestructible")
	assert_true(map.is_indestructible(4, 0), "borde derecho debería ser indestructible")
	assert_true(map.is_indestructible(0, 4), "borde inferior debería ser indestructible")


func test_interior_is_walkable_by_default() -> void:
	var map := GameMap.from_balance(_make_balance())
	assert_true(map.is_walkable(2, 2), "el centro debería ser caminable")


func test_out_of_bounds_is_not_walkable() -> void:
	var map := GameMap.from_balance(_make_balance())
	assert_false(map.is_walkable(-1, 2))
	assert_false(map.is_walkable(5, 2))


func test_set_cell_changes_walkability() -> void:
	var map := GameMap.from_balance(_make_balance())
	map.set_cell(2, 2, GameMap.CELL_DESTRUCTIBLE)
	assert_false(map.is_walkable(2, 2))
	assert_true(map.is_destructible(2, 2))


func test_world_grid_roundtrip() -> void:
	var map := GameMap.from_balance(_make_balance())
	var world := map.grid_to_world(3, 2)
	var back := map.world_to_grid(world)
	assert_eq(back, Vector2i(3, 2))


func test_regenerate_from_balance_clears_manual_edits() -> void:
	var map := GameMap.from_balance(_make_balance())
	map.set_cell(2, 2, GameMap.CELL_DESTRUCTIBLE)

	map.regenerate()

	assert_true(map.is_walkable(2, 2), "regenerate() debería volver al borde+vacío de siempre")


func test_from_definition_uses_definitions_own_layout() -> void:
	var def := MapDefinition.create_empty(6, 5)
	def.set_cell(2, 2, GameMap.CELL_DESTRUCTIBLE)
	def.add_spawn(Vector2i(1, 1))

	var map := GameMap.from_definition(def)

	assert_eq(map.width, 6)
	assert_eq(map.height, 5)
	assert_true(map.is_destructible(2, 2), "el mapa custom trae sus propios bloques ya pintados")
	assert_true(map.is_indestructible(0, 0), "el borde que pintó el autor del mapa se respeta")
	assert_eq(map.get_spawn_position(0), Vector2i(1, 1))


func test_from_definition_regenerate_restores_original_cells() -> void:
	var def := MapDefinition.create_empty(6, 5)
	def.set_cell(2, 2, GameMap.CELL_DESTRUCTIBLE)
	var map := GameMap.from_definition(def)

	map.set_cell(2, 2, GameMap.CELL_EMPTY)  # simula que una bomba destruyó el bloque
	assert_true(map.is_walkable(2, 2))

	map.regenerate()  # simula el reset de ronda

	assert_true(map.is_destructible(2, 2), "regenerate() debería volver al mapa tal como lo pintó su autor")
