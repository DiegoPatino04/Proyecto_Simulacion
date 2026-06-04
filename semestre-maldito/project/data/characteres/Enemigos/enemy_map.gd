extends CharacterBody2D

@export var angle: float = 60.0
@export var length: float = 100.0
@export var direction = Vector2.UP
var half_angle_rads: float = 0.0
var player

func _ready():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("Player")
	half_angle_rads = deg_to_rad(angle / 2)
	queue_redraw()

@onready var animated_sprite_2d = $AnimatedSprite2D

func _physics_process(delta):
	
	print(
		"player=", player,
		" angle=", angle,
		" length=", length,
		" half=", half_angle_rads,
		" direction=", direction
	)
	if is_in_cone():
		animated_sprite_2d.self_modulate = Color.RED
	else:
		animated_sprite_2d.self_modulate = Color.WHITE

func _draw():
	var left_dir = direction.rotated(-half_angle_rads) * length
	var right_dir = direction.rotated(half_angle_rads) * length
	
	draw_line(Vector2.ZERO, left_dir, Color.YELLOW, 2.0)
	draw_line(Vector2.ZERO, right_dir, Color.YELLOW, 2.0)

func is_in_cone():
	if player == null:
			return false
	var player_local_position = to_local(player.global_position)
	if player_local_position.length() > length:
		return false
	var angle_to_player = direction.angle_to(player_local_position)
	if abs(angle_to_player) <= half_angle_rads:
		return true
	else:
		return false
