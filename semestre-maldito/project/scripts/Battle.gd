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
var party = []
var current_player_index = 0
var jugadores_que_actuaron = 0

# ── NODOS HUD EXISTENTES ──────────────────────────────────
@onready var turn_label     = $HUD/TurnLabel
@onready var enemy_hp_bar   = $HUD/EnemyHPBar
@onready var p1_lbl = $HUD/Player1Label
@onready var p1_bar = $HUD/Player1HPBar
@onready var p2_lbl = $HUD/Player2Label
@onready var p2_bar = $HUD/Player2HPBar
@onready var p3_lbl = $HUD/Player3Label
@onready var p3_bar = $HUD/Player3HPBar
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
	party = [
		{
			"nombre": "Programador",
			"hp": GlobalState.party_hp[0],
			"hp_max": GlobalState.party_hp_max[0],
			"dmg_min": 10,
			"dmg_max": 18
		},
		{
			"nombre": "Matematico",
			"hp": GlobalState.party_hp[1],
			"hp_max": GlobalState.party_hp_max[1],
			"dmg_min": 8,
			"dmg_max": 22
		},
		{
			"nombre": "TecnicoRedes",
			"hp": GlobalState.party_hp[2],
			"hp_max": GlobalState.party_hp_max[2],
			"dmg_min": 12,
			"dmg_max": 16
		}
	]

	# 6. Configurar UI
	_setup_ui(nombre_enemigo)
	actualizar_party_hud()
	# 7. Conectar botón y comenzar
	attack_btn.pressed.connect(_on_attack_pressed)
	_set_turn(TurnState.PLAYER)
	_actualizar_hud_simulacion()
	current_player_index = obtener_primer_vivo()

# ══════════════════════════════════════════════════════════
# SETUP UI
# ══════════════════════════════════════════════════════════
func get_current_player():
	return party[current_player_index]

func avanzar_al_siguiente_personaje():
	var inicio = current_player_index
	while true:
		current_player_index += 1
		if current_player_index >= party.size():
			current_player_index = 0
		if party[current_player_index]["hp"] > 0:
			return
		if current_player_index == inicio:
			return

func party_derrotada() -> bool:
	for miembro in party:
		if miembro["hp"] > 0:
			return false
	return true

func actualizar_party_hud():
	var labels = [
		p1_lbl,
		p2_lbl,
		p3_lbl
	]
	var bars = [
		p1_bar,
		p2_bar,
		p3_bar
	]
	for i in range(party.size()):
		var jugador = party[i]
		if i == current_player_index:
			labels[i].text = "► "
		else:
			labels[i].text = ""
		labels[i].text += "%s HP: %d/%d" % [
			jugador["nombre"],
			jugador["hp"],
			jugador["hp_max"]
		]
		bars[i].max_value = jugador["hp_max"]
		bars[i].value = jugador["hp"]
		if jugador["hp"] <= 0:
			labels[i].text += " ☠"

func _setup_ui(nombre_enemigo: String) -> void:
	enemy_hp_bar.max_value = enemy_agent.hp_max
	enemy_hp_bar.value = enemy_agent.hp
	corruption_bar.max_value = 100
	corruption_bar.value = 0
	enemy_name_lbl.text = nombre_enemigo.to_upper()
	result_label.visible = false
	actualizar_party_hud()

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
			var jugador = get_current_player()
			turn_label.text = "⚔ Turno de %s" % jugador["nombre"]
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
			
func contar_vivos() -> int:
	var vivos = 0
	for miembro in party:
		if miembro["hp"] > 0:
			vivos += 1
	return vivos
# ══════════════════════════════════════════════════════════
# BOTÓN ATACAR
# ══════════════════════════════════════════════════════════
func _on_attack_pressed() -> void:

	if not battle_active:
		return
	if current_turn != TurnState.PLAYER:
		return
	attack_btn.disabled = true
	# Acción del personaje actual
	_process_turn_player()
	actualizar_party_hud()
	if not battle_active:
		return
	jugadores_que_actuaron += 1
	# ¿Ya actuaron los tres?
	if jugadores_que_actuaron >= contar_vivos():
		jugadores_que_actuaron = 0
		await get_tree().create_timer(
			ENEMY_TURN_DELAY
		).timeout
		_process_turn_enemy()
		if not battle_active:
			return

	# Buscar siguiente personaje vivo
	avanzar_al_siguiente_personaje()
	actualizar_party_hud()
	_set_turn(TurnState.PLAYER)

# ══════════════════════════════════════════════════════════
# TURNO JUGADOR
# ══════════════════════════════════════════════════════════
func _process_turn_player() -> void:
	# EnemyAgent evalúa si esquiva
	if monte_carlo.is_evaded(0.10):
		_log("¡%s esquivó tu ataque!" % enemy_agent.nombre)
		return
	var jugador = get_current_player()
	var dmg = monte_carlo.roll_damage(
		jugador["dmg_min"],
		jugador["dmg_max"]
	)
	var crit = monte_carlo.is_critical(PLAYER_CRIT)
	if crit: dmg = int(dmg * 1.5)

	# EnemyAgent recibe el daño y actualiza su estado interno
	enemy_agent.recibir_daño(dmg)
	enemy_hp_bar.value = enemy_agent.hp

	var msg = "%s ataca por %d%s | HP enemigo: %d | Estado: %s" % [
		jugador["nombre"],
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
	var jugadores = []
	for miembro in party:
		if miembro["hp"] > 0:
			jugadores.append(miembro["nombre"])
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

			var vivos = []
			for i in range(party.size()):
				if party[i]["hp"] > 0:
					vivos.append(i)
			if vivos.is_empty():
				battle_active = false
				_set_turn(TurnState.DEFEAT)
				return
			var objetivo = vivos[randi() % vivos.size()]
			party[objetivo]["hp"] = max(
				party[objetivo]["hp"] - dmg,
				0
			)
			if party[current_player_index]["hp"] <= 0:
				avanzar_al_siguiente_personaje()
			actualizar_party_hud()
			# Corrupción adicional del enemigo
			SystemDynamics.add_corruption(ENEMY_CORR_DMG)
			corruption_bar.value = GlobalState.corruption * 100

			_log("%s usa %s sobre %s → %d daño | HP restante: %d" % [
				enemy_agent.nombre,
				decision.accion,
				party[objetivo]["nombre"],
				dmg,
				party[objetivo]["hp"]
			])
			for i in range(party.size()):
				GlobalState.party_hp[i] = party[i]["hp"]

			if party_derrotada():
				battle_active = false
				_set_turn(TurnState.DEFEAT)

		"defensa":
			_log("%s se defiende este turno." % enemy_agent.nombre)

		"habilidad_especial":
			# Habilidad especial: daño + corrupción alta
			var dmg = monte_carlo.roll_damage(12, 20)
			dmg = int(dmg * SystemDynamics.get_damage_multiplier())
			var vivos = []
			for i in range(party.size()):
				if party[i]["hp"] > 0:
					vivos.append(i)
			if vivos.is_empty():
				battle_active = false
				_set_turn(TurnState.DEFEAT)
				return
			var objetivo = vivos[randi() % vivos.size()]
			party[objetivo]["hp"] = max(
				party[objetivo]["hp"] - dmg,
				0
			)
			SystemDynamics.add_corruption(ENEMY_CORR_DMG * 2.0)
			corruption_bar.value = GlobalState.corruption * 100
			_log("⚡ %s usa habilidad especial → %d daño | Corr: %.0f%%" % [
				enemy_agent.nombre, dmg, GlobalState.corruption * 100
			])
			for i in range(party.size()):
				GlobalState.party_hp[i] = party[i]["hp"]
			if party[objetivo]["hp"] <= 0:
				_log("%s ha sido derrotado" %
					party[objetivo]["nombre"])
			if party_derrotada():
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
	get_tree().change_scene_to_file("res://project/scenes/maps/Escena Principal/escena_principal.tscn")

func _log(msg: String) -> void:
	battle_log.text = msg
	print(msg)
	
func obtener_primer_vivo():
	for i in range(party.size()):
		if party[i]["hp"] > 0:
			return i
	return 0
