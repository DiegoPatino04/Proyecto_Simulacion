# MonteCarlo.gd — Simulación Monte Carlo
# Modelo standalone: se instancia en Battle.gd
# Estima probabilidades por muestreo aleatorio (N iteraciones)
# Variables entrada: probabilidades, rangos de daño
# Variables salida: bool de evento, valor de daño estimado
class_name MonteCarlo
extends RefCounted

# ── PARÁMETROS ────────────────────────────────────────────
const N_SAMPLES = 100    # iteraciones por estimación

# ── CRÍTICO ───────────────────────────────────────────────
# Devuelve true con probabilidad p_crit
func is_critical(p_crit: float) -> bool:
	var hits = 0
	for i in N_SAMPLES:
		if randf() < p_crit: hits += 1
	var result = (hits / float(N_SAMPLES)) >= p_crit
	print("[MC] crítico: hits=%d/%d → %s" % [hits, N_SAMPLES, result])
	return result

# ── EVASIÓN ───────────────────────────────────────────────
func is_evaded(p_eva: float) -> bool:
	var hits = 0
	for i in N_SAMPLES:
		if randf() < p_eva: hits += 1
	return (hits / float(N_SAMPLES)) >= p_eva

# ── DAÑO CON VARIANZA ─────────────────────────────────────
# Estima daño promedio en [dmg_min, dmg_max] por N muestras
func roll_damage(dmg_min: int, dmg_max: int) -> int:
	var total = 0
	for i in N_SAMPLES:
		total += randi_range(dmg_min, dmg_max)
	var avg = int(total / float(N_SAMPLES))
	# Ajustar con una muestra final para mantener varianza real
	var final_dmg = randi_range(max(dmg_min, avg - 3), min(dmg_max, avg + 3))
	print("[MC] daño: avg=%d final=%d" % [avg, final_dmg])
	return final_dmg

# ── LOOT ──────────────────────────────────────────────────
# loot_table = [{item, prob}, ...]  prob suma 1.0
func roll_loot(loot_table: Array) -> String:
	var r = randf()
	var acc = 0.0
	for entry in loot_table:
		acc += entry.prob
		if r <= acc: return entry.item
	return "nada"
