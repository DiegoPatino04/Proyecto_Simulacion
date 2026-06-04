# main_menu.gd
extends Control

const PATH = "res://project/scenes/maps/Select_Menu/Select_Menu.tscn"

func _ready() -> void:
	$Button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(PATH)
