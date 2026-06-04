extends CharacterBody2D

@export var animation: Node
@export var area_2D: Node

const speed = 100

var ultima_direccion = "abajo"

func _ready() -> void:
	area_2D.body_entered.connect(_on_area_2d_body_entered)

func _physics_process(delta: float) -> void:

	velocity = Vector2.ZERO

	if Input.is_action_pressed("Arriba"):
		velocity.y = -speed
		ultima_direccion = "arriba"
		animation.play("Caminar pa Arriba")

	elif Input.is_action_pressed("Abajo"):
		velocity.y = speed
		ultima_direccion = "abajo"
		animation.play("Caminar pa Abajo")

	elif Input.is_action_pressed("Izquierda"):
		velocity.x = -speed
		ultima_direccion = "izquierda"
		animation.play("Caminar pa la Izquierda")

	elif Input.is_action_pressed("Derecha"):
		velocity.x = speed
		ultima_direccion = "derecha"
		animation.play("Caminar pa la Derecha")

	else:
		match ultima_direccion:
			"arriba":
				animation.play("Idle Mirando Arriba")
			"abajo":
				animation.play("Idle Mirando Abajo")
			"izquierda":
				animation.play("Idle Mirando Izquierda")
			"derecha":
				animation.play("Idle Mirando Derecha")

	move_and_slide()
	
func _on_area_2d_body_entered(body: Node2D) -> void:
	pass
	
