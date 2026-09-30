class_name SetPieceShape
extends RefCounted
## Posiciones de ambos equipos en las pelotas paradas (en coordenadas del
## mundo). Devuelve {Footballer: Vector3} para los jugadores de campo que no
## ejecutan; el arquero lo maneja su controlador.
## - Saque de arco propio: salida escalonada (centrales abiertos, laterales altos).
##   Del rival: presión alta, delanteros en la puerta del área.
## - Lateral: dos opciones cortas cerca del que saca; el resto según la zona.
## - Córner a favor: cinco cabeceadores al área, una opción corta, dos atrás.
##   En contra: palos, zona en el área chica y en el punto penal, uno para el
##   rebote y uno arriba para la contra.


static func targets(team: Team, restart_type: int, taker_team: int, spot: Vector3, taker: Footballer) -> Dictionary:
	var own := team.index == taker_team
	var field := _outfield(team, taker)
	match restart_type:
		MatchRules.Restart.CORNER:
			return _corner_attack(team, spot, field) if own else _corner_defend(team, field)
		MatchRules.Restart.GOAL_KICK:
			return _goal_kick(team, spot, field, own)
		MatchRules.Restart.THROW_IN:
			return _throw_in(team, spot, field, own)
	return {}


static func _outfield(team: Team, taker: Footballer) -> Array[Footballer]:
	var out: Array[Footballer] = []
	for p in team.players:
		if not p.is_keeper() and p != taker:
			out.append(p)
	return out


static func _ball_ts(team: Team, spot: Vector3) -> Vector2:
	return Vector2(team.progress_of(spot), team.lateral_of(spot))


## Forma del estado dado con la pelota en `spot`, para una lista de jugadores.
static func _shape_targets(team: Team, state: int, spot: Vector3, field: Array[Footballer]) -> Dictionary:
	var shape := TeamShape.compute(team.formation if team.formation else FormationLibrary.build("4-4-2"),
		state, _ball_ts(team, spot))
	var out := {}
	for p in field:
		var slot := team.players.find(p)
		if slot >= 0 and slot < shape.size():
			out[p] = team.to_world(shape[slot])
	return out


static func _goal_kick(team: Team, spot: Vector3, field: Array[Footballer], own: bool) -> Dictionary:
	if own:
		return _shape_targets(team, TeamShape.State.BUILD_UP, spot, field)
	# El rival presiona la salida: bloque alto, delanteros en la puerta del área.
	var out := _shape_targets(team, TeamShape.State.PRESSING, spot, field)
	for p in field:
		if TacticalRole.is_forward(p.tactical_role):
			var t: Vector3 = out[p]
			var edge := team.to_world(Vector2(0.78, team.lateral_of(t) * 0.6))
			out[p] = edge
	return out


static func _throw_in(team: Team, spot: Vector3, field: Array[Footballer], own: bool) -> Dictionary:
	var progress := team.progress_of(spot)
	var state := TeamShape.State.DEFENDING
	if own:
		state = TeamShape.State.BUILD_UP if progress < 0.34 else TeamShape.State.ATTACKING
	var out := _shape_targets(team, state, spot, field)
	if not own:
		return out
	# Dos opciones cortas: una hacia adelante por la banda y otra hacia adentro.
	var inward := Vector3(0.0, 0.0, -signf(spot.z))
	var forward := Vector3(team.attack_dir, 0.0, 0.0)
	var options: Array[Vector3] = [
		spot + forward * 8.0 + inward * 5.0,
		spot - forward * 6.0 + inward * 9.0,
	]
	var used: Array[Footballer] = []
	for o in options:
		var best: Footballer = null
		var best_d := INF
		for p in field:
			if p in used:
				continue
			var d := p.flat_pos().distance_to(o)
			if d < best_d:
				best_d = d
				best = p
		if best != null:
			used.append(best)
			out[best] = Pitch.clamp_to_field(o, 1.0)
	return out


static func _corner_attack(team: Team, spot: Vector3, field: Array[Footballer]) -> Dictionary:
	var side := float(team.attack_dir)
	var zs := signf(spot.z) if spot.z != 0.0 else 1.0
	var hl := Pitch.HALF_LENGTH
	var box: Array[Vector3] = [
		Vector3(side * (hl - 4.5), 0.0, zs * 2.5), # primer palo
		Vector3(side * (hl - 5.0), 0.0, -zs * 3.5), # segundo palo
		Vector3(side * (hl - 10.0), 0.0, 0.0), # punto penal
		Vector3(side * (hl - 6.5), 0.0, -zs * 0.5), # centro del área chica
		Vector3(side * (hl - 13.0), 0.0, -zs * 6.0), # borde, segundo palo
	]
	var out := {}
	# Los mejores cabeceadores van al área.
	var by_heading := field.duplicate()
	by_heading.sort_custom(func(a: Footballer, b: Footballer) -> bool:
		return (a.data.heading if a.data else 50) > (b.data.heading if b.data else 50))
	var rest: Array[Footballer] = []
	for i in by_heading.size():
		var p: Footballer = by_heading[i]
		if i < box.size():
			out[p] = box[i]
		else:
			rest.append(p)
	# Opción corta, dos al borde del área y el resto atrás para cuidar la contra.
	var others: Array[Vector3] = [
		spot + Vector3(-side * 6.0, 0.0, -zs * 6.0),
		team.to_world(Vector2(0.78, 0.45)),
		team.to_world(Vector2(0.78, -0.45)),
		team.to_world(Vector2(0.5, 0.3)),
		team.to_world(Vector2(0.5, -0.3)),
	]
	for i in rest.size():
		out[rest[i]] = Pitch.clamp_to_field(others[mini(i, others.size() - 1)], 1.0)
	return out


static func _corner_defend(team: Team, field: Array[Footballer]) -> Dictionary:
	var g := float(team.own_side())
	var hl := Pitch.HALF_LENGTH
	var spots: Array[Vector3] = [
		Vector3(g * (hl - 0.5), 0.0, -(Pitch.GOAL_HALF_WIDTH - 0.3)), # palo
		Vector3(g * (hl - 0.5), 0.0, Pitch.GOAL_HALF_WIDTH - 0.3), # palo
		Vector3(g * (hl - 5.5), 0.0, -4.0),
		Vector3(g * (hl - 5.5), 0.0, -1.3),
		Vector3(g * (hl - 5.5), 0.0, 1.3),
		Vector3(g * (hl - 5.5), 0.0, 4.0),
		Vector3(g * (hl - 10.0), 0.0, -3.0),
		Vector3(g * (hl - 10.0), 0.0, 3.0),
		Vector3(g * (hl - 17.0), 0.0, 0.0), # rebote
		team.to_world(Vector2(0.45, 0.0)), # arriba para la contra
	]
	return _assign_nearest(field, spots)


## Asigna cada puesto al jugador libre más cercano (codicioso, en orden).
static func _assign_nearest(field: Array[Footballer], spots: Array[Vector3]) -> Dictionary:
	var out := {}
	var free := field.duplicate()
	for s in spots:
		if free.is_empty():
			break
		var best: Footballer = null
		var best_d := INF
		for p in free:
			var d: float = p.flat_pos().distance_to(s)
			if d < best_d:
				best_d = d
				best = p
		out[best] = s
		free.erase(best)
	return out
