class_name FutsalLeague
extends RefCounted
## Liga de futsal de la AFA (F5): una Competition con fase de liga (ida y
## vuelta; la D en dos zonas) y playoff (ko = "futsal").
##
##  - Primera A: no hay campeón de la fase regular; del 1.º al 8.º juegan el
##    playoff y el ganador es el campeón. Descienden los 2 últimos.
##  - Primera B y C: el 1.º es campeón y asciende; del 2.º al 9.º, playoff y el
##    ganador también asciende. Descienden los 2 (B) o 3 (C) últimos.
##  - Primera D (Zona 1 y Zona 2): asciende el campeón de cada zona; playoff
##    del 2.º al 5.º cruzando zonas (2.º Z1 - 5.º Z2, 3.º Z1 - 4.º Z2...); el
##    ganador es el tercer ascenso.
##  - Llaves de ida y vuelta, la vuelta en cancha del mejor ubicado. Empate en
##    el global: en cuartos pasa el mejor ubicado; desde semifinales, penales.
##
## Supercopa (ko = "super"): los campeones de las dos zonas de la D se cruzan
## antes; el ganador juega la semifinal con el de la A; la otra, B contra C.

const FORMATS := {
	"futA": {"name": "Primera A", "from": 1, "to": 8, "league_champ": false, "down": 2},
	"futB": {"name": "Primera B", "from": 2, "to": 9, "league_champ": true, "down": 2},
	"futC": {"name": "Primera C", "from": 2, "to": 9, "league_champ": true, "down": 3},
	"futD": {"name": "Primera D", "from": 2, "to": 5, "league_champ": true, "down": 0, "zones": true},
}
const STAGES := ["Playoff · cuartos de final", "Playoff · semifinales", "Playoff · final"]


## Formato de una división de la base ("futD1" y "futD2" son la D).
static func format_of(division_id: String) -> String:
	return "futD" if division_id.begins_with("futD") else division_id


## Liga de una división: `zones` = rutas de los equipos de cada zona (una
## sola zona salvo en la D). `user_path`: el equipo del jugador.
static func create(fmt: String, zones: Array, user_path: String, seed: int = 0) -> Competition:
	var c := Competition.new()
	c.kind = Competition.Kind.WORLD_CUP
	c.ko = "futsal"
	c.fmt = fmt
	c.legs = 2
	c.stage_names = STAGES.duplicate()
	var rng_seed := seed if seed != 0 else randi()
	c.draw_seed = rng_seed
	var zone_rounds: Array = []
	for z in zones.size():
		var ids: Array[int] = []
		for p in zones[z]:
			ids.append(c.team_paths.size())
			c.team_paths.append(p)
		c.groups.append(ids)
		var rr := Competition.round_robin(ids.size(), true, rng_seed + z * 7)
		# Índices de la zona -> índices de la competición.
		for games in rr:
			for g in games:
				g["home"] = ids[int(g["home"])]
				g["away"] = ids[int(g["away"])]
		zone_rounds.append(rr)
	var n := 0
	for rr in zone_rounds:
		n = maxi(n, (rr as Array).size())
	for i in n:
		var games := []
		for rr in zone_rounds:
			if i < (rr as Array).size():
				games.append_array(rr[i])
		c.rounds.append(games)
	c.group_rounds = n
	c.user_team = c.team_paths.find(user_path)
	return c


## Rutas de una división (en la D, las dos zonas).
static func division_zones(division_id: String) -> Array:
	if format_of(division_id) == "futD":
		return [TeamDB.division_paths("arg", "futD1"), TeamDB.division_paths("arg", "futD2")]
	return [TeamDB.division_paths("arg", division_id)]


## Valor para comparar quién está mejor ubicado (menor = mejor): la posición
## en su tabla y, entre zonas, los puntos y la diferencia de gol.
static func _rank_value(pos: int, row: Dictionary) -> float:
	return pos * 10000.0 - float(row["pts"]) * 100.0 - float(row["dg"])


## Termina la fase de liga: anota campeones, ascensos y descensos y arma los
## cuartos del playoff.
static func after_league(c: Competition) -> void:
	var f: Dictionary = FORMATS.get(c.fmt, FORMATS["futA"])
	c.notes.clear()
	var tables: Array = []
	for gi in c.groups.size():
		var t := c.group_table(gi)
		tables.append(t)
		for k in t.size():
			c.rank[str(int(t[k]["team"]))] = _rank_value(k + 1, t[k])
	var zones := c.groups.size() > 1
	if bool(f["league_champ"]):
		for gi in tables.size():
			var champ := int(tables[gi][0]["team"])
			c.notes.append("%s%s: %s (asciende)" % ["Campeón" if not zones else "Campeón de la Zona %d" % (gi + 1),
				"" if zones else " del torneo", c.team(champ).team_name])
	var down := int(f["down"])
	if down > 0:
		var t0: Array = tables[0]
		var names: Array = []
		for k in range(t0.size() - down, t0.size()):
			names.append(c.team(int(t0[k]["team"])).team_name)
		c.notes.append("Descienden: %s" % ", ".join(names))
	var pairs := []
	if zones:
		var a: Array = []
		var b: Array = []
		for k in range(1, 5):
			a.append(int(tables[0][k]["team"]))
			b.append(int(tables[1][k]["team"]))
		# 2.º Z1 - 5.º Z2 y 5.º Z1 - 2.º Z2 de un lado; 3.º - 4.º del otro.
		pairs = [[a[0], b[3]], [a[3], b[0]], [a[1], b[2]], [a[2], b[1]]]
	else:
		var s: Array = []
		for k in range(int(f["from"]) - 1, int(f["to"])):
			s.append(int(tables[0][k]["team"]))
		# 1-8 y 4-5 de un lado; 2-7 y 3-6 del otro.
		pairs = [[s[0], s[7]], [s[3], s[4]], [s[1], s[6]], [s[2], s[5]]]
	push_round(c, pairs, true)


## Agrega una ronda del playoff: la ida en cancha del peor ubicado y, si
## `seed_adv`, empate en el global = pasa el mejor ubicado (cuartos).
static func push_round(c: Competition, pairs: Array, seed_adv: bool) -> void:
	var ordered := []
	for pr in pairs:
		var x := int(pr[0])
		var y := int(pr[1])
		var better := x if rank_of(c, x) <= rank_of(c, y) else y
		var worse := y if better == x else x
		ordered.append([worse, better])
	c._push_ko(ordered)
	if seed_adv:
		for g in c.rounds.back():
			g["adv"] = g["away"]


static func rank_of(c: Competition, t: int) -> float:
	return float(c.rank.get(str(t), 999999.0))


## Siguiente ronda del playoff con los ganadores (semis y final: penales).
static func next_round(c: Competition, winners: Array) -> void:
	if winners.size() == 1:
		c.champion = int(winners[0])
		var f: Dictionary = FORMATS.get(c.fmt, FORMATS["futA"])
		var name := c.team(c.champion).team_name
		c.notes.push_front("Campeón: %s" % name if not bool(f["league_champ"]) else "Ganador del playoff: %s (asciende)" % name)
		return
	var pairs := []
	for i in range(0, winners.size() - 1, 2):
		pairs.append([winners[i], winners[i + 1]])
	push_round(c, pairs, false)


## Supercopa: `paths` = campeones [A, B, C, D Zona 1, D Zona 2].
static func create_supercup(paths: Array[String], user: int) -> Competition:
	var c := Competition.new()
	c.kind = Competition.Kind.CUP
	c.ko = "super"
	c.team_paths = paths.duplicate()
	c.user_team = user
	c.rounds = [[{"home": 3, "away": 4, "result": []}]]
	c.labels["0"] = "Repechaje de la Primera D"
	c.entries = [[], [0, 1, 2]]
	return c


## Semifinales de la Supercopa: A contra el de la D; B contra C.
static func super_semis(c: Competition, d_winner: int) -> void:
	c._push_ko([[0, d_winner], [1, 2]], "Semifinales")


## Campeones de la temporada anterior (el primero de cada tabla de la base).
static func supercup_paths() -> Array[String]:
	var out: Array[String] = []
	for d in ["futA", "futB", "futC", "futD1", "futD2"]:
		var ps := TeamDB.division_paths("arg", d)
		if not ps.is_empty():
			out.append(ps[0])
	return out


## Color de la fila de la tabla (playoff, ascenso, descenso) y su leyenda.
static func zone_color(c: Competition, pos: int, size: int) -> Color:
	var f: Dictionary = FORMATS.get(c.fmt, FORMATS["futA"])
	if bool(f["league_champ"]) and pos == 1:
		return WEStyle.ACCENT
	if pos >= int(f["from"]) and pos <= int(f["to"]):
		return WEStyle.ACCENT_GREEN
	if pos > size - int(f["down"]):
		return Color(0.85, 0.25, 0.25)
	return Color(0, 0, 0, 0)


static func legend(c: Competition) -> String:
	var f: Dictionary = FORMATS.get(c.fmt, FORMATS["futA"])
	var parts: Array[String] = []
	if bool(f["league_champ"]):
		parts.append("Amarillo: campeón (asciende)")
	parts.append("Verde: playoff (%d.º al %d.º%s)" % [f["from"], f["to"], ", cruzando zonas" if f.get("zones", false) else ""])
	if int(f["down"]) > 0:
		parts.append("Rojo: descienden")
	return "  ·  ".join(parts)


# --- Copa Argentina de futsal ------------------------------------------------
# Entrada escalonada (ko = "copa_arg"): Fase 1, los de la D; Fase 2, los que
# pasaron y los de la C; 32avos, los de la A y la B; de ahí, llaves a partido
# único hasta la final (penales). Cuando la cuenta no cierra, los mejor
# ubicados (división y puesto) pasan de ronda sin jugar (exentos).

const COPA_STAGES := ["Fase 1", "Fase 2", "32avos de final"]


## Todos los clubes de la base, de la D a la A, con su nivel para los exentos.
static func create_copa_argentina(user_path: String, seed: int = 0) -> Competition:
	var c := Competition.new()
	c.kind = Competition.Kind.CUP
	c.ko = "copa_arg"
	var rng_seed := seed if seed != 0 else randi()
	c.draw_seed = rng_seed
	var stages := [["futD1", "futD2"], ["futC"], ["futA", "futB"]]
	var level := {"futA": 0, "futB": 1, "futC": 2, "futD1": 3, "futD2": 3}
	for s in stages.size():
		var ids: Array = []
		for div in stages[s]:
			var ps := TeamDB.division_paths("arg", div)
			for k in ps.size():
				var i := c.team_paths.size()
				c.team_paths.append(ps[k])
				c.rank[str(i)] = int(level[div]) * 100 + k
				ids.append(i)
		c.entries.append(ids)
	c.user_team = c.team_paths.find(user_path)
	copa_round(c, (c.entries[0] as Array).duplicate(), 0)
	return c


## Arma una ronda de la Copa con `teams`: en las fases previas juegan todos
## (con un exento si son impares); desde 32avos, los justos para que la ronda
## siguiente sea de una potencia de dos.
static func copa_round(c: Competition, teams: Array, stage: int) -> void:
	var by_rank := teams.duplicate()
	by_rank.sort_custom(func(a: int, b: int) -> bool: return rank_of(c, a) < rank_of(c, b))
	var games := teams.size() / 2
	if stage >= 2:
		var p := 1
		while p * 2 <= teams.size():
			p *= 2
		games = teams.size() - p if teams.size() != p else teams.size() / 2
	var byes_n := teams.size() - games * 2
	c.extra = by_rank.slice(0, byes_n)
	var playing: Array = by_rank.slice(byes_n)
	var rng := RandomNumberGenerator.new()
	rng.seed = c.draw_seed + stage * 31
	Competition._shuffle(playing, rng)
	var pairs := []
	for i in range(0, playing.size() - 1, 2):
		pairs.append([playing[i], playing[i + 1]])
	c._push_ko(pairs, COPA_STAGES[stage] if stage < COPA_STAGES.size() else "")


## Ronda siguiente de la Copa: ganadores, exentos y los que se suman.
static func copa_next(c: Competition, winners: Array) -> void:
	var teams := winners.duplicate()
	teams.append_array(c.extra)
	c.extra = []
	if c.stage < c.entries.size():
		teams.append_array(c.entries[c.stage])
	if teams.size() == 1:
		c.champion = int(teams[0])
		return
	copa_round(c, teams, c.stage)
