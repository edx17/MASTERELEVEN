class_name HumanController
extends RefCounted
## Control de un jugador humano sobre su equipo: movimiento, sprint, barra de
## potencia para pases/tiros, toque de primera (acción "guardada" mientras llega
## la pelota), presión, barrida y cambio de jugador automático + manual.
## Combinaciones (como en el WE):
##   L1 + Cuadrado = globo · doble Cuadrado = remate rasante
##   L1 + Círculo = centro alto · doble Círculo = centro raso
##   L1 + X = pared · L1 + R1 = super cancel · L1 x3 = bicicleta
##   L1 + R1 + Cuadrado = remate potente (carga y perfila más lento)
##   Cuadrado + X / Círculo + X = amague · stick derecho 360° = marsellesa
##   L1 mantenido con la pelota = conducción cerrada; sin la pelota, cambia de jugador.

const KICK_BUTTONS := {
	&"pass_short": KickActions.Kind.SHORT_PASS,
	&"shoot": KickActions.Kind.SHOT,
	&"pass_long": KickActions.Kind.LONG_PASS,
	&"pass_through": KickActions.Kind.THROUGH_PASS,
}
const AUTO_SWITCH_MARGIN := 4.0
## Ángulo a partir del cual mover el stick cuenta como "nueva orden" y le
## devuelve el control del receptor al jugador.
const RECEIVE_RELEASE_ANGLE := deg_to_rad(50.0)
## Durante cuánto se recuerda la última dirección del stick (para pasar hacia
## donde se apuntó aunque el stick ya se haya soltado al apretar el botón).
const AIM_MEMORY := 0.35
## Ventana del doble toque (remate rasante / centro raso), de los tres toques
## de L1 (bicicleta) y del giro del stick derecho (marsellesa).
const DOUBLE_TAP := 0.2
const TRIPLE_TAP := 0.8
const SPIN_WINDOW := 1.0
## Remate potente: la barra carga más lento y el jugador tarda en perfilarse.
const POWER_CHARGE_SLOW := 1.6
const POWER_WINDUP := 0.3

var slot: int = 0
var team: Team
## Fuente de órdenes (HumanInput por defecto; intercambiable).
var input: InputSource
var controlled: Footballer = null
## Botones silenciados hasta soltarlos (se usaron con L2 para una estrategia).
var _strategy_mute := false

## Barra de potencia (se muestra en el HUD).
var charging_action: StringName = &""
var power: float = 0.0
var _buffered_kind: int = -1
var _buffered_power: float = 0.0
var _buffered_dir: Vector3 = Vector3.ZERO
var _buffered_receiver: Footballer = null
var _buffered_variant: int = KickActions.Variant.NORMAL
var _buffered_one_two: bool = false
## L1 estaba apretado al empezar a cargar (globo, centro alto, pared).
var _charge_l1: bool = false
## Remate / centro soltado esperando un posible segundo toque:
## {kind, power, aim, target, time}. Vacío = nada pendiente.
var _tap := {}
## R2 apretado mientras se cargaba el remate: sale colocado.
var _charge_placed := false
## L1 + R1 al empezar a cargar el remate: remate potente.
var _charge_power := false
## Remate potente soltado: el jugador se perfila (frena y arma la pierna)
## antes de pegarle. {power, aim, t}. Vacío = nada.
var _windup := {}
var _l1_taps: Array[float] = []
var _spin_acc: float = 0.0
var _spin_prev: float = INF
var _spin_time: float = 0.0
var _clock: float = 0.0
## Super cancel: el jugador deja de ir solo a buscar la pelota.
var _auto_off: bool = false
## Compañero que recibiría el pase que se está cargando (marcado en la cancha).
var preview_receiver: Footballer = null
## Recepción asistida trabada: tras pasar, el receptor va a buscar la pelota
## aunque el stick siga apretado en la dirección del pase.
var _receive_lock: bool = false
var _receive_lock_dir: Vector3 = Vector3.ZERO
var _aim_dir: Vector3 = Vector3.ZERO
var _aim_age: float = 999.0
var _switch_cooldown: float = 0.0
## L1: segundos hacia adelante en que se mira la pelota y ventaja (m) de los
## que están entre la pelota y el arco propio al defender.
const SWITCH_LOOKAHEAD := 0.45
const SWITCH_GOAL_SIDE_BONUS := 4.0
## Último pase (contador de patadas del partido) ya usado para cambio automático.
var _handled_kick: int = -1

var _match: MatchController
## Stick en rumbos fijos (8/16, estilo WE2002); se lee de GameSettings.
var _directions := StickDirections.new()


func _init(p_slot: int, p_team: Team, p_match: MatchController, p_input: InputSource = null) -> void:
	slot = p_slot
	team = p_team
	_match = p_match
	input = p_input if p_input != null else HumanInput.new(slot)


func is_charging() -> bool:
	return charging_action != &""


func select(player: Footballer) -> void:
	if player == controlled:
		return
	cancel_order()
	if controlled != null:
		controlled.set_human_slot(-1)
		controlled.desired_move = Vector3.ZERO
		controlled.wants_sprint = false
		controlled.pressing = false
	controlled = player
	if controlled != null:
		controlled.set_human_slot(slot)
		controlled.clear_pass_target()


## El más cercano a la pelota (sin contar al arquero), opcionalmente excluyendo uno.
func nearest_to_ball(exclude: Footballer = null) -> Footballer:
	var best: Footballer = null
	var best_d := INF
	var bp := _match.ball.flat_pos()
	for p in team.players:
		if p == exclude or p.is_keeper() or (p.is_human() and p.human_slot != slot):
			continue
		var d := p.flat_pos().distance_to(bp)
		if d < best_d:
			best_d = d
			best = p
	return best


## A quién pasa el control con L1 (al instante): el destinatario de un pase
## que viaja; si no, el que mejor llega adonde va a estar la pelota en un
## momento. Defendiendo, pesan más los que están entre la pelota y el arco
## propio (los que pueden cortar la línea).
func switch_target() -> Footballer:
	var ball := _match.ball
	var recv := ball.intended_receiver
	if recv != null and recv.team == team and recv != controlled and not recv.is_keeper() and ball.is_loose():
		return recv
	var ahead := ball.flat_pos() + Vector3(ball.state.vel.x, 0.0, ball.state.vel.z) * SWITCH_LOOKAHEAD
	var rival_has_it := ball.owner_player != null and ball.owner_player.team != team
	var own_goal := team.own_goal()
	var best: Footballer = null
	var best_score := INF
	for p in team.players:
		if p == controlled or p.is_keeper() or (p.is_human() and p.human_slot != slot):
			continue
		var score := p.flat_pos().distance_to(ahead)
		if rival_has_it:
			# Entre la pelota y el arco propio: puede cerrar el camino.
			var to_goal := own_goal - ahead
			var along := (p.flat_pos() - ahead).dot(to_goal.normalized())
			if along > 0.0 and along < to_goal.length():
				score -= SWITCH_GOAL_SIDE_BONUS
		if score < best_score:
			best_score = score
			best = p
	return best


## Botones de las estrategias (L2 + X / Cuadrado / Círculo / Triángulo).
const STRATEGY_BUTTONS: Array[StringName] = [&"pass_short", &"shoot", &"pass_long", &"pass_through"]


## L2 (o R) mantenido + un botón: activa o apaga la estrategia de ese botón.
## Mientras tanto (y hasta soltarlos) los botones no patean.
func _strategy_buttons() -> void:
	input.muted.clear()
	var held := input.pressed(&"strategy")
	if held:
		for i in STRATEGY_BUTTONS.size():
			if input.just_pressed(STRATEGY_BUTTONS[i]):
				_match.toggle_strategy(team, i)
		# L2 + cruceta izquierda / derecha: mentalidad más defensiva / ofensiva.
		if input.just_pressed(&"mentality_down"):
			_match.set_mentality(team, team.mentality - 1)
		if input.just_pressed(&"mentality_up"):
			_match.set_mentality(team, team.mentality + 1)
	if held or _strategy_mute:
		_strategy_mute = false
		for b in STRATEGY_BUTTONS:
			if input.pressed(b):
				_strategy_mute = true
		input.muted.assign(STRATEGY_BUTTONS)
		if not held and not _strategy_mute:
			input.muted.clear()


func tick(dt: float) -> void:
	input.poll()
	_switch_cooldown = maxf(0.0, _switch_cooldown - dt)
	var ball := _match.ball
	_auto_switch(ball)

	_strategy_buttons()
	var l1 := input.pressed(&"special")
	var r1 := input.pressed(&"sprint")
	_clock += dt
	# Super cancel (L1 + R1): se cancela la orden, la pared y la carrera
	# automática a buscar la pelota.
	if l1 and r1 and (input.just_pressed(&"special") or input.just_pressed(&"sprint")):
		cancel_order()
		_tap = {}
		_match.cancel_one_two()
		_receive_lock = false
		_auto_off = true
	var p0 := controlled
	var has_ball := p0 != null and ball.owner_player == p0
	if _auto_off and ball.owner_player != null:
		_auto_off = false
	# L1 sin la pelota = cambio de jugador (con la pelota es gambeta).
	if input.just_pressed(&"special") and not r1 and not has_ball and not _match.is_restart_taker(controlled):
		var next := switch_target()
		if next != null:
			select(next)
			_switch_cooldown = 1.0

	var p := controlled
	if p == null:
		_set_preview(null)
		return

	# El stick está en coordenadas de pantalla: se traduce según la cámara.
	# Para apuntar pases se usa el ángulo exacto; para correr, el rumbo fijo
	# más cercano (8/16 direcciones, como el WE2002).
	var raw := input.move_vector()
	var aim_move := _match.screen_to_world(raw)
	_directions.steps = GameSettings.stick_directions
	var move := _match.screen_to_world(_directions.apply(raw))
	_aim_age += dt
	if aim_move.length_squared() > 0.09:
		_aim_dir = aim_move.normalized()
		_aim_age = 0.0
	var opponent_has_ball := ball.owner_player != null and ball.owner_player.team != team

	move = _apply_receive_lock(p, ball, move)
	# Arquero con la pelota en las manos: camina, pero no sale del área.
	if p.is_keeper() and ball.in_hands and ball.owner_player == p and move.length_squared() > 0.01:
		if not Pitch.in_penalty_area(p.flat_pos() + move.normalized() * 0.8, team.own_side()):
			move = Vector3.ZERO
	# Antes del saque del medio no se mueve nadie (sólo el que saca apunta).
	if _match.waiting_kickoff(p):
		move = Vector3.ZERO
	p.wants_sprint = r1 and not l1
	p.desired_move = move
	p.pressing = false
	# L1 mantenido con la pelota: conducción cerrada (gambeta).
	p.close_control = has_ball and l1 and not r1

	# Tiro libre con la cámara atrás: el stick derecho gira la mira (y la
	# cámara); el pateador no gira en el lugar.
	if _match.free_kick_camera_active() and _match.is_restart_taker(p):
		_match.turn_set_piece_aim(input.right_vector().x, dt)

	# Remate potente perfilándose: frena, no acepta otra orden y le pega al
	# terminar el armado (si todavía la tiene al alcance).
	if not _windup.is_empty():
		p.desired_move = move * 0.25
		p.wants_sprint = false
		_windup["t"] -= dt
		if _windup["t"] <= 0.0:
			var w := _windup
			_windup = {}
			if _match.can_kick(p):
				_do_kick(KickActions.Kind.SHOT, w["power"], w["aim"], null, KickActions.Variant.POWER)
		elif ball.owner_player != p and not _match.can_kick(p):
			_windup = {} # se la sacaron mientras armaba
		return

	# Gambetas con la pelota: bicicleta (L1 x3) y marsellesa (stick derecho 360°).
	if has_ball and _match.phase != MatchController.Phase.RESTART:
		if input.just_pressed(&"special"):
			_l1_taps.append(_clock)
			while not _l1_taps.is_empty() and _clock - _l1_taps[0] > TRIPLE_TAP:
				_l1_taps.pop_front()
			if _l1_taps.size() >= 3:
				_l1_taps.clear()
				_match.perform_skill(p, Footballer.Skill.STEPOVER)
		if _right_stick_spin(dt):
			_match.perform_skill(p, Footballer.Skill.ROULETTE)
	else:
		_l1_taps.clear()

	# Pared en curso: con el stick suelto, el que la tocó pica al espacio.
	if not _match.one_two.is_empty() and _match.one_two.get("passer") == p and move.length_squared() < 0.04:
		var to_run: Vector3 = (_match.one_two["run"] as Vector3) - p.flat_pos()
		if to_run.length() > 0.6:
			p.desired_move = to_run.normalized()
			p.wants_sprint = true

	# Recepción asistida: con el stick suelto, el receptor de un pase va al
	# encuentro de la pelota (como en WE); mover el stick lo cancela. Si ya
	# pidió un toque de primera (cargando o guardado), el stick sólo apunta el
	# próximo pase: el receptor sigue yendo a la pelota.
	var one_touch_pending := is_charging() or _buffered_kind >= 0
	var incoming := ball.is_loose() and ball.intended_receiver == p
	# Con una orden guardada y el stick suelto también va a buscar una pelota
	# suelta cualquiera (como en WE: "esperando" para patear de primera).
	if _buffered_kind >= 0 and ball.is_loose() and move.length_squared() < 0.04:
		incoming = true
	if incoming and not _auto_off and (move.length_squared() < 0.04 or one_touch_pending):
		var meet := _match.loose_ball_intercept(p)
		var to_meet := meet - p.flat_pos()
		if to_meet.length() > 0.4:
			p.desired_move = to_meet.normalized() * clampf(to_meet.length() / 2.0, 0.3, 1.0)
		else:
			p.look_at_point(ball.flat_pos())
	elif incoming and not _auto_off and ball.intended_receiver == p:
		# Como en WE: mientras viene el pase el receptor va al encuentro de la
		# pelota aunque se mueva el stick (si se corre de la línea, la pelota
		# le pasa de largo). El control vuelve apenas la recibe.
		var meet2 := _match.loose_ball_intercept(p)
		var to_meet2 := meet2 - p.flat_pos()
		if to_meet2.length() > 0.4:
			p.desired_move = to_meet2.normalized() * clampf(to_meet2.length() / 2.0, 0.3, 1.0)
		else:
			p.desired_move = Vector3.ZERO
			p.look_at_point(ball.flat_pos())
		p.wants_sprint = false

	# Sin pelota: pase corto mantenido = presionar (corre hacia la pelota) y,
	# al llegar a distancia, intentar la entrada (como en WE). Se puede fallar.
	if opponent_has_ball and input.pressed(&"pass_short") and not is_charging():
		p.pressing = true
		p.wants_tackle = true
		var to_ball := ball.flat_pos() - p.flat_pos()
		if move.length_squared() < 0.04 and to_ball.length() > 0.3:
			p.desired_move = to_ball.normalized()
	# Sin pelota: Cuadrado mantenido = un compañero (CPU) sale a presionar.
	if opponent_has_ball and input.pressed(&"shoot"):
		_match.support_press[team.index] = true
	# Sin pelota: pase al hueco (Triángulo) mantenido = el arquero sale a
	# achicar (con el rival conduciendo o con la pelota suelta que tocó él).
	var rival_ball := opponent_has_ball or (ball.is_loose() and ball.last_touch_team != team.index)
	if rival_ball and input.pressed(&"pass_through"):
		_match.keeper_rush[team.index] = true
	# Sin pelota: pase largo (Círculo / B) = barrida.
	if opponent_has_ball and input.just_pressed(&"pass_long"):
		p.start_slide(move if move.length_squared() > 0.04 else ball.flat_pos() - p.flat_pos())
		return

	# Toques repetidos: el remate / centro soltado espera un instante otro
	# toque. Remate: doble = rasante. Centro (como en WE): 1 = alto al segundo
	# palo, 2 = a media altura, 3 = rasante al primer palo. R2 en ese
	# instante = remate colocado.
	if not _tap.is_empty():
		var action: StringName = _tap["action"]
		if _tap["kind"] == KickActions.Kind.SHOT and input.just_pressed(&"brake"):
			var tp := _tap
			_tap = {}
			_try_kick(tp["kind"], tp["power"], tp["aim"], tp["target"], KickActions.Variant.PLACED)
			return
		if input.just_pressed(action):
			_tap["count"] += 1
			_tap["time"] = 0.0
			if _tap["count"] >= _max_taps(_tap["kind"], p):
				var t := _tap
				_tap = {}
				_try_kick(t["kind"], t["power"], t["aim"], t["target"], tap_variant(t["kind"], t["count"], KickActions.is_cross_position(p, ball.flat_pos())))
				return
		_tap["time"] += dt
		if _tap["time"] >= DOUBLE_TAP:
			var t2 := _tap
			_tap = {}
			_try_kick(t2["kind"], t2["power"], t2["aim"], t2["target"], tap_variant(t2["kind"], t2["count"], KickActions.is_cross_position(p, ball.flat_pos())))

	# R2 conduciendo (sin cargar nada): pisa la pelota y frena en seco (el
	# cambio de ritmo del WE para dejar pasar al defensor).
	if has_ball and not is_charging() and _tap.is_empty() and input.just_pressed(&"brake") and not ball.in_hands:
		_match.stop_with_ball(p)
		return

	# Arquero con la pelota en las manos: Triángulo la suelta para jugarla con
	# los pies (no en un saque de arco: ahí ya está en el piso).
	if p.is_keeper() and ball.in_hands and ball.owner_player == p and input.just_pressed(&"pass_through"):
		_match.keeper_drop(p)
		return

	# Barra de potencia.
	if not is_charging() and not opponent_has_ball and _tap.is_empty():
		for action in KICK_BUTTONS:
			if input.just_pressed(action):
				charging_action = action
				power = 0.0
				_charge_power = l1 and r1 and KICK_BUTTONS[action] == KickActions.Kind.SHOT
				_charge_l1 = l1 and not _charge_power
				_charge_placed = false
				break
	if is_charging():
		power = minf(1.0, power + dt / (_match.tuning.power_charge_time * (POWER_CHARGE_SLOW if _charge_power else 1.0)))
		# R2 mientras se carga el remate: sale colocado.
		if input.just_pressed(&"brake"):
			_charge_placed = true
		var kind: int = KICK_BUTTONS[charging_action]
		var aim := aim_direction(aim_move)
		# Amague (Cuadrado + X / Círculo + X): no patea, engancha.
		if (kind == KickActions.Kind.SHOT or kind == KickActions.Kind.LONG_PASS) and input.just_pressed(&"pass_short"):
			charging_action = &""
			_set_preview(null)
			_match.perform_feint(p, aim)
			return
		# Mientras se carga, se marca a quién va el pase (y se puede corregir
		# con el stick). Al soltar, ese receptor queda "trabado".
		_set_preview(_match.kicks.preview_receiver(kind, p, aim) if kind != KickActions.Kind.SHOT else null)
		if input.just_released(charging_action) or not input.pressed(charging_action):
			var released := charging_action
			charging_action = &""
			var target := preview_receiver
			_set_preview(null)
			if _charge_power:
				_windup = {"power": power, "aim": aim, "t": POWER_WINDUP}
			elif _charge_l1:
				# L1 + botón: globo, centro alto o pared.
				match kind:
					KickActions.Kind.SHOT, KickActions.Kind.LONG_PASS:
						_try_kick(kind, power, aim, target, KickActions.Variant.HIGH)
					KickActions.Kind.SHORT_PASS:
						_try_kick(kind, power, aim, target, KickActions.Variant.NORMAL, true)
					KickActions.Kind.THROUGH_PASS:
						# L1 + Triángulo: filtrado por elevación.
						_try_kick(kind, power, aim, target, KickActions.Variant.HIGH)
					_:
						_try_kick(kind, power, aim, target)
			elif kind == KickActions.Kind.SHOT or kind == KickActions.Kind.LONG_PASS:
				if kind == KickActions.Kind.SHOT and _charge_placed:
					_try_kick(kind, power, aim, target, KickActions.Variant.PLACED)
				else:
					_tap = {"action": released, "kind": kind, "power": power, "aim": aim, "target": target, "time": 0.0, "count": 1}
			else:
				_try_kick(kind, power, aim, target)
	elif _buffered_kind < 0:
		_set_preview(null)

	# Orden guardada (como en WE): el jugador queda esperando la pelota y
	# patea (o cabecea) de primera apenas le llega. Se pierde si el rival la
	# anticipa, si se corta el juego o con el super cancel (L1 + R1).
	if _buffered_kind >= 0:
		if _order_cancelled(ball):
			cancel_order()
		elif _match.can_kick(p):
			var k := _buffered_kind
			_buffered_kind = -1
			_set_preview(null)
			_do_kick(k, _buffered_power, _buffered_dir, _buffered_receiver, _buffered_variant, _buffered_one_two)


## Cuántos toques seguidos se esperan: 3 en un centro, 2 si no.
func _max_taps(kind: int, p: Footballer) -> int:
	if kind == KickActions.Kind.LONG_PASS and KickActions.is_cross_position(p, _match.ball.flat_pos()):
		return 3
	return 2


## Variante según los toques: remate doble = rasante; centro 2 = media
## altura, 3 = rasante al primer palo; pase largo doble = raso.
static func tap_variant(kind: int, count: int, cross: bool) -> int:
	if count <= 1:
		return KickActions.Variant.NORMAL
	if kind == KickActions.Kind.LONG_PASS and cross:
		return KickActions.Variant.MID if count == 2 else KickActions.Variant.LOW
	return KickActions.Variant.LOW


## Giro completo del stick derecho (marsellesa) en menos de SPIN_WINDOW.
func _right_stick_spin(dt: float) -> bool:
	var r := input.right_vector()
	var v := Vector2(r.x, r.z)
	_spin_time += dt
	if v.length() < 0.6:
		if v.length() < 0.3:
			_spin_acc = 0.0
			_spin_prev = INF
			_spin_time = 0.0
		return false
	var a := v.angle()
	if _spin_prev != INF:
		_spin_acc += angle_difference(_spin_prev, a)
	else:
		_spin_time = 0.0
	_spin_prev = a
	if _spin_time > SPIN_WINDOW:
		_spin_acc = 0.0
		_spin_time = 0.0
	if absf(_spin_acc) >= TAU * 0.9:
		_spin_acc = 0.0
		_spin_prev = INF
		return true
	return false


## Hay una orden esperando la pelota.
func has_order() -> bool:
	return _buffered_kind >= 0


func cancel_order() -> void:
	_buffered_kind = -1
	_buffered_receiver = null
	_buffered_one_two = false
	_set_preview(null)


func _order_cancelled(ball: Ball) -> bool:
	if _match.phase != MatchController.Phase.PLAYING:
		return true
	# El rival la anticipó (o un compañero la ganó antes).
	return ball.owner_player != null and ball.owner_player != controlled


## Dirección a usar para un pase/tiro: el stick actual o, si se soltó hace
## muy poco, la última dirección marcada. Vacío = hacia donde mira el jugador.
func aim_direction(move: Vector3) -> Vector3:
	if move.length_squared() > 0.09:
		return move
	if _aim_age <= AIM_MEMORY:
		return _aim_dir
	return Vector3.ZERO


func _set_preview(p: Footballer) -> void:
	if p == preview_receiver:
		return
	if preview_receiver != null:
		preview_receiver.set_pass_marker(-1)
	preview_receiver = p
	# La marca visual es una ayuda opcional (apagada por defecto); el receptor
	# se elige y se traba igual.
	if preview_receiver != null and GameSettings.show_pass_target:
		preview_receiver.set_pass_marker(slot)


func _try_kick(kind: int, pwr: float, move: Vector3, target: Footballer = null,
		variant: int = KickActions.Variant.NORMAL, one_two: bool = false) -> void:
	if controlled == null:
		return
	# Pelota al alcance (conducida o suelta): se patea ya, de primera.
	if _match.can_kick(controlled):
		_do_kick(kind, pwr, move, target, variant, one_two)
		return
	# Si no (la pelota viene o quedó adelantada en la conducción), la orden se
	# guarda y se ejecuta apenas la pelota esté al alcance.
	_buffered_kind = kind
	_buffered_power = pwr
	_buffered_dir = move
	_buffered_receiver = target
	_buffered_variant = variant
	_buffered_one_two = one_two
	_set_preview(target)


func _do_kick(kind: int, pwr: float, move: Vector3, target: Footballer = null,
		variant: int = KickActions.Variant.NORMAL, one_two: bool = false) -> void:
	kind = aerial_kind(kind, controlled, _match.ball)
	var passer := controlled
	var restart := _match.phase == MatchController.Phase.RESTART and _match.is_restart_taker(controlled)
	# Pelota parada a la WE2002: el pateador toma carrera y lo que se
	# mantiene en el stick al llegar decide el tipo de remate.
	if restart and _match.restart_type == MatchRules.Restart.PENALTY and kind == KickActions.Kind.SHOT:
		_match.order_penalty(controlled, pwr, self)
		return
	if restart and _match.free_kick_camera_active() and kind in [KickActions.Kind.SHOT, KickActions.Kind.LONG_PASS]:
		_match.order_free_kick(controlled, kind, pwr, self)
		return
	if restart and _match.restart_type in [MatchRules.Restart.FREE_KICK, MatchRules.Restart.CORNER]:
		# La comba (stick derecho) se aplica cuando le pega, después de la carrera.
		_match.pending_curl = _match.screen_to_world(input.right_vector())
	var receiver := _match.perform_kick(controlled, kind, move, pwr, target, variant)
	_auto_off = false
	if one_two and receiver != null and receiver.team == team and not receiver.is_keeper():
		# Pared: el control se queda en el que la tocó, que pica al espacio.
		_match.start_one_two(passer, receiver)
		_handled_kick = _match.kick_count
		return
	if receiver != null and receiver.team == team and not receiver.is_keeper():
		# Cambio automático al receptor del pase (como en WE).
		select(receiver)
		_handled_kick = _match.kick_count
		# El stick que se usó para pasar no debe mandar al receptor para ese lado.
		_receive_lock = true
		_receive_lock_dir = move.normalized() if move.length_squared() > 0.01 else Vector3.ZERO


## Pelota aérea (al salto o alta): cada botón hace otra cosa.
## X = pase de cabeza a un compañero (sí o sí). Círculo = despeje (con el pie
## o de cabeza). Cuadrado = en campo propio despeja de cabeza; en el rival,
## remate de cabeza (si no está tan alta, de volea). Triángulo = al hueco.
static func aerial_kind(kind: int, p: Footballer, ball: Ball) -> int:
	if p == null or ball.owner_player == p:
		return kind
	var h := ball.state.pos.y
	if kind == KickActions.Kind.LONG_PASS and h > 0.9:
		return KickActions.Kind.CLEAR
	if kind == KickActions.Kind.SHOT and h >= MatchController.HEADER_MIN_HEIGHT and p.team.progress_of(p.flat_pos()) < 0.5:
		return KickActions.Kind.CLEAR
	return kind


## Mientras la pelota viaja hacia el receptor, el stick que quedó apretado en
## la dirección del pase se ignora (el receptor va al encuentro). Se devuelve
## el control al soltar el stick o al moverlo claramente hacia otro lado.
func _apply_receive_lock(p: Footballer, ball: Ball, move: Vector3) -> Vector3:
	if not _receive_lock:
		return move
	if not ball.is_loose() or ball.intended_receiver != p:
		_receive_lock = false
		return move
	if move.length_squared() < 0.04:
		# Soltó el stick: el próximo movimiento ya es una orden nueva.
		_receive_lock = false
		return move
	if _receive_lock_dir == Vector3.ZERO or move.normalized().angle_to(_receive_lock_dir) > RECEIVE_RELEASE_ANGLE:
		_receive_lock = false
		return move
	return Vector3.ZERO


func _auto_switch(ball: Ball) -> void:
	var owner := ball.owner_player
	if owner != null and owner.team == team:
		# También el arquero: con la pelota (en las manos o en los pies tras
		# un pase atrás) lo maneja el humano, como en WE.
		if owner != controlled:
			select(owner)
		return
	if _match.restart_taker != null and _match.restart_taker.team == team and not _match.restart_taker.is_keeper():
		select(_match.restart_taker)
		return
	var recv := ball.intended_receiver
	if recv != null and recv.team == team and ball.is_loose() and not recv.is_keeper():
		if _match.kick_count != _handled_kick:
			_handled_kick = _match.kick_count
			select(recv)
		return
	if controlled == null or controlled.is_keeper():
		# Soltó la pelota el arquero: vuelve a un jugador de campo.
		select(nearest_to_ball())
		return
	# Cargando o con una orden esperando la pelota: no se cambia de jugador.
	if is_charging() or has_order() or _switch_cooldown > 0.0:
		return
	var nearest := nearest_to_ball()
	if nearest != null and nearest != controlled:
		var bp := ball.flat_pos()
		if controlled.flat_pos().distance_to(bp) > nearest.flat_pos().distance_to(bp) + AUTO_SWITCH_MARGIN:
			select(nearest)
			_switch_cooldown = 0.6
