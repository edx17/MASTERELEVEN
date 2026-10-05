class_name TacticalRole
extends RefCounted
## Rol táctico de cada puesto de la formación. Define cómo se comporta el
## jugador dentro de la forma del equipo (TeamShape):
##   CB  defensor central: sostiene la línea.
##   FB  lateral: amplitud; pasa al ataque por su banda (overlap).
##   DM  volante central defensivo: queda detrás de la pelota, equilibrio.
##   CM  volante central: ofrece líneas de pase.
##   AM  enganche: entre líneas, detrás de los delanteros.
##   WM  volante por banda / carrilero: amplitud en todo el campo.
##   WF  extremo: amplitud arriba, ataca el espacio.
##   ST  delantero: en la última línea, desmarques.

enum Kind { GK, CB, FB, DM, CM, AM, WM, WF, ST }

const SHORT_NAMES := ["ARQ", "DFC", "LAT", "MCD", "MC", "MCO", "VOL", "EXT", "DC"]

## Rango de avance permitido en espacio de equipo (0 = arco propio, 1 = rival).
const X_RANGE := {
	Kind.GK: Vector2(0.005, 0.2),
	Kind.CB: Vector2(0.04, 0.62),
	Kind.FB: Vector2(0.04, 0.86),
	Kind.DM: Vector2(0.07, 0.7),
	Kind.CM: Vector2(0.09, 0.82),
	Kind.AM: Vector2(0.18, 0.9),
	Kind.WM: Vector2(0.07, 0.9),
	Kind.WF: Vector2(0.22, 0.94),
	Kind.ST: Vector2(0.3, 0.95),
}


static func is_defender(k: int) -> bool:
	return k == Kind.CB or k == Kind.FB


static func is_forward(k: int) -> bool:
	return k == Kind.ST or k == Kind.WF


static func is_wide(k: int) -> bool:
	return k == Kind.FB or k == Kind.WM or k == Kind.WF


## Sigla del puesto como en el WE2002 (CB, LB, RB, DMF, CMF, LMF, RMF, AMF,
## WG, CF). `side` es la y del puesto en espacio de equipo (negativa =
## derecha: el lateral derecho de la 4-4-2 está en y -0.68).
static func we_code(k: int, side: float) -> String:
	match k:
		Kind.GK: return "GK"
		Kind.CB: return "CB"
		Kind.FB: return "RB" if side < 0.0 else "LB"
		Kind.DM: return "DMF"
		Kind.CM: return "CMF"
		Kind.AM: return "AMF"
		Kind.WM: return "RMF" if side < 0.0 else "LMF"
		Kind.WF: return "WG"
	return "CF"


## Posición general (PlayerData.Position) que corresponde a un rol.
static func to_position(k: int) -> int:
	match k:
		Kind.GK: return PlayerData.Position.GK
		Kind.CB, Kind.FB: return PlayerData.Position.DF
		Kind.ST, Kind.WF: return PlayerData.Position.FW
	return PlayerData.Position.MF
