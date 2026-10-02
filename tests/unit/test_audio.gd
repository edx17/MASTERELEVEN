extends GutTest
## Sonido generado por código: cada efecto existe, suena y tiene la forma
## esperada; el partido lo dispara en los momentos justos.


func test_every_sound_is_generated() -> void:
	for n in ["kick", "bounce", "post", "net", "whistle_short", "whistle_long", "whistle_end", "crowd", "cheer", "ooh"]:
		var w := MatchAudio.sound(n)
		assert_not_null(w, n)
		assert_gt(w.data.size(), 400, n)
		assert_lte(w.get_length(), 6.0, n)
	assert_eq(MatchAudio.sound("crowd").loop_mode, AudioStreamWAV.LOOP_FORWARD, "el público en loop")


func test_whistle_has_three_blasts_at_full_time() -> void:
	var w := MatchAudio.sound("whistle_end")
	assert_gt(w.get_length(), 2.0, "el pitazo final es largo")
	var s := w.data
	# Hay silencio entre pitazos (a los 0,42 s).
	var i := int(0.42 * MatchAudio.RATE) * 2
	assert_lt(absi(s.decode_s16(i)), 2000)


func test_match_triggers_sounds() -> void:
	GameSettings.set_mode(GameSettings.Mode.CPU_VS_CPU)
	var m: MatchController = load("res://scenes/match/match.tscn").instantiate()
	add_child_autofree(m)
	m.set_physics_process(false)
	assert_not_null(m.audio)
	var before := m.audio._next
	m.ball.kicked.emit(m.teams[0].players[5])
	assert_ne(m.audio._next, before, "la patada suena")
	before = m.audio._next
	m.goal_scored.emit(0)
	assert_ne(m.audio._next, before, "el gol se grita")
