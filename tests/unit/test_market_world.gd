extends GutTest
## Mercado de la Liga Virtual con las ligas de los otros países.


func after_each() -> void:
	MasterCareer.deactivate()


func test_buy_a_player_from_bolivia() -> void:
	var m := MasterCareer.create("arg", "boca", "real", 31)
	var scopes := m.market_scopes()
	var bol: Array = scopes.filter(func(s: Dictionary) -> bool: return s["country"] == "bol")
	assert_false(bol.is_empty(), "Bolivia está entre las ligas del mercado")
	var clubs := m.scope_clubs(bol[0])
	assert_gt(clubs.size(), 8)
	var list := m.market_list(-1, int(bol[0]["division"]), "ovr", 10, "bol")
	assert_eq(list.size(), 10)
	assert_true(String(list[0]["club"]).begins_with("bol:"))
	var only := m.market_list(-1, int(bol[0]["division"]), "ovr", 100, "bol", String(clubs[0][0]))
	assert_true(only.all(func(it: Dictionary) -> bool: return it["club"] == clubs[0][0]), "filtro por club")
	if not m.market_open():
		return
	m.points = 10000000
	var it: Dictionary = list[0]
	var before := m.club_players(String(it["club"])).size()
	assert_eq(m.buy(String(it["club"]), int(it["d"]["pid"])), "")
	assert_true(m.club_players(m.user_club).has(it["d"]))
	assert_eq(m.club_players(String(it["club"])).size(), before - 1)
	# Guardar y cargar con el club boliviano adentro.
	var back := MasterCareer.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_eq(back.club_players(String(it["club"])).size(), before - 1)
