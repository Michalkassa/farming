class_name Animal
extends Node2D

@export var config: AnimalKind

@export_group("Produce Popup")
@export var popup_rise: float = 12.0
@export var popup_duration: float = 1.1
@export var popup_fade_delay: float = 0.4
@export var popup_offset: float = 6.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _timer: Timer = $ProduceTimer

var _target: Vector2
var _pause_left: float = 0.0

func kind() -> StringName:
	return config.kind if config else &""

func _ready() -> void:
	if config == null or config.idle_textures.is_empty():
		set_process(false)
		return
	_sprite.sprite_frames = _build_frames()
	_play("idle")
	_sprite.frame = randi() % config.idle_textures.size()
	_target = position
	_start_pause()

	var item: ItemData = ItemDatabase.get_item(config.kind)
	if item and item.product_id != &"" and item.produce_time > 0.0:
		_timer.wait_time = item.produce_time
		_timer.timeout.connect(_on_produce)
		_timer.start()

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	for anim in ["idle", "walk"]:
		if not frames.has_animation(anim):
			frames.add_animation(anim)
		frames.set_animation_speed(anim, config.walk_fps if anim == "walk" else config.idle_fps)
		for texture in config.frames_for(anim):
			frames.add_frame(anim, texture)
	return frames

func _play(anim: String) -> void:
	if _sprite.animation == anim and _sprite.is_playing():
		return
	_sprite.play(anim)
	var frame: Texture2D = _sprite.sprite_frames.get_frame_texture(anim, 0)
	if frame:
		_sprite.offset = Vector2(0, -0.5 * frame.get_height())

func _process(delta: float) -> void:
	if config == null or config.roam.size == Vector2.ZERO:
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left <= 0.0:
			_choose_target()
		return

	var to_target := _target - position
	var step := config.walk_speed * delta
	if to_target.length() <= step:
		position = _target
		_start_pause()
	else:
		position += to_target.normalized() * step

func _start_pause() -> void:
	_pause_left = randf_range(config.pause_seconds.x, config.pause_seconds.y)
	_play("idle")

func _choose_target() -> void:
	var best := position
	var best_room := -1.0
	for i in config.target_candidates:
		var step := randf_range(config.step_length.x, config.step_length.y)
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * step
		var candidate := Vector2(
			clampf(position.x + offset.x, config.roam.position.x, config.roam.end.x),
			clampf(position.y + offset.y, config.roam.position.y, config.roam.end.y))
		var room := _room_at(candidate)
		if room > best_room:
			best_room = room
			best = candidate
	_target = best
	if _target.distance_to(position) < 1.0:
		_start_pause()
		return
	if not is_equal_approx(_target.x, position.x):
		_sprite.flip_h = _target.x < position.x
	_play("walk")

func _room_at(spot: Vector2) -> float:
	var nearest := config.elbow_room
	for other in get_parent().get_children():
		if other == self or not (other is Animal) or other.kind() != config.kind:
			continue
		nearest = minf(nearest, spot.distance_to(other.position))
	return nearest

func _on_produce() -> void:
	var item: ItemData = ItemDatabase.get_item(config.kind)
	if item == null or not GameState.can_collect(item.product_id):
		return
	GameState.collect_item(item.product_id, 1, get_global_transform_with_canvas().origin)
	_show_product(item.product_id)

func _show_product(product_id: StringName) -> void:
	var product: ItemData = ItemDatabase.get_item(product_id)
	if product == null:
		return
	var pop := Sprite2D.new()
	pop.texture = product.icon
	pop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pop.z_index = 5
	var head: Texture2D = _sprite.sprite_frames.get_frame_texture("idle", 0)
	pop.position = Vector2(0, -head.get_height() - popup_offset)
	add_child(pop)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(pop, "position:y", pop.position.y - popup_rise, popup_duration)
	tween.tween_property(pop, "modulate:a", 0.0, popup_duration).set_delay(popup_fade_delay)
	tween.chain().tween_callback(pop.queue_free)
