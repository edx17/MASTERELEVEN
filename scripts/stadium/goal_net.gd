class_name GoalNet
extends MeshInstance3D
## Red de un arco que reacciona a la pelota: se infla en el punto de impacto
## (según la velocidad) y vuelve oscilando, amortiguada.

## Hasta 1,1 m con los remates más fuertes (antes 0,7: se movía poco).
const MAX_BULGE := 1.1
const DAMPING := 2.6
const FREQUENCY := 9.0
const SETTLE_TIME := 3.0

var side := 1
var _t := INF
var _amp := 0.0


func _ready() -> void:
	add_to_group(&"goal_net")


## La pelota pegó en la red en `world_pos` a `speed` m/s.
func hit(world_pos: Vector3, speed: float) -> void:
	# Crece más que lineal: el tiro flojo apenas la mueve, el fuerte la infla.
	var k := clampf(speed / 30.0, 0.0, 1.0)
	_amp = clampf(0.12 + 0.88 * pow(k, 1.3), 0.12, 1.0) * MAX_BULGE
	_t = 0.0
	_set_param(&"hit_pos", to_local(world_pos))
	_process(0.0)


## Desplazamiento actual de la red en el punto de impacto (metros).
func current_bulge() -> float:
	if _t >= SETTLE_TIME:
		return 0.0
	return _amp * exp(-DAMPING * _t) * cos(FREQUENCY * _t)


func _process(dt: float) -> void:
	if _t >= SETTLE_TIME:
		return
	_t += dt
	_set_param(&"bulge", current_bulge())


func _set_param(param: StringName, value: Variant) -> void:
	var mat := material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(param, value)
