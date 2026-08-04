class_name GameLogger
extends RefCounted

## Logger de desarrollo, silencioso salvo que se active explícitamente.
## Utilidad de infraestructura pura (no gameplay): mantiene su propio flag
## static en vez de depender de GameBalance, para no acoplar el logging a
## la configuración de balance del juego.

static var enabled: bool = false


static func set_enabled(value: bool) -> void:
	enabled = value
	print("🔧 Modo Debug: ", "ON" if enabled else "OFF")


static func toggle_enabled() -> void:
	set_enabled(!enabled)


static func debug(message: String, context: String = "") -> void:
	_log("DEBUG", message, context)


static func info(message: String, context: String = "") -> void:
	_log("INFO", message, context)


static func warning(message: String, context: String = "") -> void:
	_log("WARNING", message, context)


static func error(message: String, context: String = "") -> void:
	_log("ERROR", message, context)


static func verbose(message: String, context: String = "") -> void:
	_log("VERBOSE", message, context)


static func _log(level: String, message: String, context: String) -> void:
	if not enabled:
		return
	var prefix = "[%s]" % level
	if context != "":
		prefix += " [%s]" % context
	print("%s %s" % [prefix, message])
