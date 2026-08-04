# ============================================
# scripts/entities/player_logic.gd
# ============================================
# LÓGICA PURA DEL JUGADOR (SIN RENDER)
# MOVIMIENTO CON COLA DE INPUT (ESTILO BOMBERMAN)
# ============================================

class_name PlayerLogic
extends RefCounted

# --- Propiedades ---
var player_id: int
var grid_pos: Vector2i
var move_dir: Vector2i = Vector2i.ZERO
var next_dir: Vector2i = Vector2i.ZERO
var move_progress: float = 0.0
var speed_cells_per_second: float = 6.0
var is_alive: bool = true
var facing_direction: Vector2i = Vector2i.DOWN

# --- Variables de estado ---
var _is_moving: bool = false
var _has_pending_move: bool = false
var _debug_counter: int = 0

# --- Constructor ---
func _init(id: int, start_pos: Vector2i, speed: float = 6.0) -> void:
	player_id = id
	grid_pos = start_pos
	speed_cells_per_second = speed

# --- Métodos públicos ---
func set_move_direction(dir: Vector2i) -> void:
	var valid_dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	if dir == Vector2i.ZERO:
		next_dir = Vector2i.ZERO
		if GameBalance.debug_mode:
			print("[VERBOSE] [PlayerLogic] Input: NINGUNO (clear)")
		return
	
	if dir in valid_dirs:
		# ✅ Guardar dirección de cara para referencia visual (pero no para animación)
		facing_direction = dir
		
		if not _is_moving:
			move_dir = dir
			_is_moving = true
			move_progress = 0.0
			_has_pending_move = true
			next_dir = Vector2i.ZERO
			if GameBalance.debug_mode:
				print("[DEBUG] [PlayerLogic] ▶️ Iniciando movimiento hacia: ", str(dir))
		else:
			if dir != move_dir:
				next_dir = dir
				_has_pending_move = true
				if GameBalance.debug_mode:
					print("[DEBUG] [PlayerLogic] 📌 Encolando dirección: ", str(dir), " (movimiento actual: ", str(move_dir), ")")

func tick_update(delta: float, grid_manager) -> bool:
	if not _is_moving or move_dir == Vector2i.ZERO:
		return false
	
	var speed_per_tick: float = speed_cells_per_second * delta
	move_progress += speed_per_tick
	
	if move_progress >= 1.0:
		var new_pos = grid_pos + move_dir
		
		if grid_manager.is_walkable(new_pos.x, new_pos.y):
			grid_pos = new_pos
			move_progress = 0.0
			
			if GameBalance.debug_mode:
				_debug_counter += 1
				if _debug_counter % 10 == 0:
					print("[DEBUG] [PlayerLogic] 📍 Posición: ", str(grid_pos), " | Moviendo: ", str(_is_moving), " | Next: ", str(next_dir))
			
			if next_dir != Vector2i.ZERO:
				move_dir = next_dir
				next_dir = Vector2i.ZERO
				_is_moving = true
				_has_pending_move = true
				if GameBalance.debug_mode:
					print("[DEBUG] [PlayerLogic] 🔄 Continuando hacia: ", str(move_dir))
				return true
			else:
				_is_moving = false
				_has_pending_move = false
				if GameBalance.debug_mode:
					print("[DEBUG] [PlayerLogic] ⏹️ DETENIDO en celda: ", str(grid_pos))
				return true
		else:
			move_dir = Vector2i.ZERO
			next_dir = Vector2i.ZERO
			move_progress = 0.0
			_is_moving = false
			_has_pending_move = false
			if GameBalance.debug_mode:
				print("[WARNING] [PlayerLogic] 🧱 BLOQUEADO en: ", str(new_pos))
			return false
	
	return false

func clear_input() -> void:
	next_dir = Vector2i.ZERO
	_has_pending_move = false

# --- Getters ---
func is_moving() -> bool:
	return _is_moving

func has_pending_move() -> bool:
	return _has_pending_move

func get_current_cell() -> Vector2i:
	return grid_pos

func get_current_move_direction() -> Vector2i:
	"""Retorna la dirección actual del movimiento (no la encolada)"""
	return move_dir

func get_position_for_render() -> Vector2:
	var base_pos = Vector2(grid_pos) * 32 + Vector2(16, 16)
	var offset = Vector2(move_dir) * (move_progress * 32)
	return base_pos + offset

func get_move_progress() -> float:
	return move_progress

func get_facing_direction() -> Vector2i:
	"""Retorna la dirección hacia donde mira el jugador (puede ser encolada)"""
	return facing_direction

func get_move_direction() -> Vector2i:
	return move_dir

# --- Métodos de utilidad ---
func reset_to_position(pos: Vector2i) -> void:
	grid_pos = pos
	move_dir = Vector2i.ZERO
	next_dir = Vector2i.ZERO
	move_progress = 0.0
	_is_moving = false
	_has_pending_move = false

func set_speed(speed: float) -> void:
	speed_cells_per_second = speed

func apply_speed_multiplier(multiplier: float) -> void:
	speed_cells_per_second *= multiplier