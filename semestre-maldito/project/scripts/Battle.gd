# Battle.gd v3 — los 5 modelos de simulación integrados
# Cambios vs v2:
#   + RandomWalk  → determina qué enemigo aparece
#   + EnemyAgent  → IA autónoma del enemigo con estado interno
#   + HUD ampliado → muestra λ, μ, ρ, corrupción, estado agente
extends Node2D

# ── MODELOS DE SIMULACIÓN ─────────────────────────────────
var queue_model:  QueueModel
var monte_carlo:  MonteCarlo
var random_walk:  RandomWalk
var enemy_agent:  EnemyAgent
# SystemDynamics es Autoload, se accede directo

# ── STATS JUGADOR ─────────────────────────────────────────
const PLAYER_DMG_MIN  = 10
const PLAYER_DMG_MAX  = 18
const PLAYER_SPEED    = 10
const PLAYER_CRIT     = 0.20
const PLAYER_EVA      = 0.10

# ── STATS ENEMIGO (base, luego EnemyAgent los maneja) ─────
const ENEMY_CORR_DMG   = 0.08
const ENEMY_TURN_DELAY = 1.0

# ── ESTADO DEL COMBATE ────────────────────────────────────
enum TurnState { PLAYER, ENEMY, VICTORY, DEFEAT }
var current_turn: TurnState = TurnState.PLAYER
var battle_active: bool = true
var player_hp:     int
var player_hp_max: int

# ── NODOS HUD EXISTENTES ──────────────────────────────────
@onready var turn_label     = $HUD/TurnLabel
@onready var enemy_hp_bar   = $HUD/EnemyHPBar
@onready var player_hp_bar  = $HUD/PlayerHPBar
@onready var player_hp_lbl  = $HUD/PlayerHPLabel
@onready var battle_log     = $HUD/BattleLog
@onready var attack_btn     = $HUD/AttackButton
@onready var result_label   = $HUD/ResultLabel
@onready var enemy_name_lbl = $HUD/EnemyName
@onready var corruption_bar = $HUD/CorruptionBar

# ── NODOS HUD NUEVOS (agrégalos en Battle.tscn) ───────────
# Son Labels simples — ve a Battle.tscn → HUD → agrega 4 Labels
@onready var lbl_lambda     = $HUD/SimPanel/LblLambda    # "λ = 0.00"
@onready var lbl_mu         = $HUD/SimPanel/LblMu        # "μ = 0.00"
@onready var lbl_rho        = $HUD/SimPanel/LblRho       # "ρ = 0.00"
@onready var lbl_agente     = $HUD/SimPanel/LblAgente    # "Estado: ACTIVO"

# ══════════════════════════════════════════════════════════
func _ready() -> void:
	# 1. Instanciar modelos
	queue_model = QueueModel.new()
	monte_carlo = MonteCarlo.new()
	random_walk = RandomWalk.new()
	SystemDynamics.reset_phase()

	# 2. Configurar RandomWalk con el grafo del mapa actual
	var grafo = _get_grafo_mapa_actual()
	random_walk.configurar_mapa("entrada", grafo, 1234)

	# 3. Determinar qué enemigo aparece según la caminata
	var nombre_enemigo = _determinar_enemigo()

	# 4. Crear el agente enemigo
	enemy_agent = EnemyAgent.crear(nombre_enemigo)

	# 5. Cargar HP desde GlobalState
	player_hp     = GlobalState.party_hp[0]
	player_hp_max = GlobalState.party_hp_max[0]

	# 6. Configurar UI
	_setup_ui(nombre_enemigo)

	# 7. Conectar botón y comenzar
	attack_btn.pressed.connect(_on_attack_pressed)
	_set_turn(TurnState.PLAYER)
	_actualizar_hud_simulacion()

# ══════════════════════════════════════════════════════════
# SETUP UI
# ══════════════════════════════════════════════════════════
func _setup_ui(nombre_enemigo: String) -> void:
	enemy_hp_bar.max_value  = enemy_agent.hp_max
	enemy_hp_bar.value      = enemy_agent.hp
	player_hp_bar.max_value = player_hp_max
	player_hp_bar.value     = player_hp
	player_hp_lbl.text      = "HP: %d/%d" % [player_hp, player_hp_max]
	corruption_bar.max_value = 100
	corruption_bar.value     = 0
	enemy_name_lbl.text      = nombre_enemigo.to_upper()
	result_label.visible     = false

# ══════════════════════════════════════════════════════════
# DETERMINAR ENEMIGO CON CAMINATA ALEATORIA
# ══════════════════════════════════════════════════════════
func _determinar_enemigo() -> String:
	# Camina 3 pasos para llegar a un enemigo
	var nombre = ""
	for i in range(3):
		nombre = random_walk.caminar()
		if nombre != "ninguno" and nombre != "":
			break
	# Si no encontró enemigo tras 3 pasos, usa el de GlobalState
	if nombre == "" or nombre == "ninguno":
		nombre = GlobalState.enemy_name
	_log("🎲 Caminata aleatoria → enemigo: %s" % nombre)
	return nombre

# ══════════════════════════════════════════════════════════
# GRAFO SEGÚN MAPA ACTUAL
# ══════════════════════════════════════════════════════════
func _get_grafo_mapa_actual() -> Dictionary:
	match GlobalState.current_map:
		1: return RandomWalk.grafo_mapa1()
		2: return RandomWalk.grafo_mapa2()
		_: return RandomWalk.grafo_mapa1()

# ══════════════════════════════════════════════════════════
# CONTROL DE TURNOS
# ══════════════════════════════════════════════════════════
func _set_turn(state: TurnState) -> void:
	current_turn = state
	match state:
		TurnState.PLAYER:
			turn_label.text     = "⚔ Tu turno"
			attack_btn.disabled = false
		TurnState.ENEMY:
			turn_label.text     = "💀 Turno del enemigo..."
			attack_btn.disabled = true
			await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
			_process_turn_enemy()
		TurnState.VICTORY:
			_show_result("✅ VICTORIA")
		TurnState.DEFEAT:
			_show_result("💀 DERROTA")

# ══════════════════════════════════════════════════════════
# BOTÓN ATACAR
# ══════════════════════════════════════════════════════════
func _on_attack_pressed() -> void:
	if not battle_active or current_turn != TurnState.PLAYER:
		return
	attack_btn.disabled = true

	# 1. Dinámica de sistemas — corrupción sube cada turno
	SystemDynamics.update()
	corruption_bar.value = GlobalState.corruption * 100

	# 2. Cola M/M/1 — decidir quién actúa primero
	var enemy_speed = 8 + SystemDynamics.get_enemy_speed_bonus()
	queue_model.enqueue({actor = "jugador", speed = PLAYER_SPEED, type = "attack"})
	queue_model.enqueue({actor = "enemigo", speed = enemy_speed,  type = "attack"})

	# 3. Turno del jugador (primero si speed > enemy_speed)
	var first = queue_model.process_next()
	if first.actor == "jugador":
		_process_turn_player()
		if not battle_active: return
		await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
		queue_model.process_next()
		_process_turn_enemy()
	else:
		# Enemigo actúa primero
		_process_turn_enemy()
		if not battle_active: return
		await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
		queue_model.process_next()
		_process_turn_player()

	if not battle_active: return

	# 4. Chequear derrota por corrupción
	if SystemDynamics.is_game_over():
		_log("💀 Corrupción al 100% — derrota")
		_set_turn(TurnState.DEFEAT)
		return

	# 5. Actualizar HUD de simulación
	_actualizar_hud_simulacion()
	_set_turn(TurnState.PLAYER)

# ══════════════════════════════════════════════════════════
# TURNO JUGADOR
# ══════════════════════════════════════════════════════════
func _process_turn_player() -> void:
	# EnemyAgent evalúa si esquiva
	if monte_carlo.is_evaded(0.10):
		_log("¡%s esquivó tu ataque!" % enemy_agent.nombre)
		return

	var dmg  = monte_carlo.roll_damage(PLAYER_DMG_MIN, PLAYER_DMG_MAX)
	var crit = monte_carlo.is_critical(PLAYER_CRIT)
	if crit: dmg = int(dmg * 1.5)

	# EnemyAgent recibe el daño y actualiza su estado interno
	enemy_agent.recibir_daño(dmg)
	enemy_hp_bar.value = enemy_agent.hp

	var msg = "Atacas por %d%s | HP enemigo: %d | Estado: %s" % [
		dmg,
		" ¡CRÍTICO!" if crit else "",
		enemy_agent.hp,
		enemy_agent.get_estado_texto()
	]
	_log(msg)

	if not enemy_agent.esta_vivo():
		battle_active = false
		_set_turn(TurnState.VICTORY)

# ══════════════════════════════════════════════════════════
# TURNO ENEMIGO — EnemyAgent decide autónomamente
# ══════════════════════════════════════════════════════════
func _process_turn_enemy() -> void:
	if not battle_active: return

	# EnemyAgent decide qué hacer con su lógica interna
	var jugadores = ["Programador", "Matematico", "TecnicoRedes"]
	var decision  = enemy_agent.decidir_accion(jugadores)

	match decision.accion:
		"ataque_normal", "ataque_fuerte":
			# Jugador intenta esquivar
			if monte_carlo.is_evaded(PLAYER_EVA):
				_log("¡Esquivaste el ataque de %s!" % enemy_agent.nombre)
				return

			# Daño base según acción + multiplicador de corrupción
			var dmg_min = 8  if decision.accion == "ataque_normal" else 14
			var dmg_max = 15 if decision.accion == "ataque_normal" else 25
			var dmg = monte_carlo.roll_damage(dmg_min, dmg_max)
			dmg = int(dmg * SystemDynamics.get_damage_multiplier())

			player_hp = max(player_hp - dmg, 0)
			player_hp_bar.value = player_hp
			player_hp_lbl.text  = "HP: %d/%d" % [player_hp, player_hp_max]

			# Corrupción adicional del enemigo
			SystemDynamics.add_corruption(ENEMY_CORR_DMG)
			corruption_bar.value = GlobalState.corruption * 100

			_log("%s usa %s → %d daño | Tu HP: %d | Corr: %.0f%%" % [
				enemy_agent.nombre, decision.accion, dmg,
				player_hp, GlobalState.corruption * 100
			])
			GlobalState.party_hp[0] = player_hp

			if player_hp <= 0:
				battle_active = false
				_set_turn(TurnState.DEFEAT)

		"defensa":
			_log("%s se defiende este turno." % enemy_agent.nombre)

		"habilidad_especial":
			# Habilidad especial: daño + corrupción alta
			var dmg = monte_carlo.roll_damage(12, 20)
			dmg = int(dmg * SystemDynamics.get_damage_multiplier())
			player_hp = max(player_hp - dmg, 0)
			player_hp_bar.value = player_hp
			player_hp_lbl.text  = "HP: %d/%d" % [player_hp, player_hp_max]
			SystemDynamics.add_corruption(ENEMY_CORR_DMG * 2.0)
			corruption_bar.value = GlobalState.corruption * 100
			_log("⚡ %s usa habilidad especial → %d daño | Corr: %.0f%%" % [
				enemy_agent.nombre, dmg, GlobalState.corruption * 100
			])
			GlobalState.party_hp[0] = player_hp
			if player_hp <= 0:
				battle_active = false
				_set_turn(TurnState.DEFEAT)

# ══════════════════════════════════════════════════════════
# HUD DE SIMULACIÓN (visible en pantalla — requisito taller)
# ══════════════════════════════════════════════════════════
func _actualizar_hud_simulacion() -> void:
	# Métricas de la cola M/M/1
	var lam = float(PLAYER_SPEED) / 10.0
	var mu  = float(8 + SystemDynamics.get_enemy_speed_bonus()) / 10.0
	var rho = lam / mu if mu > 0 else 0.0

	lbl_lambda.text = "λ = %.2f" % lam
	lbl_mu.text     = "μ = %.2f" % mu
	lbl_rho.text    = "ρ = %.0f%%" % (rho * 100)
	lbl_agente.text = "Agente: %s" % enemy_agent.get_estado_texto()

# ══════════════════════════════════════════════════════════
# RESULTADO Y LOG
# ══════════════════════════════════════════════════════════
func _show_result(msg: String) -> void:
	battle_active       = false
	attack_btn.disabled = true
	result_label.text   = msg
	result_label.visible = true
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://project/scenes/MainMenu.tscn")

func _log(msg: String) -> void:
	battle_log.text = msg
	print(msg)
