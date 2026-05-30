# EnemyAgent.gd — Modelo Basado en Agentes
# Cada enemigo es un agente autónomo con estado interno propio
# Variables entrada: HP, agresividad, tipo de enemigo
# Variables salida: acción decidida, estado actual, target
class_name EnemyAgent
extends RefCounted

# ── PRNG CONGRUENCIAL LINEAL (para selección de acción) ───
var _lcg_seed: int = 99991
const LCG_A = 1664525
const LCG_C = 1013904223
const LCG_M = 4294967296  # 2^32

func _lcg_next() -> float:
	_lcg_seed = (LCG_A * _lcg_seed + LCG_C) % LCG_M
	return float(_lcg_seed) / float(LCG_M)

func set_semilla(s: int) -> void:
	_lcg_seed = s

# ── ESTADOS POSIBLES DEL AGENTE ───────────────────────────
enum Estado { ACTIVO, ENRAGED, DERROTADO }

# ── TIPOS DE ENEMIGO (cada uno con reglas distintas) ──────
enum Tipo {
	DERIVATOR,        # Mapa 1 — matemático
	MATRIX_HORROR,    # Mapa 1 — algebraico
	QUANTUM_SPECTER,  # Mapa 1 — probabilístico
	SYNTAX_ERROR,     # Mapa 2 — compilador
	KERNEL_REAPER,    # Mapa 2 — sistema operativo
	BINARY_TITAN,     # Mapa 2 — arquitectura
	RECURSIVE_BEAST,  # Mapa 2 — recursivo
	SQL_DEVOURER,     # Mapa 3 — bases de datos
	NEURAL_ABERRATION,# Mapa 3 — IA
	NULL_POINTER      # Boss final
}

# ── VARIABLES DE ESTADO INTERNAS ──────────────────────────
var nombre:      String
var tipo:        Tipo
var hp:          int
var hp_max:      int
var agresividad: float   # α ∈ [0.0, 1.0] — afecta probabilidad de ataque fuerte
var estado:      Estado = Estado.ACTIVO
var target:      String = ""   # nombre del jugador objetivo
var turno_count: int = 0

# ── ACCIONES DISPONIBLES ──────────────────────────────────
const ACCIONES_BASE = ["ataque_normal", "defensa", "habilidad_especial"]
const ACCIONES_ENRAGED = ["ataque_fuerte", "ataque_fuerte", "habilidad_especial"]
# (ataque_fuerte repetido = mayor probabilidad en estado enraged)

# ── CONSTRUCTOR ───────────────────────────────────────────
func _init(p_nombre: String, p_tipo: Tipo, p_hp: int, p_agresividad: float) -> void:
	nombre      = p_nombre
	tipo        = p_tipo
	hp          = p_hp
	hp_max      = p_hp
	agresividad = clampf(p_agresividad, 0.0, 1.0)
	_lcg_seed   = p_hp * 31 + int(p_agresividad * 1000)  # semilla única por agente
	print("[Agente] creado: %s | HP=%d | α=%.2f" % [nombre, hp, agresividad])

# ── DECIDIR ACCIÓN (lógica autónoma) ─────────────────────
func decidir_accion(jugadores: Array) -> Dictionary:
	if estado == Estado.DERROTADO:
		return { "accion": "ninguna", "actor": nombre, "target": "" }

	turno_count += 1
	_actualizar_estado()
	_elegir_target(jugadores)

	var accion = _seleccionar_accion()
	var resultado = {
		"accion": accion,
		"actor":  nombre,
		"target": target,
		"estado": Estado.keys()[estado],
		"hp_pct": float(hp) / float(hp_max)
	}

	print("[Agente] %s → %s sobre %s | estado: %s | HP: %d/%d" \
		% [nombre, accion, target, Estado.keys()[estado], hp, hp_max])
	return resultado

# ── RECIBIR DAÑO ──────────────────────────────────────────
func recibir_daño(cantidad: int) -> void:
	hp = max(0, hp - cantidad)
	_actualizar_estado()
	print("[Agente] %s recibió %d daño | HP restante: %d" % [nombre, cantidad, hp])
	if estado == Estado.DERROTADO:
		print("[Agente] %s DERROTADO" % nombre)

# ── ACTUALIZAR ESTADO INTERNO ─────────────────────────────
# Regla principal: si HP < 30% → ENRAGED
func _actualizar_estado() -> void:
	if hp <= 0:
		estado = Estado.DERROTADO
	elif float(hp) / float(hp_max) < 0.30:
		if estado != Estado.ENRAGED:
			estado = Estado.ENRAGED
			print("[Agente] %s entró en ENRAGED (HP < 30%%)" % nombre)
	else:
		estado = Estado.ACTIVO

# ── ELEGIR TARGET ─────────────────────────────────────────
# Cada tipo de enemigo prioriza un target distinto
func _elegir_target(jugadores: Array) -> void:
	if jugadores.is_empty():
		target = ""
		return

	match tipo:
		Tipo.DERIVATOR, Tipo.MATRIX_HORROR:
			# Atacan al jugador con menos HP (más vulnerable)
			target = _jugador_menor_hp(jugadores)
		Tipo.QUANTUM_SPECTER, Tipo.NEURAL_ABERRATION:
			# Atacan al azar (comportamiento probabilístico)
			var idx = int(_lcg_next() * jugadores.size())
			target = jugadores[clamp(idx, 0, jugadores.size()-1)]
		Tipo.KERNEL_REAPER, Tipo.NULL_POINTER:
			# Atacan siempre al Programador (mayor daño)
			target = "Programador" if "Programador" in jugadores else jugadores[0]
		Tipo.RECURSIVE_BEAST:
			# En enraged ataca al soporte, normal al de mayor HP
			if estado == Estado.ENRAGED:
				target = "TecnicoRedes" if "TecnicoRedes" in jugadores else jugadores[0]
			else:
				target = _jugador_mayor_hp(jugadores)
		_:
			# Por defecto: primer jugador disponible
			target = jugadores[0]

# ── SELECCIONAR ACCIÓN ────────────────────────────────────
func _seleccionar_accion() -> String:
	var r = _lcg_next()
	var pool = ACCIONES_ENRAGED if estado == Estado.ENRAGED else ACCIONES_BASE

	# agresividad α modifica la distribución:
	# α alto → más probabilidad de acción ofensiva
	if r < agresividad:
		# acción ofensiva
		return pool[0]  # ataque_fuerte o ataque_normal
	elif r < agresividad + 0.2:
		# habilidad especial
		return pool[2]
	else:
		# defensa o acción débil
		return pool[1] if estado == Estado.ACTIVO else pool[0]

# ── HELPERS ───────────────────────────────────────────────
func _jugador_menor_hp(jugadores: Array) -> String:
	# Simplificado: en integración real recibiría los HP también
	# Por ahora retorna el primero de la lista como fallback
	return jugadores[0]

func _jugador_mayor_hp(jugadores: Array) -> String:
	return jugadores[jugadores.size() - 1] if jugadores.size() > 1 else jugadores[0]

# ── GETTERS PARA HUD ──────────────────────────────────────
func get_hp_porcentaje() -> float:
	return float(hp) / float(hp_max)

func get_estado_texto() -> String:
	return Estado.keys()[estado]

func esta_vivo() -> bool:
	return estado != Estado.DERROTADO

# ── FÁBRICA DE ENEMIGOS PREDEFINIDOS ─────────────────────
# Usar así: var enemigo = EnemyAgent.crear("Derivator")
static func crear(nombre_enemigo: String) -> EnemyAgent:
	match nombre_enemigo:
		"Derivator":
			return EnemyAgent.new("Derivator", Tipo.DERIVATOR, 80, 0.6)
		"MatrixHorror":
			return EnemyAgent.new("MatrixHorror", Tipo.MATRIX_HORROR, 100, 0.5)
		"QuantumSpecter":
			return EnemyAgent.new("QuantumSpecter", Tipo.QUANTUM_SPECTER, 60, 0.7)
		"TheApproximation":
			return EnemyAgent.new("TheApproximation", Tipo.DERIVATOR, 70, 0.4)
		"SyntaxError":
			return EnemyAgent.new("SyntaxError", Tipo.SYNTAX_ERROR, 90, 0.65)
		"KernelReaper":
			return EnemyAgent.new("KernelReaper", Tipo.KERNEL_REAPER, 120, 0.8)
		"BinaryTitan":
			return EnemyAgent.new("BinaryTitan", Tipo.BINARY_TITAN, 150, 0.55)
		"RecursiveBeast":
			return EnemyAgent.new("RecursiveBeast", Tipo.RECURSIVE_BEAST, 110, 0.75)
		"NullPointer":
			return EnemyAgent.new("NullPointer", Tipo.NULL_POINTER, 500, 0.9)
		_:
			return EnemyAgent.new(nombre_enemigo, Tipo.DERIVATOR, 50, 0.5)