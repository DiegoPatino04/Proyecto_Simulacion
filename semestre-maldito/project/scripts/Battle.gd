# Battle.gd v2 — integra QueueModel + MonteCarlo + SystemDynamics
extends Node2D

# ── MODELOS DE SIMULACIÓN ─────────────────────────────────
var queue_model: QueueModel
var monte_carlo: MonteCarlo

# ── STATS ─────────────────────────────────────────────────
const PLAYER_DMG_MIN  = 10
const PLAYER_DMG_MAX  = 18
const PLAYER_SPEED    = 10
const PLAYER_CRIT     = 0.20   # 20% prob crítico
const PLAYER_EVA      = 0.10   # 10% prob evasión
const ENEMY_DMG_MIN   = 8
const ENEMY_DMG_MAX   = 15
const ENEMY_SPEED     = 8
const ENEMY_CORR_DMG  = 0.08   # daño de corrupción por turno del enemigo
const ENEMY_TURN_DELAY = 1.0

enum TurnState { PLAYER, ENEMY, VICTORY, DEFEAT }
var current_turn: TurnState = TurnState.PLAYER
var battle_active: bool = true
var player_hp:  int
var enemy_hp:   int
var player_hp_max: int
var enemy_hp_max:  int

@onready var turn_label      = $HUD/TurnLabel
@onready var enemy_hp_bar    = $HUD/EnemyHPBar
@onready var player_hp_bar   = $HUD/PlayerHPBar
@onready var player_hp_lbl   = $HUD/PlayerHPLabel
@onready var battle_log      = $HUD/BattleLog
@onready var attack_btn      = $HUD/AttackButton
@onready var result_label    = $HUD/ResultLabel
@onready var enemy_name_lbl  = $HUD/EnemyName
@onready var corruption_bar  = $HUD/CorruptionBar  # nuevo nodo

func _ready() -> void:
	# Instanciar modelos
	queue_model = QueueModel.new()
	monte_carlo = MonteCarlo.new()
	SystemDynamics.reset_phase()   # corrupción a 0 al inicio

	# Cargar stats desde GlobalState
	player_hp     = GlobalState.party_hp[0]
	player_hp_max = GlobalState.party_hp_max[0]
	enemy_hp      = GlobalState.enemy_hp
	enemy_hp_max  = GlobalState.enemy_hp_max

	# Configurar UI
	enemy_hp_bar.max_value   = enemy_hp_max
	enemy_hp_bar.value       = enemy_hp
	player_hp_bar.max_value  = player_hp_max
	player_hp_bar.value      = player_hp
	corruption_bar.max_value = 100
	corruption_bar.value     = 0
	enemy_name_lbl.text      = GlobalState.enemy_name.to_upper()
	result_label.visible     = false

	attack_btn.pressed.connect(_on_attack_pressed)
	_set_turn(TurnState.PLAYER)

func _set_turn(state: TurnState) -> void:
	current_turn = state
	match state:
		TurnState.PLAYER:
			turn_label.text = "⚔ Turno del jugador"
			attack_btn.disabled = false
		TurnState.ENEMY:
			turn_label.text = "💀 Turno del enemigo..."
			attack_btn.disabled = true
			await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
			_process_turn_enemy()
		TurnState.VICTORY:
			_show_result("✅ VICTORIA")
		TurnState.DEFEAT:
			_show_result("💀 DERROTA")

func _on_attack_pressed() -> void:
	if not battle_active or current_turn != TurnState.PLAYER:
		return
	attack_btn.disabled = true

	# 1. Actualizar dinámica de sistemas
	SystemDynamics.update()
	corruption_bar.value = GlobalState.corruption * 100

	# 2. Encolar ambas acciones
	var enemy_speed = ENEMY_SPEED + SystemDynamics.get_enemy_speed_bonus()
	queue_model.enqueue({actor="jugador", speed=PLAYER_SPEED, type="attack"})
	queue_model.enqueue({actor="enemigo", speed=enemy_speed,  type="attack"})

	# 3. Procesar turno del jugador
	var player_action = queue_model.process_next()
	if player_action.actor == "jugador":
		_process_turn_player()
	
	if not battle_active:
		return

	# 4. Turno del enemigo con delay visual
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
	var enemy_action = queue_model.process_next()
	if enemy_action.actor == "enemigo":
		_process_turn_enemy()

	if not battle_active:
		return

	# 5. Verificar derrota por corrupción
	if SystemDynamics.is_game_over():
		_set_turn(TurnState.DEFEAT)
		return

	# 6. Devolver el turno al jugador
	_set_turn(TurnState.PLAYER)

func _process_turn_player() -> void:
	# Evasión del enemigo
	if monte_carlo.is_evaded(0.10):
		_log("¡El enemigo esquivó tu ataque!")
		return
	# Calcular daño
	var dmg = monte_carlo.roll_damage(PLAYER_DMG_MIN, PLAYER_DMG_MAX)
	var crit = monte_carlo.is_critical(PLAYER_CRIT)
	if crit: dmg = int(dmg * 1.5)
	var msg = "Atacas por %d" % dmg
	if crit: msg += " ¡CRÍTICO!"
	enemy_hp = max(enemy_hp - dmg, 0)
	enemy_hp_bar.value = enemy_hp
	_log(msg + " | HP enemigo: %d" % enemy_hp)
	if enemy_hp <= 0:
		battle_active = false
		_set_turn(TurnState.VICTORY)

func _process_turn_enemy() -> void:
	if not battle_active: return
	# Evasión del jugador
	if monte_carlo.is_evaded(PLAYER_EVA):
		_log("¡Esquivaste el ataque del enemigo!")
		return
	# Daño HP + multiplicador de corrupción
	var dmg = monte_carlo.roll_damage(ENEMY_DMG_MIN, ENEMY_DMG_MAX)
	dmg = int(dmg * SystemDynamics.get_damage_multiplier())
	player_hp = max(player_hp - dmg, 0)
	player_hp_bar.value = player_hp
	player_hp_lbl.text  = "HP: %d/%d" % [player_hp, player_hp_max]
	# Daño de corrupción
	SystemDynamics.add_corruption(ENEMY_CORR_DMG)
	corruption_bar.value = GlobalState.corruption * 100
	_log("%s ataca por %d | Tu HP: %d | Corr: %.0f%%" % [
		GlobalState.enemy_name, dmg, player_hp, GlobalState.corruption * 100])
	GlobalState.party_hp[0] = player_hp
	if player_hp <= 0:
		battle_active = false
		_set_turn(TurnState.DEFEAT)

func _show_result(msg: String) -> void:
	battle_active = false
	attack_btn.disabled = true
	result_label.text    = msg
	result_label.visible = true
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://project/scenes/MainMenu.tscn")

func _log(msg: String) -> void:
	battle_log.text = msg
	print(msg)
