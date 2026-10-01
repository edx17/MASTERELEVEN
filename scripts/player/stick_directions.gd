class_name StickDirections
extends RefCounted
## Stick en 8 o 16 direcciones fijas, como el WE2002: el jugador corre por
## rumbos marcados (arriba, diagonal, costado...) en vez de por cualquier
## ángulo. Se cuantiza en coordenadas de pantalla (antes de pasar a la
## cancha), así "arriba" es siempre arriba en la pantalla.
## Con histéresis: cerca del borde entre dos rumbos se mantiene el anterior,
## para que un stick analógico apenas inclinado no haga zigzag.

## Rumbos posibles: 0 = libre (sin cuantizar), 8 o 16.
var steps: int = 8
## Fracción del ancho de un rumbo que hay que pasarse del borde para cambiar.
var hysteresis: float = 0.2
## Rumbo actual (-1 = stick suelto).
var sector: int = -1


func _init(p_steps: int = 8) -> void:
	steps = p_steps


## Devuelve el vector con la misma intensidad y la dirección del rumbo más
## cercano (en el plano XZ). Un stick suelto (zona muerta) pasa sin cambios.
func apply(v: Vector3) -> Vector3:
	var flat := Vector2(v.x, v.z)
	var mag := flat.length()
	if steps <= 0 or mag < 0.2:
		sector = -1
		return v
	var width := TAU / steps
	var angle := flat.angle()
	var candidate := posmod(roundi(angle / width), steps)
	if sector >= 0 and candidate != sector:
		# Sólo cambia si se pasó claramente del borde con el rumbo anterior.
		var off := absf(angle_difference(angle, sector * width))
		if off < width * (0.5 + hysteresis):
			candidate = sector
	sector = candidate
	var dir := Vector2.from_angle(sector * width) * minf(mag, 1.0)
	return Vector3(dir.x, v.y, dir.y)
