class_name GrowthBar
extends Node2D

@export var bar_width: float = 14.0
@export var bar_height: float = 3.0
@export var outline_thickness: float = 1.0
@export var outline_color: Color = Color(0.47, 0.3, 0.18, 1)
@export var track_color: Color = Color(0.98, 0.9, 0.76, 1)
@export var fill_color: Color = Color(0.53, 0.8, 0.42)

var progress: float = 0.0 : set = _set_progress

func _set_progress(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, progress):
		return
	progress = clamped
	queue_redraw()

func _draw() -> void:
	var bar := Rect2(-bar_width * 0.5, -bar_height * 0.5, bar_width, bar_height)
	draw_rect(bar.grow(outline_thickness), outline_color)
	draw_rect(bar, track_color)
	if progress > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar_width * progress, bar_height)), fill_color)
