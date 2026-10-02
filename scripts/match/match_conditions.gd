class_name MatchConditions
extends Resource
## Condiciones del partido: horario, clima, viento y estado del césped.
## Se eligen en el menú (o al azar) y afectan la imagen (luz, lluvia, nieve) y
## el juego: apply_to() ajusta una copia del Tuning del partido.
##   Césped mojado: la pelota corre y patina más, cuesta más dominarla y las
##     barridas resbalan más lejos (y derriban más).
##   Nieve: la pelota frena y pica menos; los jugadores van algo más lentos.
##   Viento: empuja la pelota en el aire (BallPhysics usa la velocidad
##     relativa al aire para el arrastre).

enum TimeOfDay { MORNING, AFTERNOON, DUSK, NIGHT }
enum Weather { CLEAR, CLOUDY, RAIN, SNOW }

const TIME_NAMES := ["Mañana", "Tarde", "Atardecer", "Noche"]
const WEATHER_NAMES := ["Despejado", "Nublado", "Lluvia", "Nieve"]

@export var time_of_day: TimeOfDay = TimeOfDay.AFTERNOON
@export var weather: Weather = Weather.CLEAR
## Viento en m/s (0 = calma; ~4 leve; ~9 fuerte) y hacia dónde sopla (grados
## en el plano de la cancha; 0 = hacia +X).
@export var wind_speed: float = 0.0
@export var wind_angle: float = 0.0
## Césped: 0 = seco, ~0,4 = húmedo, 1 = empapado.
@export_range(0.0, 1.0) var wetness: float = 0.0


static func create(time: int, w: int, wind: float, wind_deg: float, wet: float) -> MatchConditions:
	var c := MatchConditions.new()
	c.time_of_day = time as TimeOfDay
	c.weather = w as Weather
	c.wind_speed = wind
	c.wind_angle = wind_deg
	c.wetness = wet
	return c


## Condiciones al azar, con probabilidades razonables (casi siempre se juega
## de día y sin lluvia; la nieve es rara).
static func random(rng: RandomNumberGenerator) -> MatchConditions:
	var c := MatchConditions.new()
	c.time_of_day = _pick(rng, [0.2, 0.4, 0.15, 0.25]) as TimeOfDay
	c.weather = _pick(rng, [0.5, 0.25, 0.18, 0.07]) as Weather
	c.wind_speed = [0.0, rng.randf_range(2.0, 5.0), rng.randf_range(6.0, 10.0)][_pick(rng, [0.45, 0.4, 0.15])]
	c.wind_angle = rng.randf_range(0.0, 360.0)
	c.wetness = default_wetness(c.weather, c.time_of_day, rng)
	return c


## Estado del césped que va con el clima (la lluvia lo moja; a la mañana o a la
## noche suele haber algo de humedad).
static func default_wetness(w: int, time: int, rng: RandomNumberGenerator = null) -> float:
	match w:
		Weather.RAIN:
			return 0.85
		Weather.SNOW:
			return 0.3
		Weather.CLOUDY:
			return 0.3 if rng != null and rng.randf() < 0.4 else 0.0
	if time == TimeOfDay.MORNING or time == TimeOfDay.NIGHT:
		return 0.25 if rng == null or rng.randf() < 0.5 else 0.0
	return 0.0


static func _pick(rng: RandomNumberGenerator, weights: Array) -> int:
	var r := rng.randf()
	var acc := 0.0
	for i in weights.size():
		acc += weights[i]
		if r < acc:
			return i
	return weights.size() - 1


func wind_vector() -> Vector3:
	var a := deg_to_rad(wind_angle)
	return Vector3(cos(a), 0.0, sin(a)) * wind_speed


func is_snow() -> bool:
	return weather == Weather.SNOW


## Ajusta el Tuning del partido (una copia) según las condiciones.
func apply_to(t: Tuning) -> void:
	t.wind = wind_vector()
	var w := clampf(wetness, 0.0, 1.0)
	if w > 0.0:
		t.rolling_decel *= lerpf(1.0, 0.62, w)
		t.bounce_friction = lerpf(t.bounce_friction, 0.96, w)
		t.ground_restitution *= lerpf(1.0, 0.88, w)
		t.dribble_distance *= 1.0 + 0.2 * w
		t.dribble_distance_sprint *= 1.0 + 0.2 * w
		t.slide_speed *= 1.0 + 0.1 * w
		t.slide_duration *= 1.0 + 0.25 * w
		t.slide_trip_chance = minf(0.85, t.slide_trip_chance + 0.25 * w)
		t.acceleration *= 1.0 - 0.05 * w
		t.slip_chance = 0.3 * w
	if is_snow():
		t.slip_chance = maxf(t.slip_chance, 0.2)
		t.rolling_decel *= 1.7
		t.ground_restitution *= 0.6
		t.bounce_friction *= 0.85
		t.run_speed *= 0.96
		t.sprint_speed *= 0.96
		t.acceleration *= 0.9
		t.dribble_distance *= 0.85
		t.dribble_distance_sprint *= 0.85


## "Tarde · Lluvia · viento 6 m/s · césped mojado".
func describe() -> String:
	var parts: Array[String] = [TIME_NAMES[time_of_day], WEATHER_NAMES[weather]]
	if wind_speed >= 0.5:
		parts.append("viento %d m/s" % roundi(wind_speed))
	else:
		parts.append("sin viento")
	if wetness >= 0.6:
		parts.append("césped mojado")
	elif wetness >= 0.2:
		parts.append("césped húmedo")
	else:
		parts.append("césped seco")
	return " · ".join(parts)
