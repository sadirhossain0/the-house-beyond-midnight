class_name UIKit
## Shared look for every screen: ink-blue panels with gilt edges, Cinzel headings, Alegreya text.

const GOLD := Color(0.86, 0.7, 0.38)
const GOLD_DIM := Color(0.62, 0.5, 0.3)
const INK := Color(0.055, 0.06, 0.09, 0.94)
const INK_SOFT := Color(0.09, 0.1, 0.14, 0.9)
const PAPER := Color(0.93, 0.89, 0.8)
const TEXT := Color(0.9, 0.87, 0.8)
const MUTED := Color(0.66, 0.63, 0.58)
const SPECTRAL := Color(0.55, 1.0, 0.86)

static var _theme: Theme
static var fonts := {}

static func font(name: String) -> Font:
	if fonts.has(name): return fonts[name]
	var path := {"head": "res://assets/fonts/Cinzel.ttf", "deco": "res://assets/fonts/CinzelDecorative-Bold.ttf", "deco_r": "res://assets/fonts/CinzelDecorative-Regular.ttf",
		"body": "res://assets/fonts/Alegreya.ttf", "italic": "res://assets/fonts/Alegreya-Italic.ttf", "caps": "res://assets/fonts/IMFellEnglishSC.ttf"}.get(name, "res://assets/fonts/Alegreya.ttf")
	var f: FontFile = load(path)
	fonts[name] = f
	return f

static func text_scale() -> float:
	return float(Settings.data.hud.get("text_scale", 1.0))

static func theme() -> Theme:
	if _theme: return _theme
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 22
	var panel := style(INK, GOLD_DIM, 1, 6)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var bn := style(Color(0.1, 0.11, 0.15, 0.9), Color(0.4, 0.34, 0.24), 1, 4, 14, 8)
	var bh := style(Color(0.16, 0.15, 0.17, 0.95), GOLD, 1, 4, 14, 8)
	var bp := style(Color(0.22, 0.18, 0.12, 0.95), GOLD, 2, 4, 14, 8)
	var bd := style(Color(0.08, 0.08, 0.1, 0.6), Color(0.25, 0.23, 0.2), 1, 4, 14, 8)
	for cls in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, bn); t.set_stylebox("hover", cls, bh); t.set_stylebox("pressed", cls, bp)
		t.set_stylebox("focus", cls, style(Color(0, 0, 0, 0), SPECTRAL, 2, 4)); t.set_stylebox("disabled", cls, bd)
		t.set_color("font_color", cls, TEXT); t.set_color("font_hover_color", cls, Color(1, 0.95, 0.82)); t.set_color("font_pressed_color", cls, GOLD)
		t.set_color("font_focus_color", cls, Color(1, 0.97, 0.88)); t.set_color("font_disabled_color", cls, MUTED * Color(1, 1, 1, 0.7))
		t.set_font("font", cls, font("body")); t.set_font_size("font_size", cls, 21)
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", 21)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", font("body")); t.set_font("italics_font", "RichTextLabel", font("italic")); t.set_font("bold_font", "RichTextLabel", font("head"))
	t.set_font_size("normal_font_size", "RichTextLabel", 21); t.set_font_size("italics_font_size", "RichTextLabel", 21); t.set_font_size("bold_font_size", "RichTextLabel", 20)
	var sl := StyleBoxFlat.new(); sl.bg_color = Color(0.2, 0.18, 0.16); sl.content_margin_top = 3; sl.content_margin_bottom = 3; sl.set_corner_radius_all(3)
	var sla := StyleBoxFlat.new(); sla.bg_color = GOLD_DIM; sla.content_margin_top = 3; sla.content_margin_bottom = 3; sla.set_corner_radius_all(3)
	t.set_stylebox("slider", "HSlider", sl); t.set_stylebox("grabber_area", "HSlider", sla); t.set_stylebox("grabber_area_highlight", "HSlider", sla)
	t.set_stylebox("panel", "TabContainer", style(INK_SOFT, GOLD_DIM, 1, 4))
	t.set_stylebox("tab_selected", "TabBar", style(Color(0.2, 0.17, 0.12), GOLD, 1, 3, 12, 6))
	t.set_stylebox("tab_unselected", "TabBar", style(Color(0.08, 0.08, 0.1), Color(0.3, 0.27, 0.22), 1, 3, 12, 6))
	t.set_stylebox("tab_hovered", "TabBar", style(Color(0.14, 0.13, 0.13), GOLD_DIM, 1, 3, 12, 6))
	t.set_color("font_selected_color", "TabBar", GOLD); t.set_color("font_unselected_color", "TabBar", MUTED); t.set_color("font_hovered_color", "TabBar", TEXT)
	t.set_font("font", "TabBar", font("caps")); t.set_font_size("font_size", "TabBar", 20)
	t.set_stylebox("normal", "LineEdit", style(Color(0.04, 0.04, 0.06, 0.95), Color(0.4, 0.34, 0.24), 1, 3, 10, 6))
	t.set_stylebox("focus", "LineEdit", style(Color(0.04, 0.04, 0.06, 0.95), SPECTRAL, 1, 3, 10, 6))
	t.set_color("font_color", "LineEdit", PAPER)
	t.set_stylebox("normal", "TextEdit", style(Color(0.04, 0.04, 0.06, 0.95), Color(0.4, 0.34, 0.24), 1, 3, 10, 6))
	t.set_color("font_color", "TextEdit", PAPER)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.3, 0.26, 0.2, 0.6); sb.set_corner_radius_all(4)
	var sg := StyleBoxFlat.new(); sg.bg_color = GOLD_DIM; sg.set_corner_radius_all(4)
	t.set_stylebox("scroll", "VScrollBar", sb); t.set_stylebox("grabber", "VScrollBar", sg); t.set_stylebox("grabber_highlight", "VScrollBar", sg); t.set_stylebox("grabber_pressed", "VScrollBar", sg)
	t.set_constant("separation", "VBoxContainer", 8); t.set_constant("separation", "HBoxContainer", 10)
	t.set_stylebox("panel", "PopupMenu", style(INK, GOLD_DIM, 1, 4, 6, 6))
	t.set_color("font_color", "PopupMenu", TEXT); t.set_color("font_hover_color", "PopupMenu", GOLD)
	t.set_stylebox("hover", "PopupMenu", style(Color(0.2, 0.17, 0.12), GOLD_DIM, 0, 2))
	t.set_font_size("font_size", "PopupMenu", 20)
	_theme = t
	return t

static func style(bg: Color, border: Color, bw := 1, radius := 4, mx := 18, my := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border; s.set_border_width_all(bw); s.set_corner_radius_all(radius)
	s.content_margin_left = mx; s.content_margin_right = mx; s.content_margin_top = my; s.content_margin_bottom = my
	s.shadow_color = Color(0, 0, 0, 0.35); s.shadow_size = 6 if bw > 0 else 0
	return s

static func label(text: String, size := 21, color := TEXT, f := "body") -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_override("font", font(f)); l.add_theme_font_size_override("font_size", int(size * text_scale())); l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func heading(text: String, size := 34) -> Label:
	var l := label(text, size, GOLD, "head")
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6)); l.add_theme_constant_override("shadow_offset_y", 2)
	return l

static func rich(bb: String, size := 21) -> RichTextLabel:
	var r := RichTextLabel.new(); r.bbcode_enabled = true; r.text = bb; r.fit_content = true
	r.scroll_active = false; r.selection_enabled = false
	for k in ["normal_font_size", "italics_font_size", "bold_font_size"]: r.add_theme_font_size_override(k, int(size * text_scale()))
	return r

static func button(text: String, cb: Callable, min_w := 0) -> Button:
	var b := Button.new(); b.text = text
	if min_w > 0: b.custom_minimum_size.x = min_w
	b.pressed.connect(func(): Audio.ui("click"); cb.call())
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	b.focus_entered.connect(func(): Audio.ui("hover"))
	return b

static func rule() -> Control:
	var c := ColorRect.new(); c.color = GOLD_DIM * Color(1, 1, 1, 0.5); c.custom_minimum_size = Vector2(0, 1)
	return c

static func margin(c: Control, px := 24) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + side, px)
	m.add_child(c)
	return m

static func scroll(c: Control) -> ScrollContainer:
	var s := ScrollContainer.new(); s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL; s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(c)
	return s

static func focus_first(root: Node) -> void:
	for c in root.find_children("*", "BaseButton", true, false):
		var b := c as BaseButton
		if b.is_visible_in_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus.call_deferred(); return

static func fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
