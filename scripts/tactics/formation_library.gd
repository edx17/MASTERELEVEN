class_name FormationLibrary
extends RefCounted
## Formaciones disponibles (recursos en data/formations/) y sus definiciones
## base, usadas por tools/generate_data.gd para regenerarlas.

const PATHS: Array[String] = [
	"res://data/formations/f_4-4-2.tres",
	"res://data/formations/f_4-3-3.tres",
	"res://data/formations/f_4-2-3-1.tres",
	"res://data/formations/f_3-5-2.tres",
	"res://data/formations/f_5-3-2.tres",
]
## Futsal (5 puestos: el arquero y 4), data/formations/f5_*.tres.
const FUTSAL_PATHS: Array[String] = [
	"res://data/formations/f5_1-2-1.tres",
	"res://data/formations/f5_2-2.tres",
	"res://data/formations/f5_1-3.tres",
	"res://data/formations/f5_3-1.tres",
	"res://data/formations/f5_4-0.tres",
]


## nombre -> [[x, y, rol], ...] (11 puestos, el 0 es el arquero).
## y < 0 = lado derecho mirando al ataque.
const DEFINITIONS := {
	"4-4-2": [
		[0.015, 0.0, TacticalRole.Kind.GK],
		[0.21, -0.7, TacticalRole.Kind.FB], [0.18, -0.22, TacticalRole.Kind.CB], [0.18, 0.22, TacticalRole.Kind.CB], [0.21, 0.7, TacticalRole.Kind.FB],
		[0.36, -0.72, TacticalRole.Kind.WM], [0.33, -0.2, TacticalRole.Kind.CM], [0.33, 0.2, TacticalRole.Kind.CM], [0.36, 0.72, TacticalRole.Kind.WM],
		[0.46, -0.16, TacticalRole.Kind.ST], [0.45, 0.16, TacticalRole.Kind.ST],
	],
	"4-3-3": [
		[0.015, 0.0, TacticalRole.Kind.GK],
		[0.21, -0.7, TacticalRole.Kind.FB], [0.18, -0.22, TacticalRole.Kind.CB], [0.18, 0.22, TacticalRole.Kind.CB], [0.21, 0.7, TacticalRole.Kind.FB],
		[0.37, -0.32, TacticalRole.Kind.CM], [0.29, 0.0, TacticalRole.Kind.DM], [0.37, 0.32, TacticalRole.Kind.CM],
		[0.45, -0.72, TacticalRole.Kind.WF], [0.47, 0.0, TacticalRole.Kind.ST], [0.45, 0.72, TacticalRole.Kind.WF],
	],
	"4-2-3-1": [
		[0.015, 0.0, TacticalRole.Kind.GK],
		[0.21, -0.7, TacticalRole.Kind.FB], [0.18, -0.22, TacticalRole.Kind.CB], [0.18, 0.22, TacticalRole.Kind.CB], [0.21, 0.7, TacticalRole.Kind.FB],
		[0.4, -0.7, TacticalRole.Kind.WF], [0.29, -0.2, TacticalRole.Kind.DM], [0.29, 0.2, TacticalRole.Kind.DM], [0.4, 0.7, TacticalRole.Kind.WF],
		[0.47, 0.0, TacticalRole.Kind.ST], [0.41, 0.0, TacticalRole.Kind.AM],
	],
	"3-5-2": [
		[0.015, 0.0, TacticalRole.Kind.GK],
		[0.33, -0.82, TacticalRole.Kind.WM], [0.18, -0.38, TacticalRole.Kind.CB], [0.17, 0.0, TacticalRole.Kind.CB], [0.33, 0.82, TacticalRole.Kind.WM],
		[0.35, -0.3, TacticalRole.Kind.CM], [0.28, 0.0, TacticalRole.Kind.DM], [0.35, 0.3, TacticalRole.Kind.CM], [0.18, 0.38, TacticalRole.Kind.CB],
		[0.46, -0.16, TacticalRole.Kind.ST], [0.45, 0.16, TacticalRole.Kind.ST],
	],
	"5-3-2": [
		[0.015, 0.0, TacticalRole.Kind.GK],
		[0.22, -0.82, TacticalRole.Kind.FB], [0.17, -0.36, TacticalRole.Kind.CB], [0.16, 0.0, TacticalRole.Kind.CB], [0.22, 0.82, TacticalRole.Kind.FB],
		[0.33, -0.35, TacticalRole.Kind.CM], [0.3, 0.0, TacticalRole.Kind.DM], [0.33, 0.35, TacticalRole.Kind.CM], [0.17, 0.36, TacticalRole.Kind.CB],
		[0.46, -0.16, TacticalRole.Kind.ST], [0.45, 0.16, TacticalRole.Kind.ST],
	],
}


## Futsal: cierre (CB / FB), alas (WM), pívot (ST); 4-0 todos rotan.
const FUTSAL_DEFINITIONS := {
	"1-2-1": [[0.02, 0.0, TacticalRole.Kind.GK], [0.22, 0.0, TacticalRole.Kind.CB],
		[0.38, -0.62, TacticalRole.Kind.WM], [0.38, 0.62, TacticalRole.Kind.WM], [0.52, 0.0, TacticalRole.Kind.ST]],
	"2-2": [[0.02, 0.0, TacticalRole.Kind.GK], [0.24, -0.45, TacticalRole.Kind.CB], [0.24, 0.45, TacticalRole.Kind.CB],
		[0.45, -0.45, TacticalRole.Kind.WF], [0.45, 0.45, TacticalRole.Kind.WF]],
	"1-3": [[0.02, 0.0, TacticalRole.Kind.GK], [0.22, 0.0, TacticalRole.Kind.CB],
		[0.42, -0.65, TacticalRole.Kind.WM], [0.46, 0.0, TacticalRole.Kind.AM], [0.42, 0.65, TacticalRole.Kind.WM]],
	"3-1": [[0.02, 0.0, TacticalRole.Kind.GK], [0.25, -0.55, TacticalRole.Kind.FB], [0.21, 0.0, TacticalRole.Kind.CB],
		[0.25, 0.55, TacticalRole.Kind.FB], [0.5, 0.0, TacticalRole.Kind.ST]],
	"4-0": [[0.02, 0.0, TacticalRole.Kind.GK], [0.3, -0.72, TacticalRole.Kind.WM], [0.27, -0.24, TacticalRole.Kind.CM],
		[0.27, 0.24, TacticalRole.Kind.CM], [0.3, 0.72, TacticalRole.Kind.WM]],
}


## Definiciones de la disciplina activa (Discipline).
static func definitions() -> Dictionary:
	return FUTSAL_DEFINITIONS if Discipline.is_futsal() else DEFINITIONS


## Construye un FormationData a partir de su definición.
static func build(formation_name: String) -> FormationData:
	var f := FormationData.new()
	f.formation_name = formation_name
	var defs := definitions()
	if not defs.has(formation_name):
		formation_name = Discipline.default_formation()
	for row in defs[formation_name]:
		f.slots.append(Vector2(row[0], row[1]))
		f.slot_roles.append(row[2])
		f.roles.append(TacticalRole.to_position(row[2]))
	return f


static func load_all() -> Array[FormationData]:
	var out: Array[FormationData] = []
	for p in (FUTSAL_PATHS if Discipline.is_futsal() else PATHS):
		var f := load(p) as FormationData
		if f != null:
			out.append(f)
	return out
