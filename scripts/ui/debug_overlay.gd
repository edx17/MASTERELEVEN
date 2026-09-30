class_name DebugOverlay
extends CanvasLayer
## Modo DEBUG (F9): texto con el estado del partido y, en 3D, la trayectoria
## predicha de la pelota, el objetivo de cada jugador (línea) y la posición
## base de formación (cruz). No afecta la simulación.

var _match: MatchController
var _label: Label
var _mesh: MeshInstance3D
var _im: ImmediateMesh


func setup(p_match: MatchController) -> void:
	_match = p_match
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.position += Vector2(-16, 12)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)

	_im = ImmediateMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_match.add_child(_mesh)
	_set_enabled(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle"):
		_set_enabled(not visible)


func _set_enabled(on: bool) -> void:
	visible = on
	_mesh.visible = on


func _process(_dt: float) -> void:
	if not visible or _match == null:
		return
	_label.text = _status_text()
	_draw_world()


func _status_text() -> String:
	var b := _match.ball
	var owner := b.owner_player
	var lines: Array[String] = []
	lines.append("DEBUG (F9)   fase: %s   reloj: %s" % [MatchController.Phase.keys()[_match.phase], _match.clock.display()])
	var poss := "LIBRE"
	if owner != null:
		poss = "%s (%s)" % [owner.team.short_name, owner.name]
	lines.append("posesión: %s   último toque: %s" % [poss, b.last_toucher.name if b.last_toucher else "-"])
	lines.append("pelota: vel %.1f m/s  alt %.2f m  receptor: %s" % [b.speed(), b.state.pos.y, b.intended_receiver.name if b.intended_receiver else "-"])
	if owner != null:
		lines.append("conductor: presión %.2f  toques %d  pelota a %.2f m del pie" % [owner.dribble_pressure, owner.touches,
			b.flat_pos().distance_to(Dribble.foot_point(owner.global_position, owner.facing))])
	for h in _match.humans:
		var p := h.controlled
		if p != null:
			lines.append("P%d: %s  vel %.1f m/s  potencia %.0f%%  error último pase/tiro %.1f°" % [h.slot + 1, p.name,
				Vector3(p.velocity.x, 0.0, p.velocity.z).length(), h.power * 100.0, _match.kicks.last_error])
	for t in _match.teams:
		var counts := {}
		for p in t.players:
			if not p.is_human():
				counts[p.debug_state] = counts.get(p.debug_state, 0) + 1
		var ai := _match.ais[t.index]
		lines.append("%s [%s | %s | %s]: %s" % [t.short_name, ai.state_name(),
			t.formation.formation_name if t.formation else "-", Difficulty.NAMES[ai.difficulty.level], str(counts)])
	return "\n".join(lines)


func _draw_world() -> void:
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	# Trayectoria predicha de la pelota.
	var prev := _match.ball.state.pos
	for p in _match.ball_forecast:
		_line(prev, p, Color(1.0, 0.9, 0.2))
		prev = p
	for t in _match.teams:
		var c := t.color.lightened(0.3)
		for p in t.players:
			var from := p.global_position + Vector3.UP * 0.1
			if not p.is_human() and p.debug_target != Vector3.ZERO:
				_line(from, p.debug_target + Vector3.UP * 0.1, c)
			# Posición táctica (cruz) según formación y pelota.
			var home := _match.ais[t.index].shape_target(p) + Vector3.UP * 0.05
			_line(home + Vector3(-0.4, 0, 0), home + Vector3(0.4, 0, 0), c.darkened(0.3))
			_line(home + Vector3(0, 0, -0.4), home + Vector3(0, 0, 0.4), c.darkened(0.3))
	_im.surface_end()


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_im.surface_set_color(c)
	_im.surface_add_vertex(a)
	_im.surface_set_color(c)
	_im.surface_add_vertex(b)
