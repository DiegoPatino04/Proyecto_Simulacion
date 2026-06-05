extends Node2D
@export var reproductor: AudioStreamPlayer2D
var player = null

func _ready() -> void:
	if Global.currentPlayer != null:
		player = Global.currentPlayer.instantiate()
		add_child(player)
		player.global_position = $Spawn.global_position
		reproductor.play()
