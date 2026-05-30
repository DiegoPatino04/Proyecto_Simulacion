# Map1.gd — configura el enemigo en GlobalState antes de ir a Battle
extends Node2D

const BATTLE_PATH = "res://project/scenes/battle/Battle.tscn"

func _ready() -> void:
	if has_node("FightButton"):
		$FightButton.pressed.connect(_go_to_battle)

func _go_to_battle() -> void:
	# Configurar el enemigo de este mapa en GlobalState
	GlobalState.enemy_name   = "Derivator"
	GlobalState.enemy_hp     = 80
	GlobalState.enemy_hp_max = 80
	# Resetear HP del jugador al iniciar batalla
	GlobalState.reset_battle()

	get_tree().change_scene_to_file(BATTLE_PATH)
