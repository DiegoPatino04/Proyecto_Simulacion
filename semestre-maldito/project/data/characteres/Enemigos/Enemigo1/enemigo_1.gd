extends CharacterBody2D
@export var animation: Node
@onready var animated_sprite_2d = $AnimatedSprite2D

func _ready():
	
	animation.play("Idle_Enemy")

	move_and_slide()
