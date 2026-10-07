extends GutTest
## Tokens del rediseño "estadio de noche" (WEStyle).


func test_palette_matches_the_guide() -> void:
	assert_eq(WEStyle.BG_NIGHT, Color("#0B1220"))
	assert_eq(WEStyle.BG_PANEL, Color("#111A2E"))
	assert_eq(WEStyle.BG_PANEL_ALT, Color("#16223A"))
	assert_eq(WEStyle.ACCENT, Color("#E8C547"))
	assert_eq(WEStyle.ACCENT_GREEN, Color("#3FB96B"))
	assert_eq(WEStyle.TEXT_MAIN, Color("#EDF1F7"))
	assert_eq(WEStyle.TEXT_DIM, Color("#8B96AB"))
	assert_eq(WEStyle.LINE, Color("#24304A"))
	assert_eq(WEStyle.DANGER, Color("#D95555"))


func test_scale_maps_1080p_to_the_720p_base() -> void:
	assert_almost_eq(WEStyle.px(64), 64.0 * 720.0 / 1080.0, 0.001)
	assert_eq(WEStyle.font_px(WEStyle.TITLE_XL), 43)
	assert_eq(WEStyle.font_px(WEStyle.BODY_S), 9)
	# Escalado a 1920×1080 vuelve a ser la medida de la guía.
	assert_almost_eq(WEStyle.px(WEStyle.ROW_H) * 1080.0 / 720.0, 44.0, 0.001)


func test_focus_and_panel_styles() -> void:
	var f := WEStyle.make_focus_style()
	assert_eq(f.border_color, WEStyle.ACCENT)
	assert_eq(f.border_width_left, 2)
	assert_eq(f.bg_color, WEStyle.BG_PANEL_ALT)
	var p := WEStyle.make_panel_style()
	assert_eq(p.bg_color, WEStyle.BG_PANEL)
	assert_eq(p.border_color, WEStyle.LINE)
	assert_eq(p.border_width_top, 1)
	assert_eq(WEStyle.make_button_style("focus").border_color, WEStyle.ACCENT)


func test_fonts_load() -> void:
	for face in WEStyle.FONT_PATHS:
		var f := WEStyle.font(face)
		assert_not_null(f)
		assert_ne(f, ThemeDB.fallback_font, "carga %s" % WEStyle.FONT_PATHS[face])
	var t := WEStyle.make_title_label("VIRTUAL ELEVEN", WEStyle.TITLE_XL)
	assert_eq(t.get_theme_font_size("font_size"), 43)
	t.free()
