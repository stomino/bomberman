extends SceneTree

## Ejecuta todos los tests en tests/unit/*.gd sin abrir el editor ni una
## escena. Uso:
##   godot --headless --path . -s tests/test_runner.gd
## Sale con código 1 si algún test falla (para CI), 0 si todos pasan.


func _init() -> void:
	quit(run_tests())


func run_tests() -> int:
	var test_files := _discover_test_files("res://tests/unit")
	var total_passed := 0
	var total_failed := 0
	var failure_details: Array[String] = []

	for path in test_files:
		var script: GDScript = load(path)
		var probe = script.new()
		var test_methods := _get_test_method_names(probe)

		for method_name in test_methods:
			var instance = script.new()
			if instance.has_method("before_each"):
				instance.before_each()
			instance.call(method_name)

			var label := "%s :: %s" % [path.get_file(), method_name]

			if instance.failures.is_empty():
				total_passed += 1
				print("  [OK]   " + label)
			else:
				total_failed += 1
				print("  [FAIL] " + label)
				for f in instance.failures:
					failure_details.append("%s -> %s" % [label, f])

	print("")
	print("Resultado: %d passed, %d failed" % [total_passed, total_failed])

	if not failure_details.is_empty():
		print("\nDetalle de fallas:")
		for d in failure_details:
			print("  - " + d)

	return 1 if total_failed > 0 else 0


func _discover_test_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)

	if dir == null:
		push_error("No se pudo abrir: " + dir_path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			result.append(dir_path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	result.sort()
	return result


func _get_test_method_names(instance) -> Array[String]:
	var names: Array[String] = []
	for m in instance.get_method_list():
		var method_name: String = m.get("name", "")
		if method_name.begins_with("test_"):
			names.append(method_name)
	names.sort()
	return names
