extends Node
## Captura del menú principal (para revisar su diseño):
## xvfb-run godot -- --menu-shot=archivo.png [--menu-page=teams]
## Páginas: home, modes, teams, setup, options, controls.

var out := "user://menu.png"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for f in 10:
		await get_tree().process_frame
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
				page = "hub"
			if page == "teams":
				menu.call("show_page", "modes")
			menu.call("show_page", page)
	for f in 20:
		await get_tree().process_frame
	var img := get_tree().root.get_texture().get_image()
	img.save_png(out)
	print("menú: ", out)
	get_tree().quit()
