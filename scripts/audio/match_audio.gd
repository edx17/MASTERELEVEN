class_name MatchAudio
extends Node
## Sonido del partido, generado por código (sin archivos: nada con licencia de
## terceros): silbato del árbitro, patadas, piques, palo y red, el murmullo
## del público (en loop, sube cuando la pelota se acerca a un arco), el grito
## del gol, el "uhh" de un remate que se va cerca, los silbidos de la hinchada
## en las faltas y tarjetas, cánticos con bombo de fondo (cada tanto), los
## aplausos al jugador que sale reemplazado, el "swoosh" de la cortina de la
## repetición y la música del menú. Volúmenes en Opciones.

const RATE := 22050

static var _cache := {}

var _match: MatchController
var _crowd: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _excite := 0.0
var _training := false
## Cánticos con bombo: arrancan cada tanto, duran un rato y se apagan.
var _chant: AudioStreamPlayer
var _chant_wait := 20.0
var _chant_left := 0.0
var _chant_level := 0.0


func setup(m: MatchController) -> void:
	_match = m
	_crowd = AudioStreamPlayer.new()
	# En el Club House no hay público: redoblantes y bombo de fondo.
	_training = GameSettings.training
	_crowd.stream = sound("drums" if _training else "crowd")
	_crowd.bus = &"Master"
	add_child(_crowd)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	m.ball.kicked.connect(func(_k: Footballer) -> void:
		var v := m.ball.speed()
		play("kick", clampf(v / 30.0, 0.25, 1.0), randf_range(0.9, 1.12) * lerpf(1.15, 0.85, clampf(v / 30.0, 0.0, 1.0))))
	m.ball.bounced.connect(func(strength: float) -> void:
		if strength > 2.0:
			play("bounce", clampf(strength / 12.0, 0.1, 0.6), randf_range(0.95, 1.1)))
	m.ball.hit_post.connect(func() -> void:
		play("post", 1.0)
		cheer("ooh"))
	m.ball.hit_net.connect(func() -> void: play("net", 0.7))
	m.goal_scored.connect(func(_t: int) -> void: cheer("goal"))
	m.phase_changed.connect(_on_phase)
	# Tarjeta: silbidos fuertes de la tribuna.
	m.card_shown.connect(func(_p: Footballer) -> void: crowd_whistles(1.0))
	if not _training:
		_chant = AudioStreamPlayer.new()
		_chant.stream = sound("chant")
		_chant.volume_db = -80.0
		add_child(_chant)
		_chant_wait = randf_range(8.0, 25.0)
	# Presentación: el público responde a cada nombre que dice el locutor.
	if m.intro != null:
		m.intro.player_announced.connect(func(_p: Footballer) -> void:
			if not _training:
				play("ooh", 0.45, randf_range(0.95, 1.1), true))
	_crowd.play()


func _process(dt: float) -> void:
	if _match == null or _crowd == null:
		return
	if _training:
		_crowd.volume_db = linear_to_db(maxf(0.0001, GameSettings.crowd_volume / 10.0 * 0.45))
		return
	# El murmullo sube cuando la pelota se acerca a un arco.
	var x := absf(_match.ball.global_position.x) / Pitch.HALF_LENGTH
	var target := clampf((x - 0.55) * 2.2, 0.0, 1.0)
	_excite = lerpf(_excite, target, 1.0 - exp(-dt * 1.5))
	_crowd.volume_db = linear_to_db(maxf(0.0001, GameSettings.crowd_volume / 10.0 * (0.35 + 0.35 * _excite)))
	_update_chant(dt)


## Cánticos de fondo: cada 30-70 s la hinchada canta 12-25 s con el bombo
## (sólo con la pelota en juego o parada; se callan en el gol y al final).
func _update_chant(dt: float) -> void:
	if _chant == null:
		return
	var singing := _match.phase in [MatchController.Phase.PLAYING, MatchController.Phase.STOPPED,
		MatchController.Phase.RESTART, MatchController.Phase.REPLAY]
	if _chant_left > 0.0:
		_chant_left -= dt
	elif singing:
		_chant_wait -= dt
		if _chant_wait <= 0.0:
			_chant_left = randf_range(12.0, 25.0)
			_chant_wait = randf_range(30.0, 70.0)
			if not _chant.playing:
				_chant.play()
	var target := 1.0 if _chant_left > 0.0 and singing else 0.0
	_chant_level = move_toward(_chant_level, target, dt / 2.5)
	if _chant_level <= 0.0:
		if _chant.playing:
			_chant.stop()
		return
	_chant.volume_db = linear_to_db(maxf(0.0001, GameSettings.crowd_volume / 10.0 * 0.4 * _chant_level))


## Silbidos de la hinchada (faltas, tarjetas). `strength` 0..1.
func crowd_whistles(strength: float = 0.6) -> void:
	if _training:
		return
	play("whistles", clampf(strength, 0.1, 1.0), randf_range(0.94, 1.06), true)


## Aplausos (jugador reemplazado que sale).
func applause() -> void:
	if _training:
		return
	play("applause", 0.8, randf_range(0.97, 1.03), true)


func _on_phase(phase: int) -> void:
	match phase:
		MatchController.Phase.STOPPED:
			play("whistle_short", 0.9)
		MatchController.Phase.HALFTIME:
			play("whistle_long", 1.0)
		MatchController.Phase.FULLTIME:
			play("whistle_end", 1.0)
		MatchController.Phase.RESTART:
			if _match.restart_type == MatchRules.Restart.KICKOFF:
				play("whistle_short", 0.9)


## Grito del público: "goal" (gol) u "ooh" (se fue cerca / palo).
func cheer(kind: String) -> void:
	if _training:
		return # sin público
	play("cheer" if kind == "goal" else "ooh", 1.0, 1.0, true)


## Reproduce un sonido (volumen 0..1 sobre el de efectos o el del público).
func play(name: String, volume: float = 1.0, pitch: float = 1.0, crowd := false) -> void:
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = sound(name)
	p.pitch_scale = pitch
	var master := (GameSettings.crowd_volume if crowd else GameSettings.sfx_volume) / 10.0
	p.volume_db = linear_to_db(maxf(0.0001, volume * master))
	p.play()


# --- Síntesis ---------------------------------------------------------------------

static func sound(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var s: PackedFloat32Array
	var loop := false
	match name:
		"kick": s = _kick()
		"bounce": s = _bounce()
		"post": s = _post()
		"net": s = _noise_burst(0.35, 0.2, 0.0, 0.25)
		"whistle_short": s = _whistle([[0.0, 0.32]])
		"whistle_long": s = _whistle([[0.0, 0.3], [0.45, 1.3]])
		"whistle_end": s = _whistle([[0.0, 0.35], [0.5, 0.85], [1.0, 2.2]])
		"crowd":
			s = _crowd_loop(6.0)
			loop = true
		"drums":
			s = _drums_loop()
			loop = true
		"cheer": s = _cheer(4.5, 1.0)
		"ooh": s = _cheer(1.6, 0.6)
		"whistles": s = _crowd_whistles(2.0)
		"applause": s = _applause(3.0)
		"swoosh": s = _swoosh(0.45)
		"chant":
			s = _chant_loop()
			loop = true
		"menu_music":
			s = _menu_music()
			loop = true
		_: s = PackedFloat32Array([0.0])
	var w := to_wav(s, loop)
	_cache[name] = w
	return w


static func to_wav(s: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w


## Patada: golpe grave que cae de tono y un "clic" del cuero.
static func _kick() -> PackedFloat32Array:
	var n := int(RATE * 0.16)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(140.0, 55.0, minf(t / 0.06, 1.0))
		ph += TAU * f / RATE
		var body := sin(ph) * exp(-t * 32.0)
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.6
		out[i] = (body + click) * 0.9
	return out


static func _bounce() -> PackedFloat32Array:
	var n := int(RATE * 0.1)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * lerpf(110.0, 70.0, t / 0.1) / RATE
		out[i] = sin(ph) * exp(-t * 45.0) * 0.8
	return out


## Palo: parciales metálicos que suenan un rato.
static func _post() -> PackedFloat32Array:
	var n := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials := [[520.0, 1.0, 5.0], [1380.0, 0.6, 7.0], [2260.0, 0.4, 9.0], [3410.0, 0.25, 12.0]]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for pp in partials:
			v += sin(TAU * pp[0] * t) * pp[1] * exp(-t * pp[2])
		out[i] = v * 0.35 + (randf_range(-1.0, 1.0) * exp(-t * 300.0) * 0.3 if i < 200 else 0.0)
	return out


## Ráfaga de ruido filtrado (red, ambiente).
static func _noise_burst(seconds: float, attack: float, sustain: float, release: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / maxf(attack, 0.001), 1.0) if t < attack + sustain else maxf(0.0, 1.0 - (t - attack - sustain) / maxf(release, 0.001))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		out[i] = lp * env * 0.7
	return out


## Silbato de árbitro: tono agudo con el trino de la bolita.
static func _whistle(blasts: Array) -> PackedFloat32Array:
	var total := 0.0
	for b in blasts:
		total = maxf(total, b[0] + b[1])
	var n := int(RATE * (total + 0.1))
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := 0.0
		for b in blasts:
			var lt: float = t - b[0]
			if lt >= 0.0 and lt <= b[1]:
				env = maxf(env, minf(lt / 0.015, 1.0) * minf((b[1] - lt) / 0.04, 1.0))
		var trill := 0.75 + 0.25 * sin(TAU * 32.0 * t)
		ph += TAU * (2950.0 + 60.0 * sin(TAU * 32.0 * t)) / RATE
		out[i] = (sin(ph) + 0.25 * sin(ph * 2.0)) * env * trill * 0.45
	return out


## Murmullo del público en loop: ruido grave filtrado con oleadas lentas. El
## final se funde con el principio para que no se note el corte.
static func _crowd_loop(seconds: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var lp1 := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		lp1 += (x - lp1) * 0.08
		lp2 += (lp1 - lp2) * 0.25
		var swell := 0.75 + 0.15 * sin(TAU * t / seconds * 2.0) + 0.1 * sin(TAU * t / seconds * 5.0 + 1.3)
		out[i] = lp2 * 3.2 * swell
	var fade := int(RATE * 0.5)
	for i in fade:
		var k := float(i) / fade
		out[i] = out[i] * k + out[n - fade + i] * (1.0 - k)
	return out.slice(0, n - fade)


## Grito: ruido que sube de golpe y baja despacio, con "vocales" (bandas).
static func _cheer(seconds: float, strength: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var lp := 0.0
	var bp := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.25, 1.0) * exp(-maxf(0.0, t - 0.6) * 1.1 / seconds * 3.0)
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.22
		hp = lp - bp
		bp += hp * 0.06
		var vowel := 0.8 + 0.2 * sin(TAU * 3.0 * t + sin(TAU * 0.7 * t))
		out[i] = (lp * 0.8 + hp * 0.6) * env * vowel * strength
	return out


## Percusión del Club House: marcha de redoblante (golpes y redobles) sobre
## un bombo, a 100 pulsos por minuto, dos compases en loop.
static func _drums_loop() -> PackedFloat32Array:
	var bpm := 100.0
	var beat := 60.0 / bpm
	var bars := 2
	var n := int(RATE * beat * 4.0 * bars)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2002
	# Golpes en semicorcheas: [paso (0..31), instrumento, fuerza]. 0 = bombo,
	# 1 = redoblante.
	var hits := []
	for b in bars:
		var o := b * 16
		hits.append([o + 0, 0, 1.0])
		hits.append([o + 8, 0, 0.9])
		hits.append([o + 4, 1, 1.0])
		hits.append([o + 12, 1, 1.0])
		hits.append([o + 6, 1, 0.45])
		hits.append([o + 14, 1, 0.45])
		hits.append([o + 15, 1, 0.55])
	# Redoble al final del segundo compás.
	for k in 4:
		hits.append([28 + k, 1, 0.5 + k * 0.12])
	var step := beat / 4.0
	for h in hits:
		var start := int(float(h[0]) * step * RATE)
		var strength: float = h[2]
		if h[1] == 0:
			var ph := 0.0
			for i in int(RATE * 0.35):
				if start + i >= n:
					break
				var t := float(i) / RATE
				ph += TAU * lerpf(90.0, 48.0, minf(t / 0.12, 1.0)) / RATE
				out[start + i] += sin(ph) * exp(-t * 11.0) * 0.8 * strength
		else:
			var lp := 0.0
			for i in int(RATE * 0.18):
				if start + i >= n:
					break
				var t := float(i) / RATE
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.6
				var tone := sin(TAU * 190.0 * t) * exp(-t * 40.0) * 0.4
				out[start + i] += (lp * exp(-t * 24.0) * 0.55 + tone) * strength
	return out


## Silbidos de la tribuna: muchos silbidos agudos, cada uno con su tono, su
## vibrato y su momento (no al unísono).
static func _crowd_whistles(seconds: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for k in 14:
		var f0 := rng.randf_range(1700.0, 3300.0)
		var start := rng.randf_range(0.0, 0.5)
		var length := rng.randf_range(0.8, seconds - start)
		var vib := rng.randf_range(4.0, 7.0)
		var glide := rng.randf_range(-300.0, 200.0)
		var amp := rng.randf_range(0.04, 0.09)
		var ph := 0.0
		var i0 := int(start * RATE)
		for i in int(length * RATE):
			if i0 + i >= n:
				break
			var t := float(i) / RATE
			var env := minf(t / 0.08, 1.0) * minf((length - t) / 0.25, 1.0)
			ph += TAU * (f0 + glide * t / length + 40.0 * sin(TAU * vib * t)) / RATE
			out[i0 + i] += sin(ph) * env * amp
	return out


## Aplausos: palmadas sueltas (ráfagas cortas de ruido) que se juntan y se
## van apagando.
static func _applause(seconds: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	var claps := int(seconds * 70.0)
	for c in claps:
		# Más palmadas al principio; se apaga hacia el final.
		var t0 := pow(rng.randf(), 1.4) * (seconds - 0.05)
		var amp := rng.randf_range(0.25, 0.55) * (1.0 - t0 / seconds * 0.7)
		var bright := rng.randf_range(0.35, 0.75)
		var i0 := int(t0 * RATE)
		var lp := 0.0
		for i in int(RATE * 0.03):
			if i0 + i >= n:
				break
			var x := rng.randf_range(-1.0, 1.0)
			lp += (x - lp) * bright
			out[i0 + i] += (x - lp) * exp(-float(i) / RATE * 160.0) * amp
	return out


## Cortina de la repetición: ruido que barre de grave a agudo y vuelve.
static func _swoosh(seconds: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / n
		var env := sin(PI * t)
		env *= env
		var k := lerpf(0.03, 0.45, sin(PI * t))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * k
		lp2 += (lp - lp2) * k
		out[i] = lp2 * env * 1.4
	return out


## Cántico con bombo (loop de 2 compases a 120 por minuto): un coro de voces
## desafinadas entre sí cantando "o-le-o-le" (vocales con formantes) y el
## bombo marcando el tiempo.
static func _chant_loop() -> PackedFloat32Array:
	var beat := 0.5
	var n := int(RATE * beat * 8.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# [inicio (tiempos), duración (tiempos), semitono sobre la base].
	var melody := [[0.0, 1.0, 0], [1.0, 1.0, 4], [2.0, 0.5, 7], [2.5, 1.5, 4],
		[4.0, 1.0, 0], [5.0, 1.0, 4], [6.0, 0.5, 5], [6.5, 1.5, 2]]
	var base := 196.0 # sol
	for v in 7:
		var detune := rng.randf_range(-0.025, 0.025)
		var delay := rng.randf_range(0.0, 0.05)
		var amp := rng.randf_range(0.035, 0.06)
		var oct := 0.5 if v % 3 == 0 else 1.0
		for note in melody:
			var f := base * oct * pow(2.0, float(note[2]) / 12.0) * (1.0 + detune)
			var i0 := int((float(note[0]) * beat + delay) * RATE)
			var count := int(float(note[1]) * beat * RATE * 0.92)
			var ph := rng.randf() * TAU
			var lp := 0.0
			for i in count:
				var idx := (i0 + i) % n
				var t := float(i) / RATE
				var env := minf(t / 0.06, 1.0) * minf(float(count - i) / (RATE * 0.08), 1.0)
				ph += TAU * f * (1.0 + 0.006 * sin(TAU * 5.0 * t)) / RATE
				# Diente de sierra suavizado: voz "abierta" (vocal o / e).
				var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
				lp += (saw - lp) * 0.12
				out[idx] += lp * env * amp
	# Bombo en cada tiempo (más fuerte en el 1 y el 3).
	for b in 8:
		var i0 := int(b * beat * RATE)
		var ph2 := 0.0
		var strength := 1.0 if b % 2 == 0 else 0.7
		for i in int(RATE * 0.4):
			if i0 + i >= n:
				break
			var t := float(i) / RATE
			ph2 += TAU * lerpf(85.0, 45.0, minf(t / 0.1, 1.0)) / RATE
			out[i0 + i] += sin(ph2) * exp(-t * 9.0) * 0.55 * strength
	return out


## Música del menú: pop electrónico simple a 128 por minuto (bajo, acordes
## en arpegio, bombo, redoblante y platillo), 8 compases en loop.
## Progresión I - vi - IV - V en do.
static func _menu_music() -> PackedFloat32Array:
	var bpm := 128.0
	var beat := 60.0 / bpm
	var bars := 8
	var n := int(RATE * beat * 4.0 * bars)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2002
	var chords := [[48, 52, 55], [45, 48, 52], [41, 45, 48], [43, 47, 50]]
	var step := beat / 4.0
	for bar in bars:
		var ch: Array = chords[bar % 4]
		var bar0 := bar * 4.0 * beat
		# Bajo: corcheas en la fundamental (una octava abajo).
		for e in 8:
			var f := _midi(int(ch[0]) - 12)
			_tone(out, bar0 + e * beat * 0.5, beat * 0.45, f, 0.16, 1)
		# Arpegio: semicorcheas subiendo por el acorde (una octava arriba).
		for s16 in 16:
			var note: int = int(ch[s16 % 3]) + 12 + (12 if s16 % 8 >= 6 else 0)
			_tone(out, bar0 + s16 * step, step * 0.8, _midi(note), 0.07, 0)
		# Melodía larga (la tercera del acorde, dos octavas arriba) en la 2da mitad.
		if bar >= 4:
			_tone(out, bar0, beat * 1.9, _midi(int(ch[1]) + 24), 0.05, 2)
			_tone(out, bar0 + beat * 2.0, beat * 1.9, _midi(int(ch[2]) + 24), 0.05, 2)
		# Batería.
		for q in 4:
			_kick_at(out, bar0 + q * beat, 0.5)
			if q % 2 == 1:
				_noise_at(out, bar0 + q * beat, 0.16, 0.22, 0.5, rng)
			_noise_at(out, bar0 + q * beat + beat * 0.5, 0.05, 0.06, 0.95, rng)
	return out


static func _midi(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)


## Nota con envolvente. wave: 0 pulso suave, 1 cuadrada (bajo), 2 seno.
static func _tone(out: PackedFloat32Array, start: float, length: float, f: float, amp: float, wave: int) -> void:
	var i0 := int(start * RATE)
	var count := int(length * RATE)
	var lp := 0.0
	for i in count:
		var idx := i0 + i
		if idx >= out.size():
			break
		var t := float(i) / RATE
		var env := minf(t / 0.005, 1.0) * exp(-t * (6.0 if wave == 0 else 1.5)) * minf(float(count - i) / (RATE * 0.01), 1.0)
		var ph := fmod(f * t, 1.0)
		var v := 0.0
		match wave:
			0: v = 1.0 if ph < 0.25 else -0.33
			1: v = 1.0 if ph < 0.5 else -1.0
			2: v = sin(TAU * ph) + 0.2 * sin(TAU * ph * 2.0)
		lp += (v - lp) * 0.3
		out[idx] += lp * env * amp


static func _kick_at(out: PackedFloat32Array, start: float, amp: float) -> void:
	var i0 := int(start * RATE)
	var ph := 0.0
	for i in int(RATE * 0.2):
		if i0 + i >= out.size():
			break
		var t := float(i) / RATE
		ph += TAU * lerpf(120.0, 45.0, minf(t / 0.05, 1.0)) / RATE
		out[i0 + i] += sin(ph) * exp(-t * 18.0) * amp


static func _noise_at(out: PackedFloat32Array, start: float, length: float, amp: float, bright: float,
		rng: RandomNumberGenerator) -> void:
	var i0 := int(start * RATE)
	var lp := 0.0
	for i in int(length * RATE):
		if i0 + i >= out.size():
			break
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * (1.0 - bright)
		out[i0 + i] += (x - lp) * exp(-t * 3.0 / length) * amp
