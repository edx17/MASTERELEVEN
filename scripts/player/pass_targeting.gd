class_name PassTargeting
extends RefCounted
## Selección del receptor de un pase según la dirección del stick (pura, testeable).


## Devuelve el índice del mejor candidato o -1 si no hay ninguno en el cono.
## - `from`: posición del pasador.
## - `dir`: dirección pedida (plano XZ, no hace falta normalizar).
## - `candidates`: posiciones de los compañeros.
## - `prefer_far`: true para pases largos (premia la distancia en vez de penalizarla).
static func choose(from: Vector3, dir: Vector3, candidates: Array[Vector3], cone_degrees: float,
		min_distance: float, max_distance: float, prefer_far: bool = false) -> int:
	var flat_dir := Vector3(dir.x, 0.0, dir.z)
	if flat_dir.length_squared() < 0.0001:
		return -1
	flat_dir = flat_dir.normalized()
	var best := -1
	var best_score := INF
	for i in candidates.size():
		var to := candidates[i] - from
		to.y = 0.0
		var dist := to.length()
		if dist < min_distance or dist > max_distance:
			continue
		var angle := rad_to_deg(flat_dir.angle_to(to / dist))
		if angle > cone_degrees:
			continue
		var dist_term := dist / max_distance
		if prefer_far:
			dist_term = 1.0 - dist_term
		var score := angle / cone_degrees + dist_term * 0.7
		if score < best_score:
			best_score = score
			best = i
	return best
