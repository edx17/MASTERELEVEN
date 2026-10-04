class_name Strategy
extends RefCounted
## Estrategias del WE: se asignan a cuatro botones en la Dirección del equipo
## y se activan en el partido con L2 + X / Cuadrado / Círculo / Triángulo (con
## teclado, R + la tecla del botón). Cambian la forma del equipo (TeamShape) y
## el estado táctico (TeamAI). La CPU las usa sola según el resultado.

enum Kind { NONE, PRESSING, COUNTER, OFFSIDE_TRAP, WINGS, ALL_ATTACK, ALL_DEFENSE }

const NAMES := ["Ninguna", "Presión", "Contraataque", "Trampa del offside", "Ataque por las bandas",
	"Todos al ataque", "Todos atrás"]
## Botones (en el orden de HumanController.STRATEGY_BUTTONS).
const BUTTON_NAMES := ["X", "Cuadrado", "Círculo", "Triángulo"]
## Íconos (ButtonIcons) de esos botones.
const BUTTON_ICONS := ["X", "SQ", "O", "TRI"]
const DEFAULT_SLOTS: Array[int] = [Kind.PRESSING, Kind.COUNTER, Kind.OFFSIDE_TRAP, Kind.WINGS]


## Ajusta el objetivo (x, y en espacio de equipo) de un puesto según la
## estrategia.
static func adjust(kind: int, role: int, target: Vector2, ball: Vector2, in_possession: bool) -> Vector2:
	var t := target
	match kind:
		Kind.OFFSIDE_TRAP:
			# Línea alta y adelantada para dejar en offside a los delanteros.
			if not in_possession and TacticalRole.is_defender(role):
				t.x += 0.08
		Kind.ALL_ATTACK:
			t.x += 0.1
		Kind.ALL_DEFENSE:
			t.x -= 0.1
			t.y *= 0.85
		Kind.WINGS:
			# Bien abiertos y los laterales pasando por afuera.
			if in_possession and TacticalRole.is_wide(role):
				t.y = signf(t.y if t.y != 0.0 else 1.0) * 0.95
				if role == TacticalRole.Kind.FB:
					t.x += 0.06
		Kind.COUNTER:
			# Los de arriba no bajan: quedan esperando la contra.
			if not in_possession and TacticalRole.is_forward(role):
				t.x = maxf(t.x, minf(ball.x + 0.3, 0.75))
	return t
