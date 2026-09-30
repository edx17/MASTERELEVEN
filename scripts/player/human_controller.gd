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
## Ángulo a partir del cual mover el stick cuenta como "nueva orden" y le
## devuelve el control del receptor al jugador.
const RECEIVE_RELEASE_ANGLE := deg_to_rad(50.0)
## Durante cuánto se recuerda la última dirección del stick (para pasar hacia
## donde se apuntó aunque el stick ya se haya soltado al apretar el botón).
const AIM_MEMORY := 0.35

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
var _buffered_receiver: Footballer = null
## Compañero que recibiría el pase que se está cargando (marcado en la cancha).
var preview_receiver: Footballer = null
## Recepción asistida trabada: tras pasar, el receptor va a buscar la pelota
## aunque el stick siga apretado en la dirección del pase.
var _receive_lock: bool = false
var _receive_lock_dir: Vector3 = Vector3.ZERO
var _aim_dir: Vector3 = Vector3.ZERO
var _aim_age: float = 999.0
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
		_set_preview(null)
		return

	# El stick está en coordenadas de pantalla: se traduce según la cámara.
	var move := _match.screen_to_world(input.move_vector())
	_aim_age += dt
	if move.length_squared() > 0.09:
		_aim_dir = move.normalized()
		_aim_age = 0.0
	var opponent_has_ball := ball.owner_player != null and ball.owner_player.team != team

	move = _apply_receive_lock(p, ball, move)
	p.wants_sprint = input.pressed(&"sprint")
	p.desired_move = move
	p.pressing = false

	# Recepción asistida: con el stick suelto, el receptor de un pase va al
	# encuentro de la pelota (como en WE); mover el stick lo cancela. Si ya
	# pidió un toque de primera (cargando o guardado), el stick sólo apunta el
	# próximo pase: el receptor sigue yendo a la pelota.
	var one_touch_pending := is_charging() or _buffered_kind >= 0
	var incoming := ball.is_loose() and ball.intended_receiver == p
	if incoming and _buffered_kind >= 0:
		# La orden guardada dura hasta que la pelota llega (pase largo).
		_buffer_timer = maxf(_buffer_timer, 0.2)
	if incoming and (move.length_squared() < 0.04 or one_touch_pending):
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
	# Sin pelota: pase al hueco (Triángulo) mantenido = el arquero sale a achicar.
	if opponent_has_ball and input.pressed(&"pass_through"):
		_match.keeper_rush[team.index] = true
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
		var kind: int = KICK_BUTTONS[charging_action]
		var aim := aim_direction(move)
		# Mientras se carga, se marca a quién va el pase (y se puede corregir
		# con el stick). Al soltar, ese receptor queda "trabado".
		_set_preview(_match.kicks.preview_receiver(kind, p, aim) if kind != KickActions.Kind.SHOT else null)
		if input.just_released(charging_action) or not input.pressed(charging_action):
			charging_action = &""
			var target := preview_receiver
			_set_preview(null)
			_try_kick(kind, power, aim, target)
	elif _buffered_kind < 0:
		_set_preview(null)

	# Toque de primera: si la pelota llegó y había una acción guardada.
	if _buffered_kind >= 0 and _buffer_timer > 0.0 and _match.can_kick(p):
		var k := _buffered_kind
		_buffered_kind = -1
		_set_preview(null)
		_do_kick(k, _buffered_power, _buffered_dir, _buffered_receiver)
	elif _buffer_timer <= 0.0 and _buffered_kind >= 0:
		_buffered_kind = -1
		_set_preview(null)


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


func _try_kick(kind: int, pwr: float, move: Vector3, target: Footballer = null) -> void:
	# Pelota al alcance (conducida o suelta): se patea ya, de primera.
	if _match.can_kick(controlled):
		_do_kick(kind, pwr, move, target)
		return
	# Si no (la pelota viene o quedó adelantada en la conducción), la orden se
	# guarda y se ejecuta apenas la pelota esté al alcance.
	_buffered_kind = kind
	_buffered_power = pwr
	_buffered_dir = move
	_buffered_receiver = target
	_buffer_timer = _match.tuning.one_touch_buffer
	_set_preview(target)


func _do_kick(kind: int, pwr: float, move: Vector3, target: Footballer = null) -> void:
	var receiver := _match.perform_kick(controlled, kind, move, pwr, target)
	if receiver != null and receiver.team == team and not receiver.is_keeper():
		# Cambio automático al receptor del pase (como en WE).
		select(receiver)
		_handled_kick = _match.kick_count
		# El stick que se usó para pasar no debe mandar al receptor para ese lado.
		_receive_lock = true
		_receive_lock_dir = move.normalized() if move.length_squared() > 0.01 else Vector3.ZERO


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
