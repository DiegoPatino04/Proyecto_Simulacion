# MonteCarlo.gd — Simulación Monte Carlo (CORREGIDO)
# Cambio respecto a la versión anterior:
# → randf() reemplazado por Mersenne Twister propio (requisito del taller)
class_name MonteCarlo
extends RefCounted

const N_SAMPLES = 100

# ── MERSENNE TWISTER PROPIO ───────────────────────────────
var _mt: Array = []
var _mt_index: int = 624
const MT_N = 624
const MT_M = 397
const MT_MATRIX_A  = 0x9908b0df
const MT_UPPER_MASK = 0x80000000
const MT_LOWER_MASK = 0x7fffffff

func _init(semilla: int = 42) -> void:
	_mt_seed(semilla)

func _mt_seed(seed: int) -> void:
	_mt.resize(MT_N)
	_mt[0] = seed & 0xffffffff
	for i in range(1, MT_N):
		_mt[i] = (1812433253 * (_mt[i-1] ^ (_mt[i-1] >> 30)) + i) & 0xffffffff
	_mt_index = MT_N

func _mt_generate() -> void:
	for i in range(MT_N):
		var y = (_mt[i] & MT_UPPER_MASK) | (_mt[(i+1) % MT_N] & MT_LOWER_MASK)
		_mt[i] = _mt[(i + MT_M) % MT_N] ^ (y >> 1)
		if y % 2 != 0:
			_mt[i] ^= MT_MATRIX_A
	_mt_index = 0

func _randf() -> float:
	if _mt_index >= MT_N:
		_mt_generate()
	var y = _mt[_mt_index]
	_mt_index += 1
	y ^= (y >> 11)
	y ^= (y << 7)  & 0x9d2c5680
	y ^= (y << 15) & 0xefc60000
	y ^= (y >> 18)
	return float(y & 0xffffffff) / float(0xffffffff)

func _randi_range(a: int, b: int) -> int:
	return a + int(_randf() * (b - a + 1))

# ── CRÍTICO ───────────────────────────────────────────────
func is_critical(p_crit: float) -> bool:
	var hits = 0
	for i in N_SAMPLES:
		if _randf() < p_crit: hits += 1
	var result = (hits / float(N_SAMPLES)) >= p_crit
	print("[MC] crítico: hits=%d/%d → %s" % [hits, N_SAMPLES, result])
	return result

# ── EVASIÓN ───────────────────────────────────────────────
func is_evaded(p_eva: float) -> bool:
	var hits = 0
	for i in N_SAMPLES:
		if _randf() < p_eva: hits += 1
	return (hits / float(N_SAMPLES)) >= p_eva

# ── DAÑO CON VARIANZA ─────────────────────────────────────
func roll_damage(dmg_min: int, dmg_max: int) -> int:
	var total = 0
	for i in N_SAMPLES:
		total += _randi_range(dmg_min, dmg_max)
	var avg = int(total / float(N_SAMPLES))
	var final_dmg = _randi_range(max(dmg_min, avg - 3), min(dmg_max, avg + 3))
	print("[MC] daño: avg=%d final=%d" % [avg, final_dmg])
	return final_dmg

# ── LOOT ──────────────────────────────────────────────────
func roll_loot(loot_table: Array) -> String:
	var r = _randf()
	var acc = 0.0
	for entry in loot_table:
		acc += entry.prob
		if r <= acc: return entry.item
	return "nada"
