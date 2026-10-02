extends SceneTree
## Generador de datos iniciales (ficticios). Se corre una vez:
##   godot --headless -s res://tools/generate_data.gd
## Crea data/formations/*.tres y data/teams/*.tres. Después los datos se
## editan desde el Inspector; este script sólo sirve para regenerarlos.

const SURNAMES := [
	"Arrieta", "Benavídez", "Castañar", "Duarte", "Echeverri", "Ferrán", "Galdós", "Hidalgo",
	"Irigoyen", "Jáuregui", "Kessler", "Larrea", "Maidana", "Nazar", "Olmedo", "Pereyra",
	"Quiroga", "Rivadeo", "Salcedo", "Taborda", "Urquiza", "Valdano", "Werthein", "Zabala",
	"Acosta", "Bermejo", "Cardozo", "Dalmasso", "Espina", "Figueras", "Garmendia", "Herrán",
]
const INITIALS := "ABCDEFGHJLMNOPRSTV"

const TEAMS := [
	{"id": "aurora", "name": "Deportivo Aurora", "short": "AUR", "color": Color(0.35, 0.65, 0.95),
		"secondary": Color(0.95, 0.95, 0.95), "keeper": Color(0.15, 0.15, 0.15), "seed": 11,
		"formation": "4-3-3"},
	{"id": "halcones", "name": "Atlético Halcones", "short": "HAL", "color": Color(0.85, 0.15, 0.15),
		"secondary": Color(0.08, 0.08, 0.08), "keeper": Color(0.2, 0.85, 0.35), "seed": 23,
		"formation": "4-4-2"},
]

# Suplentes (12, como en el WE: 23 en la lista): arquero, defensor, volante,
# volante, delantero y después dos defensores, dos volantes, dos delanteros y
# el tercer arquero. Se agregan al final para no cambiar a los anteriores.
const BENCH_ROLES := [PlayerData.Position.GK, PlayerData.Position.DF, PlayerData.Position.MF,
	PlayerData.Position.MF, PlayerData.Position.FW,
	PlayerData.Position.DF, PlayerData.Position.DF, PlayerData.Position.MF, PlayerData.Position.MF,
	PlayerData.Position.FW, PlayerData.Position.FW, PlayerData.Position.GK]


func _init() -> void:
	var formations := {}
	for fname in FormationLibrary.DEFINITIONS:
		var path := "res://data/formations/f_%s.tres" % fname
		_save(FormationLibrary.build(fname), path)
		formations[fname] = load(path)

	for t in TEAMS:
		var rng := RandomNumberGenerator.new()
		rng.seed = t["seed"]
		var team := TeamData.new()
		team.id = t["id"]
		team.team_name = t["name"]
		team.short_name = t["short"]
		team.color = t["color"]
		team.secondary_color = t["secondary"]
		team.keeper_color = t["keeper"]
		team.formation = formations[t["formation"]]
		var names := SURNAMES.duplicate()
		for i in names.size():
			var j := rng.randi_range(i, names.size() - 1)
			var tmp = names[i]
			names[i] = names[j]
			names[j] = tmp
		var roles: Array = []
		# Plantel base: 1 ARQ, 4 DEF, 4 VOL, 2 DEL + suplentes (los puestos de la
		# formación se asignan por orden; se ajusta en la Fase 4 con el menú).
		roles.append_array([PlayerData.Position.GK, PlayerData.Position.DF, PlayerData.Position.DF,
			PlayerData.Position.DF, PlayerData.Position.DF, PlayerData.Position.MF, PlayerData.Position.MF,
			PlayerData.Position.MF, PlayerData.Position.MF, PlayerData.Position.FW, PlayerData.Position.FW])
		roles.append_array(BENCH_ROLES)
		for i in roles.size():
			var p := _make_player(rng, roles[i], i + 1, names[i])
			p.id = "%s_%02d" % [team.id, i + 1]
			team.players.append(p)
		_save(team, "res://data/teams/%s.tres" % team.id)
	print("Datos generados.")
	quit()


func _make_player(rng: RandomNumberGenerator, role: int, number: int, surname: String) -> PlayerData:
	var p := PlayerData.new()
	p.player_name = "%s. %s" % [INITIALS[rng.randi_range(0, INITIALS.length() - 1)], surname]
	p.number = number
	p.position = role
	p.foot = PlayerData.Foot.LEFT if rng.randf() < 0.25 else PlayerData.Foot.RIGHT
	var base := func(mean: int) -> int: return clampi(mean + rng.randi_range(-8, 8), 30, 92)
	p.speed = base.call(66)
	p.acceleration = base.call(66)
	p.stamina = base.call(68)
	p.strength = base.call(64)
	p.passing = base.call(64)
	p.shooting = base.call(58)
	p.technique = base.call(62)
	p.ball_control = base.call(64)
	p.heading = base.call(60)
	p.defense = base.call(58)
	p.reaction = base.call(64)
	p.balance = base.call(64)
	p.goalkeeping = base.call(25)
	match role:
		PlayerData.Position.GK:
			p.goalkeeping = base.call(76)
			p.reaction = base.call(74)
			p.speed = base.call(55)
			p.shooting = base.call(35)
			p.defense = base.call(45)
		PlayerData.Position.DF:
			p.defense = base.call(74)
			p.strength = base.call(72)
			p.heading = base.call(70)
			p.shooting = base.call(48)
		PlayerData.Position.MF:
			p.passing = base.call(74)
			p.technique = base.call(70)
			p.stamina = base.call(74)
		PlayerData.Position.FW:
			p.shooting = base.call(75)
			p.speed = base.call(72)
			p.ball_control = base.call(70)
			p.defense = base.call(40)
	return p


func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("No se pudo guardar %s (%d)" % [path, err])
