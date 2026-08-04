# ============================================
# scripts/utils/logger.gd
# ============================================
# LOGGER SIMPLE - SOLO FUNCIONA EN MODO DEBUG
# ============================================

class_name Logger
extends RefCounted

# ============================================
# MÉTODOS DE LOG (SOLO EN MODO DEBUG)
# ============================================

static func debug(message: String, context: String = "") -> void:
	if GameBalance.debug_mode:
		var prefix = "[DEBUG]"
		if context != "":
			prefix += " [%s]" % context
		print("%s %s" % [prefix, message])

static func info(message: String, context: String = "") -> void:
	if GameBalance.debug_mode:
		var prefix = "[INFO]"
		if context != "":
			prefix += " [%s]" % context
		print("%s %s" % [prefix, message])

static func warning(message: String, context: String = "") -> void:
	if GameBalance.debug_mode:
		var prefix = "[WARNING]"
		if context != "":
			prefix += " [%s]" % context
		print("%s %s" % [prefix, message])

static func error(message: String, context: String = "") -> void:
	if GameBalance.debug_mode:
		var prefix = "[ERROR]"
		if context != "":
			prefix += " [%s]" % context
		print("%s %s" % [prefix, message])

static func verbose(message: String, context: String = "") -> void:
	if GameBalance.debug_mode:
		var prefix = "[VERBOSE]"
		if context != "":
			prefix += " [%s]" % context
		print("%s %s" % [prefix, message])  