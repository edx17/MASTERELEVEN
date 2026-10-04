extends SceneTree
## Completa la ficha ampliada (ataque, salto, potencia, curva, altura y
## etiquetas) en los equipos ya generados, sin tocar el resto de los datos.
## Uso: godot --headless -s tools/migrate_extended.gd


func _initialize() -> void:
	var dir := DirAccess.open("res://data/teams")
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var path := "res://data/teams/" + f
		var team := load(path) as TeamData
		if team == null:
			continue
		for p: PlayerData in team.players:
			p.fill_extended()
		var cap := PlayerData.pick_captain(team.players)
		if cap != null and not cap.abilities.has("capitan"):
			cap.abilities.append("capitan")
		var err := ResourceSaver.save(team, path)
		print("%s: %s" % [f, "ok" if err == OK else "error %d" % err])
	quit()
