class_name FormationData
extends Resource
## Formación: 11 puestos en espacio de equipo (x 0..1 desde el arco propio hacia
## el rival; y -1..1, negativo = lado derecho mirando al ataque), la posición
## general de cada puesto y su rol táctico. El puesto 0 es siempre el arquero.

@export var formation_name: String = "4-4-2"
@export var slots: Array[Vector2] = []
## Posición general por puesto (valores de PlayerData.Position).
@export var roles: Array[int] = []
## Rol táctico por puesto (valores de TacticalRole.Kind).
@export var slot_roles: Array[int] = []


func is_valid() -> bool:
	return slots.size() == 11 and roles.size() == 11 and slot_roles.size() == 11 \
		and roles[0] == PlayerData.Position.GK and slot_roles[0] == TacticalRole.Kind.GK


## Rol táctico del puesto (con respaldo para formaciones viejas sin slot_roles).
func tactical_role(i: int) -> int:
	if i < slot_roles.size():
		return slot_roles[i]
	match roles[i]:
		PlayerData.Position.GK: return TacticalRole.Kind.GK
		PlayerData.Position.DF: return TacticalRole.Kind.FB if absf(slots[i].y) > 0.5 else TacticalRole.Kind.CB
		PlayerData.Position.FW: return TacticalRole.Kind.ST
	return TacticalRole.Kind.WM if absf(slots[i].y) > 0.5 else TacticalRole.Kind.CM
