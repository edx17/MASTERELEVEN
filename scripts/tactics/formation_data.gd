class_name FormationData
extends Resource
## Formación: 11 slots en espacio de equipo (x 0..1 desde el arco propio hacia
## el rival; y -1..1, negativo = lado derecho mirando al ataque) y el rol de
## cada slot. El slot 0 es siempre el arquero.

@export var formation_name: String = "4-4-2"
@export var slots: Array[Vector2] = []
## Rol por slot (valores de PlayerData.Position).
@export var roles: Array[int] = []


func is_valid() -> bool:
	return slots.size() == 11 and roles.size() == 11 and roles[0] == PlayerData.Position.GK
