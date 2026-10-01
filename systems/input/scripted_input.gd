class_name ScriptedInput
extends InputSource
## Input programable para tests y demos: se fija la dirección y qué botones
## están apretados; "just_pressed/released" se calculan entre polls.

var move: Vector3 = Vector3.ZERO
var right: Vector3 = Vector3.ZERO
var _held: Dictionary = {}
var _prev: Dictionary = {}
var _now: Dictionary = {}


func hold(action: StringName) -> void:
	_held[action] = true


func release(action: StringName) -> void:
	_held.erase(action)


func poll() -> void:
	_prev = _now
	_now = _held.duplicate()


func move_vector() -> Vector3:
	return move


func right_vector() -> Vector3:
	return right


func pressed(action: StringName) -> bool:
	return _now.has(action)


func just_pressed(action: StringName) -> bool:
	return _now.has(action) and not _prev.has(action)


func just_released(action: StringName) -> bool:
	return _prev.has(action) and not _now.has(action)
