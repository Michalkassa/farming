@tool
class_name HubPaths
extends Node2D
## Sandy footpaths joining the hub's places, drawn as pixel rectangles with a
## darker rim and a scatter of pebbles. Edit `paths` in the inspector.

@export var paths: Array[Rect2] = [] : set = _set_paths
@export var sand: Color = Color8(236, 206, 112)
@export var rim: Color = Color8(196, 160, 80)
@export var pebble: Color = Color8(210, 176, 92)
@export var pebble_spacing: int = 7

func _set_paths(value: Array[Rect2]) -> void:
	paths = value
	queue_redraw()

func _draw() -> void:
	for rect in paths:
		draw_rect(rect.grow(1), rim)
	for rect in paths:
		draw_rect(rect, sand)
	# Deterministic pebbles so the paths don't look like flat paint.
	for rect in paths:
		var x := int(rect.position.x) + 2
		while x < int(rect.end.x) - 1:
			var y := int(rect.position.y) + 2
			while y < int(rect.end.y) - 1:
				var h := absi(x * 73856093 ^ y * 19349663) % 11
				if h < 2:
					draw_rect(Rect2(x, y, 1, 1), pebble)
				y += pebble_spacing - 3
			x += pebble_spacing
