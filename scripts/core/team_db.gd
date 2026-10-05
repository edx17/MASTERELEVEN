class_name TeamDB
extends RefCounted
## Base de datos de equipos reales (Paso C): selecciones y clubes de las ligas
## en `data/db/` (JSON). Cada equipo se arma la primera vez que se pide (y
## queda en memoria) a partir de su entrada: nombre, colores, camisetas,
## estadio y, si los trae, sus jugadores (importados con
## tools/import_players.gd). Si no trae plantel, se genera uno estable con
## nombres del país y nivel según la selección o la división.
##
## Los equipos se identifican con una "ruta" como los .tres de siempre:
##   res://data/teams/aurora.tres   (Equipos WE, ficticios)
##   db:nat:arg                     (selección)
##   db:club:arg:boca               (club: país e id)

const ROOT := "res://data/db/"
const NATIONS_FILE := "res://data/db/nations.json"
const NAMES_FILE := "res://data/db/names.json"
const LEAGUES_DIR := "res://data/db/leagues/"

## Diseños de camiseta por nombre (TeamData.pattern).
const PATTERNS := {"plain": 0, "stripes": 1, "pinstripes": 2, "hoops": 3, "halves": 4, "sash": 5,
	"band": 6, "v": 7, "checks": 8}

## Nivel base de cada división (1 = primera) y ajuste por liga (id de
## división -> suma).
const DIVISION_LEVEL := {1: 72, 2: 65, 3: 60, 4: 56, 5: 52}
const LEAGUE_BONUS := {"eng1": 6, "esp1": 5, "ita1": 4, "ger1": 4, "por1": 0, "ned1": -1, "mex1": -1,
	"arg1": -1, "bra1": 1, "eng2": 2, "esp2": 0, "ita2": 0, "ger2": 1}

const BENCH_ROLES := [PlayerData.Position.GK, PlayerData.Position.DF, PlayerData.Position.MF,
	PlayerData.Position.MF, PlayerData.Position.FW,
	PlayerData.Position.DF, PlayerData.Position.DF, PlayerData.Position.MF, PlayerData.Position.MF,
	PlayerData.Position.FW, PlayerData.Position.FW, PlayerData.Position.GK]

static var _nations: Array = []
static var _countries: Array = []
static var _names: Dictionary = {}
static var _cache: Dictionary = {}
static var _base_nations: Array = []
static var _base_countries: Array = []
## Option File activo (cambios del jugador sobre la base) o null = la base.
static var option_file: OptionFile = null


# --- Lectura -------------------------------------------------------------------------

static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


## Selecciones (la base con el Option File activo aplicado).
static func nations() -> Array:
	if _nations.is_empty():
		_nations = option_file.apply_nations(base_nations()) if option_file != null else base_nations()
	return _nations


## Selecciones de la base del juego (sin cambios del jugador).
static func base_nations() -> Array:
	if _base_nations.is_empty():
		var d: Variant = _read_json(NATIONS_FILE)
		if d is Dictionary:
			_base_nations = d.get("nations", [])
	return _base_nations


## Países con ligas: [{id, name, divisions: [{id, name, level, clubs: [...]}]}],
## en el orden de los archivos (con el Option File activo aplicado).
static func countries() -> Array:
	if _countries.is_empty():
		_countries = option_file.apply_countries(base_countries()) if option_file != null else base_countries()
	return _countries


static func base_countries() -> Array:
	if _base_countries.is_empty():
		var dir := DirAccess.open(LEAGUES_DIR)
		if dir != null:
			var files := Array(dir.get_files()).map(func(f: String) -> String: return f.trim_suffix(".remap")) \
				.filter(func(f: String) -> bool: return f.ends_with(".json"))
			files.sort()
			for f in files:
				var d: Variant = _read_json(LEAGUES_DIR + f)
				if d is Dictionary:
					_base_countries.append(d)
	return _base_countries


## Activa un Option File (null = la base) y vuelve a armar los equipos.
static func use_option_file(of: OptionFile) -> void:
	option_file = of
	reload()


static func names() -> Dictionary:
	if _names.is_empty():
		var d: Variant = _read_json(NAMES_FILE)
		if d is Dictionary:
			_names = d
	return _names


static func nation(id: String) -> Dictionary:
	for n in nations():
		if n["id"] == id:
			return n
	return {}


static func country(id: String) -> Dictionary:
	for c in countries():
		if c["id"] == id:
			return c
	return {}


## Cuántos equipos bajan de la división `index` del país a la de abajo (y
## cuántos suben de esa). Se cambia en el Editor (Ligas); si no, 3 en
## Inglaterra y 2 en el resto.
static func relegation_count(country_id: String, index: int) -> int:
	var divs: Array = country(country_id).get("divisions", [])
	if index < 0 or index >= divs.size() - 1:
		return 0
	return int((divs[index] as Dictionary).get("down", 3 if country_id == "eng" else 2))


## Club por país e id: [entrada, división].
static func club(country_id: String, id: String) -> Array:
	var c := country(country_id)
	for div in c.get("divisions", []):
		for cl in div["clubs"]:
			if cl["id"] == id:
				return [cl, div]
	return []


# --- Rutas -------------------------------------------------------------------------

static func nation_path(id: String) -> String:
	return "db:nat:" + id


static func club_path(country_id: String, id: String) -> String:
	return "db:club:%s:%s" % [country_id, id]


static func nation_paths() -> Array[String]:
	var out: Array[String] = []
	for n in nations():
		out.append(nation_path(n["id"]))
	return out


## Clubes de una división (en el orden del archivo).
static func division_paths(country_id: String, division_id: String) -> Array[String]:
	var out: Array[String] = []
	for div in country(country_id).get("divisions", []):
		if div["id"] == division_id:
			for cl in div["clubs"]:
				out.append(club_path(country_id, cl["id"]))
	return out


static func exists(path: String) -> bool:
	if not path.begins_with("db:"):
		return ResourceLoader.exists(path)
	var parts := path.split(":")
	if parts.size() == 3 and parts[1] == "nat":
		return not nation(parts[2]).is_empty()
	if parts.size() == 4 and parts[1] == "club":
		return not club(parts[2], parts[3]).is_empty()
	return false


## El equipo de esa ruta (un .tres o uno de la base).
static func load_team(path: String) -> TeamData:
	if not path.begins_with("db:"):
		return load(path) as TeamData
	if _cache.has(path):
		return _cache[path]
	var t: TeamData = null
	var parts := path.split(":")
	if parts.size() == 3 and parts[1] == "nat":
		var n := nation(parts[2])
		if not n.is_empty():
			t = build_nation(n)
	elif parts.size() == 4 and parts[1] == "club":
		var c := club(parts[2], parts[3])
		if not c.is_empty():
			t = build_club(c[0], parts[2], c[1])
	if t != null:
		_cache[path] = t
	return t


## Olvida lo leído (después de importar o editar los JSON).
static func reload() -> void:
	_nations = []
	_countries = []
	_base_nations = []
	_base_countries = []
	_names = {}
	_cache = {}


# --- Armado ------------------------------------------------------------------------

static func build_nation(n: Dictionary) -> TeamData:
	var t := _base_team(n)
	t.id = "nat_" + String(n["id"])
	t.flag = FlagPainter.texture(n.get("flag", {}))
	t.country = n["id"]
	_fill_players(t, n, int(n.get("level", 70)), String(n.get("names", "en")), n.get("skin", [40, 30, 18, 12]),
		String(n.get("name", "")))
	return t


static func build_club(c: Dictionary, country_id: String, div: Dictionary) -> TeamData:
	var t := _base_team(c)
	t.id = "%s_%s" % [country_id, c.get("id", "club")]
	t.country = country_id
	t.stadium = String(c.get("stadium", ""))
	t.capacity = int(c.get("cap", 0))
	var level := int(DIVISION_LEVEL.get(int(div.get("level", 1)), 60)) + int(LEAGUE_BONUS.get(String(div.get("id", "")), 0)) \
		+ int(c.get("r", 0))
	var co := country(country_id)
	_fill_players(t, c, level, String(co.get("names", "en")), co.get("skin", [40, 30, 18, 12]), String(co.get("nationality", "")))
	return t


static func _base_team(e: Dictionary) -> TeamData:
	var t := TeamData.new()
	t.team_name = String(e.get("name", "?"))
	t.short_name = String(e.get("short", t.team_name.substr(0, 3).to_upper()))
	var home := parse_kit(String(e.get("home", "ffffff/ffffff/ffffff")))
	var away := parse_kit(String(e.get("away", "101820/101820/101820")))
	t.color = home["shirt"]
	t.secondary_color = home["shorts"]
	t.socks_color = home["socks"]
	t.pattern = home["pattern"]
	t.pattern_color = home["pattern_color"]
	t.away_color = away["shirt"]
	t.away_secondary = away["shorts"]
	t.away_socks = away["socks"]
	t.away_pattern = away["pattern"]
	t.away_pattern_color = away["pattern_color"]
	t.keeper_color = Color.html(String(e.get("keeper", "1a1a1a")))
	# Plantillas de camiseta del Option File (editor de camisetas).
	if option_file != null:
		for i in 2:
			var f := String(e.get(["home_tex", "away_tex"][i], ""))
			if f != "":
				t.kit_textures[i] = KitTemplate.load_texture(option_file.kits_dir().path_join(f))
	var fname := String(e.get("formation", "4-4-2"))
	var path := "res://data/formations/f_%s.tres" % fname
	t.formation = load(path) if ResourceLoader.exists(path) else load("res://data/formations/f_4-4-2.tres")
	return t


## "camiseta/pantalón/medias|diseño|color" (colores en hex; el diseño por
## número o por nombre: stripes, hoops, sash, band...).
static func parse_kit(s: String) -> Dictionary:
	var parts := s.split("|")
	var cols := parts[0].split("/")
	var shirt := Color.html(cols[0])
	var out := {"shirt": shirt, "shorts": Color.html(cols[1]) if cols.size() > 1 else shirt,
		"socks": Color.html(cols[2]) if cols.size() > 2 else shirt, "pattern": 0, "pattern_color": Color.BLACK}
	if parts.size() > 2:
		var p := parts[1]
		out["pattern"] = int(p) if p.is_valid_int() else int(PATTERNS.get(p, 0))
		out["pattern_color"] = Color.html(parts[2])
	return out


## Plantel: el importado (si la entrada trae "players") o uno generado.
static func _fill_players(t: TeamData, e: Dictionary, level: int, names_group: String, skin: Array, nationality: String) -> void:
	var listed: Array = e.get("players", [])
	if not listed.is_empty():
		for i in mini(listed.size(), 23):
			var p := player_from_dict(listed[i], t.id, i, level)
			if p.nationality == "":
				p.nationality = nationality
			t.players.append(p)
		_order_for_formation(t)
	else:
		generate_roster(t, level, names_group, skin, nationality, hash(t.id))
	var cap := PlayerData.pick_captain(t.players)
	if cap != null and not cap.abilities.has("capitan"):
		cap.abilities.append("capitan")


## Jugador importado: {n, num, pos (GK/CB/.../CF), alt, ft (R/L/B), h, age,
## nat, a: {speed, ...}}. Los atributos que falten se derivan.
static func player_from_dict(d: Dictionary, team_id: String, i: int, level: int = 65) -> PlayerData:
	var p := PlayerData.new()
	p.player_name = String(d.get("n", "Jugador %d" % (i + 1)))
	p.id = "%s_%02d" % [team_id, i + 1]
	p.number = int(d.get("num", i + 1))
	var code := String(d.get("pos", "CMF")).to_upper()
	p.role_code = code
	p.position = position_of_code(code)
	if d.has("alt"):
		p.alt_roles = PackedStringArray(String(d["alt"]).split(",", false))
	p.foot = {"L": PlayerData.Foot.LEFT, "B": PlayerData.Foot.BOTH}.get(String(d.get("ft", "R")), PlayerData.Foot.RIGHT)
	p.height = int(d.get("h", 0))
	p.age = int(d.get("age", 0))
	p.nationality = String(d.get("nat", ""))
	p.pid = int(d.get("pid", 0))
	# Aspecto (editor): -1 / ausente = automático.
	for k in LOOK_KEYS:
		if d.has(k):
			p.set(LOOK_KEYS[k], int(d[k]))
	var a: Dictionary = d.get("a", {})
	for k in a:
		if k in p:
			p.set(k, int(a[k]))
	if a.is_empty():
		# Sin atributos (p. ej. Transfermarkt): según su valoración o el nivel
		# del equipo, estable por jugador.
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(p.player_name + team_id)
		_random_attributes(p, int(d.get("ovr", level)), rng)
	p.abilities = p.suggested_abilities()
	p.fill_extended()
	return p


## Claves del aspecto en el formato de la base -> campo de PlayerData.
const LOOK_KEYS := {"skin": "skin", "hair": "hair", "hc": "hair_color", "fh": "facial_hair",
	"fhc": "facial_hair_color", "boots": "boots", "build": "build"}


## Jugador -> formato de la base (lo que guarda el editor en el Option File).
static func player_to_dict(p: PlayerData) -> Dictionary:
	var d := {"n": p.player_name, "num": p.number, "pos": p.role_code if p.role_code != "" else ["GK", "CB", "CMF", "CF"][p.position],
		"ft": ["R", "L", "B"][clampi(p.foot, 0, 2)], "h": p.height_cm(), "age": p.get_age(), "nat": p.nationality}
	if not p.alt_roles.is_empty():
		d["alt"] = ",".join(p.alt_roles)
	if p.pid > 0:
		d["pid"] = p.pid
	for k in LOOK_KEYS:
		var v := int(p.get(LOOK_KEYS[k]))
		if v >= 0:
			d[k] = v
	var a := {}
	for attr in PlayerData.ATTRIBUTES:
		a[attr] = int(p.get(attr))
	d["a"] = a
	return d


## Puesto general de una sigla del WE.
static func position_of_code(code: String) -> int:
	match code:
		"GK", "POR", "PT":
			return PlayerData.Position.GK
		"CB", "LB", "RB", "SB", "LWB", "RWB", "DF", "DFC", "LI", "LD":
			return PlayerData.Position.DF
		"CF", "ST", "SS", "LWF", "RWF", "WG", "LW", "RW", "FW", "DC":
			return PlayerData.Position.FW
	return PlayerData.Position.MF


## Titulares según la formación: para cada puesto, el mejor libre de ese
## puesto general (si no hay, el mejor de los que quedan).
static func _order_for_formation(t: TeamData) -> void:
	if t.formation == null:
		return
	var pool: Array[PlayerData] = t.players.duplicate()
	pool.sort_custom(func(a: PlayerData, b: PlayerData) -> bool: return overall(a) > overall(b))
	var xi: Array[PlayerData] = []
	for role in t.formation.roles:
		var pick: PlayerData = null
		for p in pool:
			if p.position == role:
				pick = p
				break
		if pick == null and role != PlayerData.Position.GK:
			for p in pool:
				if p.position != PlayerData.Position.GK:
					pick = p
					break
		if pick == null and not pool.is_empty():
			pick = pool[0]
		if pick != null:
			pool.erase(pick)
			xi.append(pick)
	xi.append_array(pool)
	t.players = xi


static func overall(p: PlayerData) -> float:
	if p.position == PlayerData.Position.GK:
		return (p.goalkeeping * 2 + p.reaction) / 3.0
	return (p.speed + p.passing + p.shooting + p.technique + p.ball_control + p.defense * 0.6 + p.stamina * 0.4) / 6.0


## Plantel generado (estable con `seed`): 11 según la formación y 12
## suplentes, con nombres del grupo, piel según el país y nivel `level`.
static func generate_roster(t: TeamData, level: int, names_group: String, skin: Array, nationality: String, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pool: Dictionary = names().get(names_group, names().get("en", {"f": ["Juan"], "s": ["Pérez"]}))
	var firsts: Array = pool["f"]
	var lasts: Array = pool["s"].duplicate()
	for i in lasts.size():
		var j := rng.randi_range(i, lasts.size() - 1)
		var tmp = lasts[i]
		lasts[i] = lasts[j]
		lasts[j] = tmp
	var roles: Array = []
	if t.formation != null:
		roles.append_array(t.formation.roles)
	else:
		roles.append_array([0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3])
	roles.append_array(BENCH_ROLES)
	var used := {}
	var numbers := _numbers_for(roles)
	for i in roles.size():
		var p := PlayerData.new()
		var last: String = lasts[i % lasts.size()]
		var name := "%s. %s" % [String(firsts[rng.randi_range(0, firsts.size() - 1)]).substr(0, 1), last]
		while used.has(name):
			name = "%s. %s" % [String(firsts[rng.randi_range(0, firsts.size() - 1)]).substr(0, 1), last]
			if used.has(name):
				last = lasts[rng.randi_range(0, lasts.size() - 1)]
		used[name] = true
		p.player_name = name
		p.id = "%s_%02d" % [t.id, i + 1]
		p.number = numbers[i]
		p.position = roles[i]
		p.nationality = nationality
		p.foot = PlayerData.Foot.LEFT if rng.randf() < 0.24 else (PlayerData.Foot.BOTH if rng.randf() < 0.03 else PlayerData.Foot.RIGHT)
		p.skin = PlayerData._pick(rng.randf(), skin)
		# Titulares un poco mejores que los suplentes.
		var lv := level + (2 if i < 11 else -3) + rng.randi_range(-3, 3)
		_random_attributes(p, lv, rng)
		p.abilities = p.suggested_abilities()
		p.fill_extended()
		t.players.append(p)


## Dorsales: 1 al arquero titular, 2-11 a los titulares por puesto y del 12
## en adelante a los suplentes.
static func _numbers_for(roles: Array) -> Array[int]:
	var out: Array[int] = []
	var next := 2
	for i in roles.size():
		if i == 0:
			out.append(1)
		elif i < 11:
			out.append(next)
			next += 1
		else:
			out.append(i + 1)
	return out


## Atributos alrededor de `level` (promedio general), con lo fuerte de cada
## puesto.
static func _random_attributes(p: PlayerData, level: int, rng: RandomNumberGenerator) -> void:
	var shift := level - 66
	var base := func(mean: int) -> int: return clampi(mean + shift + rng.randi_range(-7, 7), 25, 97)
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
	p.goalkeeping = clampi(25 + rng.randi_range(-5, 5), 10, 40)
	match p.position:
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
