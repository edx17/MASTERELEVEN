extends GutTest
## Resumen de la prueba de rendimiento.

func test_summary() -> void:
	var frames := PackedFloat32Array()
	for i in 99:
		frames.append(1.0 / 60.0)
	frames.append(0.05)
	var BR := load("res://tools/benchmark_runner.gd")
	var r: Dictionary = BR.summarize(frames)
	assert_almost_eq(r["worst_ms"], 50.0, 0.01)
	assert_almost_eq(r["low1_fps"], 20.0, 0.01, "1 % más lento = el cuadro de 50 ms")
	assert_between(r["avg_fps"], 55.0, 60.0)
