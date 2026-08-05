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


func test_resize_growing_preserves_content_and_stamps_new_border() -> void:
	var def := MapDefinition.create_empty(5, 5)
	def.set_cell(2, 2, GameMap.CELL_DESTRUCTIBLE)
	def.add_spawn(Vector2i(2, 2))

	def.resize(8, 7)

	assert_eq(def.width, 8)
	assert_eq(def.height, 7)
	assert_eq(def.get_cell(2, 2), GameMap.CELL_DESTRUCTIBLE, "el contenido viejo se conserva tal cual")
	assert_true(def.has_spawn_at(Vector2i(2, 2)), "un spawn que sigue adentro de los nuevos límites se conserva")
	assert_eq(def.get_cell(5, 3), GameMap.CELL_EMPTY, "celda nueva, adentro del área agrandada")
	assert_eq(def.get_cell(0, 0), GameMap.CELL_INDESTRUCTIBLE)
	assert_eq(def.get_cell(7, 0), GameMap.CELL_INDESTRUCTIBLE, "el nuevo borde derecho debe quedar indestructible")
	assert_eq(def.get_cell(0, 6), GameMap.CELL_INDESTRUCTIBLE, "el nuevo borde inferior debe quedar indestructible")
	assert_eq(def.get_cell(4, 4), GameMap.CELL_INDESTRUCTIBLE, "el borde viejo (ahora interior) se conserva tal cual, no se auto-limpia")


func test_resize_shrinking_discards_out_of_range_content_and_spawns() -> void:
	var def := MapDefinition.create_empty(8, 7)
	def.set_cell(2, 2, GameMap.CELL_DESTRUCTIBLE)
	def.add_spawn(Vector2i(2, 2))
	def.add_spawn(Vector2i(6, 5))  # queda fuera del nuevo tamaño

	def.resize(5, 5)

	assert_eq(def.width, 5)
	assert_eq(def.height, 5)
	assert_eq(def.get_cell(2, 2), GameMap.CELL_DESTRUCTIBLE)
	assert_true(def.has_spawn_at(Vector2i(2, 2)))
	assert_false(def.has_spawn_at(Vector2i(6, 5)), "un spawn fuera del nuevo tamaño se descarta")
	assert_eq(def.get_cell(4, 4), GameMap.CELL_INDESTRUCTIBLE, "el nuevo borde inferior-derecho debe quedar indestructible")


func test_resize_drops_spawn_that_lands_on_new_border() -> void:
	var def := MapDefinition.create_empty(8, 7)
	def.add_spawn(Vector2i(4, 3))  # interior en 8x7, cae justo en el borde derecho al achicar a 5x7

	def.resize(5, 7)

	assert_false(def.has_spawn_at(Vector2i(4, 3)), "un spawn que cae sobre el borde nuevo no tiene sentido, se descarta")
