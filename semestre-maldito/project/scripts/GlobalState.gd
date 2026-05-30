# GlobalState.gd
# Autoload: vive durante toda la partida.
# Acceso desde cualquier script: GlobalState.party_hp[0], etc.
extends Node

# ── PARTY ─────────────────────────────────────────────────
var party_hp:       Array[int]   = [80, 80, 80]
var party_hp_max:   Array[int]   = [80, 80, 80]
var party_names:    Array[String] = ["Programador", "Matematico", "TecnicoRedes"]

# ── CORRUPCIÓN (Dinámica de Sistemas) ─────────────────────
var corruption:     float = 0.0   # 0.0 a 1.0
var corruption_max: float = 1.0

# ── ENEMIGO ACTUAL ────────────────────────────────────────
var enemy_name:     String = "Derivator"
var enemy_hp:       int    = 80
var enemy_hp_max:   int    = 80

# ── HELPERS ───────────────────────────────────────────────
func is_party_dead() -> bool:
	for hp in party_hp:
		if hp > 0: return false
	return true

func reset_battle():
	# Llamar al iniciar cada batalla
	party_hp = party_hp_max.duplicate()
	corruption = 0.0
	enemy_hp = enemy_hp_max
