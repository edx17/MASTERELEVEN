class_name KickAccuracy
extends RefCounted
## Cálculo del error (en grados) de pases y remates según atributos, presión,
## orientación del cuerpo, distancia y potencia. Puro y testeable: la lógica de
## juego sortea un desvío uniforme en ±error.


## Error máximo de un pase.
## - skill: atributo de pase (1..99); technique suma un poco.
## - pressure: 0..1 (rival encima).
## - body_angle: grados entre hacia dónde mira el jugador y hacia dónde pasa.
## - power: 0..1 de la barra (pasarse de potencia también cuesta precisión).
static func pass_error(skill: int, technique: int, pressure: float, body_angle: float, power: float) -> float:
	var s := PlayerData.unit(skill) * 0.8 + PlayerData.unit(technique) * 0.2
	var err := lerpf(5.5, 0.8, s)
	err += clampf(pressure, 0.0, 1.0) * 2.0
	err += _body_penalty(body_angle, 4.0)
	err += maxf(power - 0.85, 0.0) * 10.0
	return err


## Error máximo de un remate.
## - distance: metros al arco; de lejos el error se nota más.
static func shot_error(shooting: int, technique: int, balance: int, pressure: float, body_angle: float,
		distance: float, power: float) -> float:
	var s := PlayerData.unit(shooting) * 0.6 + PlayerData.unit(technique) * 0.25 + PlayerData.unit(balance) * 0.15
	var err := lerpf(6.0, 1.2, s)
	err += clampf(pressure, 0.0, 1.0) * 3.0
	err += _body_penalty(body_angle, 7.0)
	err += clampf((distance - 12.0) * 0.08, 0.0, 3.0)
	# A potencia alta se pierde precisión (el clásico "reventarla").
	err *= 0.75 + power * power * 0.6
	return err


## Penalización por patear "cruzado" respecto de la orientación del cuerpo.
static func _body_penalty(body_angle: float, max_penalty: float) -> float:
	return clampf((absf(body_angle) - 45.0) / 135.0, 0.0, 1.0) * max_penalty


## Dirección final de un pase con asistencia: parte de la dirección al objetivo
## y se corre hacia la dirección del stick en la proporción (1 - assist).
static func assisted_direction(to_target: Vector3, stick: Vector3, assist: float) -> Vector3:
	var t := Vector3(to_target.x, 0.0, to_target.z)
	if t.length_squared() < 0.0001:
		return t
	t = t.normalized()
	var st := Vector3(stick.x, 0.0, stick.z)
	if st.length_squared() < 0.04:
		return t
	var angle := t.signed_angle_to(st.normalized(), Vector3.UP)
	return t.rotated(Vector3.UP, angle * (1.0 - clampf(assist, 0.0, 1.0)))
