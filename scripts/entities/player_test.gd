extends CharacterBody2D

@export var speed: float = 200.0
var direction: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	# Obtener entrada
	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Debug: mostrar si detecta input
	if direction != Vector2.ZERO:
		print("🎮 Moviendo: ", direction)
		# Redondear a 4 direcciones
		if abs(direction.x) > abs(direction.y):
			direction = Vector2(sign(direction.x), 0)
		else:
			direction = Vector2(0, sign(direction.y))
	
	# Aplicar movimiento
	velocity = direction * speed
	move_and_slide()
