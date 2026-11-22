class_name UiKit
extends RefCounted
## Shared interface helpers: the SVG kit in art/ui as nine-slice style boxes, a Bengali-capable
## font, the palette and a few widget makers. Every screen builds its controls through these.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const UI := "res://art/ui/"
const INK := Color("0B1417")
const GLASS := Color(0.07, 0.15, 0.18, 0.86)
const MARIGOLD := Color("F2A93B")
const PINK := Color("E5487F")
const RED := Color("E5483C")
const GREEN := Color("3FBF7F")
const TEAL := Color("2EC4B6")
const PAPER := Color("F3EAD7")
const DIM := Color(0.75, 0.78, 0.76)

## 9-slice margins (left, top, right, bottom) in SVG pixels, from docs/RENDERING.md section 7.
const MARGINS := {
	"exam_panel_bg": [64, 150, 64, 90], "exam_option_normal": [110, 24, 40, 24], "exam_option_hover": [110, 24, 40, 24],
	"exam_option_correct": [110, 24, 40, 24], "exam_option_wrong": [110, 24, 40, 24], "exam_option_struck": [110, 24, 40, 24],
	"bengali_text_backdrop": [40, 60, 40, 30], "bengali_title_plate": [60, 50, 60, 40], "dialogue_box_bg": [60, 70, 60, 50],
	"toast_plate": [40, 20, 40, 20], "objective_plate": [40, 20, 40, 20], "clock_plate": [30, 20, 30, 20],
	"hud_health_plate": [40, 20, 40, 20], "hud_ammo_plate": [40, 20, 40, 20], "notebook_frame": [40, 40, 40, 40],
	"prompt_key": [14, 14, 14, 14], "marker_distance_plate": [16, 10, 16, 10],
}

static var _font: Font = null
static var _bold: Font = null
static var _tex_cache: Dictionary = {}


static func font(bold: bool = false) -> Font:
	if bold and _bold != null:
		return _bold
	if not bold and _font != null:
		return _font
	var f := SystemFont.new()
	# Bengali-capable faces first (Windows: Nirmala UI / Vrinda; Linux: Noto / Lohit / FreeSans; macOS: Bangla MN)
	f.font_names = PackedStringArray(["Nirmala UI", "Noto Sans Bengali", "Noto Sans Bengali UI", "Hind Siliguri", "SolaimanLipi",
		"Kalpurush", "Vrinda", "Bangla MN", "Bangla Sangam MN", "Lohit Bengali", "FreeSans", "Segoe UI", "Noto Sans", "Arial", "sans-serif"])
	f.font_weight = 700 if bold else 400
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.allow_system_fallback = true
	if bold:
		_bold = f
	else:
		_font = f
	return f


static func tex(svg_name: String) -> Texture2D:
	if _tex_cache.has(svg_name):
		return _tex_cache[svg_name]
	var path := UI + svg_name + ".svg"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[svg_name] = t
	return t


## Nine-slice StyleBoxTexture for an SVG plate, or a flat fallback if the SVG is missing.
static func style(svg_name: String, fallback: Color = GLASS) -> StyleBox:
	var t := tex(svg_name)
	if t == null:
		return flat(fallback, 10)
	var sb := StyleBoxTexture.new()
	sb.texture = t
	var m: Array = MARGINS.get(svg_name, [24, 24, 24, 24])
	sb.texture_margin_left = float(m[0])
	sb.texture_margin_top = float(m[1])
	sb.texture_margin_right = float(m[2])
	sb.texture_margin_bottom = float(m[3])
	sb.content_margin_left = float(m[0]) * 0.6
	sb.content_margin_top = float(m[1]) * 0.4
	sb.content_margin_right = float(m[2]) * 0.6
	sb.content_margin_bottom = float(m[3]) * 0.4
	return sb


static func flat(color: Color, radius: int = 8, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func label(text: String, size: int = 20, color: Color = PAPER, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func rich(size: int = 20) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_override("normal_font", font(false))
	r.add_theme_font_override("bold_font", font(true))
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", PAPER)
	return r


static func button(text: String, size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font(true))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", flat(Color(0.06, 0.13, 0.15, 0.92), 8, Color(1, 1, 1, 0.12), 1))
	b.add_theme_stylebox_override("hover", flat(Color(0.12, 0.24, 0.26, 0.96), 8, MARIGOLD, 2))
	b.add_theme_stylebox_override("pressed", flat(Color(0.2, 0.3, 0.2, 0.96), 8, GREEN, 2))
	b.add_theme_stylebox_override("focus", flat(Color(0.12, 0.24, 0.26, 0.96), 8, MARIGOLD, 2))
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", MARIGOLD)
	b.custom_minimum_size = Vector2(0, 48)
	return b


## A theme with the Bengali-capable font, for whole screens.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(false)
	t.default_font_size = 20
	return t


static func portrait(face_id: String) -> Texture2D:
	var path := "res://art/textures/faces/face_%s_portrait.png" % face_id
	return load(path) if ResourceLoader.exists(path) else null


static func bengali_digits(s: String) -> String:
	var out := ""
	for ch in s:
		var i := "0123456789".find(ch)
		out += "০১২৩৪৫৬৭৮৯"[i] if i >= 0 else ch
	return out


## Digits in the player's language.
static func num(v: int) -> String:
	return bengali_digits(str(v)) if Game.language == "bn" else str(v)
