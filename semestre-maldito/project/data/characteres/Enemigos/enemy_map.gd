extends CharacterBody2D

@export var angle: float = 60.0
@export var length: float = 100.0
@export var direction = Vector2.UP
@export var speed: float = 70.0
@export var waypoints: Array[Marker2D]
@export var animation: Node

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var ray_cast_2d = $RayCast2D

enum State {
	PATROL,
	CHASE
}

var current_state = State.PATROL
var current_index = 0
var half_angle_rads: float = 0.0
var player

func _ready():
	await get_tree().process_frame

	player = get_tree().get_first_node_in_group("Player")
	half_angle_rads = deg_to_rad(angle / 2)
	$Area2D.body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta):
	if player != null:
		if is_in_cone() and has_line_of_sight():
			change_state(State.CHASE)
		else:
			change_state(State.PATROL)
	match current_state:
		State.PATROL:
			patrol()
		State.CHASE:
			chase()
	move_and_slide()


func patrol():
	animated_sprite_2d.self_modulate = Color.WHITE
	if waypoints.is_empty():
		velocity = Vector2.ZERO
		return
	var min_distance = 5.0
	var target_position = waypoints[current_index].global_position
	direction = target_position - global_position
	var distance = direction.length()
	direction = direction.normalized()
	velocity = direction * speed

	if distance < min_distance:
		current_index += 1
		if current_index >= waypoints.size():
			current_index = 0
	animation.play("Idle Movement")


func chase():
	animated_sprite_2d.self_modulate = Color.RED
	direction = player.global_position - global_position
	direction = direction.normalized()
	velocity = direction * speed
	animation.play("Idle Movement")

func change_state(new_state):
	if current_state == new_state:
		return
	current_state = new_state
	match current_state:
		State.PATROL:
			print("Volviendo a patrullar")
		State.CHASE:
			print("Jugador detectado")

func is_in_cone():
	if player == null:
		return false
	var player_local_position = to_local(player.global_position)
	if player_local_position.length() > length:
		return false
	var angle_to_player = direction.angle_to(player_local_position)
	return abs(angle_to_player) <= half_angle_rads


func has_line_of_sight():
	if player == null:
		return false
	ray_cast_2d.target_position = to_local(player.global_position)
	ray_cast_2d.force_raycast_update()
	var collider = ray_cast_2d.get_collider()
	if collider == null:
		return false
	return collider.is_in_group("Player")


func _draw():
	var left_dir = direction.rotated(-half_angle_rads) * length
	var right_dir = direction.rotated(half_angle_rads) * length
	
func _on_body_entered(body):
	if body.is_in_group("Player"):
		start_battle()
		
func start_battle():
	print("Comenzar combate")
	get_tree().change_scene_to_file("res://project/scenes/maps/battle/Battle.tscn")
