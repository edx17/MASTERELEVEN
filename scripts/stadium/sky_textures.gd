class_name SkyTextures
extends RefCounted
## Cielos fotográficos (HDRI, CC0) opcionales. Si están en res://assets/skies/
## se usan como fondo y luz ambiente en lugar del cielo procedural:
##   despejado, amanecer_invierno, atardecer, nublado, nublado2, nieve
## (.hdr, .exr, .jpg o .png; panorama equirectangular). De noche siempre se
## usa el procedural (las fotos de día no sirven).

const DIR := "res://assets/skies/"
const EXTS := ["hdr", "exr", "jpg", "png", "webp"]


static func find(key: String) -> Texture2D:
	for ext in EXTS:
		var path: String = DIR + key + "." + ext
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


## Nombres de cielo que corresponden a las condiciones, de más a menos
## específico. `variant` elige entre opciones parecidas (nublado / nublado2).
static func keys_for(conditions: MatchConditions, variant: int = 0) -> Array[String]:
	var keys: Array[String] = []
	if conditions.time_of_day == MatchConditions.TimeOfDay.NIGHT:
		return keys
	match conditions.weather:
		MatchConditions.Weather.SNOW:
			keys.append("nieve")
			keys.append("nublado")
		MatchConditions.Weather.CLOUDY, MatchConditions.Weather.RAIN:
			if variant % 2 == 0:
				keys.append_array(["nublado", "nublado2"])
			else:
				keys.append_array(["nublado2", "nublado"])
		_:
			match conditions.time_of_day:
				MatchConditions.TimeOfDay.MORNING:
					keys.append_array(["amanecer_invierno", "despejado"])
				MatchConditions.TimeOfDay.DUSK:
					keys.append("atardecer")
				_:
					keys.append_array(["despejado", "amanecer_invierno"])
	return keys


## El primer cielo disponible para las condiciones, o null (procedural).
static func for_conditions(conditions: MatchConditions, variant: int = 0) -> Texture2D:
	for key in keys_for(conditions, variant):
		var tex := find(key)
		if tex != null:
			return tex
	return null
