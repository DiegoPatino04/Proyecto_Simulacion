# main_menu.gd
extends Control

const BATTLE_PATH = "res://project/scenes/maps/battle/Battle.tscn"

func _ready() -> void:
	$Button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	# Configurar primer enemigo directamente aquí
	GlobalState.enemy_name   = "Derivator"
	GlobalState.enemy_hp     = 80
	GlobalState.enemy_hp_max = 80
	GlobalState.reset_battle()
	get_tree().change_scene_to_file(BATTLE_PATH)
