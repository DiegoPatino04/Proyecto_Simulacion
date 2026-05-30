# QueueModel.gd — Sistema de Colas M/M/1
# Modelo standalone: se instancia en Battle.gd
# Variables entrada: acciones con velocidad (λ)
# Variables salida: orden de procesamiento, tiempo de espera Wq
class_name QueueModel
extends RefCounted

# ── VARIABLES DEL MODELO ──────────────────────────────────
var queue:        Array = []      # cola de acciones pendientes
var lambda:       float = 1.0    # tasa de llegada (acciones/turno)
var mu:           float = 1.5    # tasa de servicio (μ > λ para estabilidad)
var total_processed: int = 0

# ── ENCOLAR ACCIÓN ────────────────────────────────────────
func enqueue(action: Dictionary) -> void:
	# action = { actor: String, speed: int, type: String }
	queue.append(action)
	# Ordenar por velocidad descendente (mayor speed actúa primero)
	queue.sort_custom(func(a, b): return a.speed > b.speed)
	print("[Cola] encolado: %s (speed %d) | cola: %d" % [action.actor, action.speed, queue.size()])

# ── PROCESAR SIGUIENTE ────────────────────────────────────
func process_next() -> Dictionary:
	if queue.is_empty():
		return {}
	var action = queue.pop_front()
	total_processed += 1
	print("[Cola] procesando: %s | restantes: %d" % [action.actor, queue.size()])
	return action

# ── MÉTRICAS M/M/1 ────────────────────────────────────────
# Tiempo promedio en cola: Wq = λ / (μ·(μ-λ))
func get_wait_time() -> float:
	if mu <= lambda: return 999.0   # sistema inestable
	return lambda / (mu * (mu - lambda))

# Utilización del servidor: ρ = λ/μ
func get_utilization() -> float:
	return lambda / mu

func is_empty() -> bool:
	return queue.is_empty()

func clear() -> void:
	queue.clear()
