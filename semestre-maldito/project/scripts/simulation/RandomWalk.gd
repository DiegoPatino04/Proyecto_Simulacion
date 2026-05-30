# RandomWalk.gd — Caminata Aleatoria
# Modelo standalone: se instancia en Battle.gd / MapManager
# Determina qué enemigo aparece según movimiento en grafo de habitaciones
# Variables entrada: grafo de nodos, posición actual
# Variables salida: nuevo nodo (enemigo que aparece), historial
class_name RandomWalk
extends RefCounted

# ── PRNG MERSENNE TWISTER (simplificado MT19937) ──────────
# Usamos implementación propia para cumplir requisito del taller
var _mt: Array = []
var _mt_index: int = 624
const MT_N = 624
const MT_M = 397
const MT_MATRIX_A = 0x9908b0df
const MT_UPPER_MASK = 0x80000000
const MT_LOWER_MASK = 0x7fffffff

func _mt_seed(seed: int) -> void:
	_mt.resize(MT_N)
	_mt[0] = seed & 0xffffffff
	for i in range(1, MT_N):
		_mt[i] = (1812433253 * (_mt[i-1] ^ (_mt[i-1] >> 30)) + i) & 0xffffffff
	_mt_index = MT_N

func _mt_generate() -> void:
	for i in range(MT_N):
		var y = (_mt[i] & MT_UPPER_MASK) | (_mt[(i + 1) % MT_N] & MT_LOWER_MASK)
		_mt[i] = _mt[(i + MT_M) % MT_N] ^ (y >> 1)
		if y % 2 != 0:
			_mt[i] ^= MT_MATRIX_A
	_mt_index = 0

func _mt_next_float() -> float:
	if _mt_index >= MT_N:
		_mt_generate()
	var y = _mt[_mt_index]
	_mt_index += 1
	y ^= (y >> 11)
	y ^= (y << 7)  & 0x9d2c5680
	y ^= (y << 15) & 0xefc60000
	y ^= (y >> 18)
	return float(y & 0xffffffff) / float(0xffffffff)

# ── GRAFO DEL MAPA ────────────────────────────────────────
# Cada nodo tiene sus vecinos y el enemigo que habita ahí
# Formato: { "nodo": { "vecinos": [...], "enemigo": "Nombre" } }
var grafo: Dictionary = {}
var posicion_actual: String = ""
var historial: Array = []   # para mostrar trayectoria en informe

# ── INICIALIZAR GRAFO ─────────────────────────────────────
# Llama esto al cargar cada mapa
func configurar_mapa(nodo_inicio: String, mapa: Dictionary, semilla: int = 7777) -> void:
	grafo = mapa
	posicion_actual = nodo_inicio
	historial = [nodo_inicio]
	_mt_seed(semilla)
	print("[RW] Mapa configurado | inicio: %s | nodos: %d" % [nodo_inicio, grafo.size()])

# ── CAMINAR UN PASO ───────────────────────────────────────
# Elige un vecino al azar con probabilidad uniforme p = 1/n_vecinos
# Retorna el nombre del enemigo en el nuevo nodo
func caminar() -> String:
	if not grafo.has(posicion_actual):
		print("[RW] ERROR: nodo '%s' no existe en el grafo" % posicion_actual)
		return ""

	var vecinos: Array = grafo[posicion_actual]["vecinos"]
	if vecinos.is_empty():
		print("[RW] Sin vecinos desde %s" % posicion_actual)
		return grafo[posicion_actual].get("enemigo", "ninguno")

	# Probabilidad uniforme: p = 1 / n_vecinos
	var r = _mt_next_float()
	var idx = int(r * vecinos.size())
	idx = clamp(idx, 0, vecinos.size() - 1)

	posicion_actual = vecinos[idx]
	historial.append(posicion_actual)

	var enemigo = grafo[posicion_actual].get("enemigo", "ninguno")
	print("[RW] paso → %s | p=%.4f | enemigo: %s" % [posicion_actual, r, enemigo])
	return enemigo

# ── CAMINAR N PASOS ───────────────────────────────────────
# Útil para pre-calcular encuentros o validación standalone
func caminar_n_pasos(n: int) -> Array:
	var resultados = []
	for i in range(n):
		var enemigo = caminar()
		resultados.append({ "paso": i+1, "nodo": posicion_actual, "enemigo": enemigo })
	return resultados

# ── PROBABILIDAD EMPÍRICA POR NODO ────────────────────────
# Cuántas veces terminó en cada nodo → validación del modelo
func distribucion_visitas() -> Dictionary:
	var conteo = {}
	for nodo in historial:
		conteo[nodo] = conteo.get(nodo, 0) + 1
	print("[RW] distribución visitas: ", conteo)
	return conteo

# ── GRAFO PREDEFINIDO MAPA 1 ─────────────────────────────
# Las Matemáticas del Abismo — 4 habitaciones, 4 enemigos
static func grafo_mapa1() -> Dictionary:
	return {
		"entrada": {
			"vecinos": ["algebra", "calculo"],
			"enemigo": "ninguno"
		},
		"algebra": {
			"vecinos": ["entrada", "calculo", "fisica"],
			"enemigo": "MatrixHorror"
		},
		"calculo": {
			"vecinos": ["entrada", "algebra", "metodos"],
			"enemigo": "Derivator"
		},
		"fisica": {
			"vecinos": ["algebra", "metodos"],
			"enemigo": "QuantumSpecter"
		},
		"metodos": {
			"vecinos": ["calculo", "fisica"],
			"enemigo": "TheApproximation"
		}
	}

# ── GRAFO PREDEFINIDO MAPA 2 ─────────────────────────────
static func grafo_mapa2() -> Dictionary:
	return {
		"lobby": {
			"vecinos": ["compilador", "kernel"],
			"enemigo": "ninguno"
		},
		"compilador": {
			"vecinos": ["lobby", "kernel", "arquitectura"],
			"enemigo": "SyntaxError"
		},
		"kernel": {
			"vecinos": ["lobby", "compilador", "memoria"],
			"enemigo": "KernelReaper"
		},
		"arquitectura": {
			"vecinos": ["compilador", "memoria"],
			"enemigo": "BinaryTitan"
		},
		"memoria": {
			"vecinos": ["kernel", "arquitectura"],
			"enemigo": "RecursiveBeast"
		}
	}