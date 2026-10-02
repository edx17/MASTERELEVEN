class_name MatchAudio
extends Node
## Sonido del partido, generado por código (sin archivos: nada con licencia de
## terceros): silbato del árbitro, patadas, piques, palo y red, el murmullo
## del público (en loop, sube cuando la pelota se acerca a un arco), el grito
## del gol y el "uhh" de un remate que se va cerca. Volúmenes en Opciones.

const RATE := 22050

static var _cache := {}

var _match: MatchController
var _crowd: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _excite := 0.0


func setup(m: MatchController) -> void:
	_match = m
	_crowd = AudioStreamPlayer.new()
	_crowd.stream = sound("crowd")
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
	_crowd.play()


func _process(dt: float) -> void:
	if _match == null or _crowd == null:
		return
	# El murmullo sube cuando la pelota se acerca a un arco.
	var x := absf(_match.ball.global_position.x) / Pitch.HALF_LENGTH
	var target := clampf((x - 0.55) * 2.2, 0.0, 1.0)
	_excite = lerpf(_excite, target, 1.0 - exp(-dt * 1.5))
	_crowd.volume_db = linear_to_db(maxf(0.0001, GameSettings.crowd_volume / 10.0 * (0.35 + 0.35 * _excite)))


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
		"cheer": s = _cheer(4.5, 1.0)
		"ooh": s = _cheer(1.6, 0.6)
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
