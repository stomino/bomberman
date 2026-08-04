extends TestCase


func test_create_empty_has_indestructible_border_and_empty_interior() -> void:
	var def := MapDefinition.create_empty(5, 5)

	assert_eq(def.get_cell(0, 0), GameMap.CELL_INDESTRUCTIBLE)
	assert_eq(def.get_cell(4, 0), GameMap.CELL_INDESTRUCTIBLE)
	assert_eq(def.get_cell(0, 4), GameMap.CELL_INDESTRUCTIBLE)
	assert_eq(def.get_cell(2, 2), GameMap.CELL_EMPTY)


func test_add_and_remove_spawn() -> void:
	var def := MapDefinition.create_empty(5, 5)

	def.add_spawn(Vector2i(2, 2))
	assert_true(def.has_spawn_at(Vector2i(2, 2)))
	assert_eq(def.spawn_positions.size(), 1)

	def.add_spawn(Vector2i(2, 2))  # duplicado, no debería agregarse dos veces
	assert_eq(def.spawn_positions.size(), 1)

	def.remove_spawn(Vector2i(2, 2))
	assert_false(def.has_spawn_at(Vector2i(2, 2)))


func test_save_and_load_round_trip() -> void:
	var def := MapDefinition.create_empty(6, 5)
	def.map_name = "Mapa de prueba"
	def.set_cell(2, 2, GameMap.CELL_DESTRUCTIBLE)
	def.set_cell(3, 2, GameMap.CELL_INDESTRUCTIBLE)
	def.add_spawn(Vector2i(1, 1))
	def.add_spawn(Vector2i(4, 3))

	var path := "user://test_map_round_trip.json"
	assert_true(def.save_to_file(path))

	var loaded := MapDefinition.load_from_file(path)

	assert_not_null(loaded)
	assert_eq(loaded.map_name, "Mapa de prueba")
	assert_eq(loaded.width, 6)
	assert_eq(loaded.height, 5)
	assert_eq(loaded.get_cell(2, 2), GameMap.CELL_DESTRUCTIBLE)
	assert_eq(loaded.get_cell(3, 2), GameMap.CELL_INDESTRUCTIBLE)
	assert_eq(loaded.get_cell(0, 0), GameMap.CELL_INDESTRUCTIBLE, "el borde original debería conservarse")
	assert_true(loaded.has_spawn_at(Vector2i(1, 1)))
	assert_true(loaded.has_spawn_at(Vector2i(4, 3)))

	DirAccess.remove_absolute(path)


func test_load_from_missing_file_returns_null() -> void:
	var loaded := MapDefinition.load_from_file("user://este_mapa_no_existe.json")
	assert_null(loaded)
