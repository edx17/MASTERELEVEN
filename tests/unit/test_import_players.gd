extends GutTest
## Paso C: importador de planteles (CSV de EA FC / SoFIFA, Transfermarkt o propio).

const Imp := preload("res://tools/import_players.gd")


func _csv(text: String) -> String:
	var path := "user://test_import.csv"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return path


func test_reads_fc_columns_and_converts_attributes() -> void:
	var path := _csv("short_name,club_name,nationality_name,club_jersey_number,player_positions,preferred_foot,height_cm,age,overall,movement_sprint_speed,movement_acceleration,power_stamina,power_strength,attacking_short_passing,attacking_finishing,skill_dribbling,skill_ball_control,attacking_heading_accuracy,defending_standing_tackle,movement_reactions,movement_balance\n" +
		"M. Delantero,CA Boca Juniors,Argentina,9,\"ST, LW\",Left,183,27,80,85,82,75,70,72,84,80,82,70,30,80,75\n")
	var rows: Array[Dictionary] = Imp.read_csv(path)
	assert_eq(rows.size(), 1)
	var p: Dictionary = Imp.to_player(rows[0])
	assert_eq(p["n"], "M. Delantero")
	assert_eq(p["pos"], "CF")
	assert_eq(p["alt"], "WG")
	assert_eq(p["ft"], "L")
	assert_eq(p["h"], 183)
	assert_eq(p["num"], 9)
	assert_eq(p["a"]["speed"], 85)
	assert_eq(p["a"]["shooting"], 84)
	var built := TeamDB.player_from_dict(p, "x", 0)
	assert_eq(built.position, PlayerData.Position.FW)
	assert_eq(built.foot, PlayerData.Foot.LEFT)
	assert_eq(built.speed, 85)


func test_spanish_columns_and_semicolons() -> void:
	var path := _csv("club;nombre;puesto;pie;estatura_cm;nacionalidad\nRiver Plate;J. Pérez;ARQ;Diestro;1,90;Argentina\n")
	var rows: Array[Dictionary] = Imp.read_csv(path)
	var p: Dictionary = Imp.to_player(rows[0])
	assert_eq(p["pos"], "GK")
	assert_eq(p["ft"], "R")
	assert_false(p.has("a"), "sin atributos: se estiman")


func test_finds_clubs_by_name() -> void:
	var idx: Dictionary = Imp.club_index()
	assert_false(Imp.find_club(idx, "CA Boca Juniors").is_empty())
	assert_false(Imp.find_club(idx, "Manchester City").is_empty())
	assert_false(Imp.find_club(idx, "FC Bayern München").is_empty())
	assert_true(Imp.find_club(idx, "Club Inexistente XYZ").is_empty())


func test_squad_keeps_minimum_per_line() -> void:
	var players := []
	for i in 30:
		players.append({"n": "F%d" % i, "pos": "CF", "ovr": 90 - i})
	for i in 4:
		players.append({"n": "G%d" % i, "pos": "GK", "ovr": 50 + i})
	var squad: Array = Imp.pick_squad(players, 23, [3, 0, 0, 0])
	assert_eq(squad.size(), 23)
	assert_eq(squad.filter(func(p: Dictionary) -> bool: return p["pos"] == "GK").size(), 3)
