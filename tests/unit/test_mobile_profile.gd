extends GutTest
## Celular: siempre de día (sin luces del estadio) y césped con texturas chicas.


func after_each() -> void:
	GameSettings.force_mobile = false
	GameSettings.time_choice = MatchConditions.TimeOfDay.AFTERNOON


func test_mobile_always_plays_by_day() -> void:
	GameSettings.force_mobile = true
	GameSettings.time_choice = MatchConditions.TimeOfDay.NIGHT
	assert_eq(GameSettings.make_conditions().time_of_day, MatchConditions.TimeOfDay.AFTERNOON, "noche -> tarde")
	GameSettings.time_choice = -1
	for i in 20:
		assert_lte(GameSettings.make_conditions().time_of_day, MatchConditions.TimeOfDay.AFTERNOON, "al azar, de día")
	GameSettings.force_mobile = false
	GameSettings.time_choice = MatchConditions.TimeOfDay.NIGHT
	assert_eq(GameSettings.make_conditions().time_of_day, MatchConditions.TimeOfDay.NIGHT, "en la PC, la noche sigue")


func test_no_floodlights_on_mobile_at_night() -> void:
	GameSettings.force_mobile = true
	var c := MatchConditions.new()
	c.time_of_day = MatchConditions.TimeOfDay.NIGHT
	var atm := Atmosphere.new()
	add_child_autofree(atm)
	atm.setup(c)
	assert_eq(atm.find_children("*", "SpotLight3D", true, false).size(), 0, "sin reflectores")


func test_grass_textures_are_smaller_on_mobile() -> void:
	GameSettings.force_mobile = true
	var mat := ShaderMaterial.new()
	if not GrassTextures.apply(mat):
		pass_test("sin texturas de césped en el proyecto")
		return
	var tex: Texture2D = mat.get_shader_parameter("albedo_tex")
	assert_lte(maxi(tex.get_width(), tex.get_height()), GrassTextures.MOBILE_MAX)
	assert_true(tex.get_image().has_mipmaps())
