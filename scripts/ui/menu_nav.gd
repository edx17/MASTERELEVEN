extends Node
## Navegación de los menús con la cruceta o las flechas (autoload):
##   - Los listados son circulares: arriba de todo, para arriba, va abajo de
##     todo (y al revés), como una rueda.
##   - Manteniendo apretado se mueve solo, cada vez más rápido.
## Sólo actúa cuando el foco está en un botón u opción de menú (los árboles,
## listas y campos de texto se manejan solos).
##
## Además pasa cada evento a InputRouter.observe(), que decide si se está
## jugando con teclado o con mando (para las indicaciones de control).

const FIRST_DELAY := 0.32
const START_RATE := 0.10
const MIN_RATE := 0.03
## Cuánto se acorta el intervalo por segundo de mantener apretado.
const ACCEL := 0.05

var _dir := 0
var _held := 0.0
var _next := 0.0


func _input(event: InputEvent) -> void:
	InputRouter.observe(event)
	var up := event.is_action(&"ui_up")
	if not up and not event.is_action(&"ui_down"):
		return
	var f := get_viewport().gui_get_focus_owner()
	if not handles(f):
		return
	get_viewport().set_input_as_handled()
	if event.is_echo():
		return # la repetición la maneja _process (con aceleración)
	var d := -1 if up else 1
	if event.is_pressed():
		_dir = d
		_held = 0.0
		_next = FIRST_DELAY
		step(f, d)
	elif _dir == d:
		_dir = 0


func _process(delta: float) -> void:
	if _dir == 0:
		return
	if not Input.is_action_pressed(&"ui_up" if _dir < 0 else &"ui_down"):
		_dir = 0
		return
	_held += delta
	_next -= delta
	if _next > 0.0:
		return
	var f := get_viewport().gui_get_focus_owner()
	if not handles(f):
		_dir = 0
		return
	step(f, _dir)
	_next = maxf(MIN_RATE, START_RATE - _held * ACCEL)


static func handles(f: Control) -> bool:
	if f == null or not f.is_visible_in_tree():
		return false
	if f is Tree or f is ItemList or f is LineEdit or f is TextEdit or f is Range:
		return false
	return f is BaseButton or f.focus_mode == Control.FOCUS_ALL


## Mueve el foco una posición (d = -1 arriba, 1 abajo); en la punta da la vuelta.
static func step(f: Control, d: int) -> Control:
	var n := f.find_valid_focus_neighbor(SIDE_TOP if d < 0 else SIDE_BOTTOM)
	if n == null or n == f:
		n = _wrap_target(f, d)
	if n != null and n != f:
		n.grab_focus()
		_show(n)
	return n


## Del otro extremo de la misma columna: el más de abajo (si se subía) o el
## más de arriba (si se bajaba), entre los que se cruzan en horizontal.
static func _wrap_target(f: Control, d: int) -> Control:
	var scope: Control = f
	while scope.get_parent() is Control:
		scope = scope.get_parent()
	var r := f.get_global_rect()
	var best: Control = null
	for c: Control in _focusables(scope):
		if c == f:
			continue
		var cr := c.get_global_rect()
		if cr.position.x > r.end.x or cr.end.x < r.position.x:
			continue
		if best == null or (d > 0 and cr.position.y < best.global_position.y) \
				or (d < 0 and cr.position.y > best.global_position.y):
			best = c
	return best


static func _focusables(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is Control and (c as Control).is_visible_in_tree():
			var cc := c as Control
			if cc.focus_mode == Control.FOCUS_ALL and not (cc is BaseButton and (cc as BaseButton).disabled):
				out.append(cc)
			out.append_array(_focusables(cc))
	return out


## Si está dentro de una lista con barra, la lista se corre para mostrarlo.
static func _show(c: Control) -> void:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(c)
			return
		p = p.get_parent()
