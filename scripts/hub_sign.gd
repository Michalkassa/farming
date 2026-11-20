@tool
class_name HubSign
extends Node2D
## A little wooden plank sign drawn in world pixels, sized to its text.
## The node's position is the bottom centre of the board.

@export var text: String = "SIGN" : set = _set_text
@export var subtitle: String = "" : set = _set_subtitle
## Monocraft is drawn on a 120-unit pixel grid (1080 per em), so multiples of 9 stay crisp.
@export var font_size: int = 9 : set = _set_font_size
@export var subtitle_size: int = 9
@export var padding: Vector2i = Vector2i(4, 2)

@export_group("Colors")
@export var board: Color = Color8(124, 80, 42)
@export var board_light: Color = Color8(156, 106, 58)
@export var outline: Color = Color8(40, 24, 14)
@export var shadow: Color = Color(0, 0, 0, 0.3)
@export var text_color: Color = Color8(255, 248, 230)
@export var subtitle_color: Color = Color8(230, 210, 170)

func _set_text(value: String) -> void:
	text = value
	queue_redraw()

func _set_subtitle(value: String) -> void:
	subtitle = value
	queue_redraw()

func _set_font_size(value: int) -> void:
	font_size = maxi(1, value)
	queue_redraw()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var theme: Theme = ThemeDB.get_project_theme()
	if theme and theme.default_font:
		font = theme.default_font
	var title_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var sub_size := Vector2.ZERO
	if subtitle != "":
		sub_size = font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_size)
	var width := ceili(maxf(title_size.x, sub_size.x)) + padding.x * 2
	var height := font_size + padding.y * 2 + (subtitle_size + 1 if subtitle != "" else 0)
	var rect := Rect2(-floori(width / 2.0), -height, width, height)

	draw_rect(Rect2(rect.position + Vector2(1, 1), rect.size), shadow)
	draw_rect(rect, outline)
	draw_rect(rect.grow(-1), board)
	draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, 1)), board_light)

	var ascent := font.get_ascent(font_size)
	var baseline := Vector2(-roundf(title_size.x / 2.0), rect.position.y + padding.y + roundi(ascent))
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, outline)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	if subtitle != "":
		var sub_base := Vector2(-roundf(sub_size.x / 2.0),
			baseline.y + 1 + roundi(font.get_ascent(subtitle_size)))
		draw_string(font, sub_base, subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_size, subtitle_color)
