class_name TeamShape
extends RefCounted
## Forma del equipo como unidad (pura, testeable). A partir de la formación,
## el estado táctico del equipo y la pelota (en espacio de equipo) calcula el
## objetivo de cada puesto:
## - la línea defensiva sube y baja con la pelota (altura según el estado),
## - las líneas se estiran al atacar y se juntan al defender (compacidad),
## - el bloque se abre a lo ancho con la pelota y se cierra sin ella,
##   corriéndose hacia el lado de la pelota,
## - roles: laterales que pasan por su banda (y el del otro lado cierra),
##   delanteros en la última línea, volante defensivo siempre detrás de la
##   pelota, extremos abiertos; sin la pelota, casi todos detrás de ella.
## Espacio de equipo: x 0..1 (arco propio -> rival), y -1..1 (y < 0 = derecha
## mirando al ataque).

enum State { DEFENDING, BUILD_UP, ATTACKING, COUNTER_ATTACK, PRESSING, RETREATING }

const STATE_NAMES := ["DEFENSA", "SALIDA", "ATAQUE", "CONTRAATAQUE", "PRESIÓN", "REPLIEGUE"]


## Parámetros de forma de un estado.
class Params:
	## Distancia (en fracción de cancha) de la línea defensiva detrás de la pelota.
	var depth: float
	## Límites de altura de la línea defensiva.
	var line_min: float
	var line_max: float
	## Distancia entre la línea defensiva y la delantera (compacidad vertical).
	var span: float
	## Ancho (1 = usa toda la cancha) y corrimiento hacia el lado de la pelota.
	var width: float
	var shift: float
	## Cuánto sube el lateral del lado de la pelota al atacar.
	var fb_overlap: float
	var in_possession: bool

	func _init(p_depth: float, p_min: float, p_max: float, p_span: float, p_width: float, p_shift: float,
			p_overlap: float, p_poss: bool) -> void:
		depth = p_depth
		line_min = p_min
		line_max = p_max
		span = p_span
		width = p_width
		shift = p_shift
		fb_overlap = p_overlap
		in_possession = p_poss


static func params_for(state: int) -> Params:
	match state:
		State.DEFENDING:
			return Params.new(0.3, 0.1, 0.45, 0.3, 0.62, 0.38, 0.0, false)
		State.PRESSING:
			return Params.new(0.22, 0.24, 0.62, 0.3, 0.72, 0.34, 0.0, false)
		State.RETREATING:
			return Params.new(0.36, 0.06, 0.34, 0.28, 0.6, 0.3, 0.0, false)
		State.BUILD_UP:
			return Params.new(0.06, 0.07, 0.36, 0.48, 0.95, 0.14, 0.0, true)
		State.COUNTER_ATTACK:
			return Params.new(0.4, 0.18, 0.5, 0.5, 0.85, 0.1, 0.08, true)
	# ATTACKING
	return Params.new(0.3, 0.25, 0.62, 0.44, 0.95, 0.2, 0.2, true)


## Objetivos (espacio de equipo) de los 11 puestos.
## Cuánto se adelanta el bloque por punto de mentalidad (espacio de equipo).
const MENTALITY_PUSH := 0.045


static func compute(formation: FormationData, state: int, ball: Vector2, strategy: int = 0,
		mentality: int = 0) -> Array[Vector2]:
	var p := params_for(state)
	var def_base := 1.0
	var fw_base := 0.0
	for i in range(1, formation.slots.size()):
		var k := formation.tactical_role(i)
		if TacticalRole.is_defender(k):
			def_base = minf(def_base, formation.slots[i].x)
		fw_base = maxf(fw_base, formation.slots[i].x)
	if fw_base - def_base < 0.05:
		fw_base = def_base + 0.25
	var line := clampf(ball.x - p.depth, p.line_min, p.line_max)
	var out: Array[Vector2] = []
	var st_count := 0
	for i in formation.slots.size():
		var slot := formation.slots[i]
		var role := formation.tactical_role(i)
		if role == TacticalRole.Kind.GK:
			out.append(Vector2(0.015, clampf(ball.y * 0.12, -0.07, 0.07)))
			continue
		var rel := (slot.x - def_base) / (fw_base - def_base)
		var x := line + rel * p.span
		var y := slot.y * p.width + ball.y * p.shift
		var same_side := signf(slot.y) == signf(ball.y) and absf(ball.y) > 0.15
		if p.in_possession:
			match role:
				TacticalRole.Kind.FB:
					if state == State.BUILD_UP:
						# Salida: laterales abiertos y algo adelantados.
						x = line + 0.08
						y = signf(slot.y) * 0.86
					elif same_side:
						# Lateral del lado de la pelota: pasa al ataque por fuera.
						x += p.fb_overlap
						y = signf(slot.y) * 0.9
					else:
						# El del otro lado cierra y equilibra.
						x -= 0.04
						y = slot.y * 0.55
				TacticalRole.Kind.WM, TacticalRole.Kind.WF:
					y = signf(slot.y) * maxf(absf(y), 0.84)
					x += 0.04
				TacticalRole.Kind.ST:
					# En la última línea, por delante de la pelota; con dos
					# delanteros, uno se ofrece más corto.
					x = maxf(x, minf(ball.x + 0.13, 0.9))
					if st_count == 1:
						x -= 0.07
					st_count += 1
				TacticalRole.Kind.DM:
					x = minf(x, ball.x - 0.06)
				TacticalRole.Kind.CB:
					if state == State.BUILD_UP:
						# Centrales abiertos para la salida (el del medio, si hay
						# tres, queda en el centro).
						y = clampf(slot.y * 1.7, -0.6, 0.6)
		else:
			# Sin la pelota casi todos quedan detrás de ella.
			match role:
				TacticalRole.Kind.ST:
					x = minf(x, ball.x + 0.2)
				TacticalRole.Kind.WF:
					x = minf(x, ball.x + 0.12)
				_:
					x = minf(x, ball.x + 0.02)
			# Los defensores forman una línea (misma altura).
			if TacticalRole.is_defender(role):
				x = line + (0.02 if role == TacticalRole.Kind.FB else 0.0)
		# Mentalidad: con la pelota, el bloque sube (ofensiva) o se queda
		# (defensiva); los laterales y volantes son los que más cambian.
		if mentality != 0:
			var k := 1.0
			if role == TacticalRole.Kind.FB or role == TacticalRole.Kind.CM or role == TacticalRole.Kind.DM:
				k = 1.6
			elif role == TacticalRole.Kind.ST or role == TacticalRole.Kind.WF:
				k = 0.5
			x += mentality * MENTALITY_PUSH * k * (1.0 if p.in_possession else 0.5)
		var r: Vector2 = TacticalRole.X_RANGE[role]
		var adj := Strategy.adjust(strategy, role, Vector2(x, y), ball, p.in_possession)
		var top := r.y + (0.08 if strategy == Strategy.Kind.OFFSIDE_TRAP else 0.0)
		out.append(Vector2(clampf(adj.x, r.x, top), clampf(adj.y, -0.95, 0.95)))
	return out


## Altura (espacio de equipo) de la línea defensiva para un estado y una pelota.
static func defensive_line(state: int, ball_x: float) -> float:
	var p := params_for(state)
	return clampf(ball_x - p.depth, p.line_min, p.line_max)
