class_name Celebrations
extends RefCounted
## Festejos de gol. Cada jugador puede tener su preferido
## (PlayerData.celebration, para el futuro modo edición); si no, uno al azar
## entre los que estén en la copia local.

## [clip de MixamoLibrary, nombre para el editor]
const LIST := [
	["celebrate", "Rueda"],
	["celebrate2", "Golpe de golf"],
	["cel_backflip", "Mortal hacia atrás"],
	["cel_capoeira", "Capoeira"],
	["cel_turn", "Carrera y frenada"],
	["cel_rifle", "El fusil"],
	["cel_crawl", "Gateo"],
	["cel_spider", "La araña"],
	["cel_flair", "Molinete"],
	["cel_horse", "Baile del jinete"],
	["cel_moonwalk", "Paso lunar"],
	["cel_robot", "El robot"],
]
## Tiempo que dura el festejo (s): los cortos se repiten; los bailes largos
## se cortan.
const MIN_TIME := 2.6
const MAX_TIME := 5.5
const LOOP_TIME := 3.5


static func clip(index: int) -> String:
	return String(LIST[index][0]) if index >= 0 and index < LIST.size() else ""


static func display_name(index: int) -> String:
	return String(LIST[index][1]) if index >= 0 and index < LIST.size() else "Al azar"


static func available(index: int) -> bool:
	var lib := MixamoLibrary._lib
	return lib != null and lib.has_animation(clip(index))


## Festejo del jugador: el preferido si está; si no, uno al azar entre los
## disponibles (0 si no hay animaciones).
static func pick(data: PlayerData) -> int:
	if data != null and available(data.celebration):
		return data.celebration
	var options: Array[int] = []
	for i in LIST.size():
		if available(i):
			options.append(i)
	return options[randi() % options.size()] if not options.is_empty() else 0


## Cuánto dura ese festejo (s).
static func duration(index: int) -> float:
	if not available(index):
		return MIN_TIME
	var name := clip(index)
	var spec: Dictionary = MixamoLibrary.CLIPS.get(name, {})
	if spec.get("loop", false):
		return LOOP_TIME
	return clampf(MixamoLibrary._lib.get_animation(name).length, MIN_TIME, MAX_TIME)
