@tool
class_name HubPaths
extends Node2D
## Sandy roads laid on the same 16px grid as the grass and fences. `roads`
## lists rectangles in grid cells; overlapping or touching rectangles merge
## into one road, and an edge is only drawn where a road tile meets grass.

@export var tile: Texture2D : set = _set_tile
@export var cell_size: int = 16
@export var roads: Array[Rect2i] = [] : set = _set_roads
@export var rim: Color = Color8(196, 160, 80)
@export var fringe: Color = Color8(120, 180, 70)

func _set_tile(value: Texture2D) -> void:
	tile = value
	queue_redraw()

func _set_roads(value: Array[Rect2i]) -> void:
	roads = value
	queue_redraw()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _cells() -> Dictionary:
	var cells := {}
	for rect in roads:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				cells[Vector2i(x, y)] = true
	return cells

func _draw() -> void:
	var cells := _cells()
	var n := cell_size
	for cell: Vector2i in cells:
		var origin := Vector2(cell * n)
		if tile:
			draw_texture(tile, origin)
		else:
			draw_rect(Rect2(origin, Vector2(n, n)), Color8(236, 206, 112))
	# Edges where the road meets grass: a darker rim plus a few grass tufts
	# poking in, so the road reads as worn into the lawn.
	for cell: Vector2i in cells:
		var o := Vector2(cell * n)
		var up := not cells.has(cell + Vector2i.UP)
		var down := not cells.has(cell + Vector2i.DOWN)
		var left := not cells.has(cell + Vector2i.LEFT)
		var right := not cells.has(cell + Vector2i.RIGHT)
		if up:
			draw_rect(Rect2(o, Vector2(n, 1)), rim)
			for x in [3, 9, 13]:
				draw_rect(Rect2(o + Vector2(x, 1), Vector2(1, 1)), fringe)
		if down:
			draw_rect(Rect2(o + Vector2(0, n - 1), Vector2(n, 1)), rim)
			for x in [5, 11]:
				draw_rect(Rect2(o + Vector2(x, n - 2), Vector2(1, 1)), fringe)
		if left:
			draw_rect(Rect2(o, Vector2(1, n)), rim)
			for y in [4, 12]:
				draw_rect(Rect2(o + Vector2(1, y), Vector2(1, 1)), fringe)
		if right:
			draw_rect(Rect2(o + Vector2(n - 1, 0), Vector2(1, n)), rim)
			for y in [6, 10]:
				draw_rect(Rect2(o + Vector2(n - 2, y), Vector2(1, 1)), fringe)
		# Round off outer corners with a grass-coloured notch.
		for corner in [[up, left, Vector2(0, 0)], [up, right, Vector2(n - 1, 0)],
				[down, left, Vector2(0, n - 1)], [down, right, Vector2(n - 1, n - 1)]]:
			if corner[0] and corner[1]:
				draw_rect(Rect2(o + corner[2], Vector2(1, 1)), fringe)
