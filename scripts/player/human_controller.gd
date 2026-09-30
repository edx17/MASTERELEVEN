class_name HumanController
extends RefCounted
## Control de un jugador humano sobre su equipo: movimiento, sprint, barra de
## potencia para pases/tiros, toque de primera (acción "guardada" mientras llega
## la pelota), presión, barrida y cambio de jugador automático + manual.

const KICK_BUTTONS := {
	&"pass_short": KickActions.Kind.SHORT_PASS,
	&"shoot": KickActions.Kind.SHOT,
	&"pass_long": KickActions.Kind.LONG_PASS,
	&"pass_through": KickActions.Kind.THROUGH_PASS,
}
const AUTO_SWITCH_MARGIN := 4.0

var slot: int = 0
var team: Team
## Fuente de órdenes (HumanInput por defecto; intercambiable).
var input: InputSource
var controlled: Footballer = null

## Barra de potencia (se muestra en el HUD).
var charging_action: StringName = &""
var power: float = 0.0
var _buffered_kind: int = -1
var _buffered_power: float = 0.0
var _buffered_dir: Vector3 = Vector3.ZERO
var _buffer_timer: float = 0.0
var _switch_cooldown: float = 0.0
## Último pase (contador de patadas del partido) ya usado para cambio automático.
var _handled_kick: int = -1

var _match: MatchController


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


func tick(dt: float) -> void:
	input.poll()
	_switch_cooldown = maxf(0.0, _switch_cooldown - dt)
	_buffer_timer = maxf(0.0, _buffer_timer - dt)
	var ball := _match.ball
	_auto_switch(ball)

	if input.just_pressed(&"switch_player") and not _match.is_restart_taker(controlled):
		var next := nearest_to_ball(controlled)
		if next != null:
			select(next)
			_switch_cooldown = 1.0

	var p := controlled
	if p == null:
		return

	# El stick está en coordenadas de pantalla: se traduce según la cámara.
	var move := _match.screen_to_world(input.move_vector())
	var opponent_has_ball := ball.owner_player != null and ball.owner_player.team != team

	p.wants_sprint = input.pressed(&"sprint")
	p.desired_move = move
	p.pressing = false

	# Recepción asistida: con el stick suelto, el receptor de un pase va al
	# encuentro de la pelota (como en WE); mover el stick lo cancela.
	if move.length_squared() < 0.04 and ball.is_loose() and ball.intended_receiver == p:
		var meet := _match.loose_ball_intercept(p)
		var to_meet := meet - p.flat_pos()
		if to_meet.length() > 0.4:
			p.desired_move = to_meet.normalized() * clampf(to_meet.length() / 2.0, 0.3, 1.0)
		else:
			p.look_at_point(ball.flat_pos())

	# Sin pelota: pase corto mantenido = presionar (corre hacia la pelota) y,
	# al llegar a distancia, intentar la entrada (como en WE). Se puede fallar.
	if opponent_has_ball and input.pressed(&"pass_short") and not is_charging():
		p.pressing = true
		p.wants_tackle = true
		var to_ball := ball.flat_pos() - p.flat_pos()
		if move.length_squared() < 0.04 and to_ball.length() > 0.3:
			p.desired_move = to_ball.normalized()
	# Sin pelota: tiro = barrida.
	if opponent_has_ball and input.just_pressed(&"shoot"):
		p.start_slide(move if move.length_squared() > 0.04 else ball.flat_pos() - p.flat_pos())
		return

	# Barra de potencia.
	if not is_charging() and not opponent_has_ball:
		for action in KICK_BUTTONS:
			if input.just_pressed(action):
				charging_action = action
				power = 0.0
				break
	if is_charging():
		power = minf(1.0, power + dt / _match.tuning.power_charge_time)
		if input.just_released(charging_action) or not input.pressed(charging_action):
			var kind: int = KICK_BUTTONS[charging_action]
			charging_action = &""
			_try_kick(kind, power, move)

	# Toque de primera: si la pelota llegó y había una acción guardada.
	if _buffered_kind >= 0 and _buffer_timer > 0.0 and _match.can_kick(p):
		var k := _buffered_kind
		_buffered_kind = -1
		_do_kick(k, _buffered_power, _buffered_dir)
	elif _buffer_timer <= 0.0:
		_buffered_kind = -1


func _try_kick(kind: int, pwr: float, move: Vector3) -> void:
	# Pelota al alcance (conducida o suelta): se patea ya, de primera.
	if _match.can_kick(controlled):
		_do_kick(kind, pwr, move)
		return
	# Si no (la pelota viene o quedó adelantada en la conducción), la orden se
	# guarda y se ejecuta apenas la pelota esté al alcance.
	_buffered_kind = kind
	_buffered_power = pwr
	_buffered_dir = move
	_buffer_timer = _match.tuning.one_touch_buffer


func _do_kick(kind: int, pwr: float, move: Vector3) -> void:
	var receiver := _match.perform_kick(controlled, kind, move, pwr)
	if receiver != null and receiver.team == team and not receiver.is_keeper():
		# Cambio automático al receptor del pase (como en WE).
		select(receiver)
		_handled_kick = _match.kick_count


func _auto_switch(ball: Ball) -> void:
	var owner := ball.owner_player
	if owner != null and owner.team == team:
		if owner != controlled and not owner.is_keeper():
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
		select(nearest_to_ball())
		return
	if is_charging() or _switch_cooldown > 0.0:
		return
	var nearest := nearest_to_ball()
	if nearest != null and nearest != controlled:
		var bp := ball.flat_pos()
		if controlled.flat_pos().distance_to(bp) > nearest.flat_pos().distance_to(bp) + AUTO_SWITCH_MARGIN:
			select(nearest)
			_switch_cooldown = 0.6
