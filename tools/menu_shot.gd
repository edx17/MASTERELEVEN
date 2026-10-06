extends Node
## Captura del menú principal (para revisar su diseño):
## xvfb-run godot -- --menu-shot=archivo.png [--menu-page=teams] [--menu-pad]
## (--menu-pad: indicaciones de control de mando en vez de teclado)
## Páginas: home, modes, teams, setup, options, controls, master, master_squad,
## master_hub, master_end, master_plantel, master_cal,
## master_market, master_sell, master_pases, master_news, master_hist,
## master_cups (con --menu-cup=ID: la copa que se ve, p. ej. lib o ucl; con
## --menu-master=eng: carrera en Inglaterra).

var out := "user://menu.png"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for f in 10:
		await get_tree().process_frame
	InputRouter.set_source(InputRouter.Source.GAMEPAD if OS.get_cmdline_user_args().has("--menu-pad")
		else InputRouter.Source.KEYBOARD, true)
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
			# Menú principal con una Liga Master guardada (Colón, 5 fechas jugadas).
			if page == "home_saved":
				var hs := MasterCareer.create("arg", "colon", "real", 21)
				for i in 5:
					hs.play_round([], [], 30 + i)
				hs.save()
				MasterCareer.deactivate()
				page = "home"
			# Liga Master: carrera de ejemplo (Boca con el Equipo WE, en Primera C).
			var master_view := ""
			if page in ["master_plantel", "master_cal", "master_market", "master_sell", "master_pases", "master_news", "master_hist", "master_cups"]:
				master_view = page
				page = "master_hub"
			if master_view in ["master_news", "master_hist"]:
				page = "master_end"
			if page in ["master_hub", "master_end"]:
				var m := MasterCareer.create("arg", "boca", "we", 21)
				for a2 in OS.get_cmdline_user_args():
					if a2 == "--menu-master=eng":
						m = MasterCareer.create("eng", String(TeamDB.country("eng")["divisions"][3]["clubs"][0]["id"]), "real", 21)
				for i in (5 if master_view != "master_cups" else 14):
					m.play_round([], [], 30 + i)
				if page == "master_end":
					m.first_year = 2030 # con Mundial al final
					m.simulate_to_end(9)
				m.save()
				GameSettings.active_save = m.file
				page = "master_hub"
			if page == "master_squad":
				menu.set("_master_country", "arg")
				menu.set("_master_club", "boca")
			if page == "teams":
				menu.call("show_page", "modes")
			# Sub-20: la página de copas con los torneos juveniles.
			menu.set("_cups_youth", page == "u20")
			if page == "u20":
				page = "cups"
			menu.call("show_page", page)
			if master_view != "":
				var hub: MasterHub = menu.get("_master_hub")
				if master_view in ["master_cal", "master_cups", "master_news", "master_hist"]:
					hub.view_mode = {"master_cal": 2, "master_cups": 3, "master_news": 4, "master_hist": 5}[master_view]
					for a2 in OS.get_cmdline_user_args():
						if a2.begins_with("--menu-cup="):
							var cid := a2.trim_prefix("--menu-cup=")
							for ci in hub.career.cups.size():
								if hub.career.cups[ci]["id"] == cid:
									hub.view_cup = ci
					hub.call("_rebuild")
				elif master_view == "master_plantel":
					hub.call("_open_squad")
				else:
					hub.call("_open_market")
					var mk: MasterMarket = hub.get("_market")
					mk.mode = {"master_market": 0, "master_sell": 1, "master_pases": 2}[master_view]
					mk.call("_rebuild")
	for f in 20:
		await get_tree().process_frame
	var img := get_tree().root.get_texture().get_image()
	img.save_png(out)
	print("menú: ", out)
	get_tree().quit()
