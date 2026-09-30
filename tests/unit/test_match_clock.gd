extends GutTest
## Reloj acelerado.


func test_five_minute_match_half_lasts_150_real_seconds() -> void:
	var c := MatchClock.new(5.0)
	c.running = true
	c.advance(149.0)
	assert_false(c.is_half_over())
	c.advance(1.5)
	assert_true(c.is_half_over())
	assert_eq(c.display(), "45:00")


func test_second_half_starts_at_45() -> void:
	var c := MatchClock.new(10.0)
	c.running = true
	c.advance(300.0)
	c.start_second_half()
	assert_eq(c.display(), "45:00")
	c.advance(150.0)
	assert_eq(c.display(), "67:30")


func test_clock_stopped_does_not_advance() -> void:
	var c := MatchClock.new(5.0)
	c.advance(10.0)
	assert_eq(c.display(), "00:00")
