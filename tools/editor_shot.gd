extends Node
## Captura del Editor (para revisar su diseño):
##   xvfb-run godot -- --editor --editor-shot=archivo.png [--editor-tab=0|1|2] [--editor-select=1|3] [--editor-review-clubs] [--editor-review-squads] [--editor-u20]

var out := "user://editor.png"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for f in 20:
		await get_tree().process_frame
	var ed := get_tree().current_scene
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--editor-tab="):
			ed.get("_tabs").current_tab = int(a.trim_prefix("--editor-tab="))
		if a == "--editor-review-clubs":
			ed.call("_clubs_review")
		if a == "--editor-review-squads":
			ed.call("_squads_review")
		if a == "--editor-u20":
			(ed.get("_t_squad") as OptionButton).select(1)
			ed.call("_show_team", ed.get("_t_current"))
		if a.begins_with("--editor-select="):
			var n := int(a.trim_prefix("--editor-select="))
			var tree: Tree = ed.get("_tree")
			var it := tree.get_root().get_first_child()
			for i in n:
				if it == null:
					break
				it.select(0)
				it = it.get_next()
			ed.call("_on_selection")
	for f in 20:
		await get_tree().process_frame
	get_tree().root.get_texture().get_image().save_png(out)
	print("editor: ", out)
	get_tree().quit()
