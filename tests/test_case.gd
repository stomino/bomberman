class_name TestCase
extends RefCounted

## Clase base para tests unitarios. Sin dependencias externas: Domain y
## Systems son RefCounted puro, así que se instancian y testean directo,
## sin escena ni nodos. Ver tests/test_runner.gd para cómo se ejecutan.

var failures: Array[String] = []


func before_each() -> void:
	pass


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append("se esperaba true. " + message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		failures.append("se esperaba false. " + message)


func assert_eq(actual, expected, message: String = "") -> void:
	if actual != expected:
		failures.append("se esperaba %s, se obtuvo %s. %s" % [str(expected), str(actual), message])


func assert_ne(actual, expected, message: String = "") -> void:
	if actual == expected:
		failures.append("no se esperaba %s. %s" % [str(expected), message])


func assert_null(value, message: String = "") -> void:
	if value != null:
		failures.append("se esperaba null, se obtuvo %s. %s" % [str(value), message])


func assert_not_null(value, message: String = "") -> void:
	if value == null:
		failures.append("se esperaba un valor no nulo. " + message)
