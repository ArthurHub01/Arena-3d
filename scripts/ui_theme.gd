class_name UiTheme
extends RefCounted

const COL_VOID := Color(0.055, 0.045, 0.036, 1.0)
const COL_PANEL := Color(0.090, 0.075, 0.058, 1.0)
const COL_HAIRLINE := Color(0.20, 0.165, 0.12, 1.0)
const COL_INK := Color(0.925, 0.895, 0.84, 1.0)
const COL_INK_DIM := Color(0.55, 0.48, 0.40, 1.0)
const COL_SIGNAL := Color(0.85, 0.63, 0.30, 1.0)
const COL_BLOOD := Color(0.549, 0.165, 0.125, 1.0)
const COL_HEALTH := Color(0.85, 0.16, 0.16, 1.0)

static func title_font() -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Cinzel-Variable.ttf")
	f.variation_opentype = {"wght": 700}
	f.spacing_glyph = 4
	return f

static func eyebrow_font() -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	f.spacing_glyph = 3
	return f

static func build() -> Theme:
	var theme := Theme.new()
	var rajdhani_medium: FontFile = load("res://assets/fonts/Rajdhani-Medium.ttf")
	var rajdhani_semibold: FontFile = load("res://assets/fonts/Rajdhani-SemiBold.ttf")

	theme.default_font = rajdhani_medium
	theme.default_font_size = 18

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0, 0, 0, 0)
	btn_normal.border_color = COL_HAIRLINE
	btn_normal.set_border_width_all(1)
	btn_normal.set_content_margin_all(14)
	btn_normal.content_margin_top = 11
	btn_normal.content_margin_bottom = 11

	var btn_hover: StyleBoxFlat = btn_normal.duplicate()
	btn_hover.border_color = COL_SIGNAL
	btn_hover.bg_color = Color(COL_SIGNAL.r, COL_SIGNAL.g, COL_SIGNAL.b, 0.07)

	var btn_pressed: StyleBoxFlat = btn_normal.duplicate()
	btn_pressed.bg_color = Color(COL_SIGNAL.r, COL_SIGNAL.g, COL_SIGNAL.b, 0.16)
	btn_pressed.border_color = COL_SIGNAL

	var btn_disabled: StyleBoxFlat = btn_normal.duplicate()
	btn_disabled.border_color = Color(COL_HAIRLINE.r, COL_HAIRLINE.g, COL_HAIRLINE.b, 0.5)

	var btn_focus := StyleBoxFlat.new()
	btn_focus.bg_color = Color(0, 0, 0, 0)
	btn_focus.border_color = COL_SIGNAL
	btn_focus.set_border_width_all(1)
	btn_focus.set_content_margin_all(14)
	btn_focus.content_margin_top = 11
	btn_focus.content_margin_bottom = 11

	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_stylebox("focus", "Button", btn_focus)
	theme.set_font("font", "Button", rajdhani_semibold)
	theme.set_font_size("font_size", "Button", 18)
	theme.set_color("font_color", "Button", COL_INK)
	theme.set_color("font_hover_color", "Button", COL_SIGNAL)
	theme.set_color("font_pressed_color", "Button", COL_SIGNAL)
	theme.set_color("font_focus_color", "Button", COL_INK)
	theme.set_color("font_disabled_color", "Button", COL_INK_DIM)

	var edit_normal := StyleBoxFlat.new()
	edit_normal.bg_color = COL_PANEL
	edit_normal.border_color = COL_HAIRLINE
	edit_normal.set_border_width_all(1)
	edit_normal.set_content_margin_all(10)

	var edit_focus: StyleBoxFlat = edit_normal.duplicate()
	edit_focus.border_color = COL_SIGNAL

	theme.set_stylebox("normal", "LineEdit", edit_normal)
	theme.set_stylebox("focus", "LineEdit", edit_focus)
	theme.set_font("font", "LineEdit", rajdhani_medium)
	theme.set_font_size("font_size", "LineEdit", 18)
	theme.set_color("font_color", "LineEdit", COL_INK)
	theme.set_color("font_placeholder_color", "LineEdit", COL_INK_DIM)
	theme.set_color("caret_color", "LineEdit", COL_SIGNAL)
	theme.set_color("selection_color", "LineEdit", Color(COL_SIGNAL.r, COL_SIGNAL.g, COL_SIGNAL.b, 0.3))

	theme.set_font("font", "Label", rajdhani_medium)
	theme.set_font_size("font_size", "Label", 16)
	theme.set_color("font_color", "Label", COL_INK_DIM)

	return theme
