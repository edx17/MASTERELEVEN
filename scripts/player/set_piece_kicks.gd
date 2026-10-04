class_name SetPieceKicks
extends RefCounted
## Tiros libres y penales como en el Winning Eleven 2002.
##
## Tiro libre (cámara atrás del pateador): la dirección la da la cámara
## (stick derecho); lo que se mantiene apretado en el stick izquierdo o la
## cruceta al patear decide el tipo de remate:
##   Cuadrado sin dirección ........ remate normal (parábola media).
##   Atrás + Cuadrado .............. colocado: sube por encima de la barrera y
##                                   cae (ideal potencia 7; con 8, más recto).
##   Adelante + toque de Cuadrado .. rasante por debajo de la barrera.
##   Adelante + Cuadrado cargado ... cañonazo casi recto (de 30-40 m, potencia
##                                   8 o más; con menos pierde fuerza).
##   Costado + Cuadrado ............ comba hacia ese lado (según la "curva").
##   Diagonal adelante + toque de Círculo .. globito al segundo palo.
##   Atrás + Círculo a fondo ....... rasante fuerte al palo del arquero.
## Los atributos cuentan: potencia de remate (velocidad y parábola),
## precisión (error) y curva (cuánto dobla). "Especialista" erra menos.
##
## Penal: 5 direcciones con el stick al patear (arriba a cada lado, abajo a
## cada lado, al medio). La fuerza sube la pelota; pasada (> 92 %) se va por
## arriba. Los malos pateadores erran más.

enum Fk { NORMAL, PLACED, LOW, POWER, CURL, SOFT_LOB, LOW_POST }

## Tope del toque corto (rasante / globito).
const TAP := 0.35
## Comba de un tiro libre (rad/s por unidad de stick) y caída del colocado.
const CURL := 52.0
const DIP := 30.0
## Puntos del arco para el penal (z a cada lado, alturas arriba / abajo).
const PK_SIDE_Z := 2.85
const PK_HIGH := 1.95
const PK_LOW := 0.35
const PK_OVERHIT := 0.92


## Tipo de tiro libre según el botón, el stick (en pantalla: z < 0 adelante)
## y la potencia cargada.
static func fk_type(kind: int, stick: Vector3, power: float) -> int:
	var fwd := -stick.z
	var side := stick.x
	var held := stick.length() > 0.35
	if kind == KickActions.Kind.LONG_PASS:
		if held and fwd < -0.5 and power > 0.85:
			return Fk.LOW_POST
		return Fk.SOFT_LOB
	if not held:
		return Fk.NORMAL
	if fwd < -0.5 and absf(side) < 0.6:
		return Fk.PLACED
	if fwd > 0.5 and absf(side) < 0.5:
		return Fk.LOW if power <= TAP else Fk.POWER
	return Fk.CURL


## Nivel de potencia como en el WE (6 a 9) a partir del atributo.
static func power_level(data: PlayerData) -> float:
	var sp: int = data.shot_power if data != null and data.shot_power > 0 else 60
	return lerpf(5.5, 9.3, PlayerData.unit(sp))


## Patea el tiro libre. `aim`: dirección en la cancha (la de la cámara).
## `stick`: lo que se mantiene al patear (pantalla). `keeper_z`: dónde está
## el arquero (para el rasante a su palo y el globito al otro).
static func free_kick(k: KickActions, player: Footballer, aim: Vector3, kind: int, stick: Vector3,
		power: float, keeper_z: float, right_world: Vector3 = Vector3.ZERO) -> int:
	var ball := k.ball
	var t := k.tuning
	var data := player.data
	var type := fk_type(kind, stick, power)
	var side := player.team.attack_dir
	var goal_x := side * Pitch.HALF_LENGTH
	aim.y = 0.0
	aim = aim.normalized() if aim.length_squared() > 0.01 else Vector3(side, 0.0, 0.0)
	# Punto del arco hacia donde apunta la cámara (puede quedar afuera).
	var dx := goal_x - ball.flat_pos().x
	var target_z := ball.flat_pos().z + aim.z / maxf(absf(aim.x), 0.05) * absf(dx)
	if type == Fk.SOFT_LOB:
		target_z = -signf(keeper_z if absf(keeper_z) > 0.2 else ball.flat_pos().z) * 2.9
	elif type == Fk.LOW_POST:
		target_z = signf(keeper_z if absf(keeper_z) > 0.2 else -ball.flat_pos().z) * 3.0
	var to := Vector3(goal_x, 0.0, target_z) - ball.flat_pos()
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	var dist := to.length()
	var lvl := power_level(data)
	var curve_k := lerpf(0.55, 1.35, PlayerData.unit(data.curve)) if data != null and data.curve > 0 else 1.0
	var err := KickAccuracy.shot_error(data.shooting if data else 60, data.technique if data else 60,
		data.balance if data else 60, 0.0, 0.0, dist, power)
	if data != null and data.has_ability("especialista"):
		err *= 0.6
	var speed := 20.0
	var height := 1.6
	var spin := Vector3.ZERO
	var along := flat
	var axis := along.cross(Vector3.UP).normalized()
	match type:
		Fk.NORMAL:
			speed = lerpf(17.0, 26.0, power) * lerpf(0.9, 1.06, (lvl - 6.0) / 3.0)
			height = lerpf(1.3, 2.3, power)
		Fk.PLACED:
			# Sube por encima de la barrera y cae: potencia 7 es la ideal; con
			# 8 o más sale más recto (más riesgo de pegar en la barrera).
			var flatness := clampf((lvl - 7.0) / 2.0, 0.0, 1.0)
			speed = lerpf(15.5, 21.0, power) * (1.0 + 0.08 * flatness)
			height = lerpf(1.7, 2.3, power)
			spin = -axis * DIP * lerpf(1.25, 0.55, flatness)
			err *= 0.9
		Fk.LOW:
			speed = lerpf(17.0, 22.0, power / TAP)
			height = 0.11
			err *= 0.85
		Fk.POWER:
			# Cañonazo: sólo llega con potencia 8 o más.
			var strong := clampf((lvl - 7.0) / 1.5, 0.0, 1.0)
			speed = lerpf(25.0, 34.0, power) * lerpf(0.82, 1.08, strong)
			height = lerpf(1.2, 2.2, power)
			err *= 1.25
		Fk.CURL:
			speed = lerpf(17.0, 25.0, power)
			height = lerpf(1.5, 2.3, power)
			# Arriba + costado dobla más (y la eleva); de costado solo, menos.
			var amount := clampf(stick.x, -1.0, 1.0) * (1.0 + 0.4 * clampf(-stick.z, 0.0, 1.0))
			# El stick a la derecha (pantalla) dobla hacia la derecha de la
			# pantalla. Con giro +Y la pelota dobla hacia (along.z, 0, -along.x).
			var perp := Vector3(along.z, 0.0, -along.x)
			var to_right := signf(right_world.dot(perp)) if right_world.length_squared() > 0.01 else 1.0
			spin = Vector3(0.0, amount * CURL * curve_k * to_right, 0.0)
		Fk.SOFT_LOB:
			speed = lerpf(13.5, 17.5, power)
			height = 2.25
			spin = -axis * DIP * 0.6
			err *= 0.95
		Fk.LOW_POST:
			speed = lerpf(22.0, 28.0, power)
			height = 0.11
			err *= 1.1
	k.last_error = err
	if k.randomize_error:
		flat = flat.rotated(Vector3.UP, deg_to_rad(randf_range(-err, err)))
		height += randf_range(-1.0, 1.0) * err * 0.07
	var vel: Vector3
	if height < 0.2:
		vel = flat * speed * 0.92
		ball.state.pos.y = t.ball_radius
	else:
		vel = KickActions.shot_velocity(ball.state.pos, flat, dist, height, speed, t)
		# Con caída (colocado) sale un poco más alta para pasar la barrera.
		if type == Fk.PLACED or type == Fk.SOFT_LOB:
			vel.y += speed * 0.12
	ball.intended_receiver = null
	ball.kick(vel, spin, player)
	return type


## Zona del penal según el stick (pantalla): x = -1, 0, 1 (izquierda, medio,
## derecha); y = 1 arriba, -1 abajo, 0 al medio. Sin stick, al medio.
static func penalty_zone(stick: Vector3) -> Vector2i:
	if absf(stick.x) < 0.35:
		return Vector2i(0, 0)
	return Vector2i(int(signf(stick.x)), 1 if stick.z < -0.25 else -1)


## Punto del arco (z del mundo, altura) de una zona; `right_z`: hacia dónde
## queda la "derecha" de la pantalla en z del mundo (+1 / -1).
static func penalty_target(zone: Vector2i, right_z: float, power: float) -> Vector2:
	var z := float(zone.x) * PK_SIDE_Z * right_z
	var h := lerpf(0.5, 1.7, power)
	if zone.y > 0:
		h = PK_HIGH
	elif zone.y < 0:
		h = PK_LOW
	# Más fuerza, más arriba; pasada, se va por arriba del travesaño.
	h += (power - 0.6) * 0.8
	if power > PK_OVERHIT:
		h += (power - PK_OVERHIT) * 22.0
	return Vector2(z, maxf(h, 0.12))


static func penalty(k: KickActions, player: Footballer, zone: Vector2i, right_z: float, power: float) -> void:
	var ball := k.ball
	var data := player.data
	var side := player.team.attack_dir
	var tgt := penalty_target(zone, right_z, power)
	var to := Vector3(side * Pitch.HALF_LENGTH, 0.0, tgt.x) - ball.flat_pos()
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	var err := KickAccuracy.shot_error(data.shooting if data else 60, data.technique if data else 60,
		data.balance if data else 60, 0.0, 0.0, to.length(), power)
	if data != null and data.has_ability("penales"):
		err *= 0.55
	err += KickAccuracy.fatigue_penalty(player.stamina_fraction())
	k.last_error = err
	var h := tgt.y
	if k.randomize_error:
		flat = flat.rotated(Vector3.UP, deg_to_rad(randf_range(-err, err) * 0.8))
		h += randf_range(-1.0, 1.0) * err * 0.05
	var speed := lerpf(17.0, 27.0, power) * lerpf(0.92, 1.06, PlayerData.unit(data.shot_power if data != null and data.shot_power > 0 else 60))
	var vel := KickActions.shot_velocity(ball.state.pos, flat, to.length(), maxf(h, 0.12), speed, k.tuning)
	ball.intended_receiver = null
	ball.kick(vel, Vector3.ZERO, player)


## Probabilidad de que el arquero ataje un penal: adivinó el lado (o los dos
## al medio) y según la altura y su atributo; si se tiró al otro lado, sólo
## una pelota al medio le pega en los pies.
static func penalty_save_chance(shot_zone: Vector2i, keeper_zone: Vector2i, keeper_skill: int) -> float:
	var gk := PlayerData.unit(keeper_skill)
	if shot_zone.x == 0:
		return 0.75 + 0.15 * gk if keeper_zone.x == 0 else 0.12
	if keeper_zone.x != shot_zone.x:
		return 0.0
	var base := 0.32 if shot_zone.y > 0 else 0.55
	if keeper_zone.y == shot_zone.y:
		base += 0.15
	return clampf(base + 0.2 * (gk - 0.5), 0.05, 0.9)
