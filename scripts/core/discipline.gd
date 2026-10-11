class_name Discipline
extends RefCounted
## Disciplina que se juega: fútbol (11 contra 11) o futsal (5 contra 5, FIFA).
## Cada una tiene su cancha (Pitch.configure), cuántos juegan, el banco, la
## duración, las formaciones, la pelota y el piso. La base del juego dice de
## qué disciplina es (TeamDB.DBS[...]["discipline"]); al cambiar de base se
## cambia la disciplina (use).

enum Kind { FOOTBALL, FUTSAL }

const FOOTBALL := "football"
const FUTSAL := "futsal"

const DATA := {
	"football": {
		"name": "Fútbol", "players": 11, "bench": 12, "minutes": 10,
		"formations": ["4-4-2", "4-3-3", "4-2-3-1", "3-5-2", "5-3-2"], "default_formation": "4-4-2",
		"pitch": {"half_length": 52.5, "half_width": 34.0, "goal_half_width": 3.66, "goal_height": 2.44,
			"goal_depth": 2.0, "post_radius": 0.06, "penalty_area_depth": 16.5, "penalty_area_half_width": 20.16,
			"goal_area_depth": 5.5, "goal_area_half_width": 9.16, "center_circle_radius": 9.15, "penalty_spot": 11.0,
			"line_width": 0.12},
		"offside": true,
	},
	"futsal": {
		"name": "Futsal", "players": 5, "bench": 9, "minutes": 10,
		"formations": ["1-2-1", "2-2", "1-3", "3-1", "4-0"], "default_formation": "1-2-1",
		# FIFA: 40 x 20 m, arcos de 3 x 2 m, área de 6 m (dos cuartos de
		# círculo desde los postes unidos por una recta: 15,16 m de ancho),
		# penal a 6 m y doble penal a 10 m, círculo central de 3 m.
		"pitch": {"half_length": 20.0, "half_width": 10.0, "goal_half_width": 1.5, "goal_height": 2.0,
			"goal_depth": 0.9, "post_radius": 0.04, "penalty_area_depth": 6.0, "penalty_area_half_width": 7.58,
			"goal_area_depth": 0.0, "goal_area_half_width": 0.0, "center_circle_radius": 3.0, "penalty_spot": 6.0,
			"line_width": 0.08, "second_penalty_spot": 10.0},
		"offside": false,
		# Pelota de bote bajo (tamaño 4): pica la mitad, rueda pegada al piso
		# (más pareja que en el césped) y frena menos en el roce.
		"ball": {"ground_restitution": 0.5, "bounce_friction": 0.8, "rolling_decel": 0.8, "bounce_min_speed": 1.6},
	},
}

## Pisos del futsal: [nombre, color de la cancha, color de afuera].
const SURFACES := [["Parquet", Color("#c8925a"), Color("#8a5a32")], ["Pista azul", Color("#1f5fa8"), Color("#173f6e")],
	["Pista negra", Color("#202326"), Color("#33383d")]]

static var current := FOOTBALL


## Cambia de disciplina (y las medidas de la cancha).
static func use(id: String) -> void:
	current = id if DATA.has(id) else FOOTBALL
	Pitch.configure(DATA[current]["pitch"])


static func is_futsal() -> bool:
	return current == FUTSAL


static func data(id: String = "") -> Dictionary:
	return DATA[id if DATA.has(id) else current]


static func display_name(id: String = "") -> String:
	return String(data(id)["name"])


## Cuántos juegan de cada lado (arquero incluido).
static func players() -> int:
	return int(data()["players"])


static func bench_size() -> int:
	return int(data()["bench"])


static func formations() -> Array:
	return data()["formations"]


static func default_formation() -> String:
	return String(data()["default_formation"])


## Archivo de una formación ("1-2-1" -> f5_1-2-1.tres en futsal).
static func formation_path(fname: String) -> String:
	if is_futsal():
		return "res://data/formations/f5_%s.tres" % fname
	return "res://data/formations/f_%s.tres" % fname


static func offside() -> bool:
	return bool(data()["offside"])


## Ajusta la física de la pelota a la disciplina (multiplica los valores del
## fútbol; bounce_min_speed se pisa).
static func apply_to(t: Tuning) -> void:
	var b: Dictionary = data().get("ball", {})
	if b.has("ground_restitution"):
		t.ground_restitution *= float(b["ground_restitution"])
	if b.has("bounce_friction"):
		t.bounce_friction *= float(b["bounce_friction"])
	if b.has("rolling_decel"):
		t.rolling_decel *= float(b["rolling_decel"])
	if b.has("bounce_min_speed"):
		t.bounce_min_speed = float(b["bounce_min_speed"])


## Piso elegido del futsal: [nombre, color de la cancha, color de afuera].
static func surface(i: int) -> Array:
	return SURFACES[clampi(i, 0, SURFACES.size() - 1)]
