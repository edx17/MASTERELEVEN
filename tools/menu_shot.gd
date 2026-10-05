extends Node
## Captura del menú principal (para revisar su diseño):
## xvfb-run godot -- --menu-shot=archivo.png [--menu-page=teams]
## Páginas: home, modes, teams, setup, options, controls, master, master_squad,
## master_hub, master_end, master_plantel, master_cal.

var out := "user://menu.png"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for f in 10:
		await get_tree().process_frame
	for a in OS.get_cmdline_user_args():
		# `--menu-home=db:nat:arg`: local elegido (la elección abre en su grupo).
		if a.begins_with("--menu-home="):
			GameSettings.home_team_path = a.trim_prefix("--menu-home=")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--menu-page="):
			var menu := get_tree().current_scene
			var page := a.trim_prefix("--menu-page=")
			if page == "setup":
				GameSettings.home_team_path = "res://data/teams/bahia.tres"
				GameSettings.away_team_path = "res://data/teams/pampa.tres"
			# Liga / Copa de ejemplo con algunas fechas jugadas.
			if page in ["league", "cup"]:
				var c := Competition.create_league(GameSettings.team_paths(), 0, false, 3) if page == "league" \
					else Competition.create_cup(GameSettings.team_paths(), 0, 3)
				for i in (3 if page == "league" else 1):
					c.complete_round([2, 1], 10 + i)
				c.save()
				GameSettings.active_save = c.file
				page = "hub"
			# Mundial con la fecha 1 jugada (la pantalla de grupos).
			if page == "wc":
				var wc: Array[String] = menu.call("world_cup_paths", GameSettings.wc_playoff)
				var c := Competition.create_world_cup(wc, maxi(wc.find(TeamDB.nation_path("arg")), 0), 5,
					[TeamDB.nation_path("usa"), TeamDB.nation_path("mex"), TeamDB.nation_path("can")])
				c.complete_round([2, 0], 11)
				c.save()
				GameSettings.active_save = c.file
				page = "hub"
			# Liga Master: carrera de ejemplo (Boca con el Equipo WE, en Primera C).
			var master_view := ""
			if page in ["master_plantel", "master_cal"]:
				master_view = page
				page = "master_hub"
			if page in ["master_hub", "master_end"]:
				var m := MasterCareer.create("arg", "boca", "we", 21)
				for i in 5:
					m.play_round([], [], 30 + i)
				if page == "master_end":
					m.simulate_to_end(9)
				m.save()
				GameSettings.active_save = m.file
				page = "master_hub"
			if page == "master_squad":
				menu.set("_master_country", "arg")
				menu.set("_master_club", "boca")
			if page == "teams":
				menu.call("show_page", "modes")
			menu.call("show_page", page)
			if master_view != "":
				var hub: MasterHub = menu.get("_master_hub")
				if master_view == "master_cal":
					hub.view_mode = 2
					hub.call("_rebuild")
				else:
					hub.call("_open_squad")
	for f in 20:
		await get_tree().process_frame
	var img := get_tree().root.get_texture().get_image()
	img.save_png(out)
	print("menú: ", out)
	get_tree().quit()
