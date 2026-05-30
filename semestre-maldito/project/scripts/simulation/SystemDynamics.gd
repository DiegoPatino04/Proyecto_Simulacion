# SystemDynamics.gd — Dinámica de Sistemas
# AUTOLOAD: registrar como "SystemDynamics" en Project Settings
# Modelo: dC/dt = k·(1 – C/C_max)  →  método Euler, Δt = 1 turno
# Variables entrada: k (tasa), ataques de corrupción externos
# Variables salida: C(t) normalizado [0,1], modificadores de dificultad
extends Node

# ── PARÁMETROS DE LA EDO ──────────────────────────────────
const K_RATE   = 0.05    # tasa de crecimiento natural por turno
const C_MAX    = 1.0     # corrupción máxima (derrota)

# ── ESTADO ────────────────────────────────────────────────
var corruption: float = 0.0   # C(t) actual ∈ [0.0, 1.0]
var turn_count: int   = 0

# ── ACTUALIZAR UN TURNO (Método de Euler) ─────────────────
# Llamar al inicio de cada turno desde BattleManager/Battle.gd
func update(delta_t: float = 1.0) -> void:
	# dC/dt = K_RATE · (1 – C/C_MAX)
	var dC = K_RATE * (1.0 - corruption / C_MAX)
	corruption += dC * delta_t
	corruption = clampf(corruption, 0.0, C_MAX)
	turn_count += 1
	# Sincronizar con GlobalState
	GlobalState.corruption = corruption
	print("[SD] turno=%d  C(t)=%.3f  dC=%.4f" % [turn_count, corruption, dC])

# ── DAÑO DE CORRUPCIÓN EXTERNO ────────────────────────────
# Llamar cuando un enemigo usa ataque de corrupción
func add_corruption(amount: float) -> void:
	corruption = clampf(corruption + amount, 0.0, C_MAX)
	GlobalState.corruption = corruption
	print("[SD] +corrupción externa: %.3f → total: %.3f" % [amount, corruption])

# ── RESET (por fase del boss o nueva batalla) ─────────────
func reset_phase() -> void:
	corruption = 0.0
	turn_count = 0
	GlobalState.corruption = 0.0
	print("[SD] fase reseteada")

# ── MODIFICADORES DE DIFICULTAD ───────────────────────────
# Estos valores modifican la batalla según C(t)
func get_enemy_speed_bonus() -> int:
	# Enemigos actúan más rápido con más corrupción
	return int(corruption * 5)     # 0 a 5 de bonus de velocidad

func get_damage_multiplier() -> float:
	# Enemigos hacen más daño
	return 1.0 + (corruption * 0.5)  # 1.0× a 1.5×

func is_game_over() -> bool:
	return corruption >= C_MAX
