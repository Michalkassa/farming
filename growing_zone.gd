class_name GrowingZone
extends StaticBody2D

@export var stage_textures: Array[Texture2D] = []
@export var ripe_texture_path: String = "res://static/crops/%s_ripe.png"
## Per-crop art for a growth stage; an empty name keeps the shared stage texture.
@export var crop_stage_path: String = "res://static/crops/%s_%s.png"
@export var crop_stage_names: PackedStringArray = ["", "", "young", "grown"]
@export var watered_speed: float = 2.0

@export_group("Tool Cue")
## Plots the selected tool can act on darken briefly once per period.
@export var cue_period: float = 1.0
@export var cue_flash_seconds: float = 0.4
@export var cue_shade: Color = Color(0.55, 0.55, 0.55)

@export_group("Starting State")
@export var tilled: bool = false
@export var wet: bool = false
@export var crop_id: StringName = &""
@export_range(0.0, 1.0, 0.01) var growth: float = 0.0
@export var grow_time: float = 20.0
@export var harvest_amount: int = 1

@export_group("Soil Animations")
@export var anim_bare_dry: StringName = &"nottilled_dry"
@export var anim_bare_wet: StringName = &"nottilled_wet"
@export var anim_tilled_dry: StringName = &"tilled_dry"
@export var anim_tilled_wet: StringName = &"tilled_wet"

@onready var _soil: AnimatedSprite2D = $AnimatedSprite2D
@onready var _plant: Sprite2D = $Plant
@onready var _bar: GrowthBar = $GrowthBar
@onready var _area: Area2D = $Area2D

## The soil this plot was authored with, restored by "New Game".
var _initial_state: Dictionary = {}
var _stage_cache_crop: StringName = &""
var _stage_cache: Dictionary = {}

func _ready() -> void:
	_area.input_event.connect(_on_area_input_event)
	_initial_state = save_state()
	GameState.register_zone(self)
	_refresh_soil()
	_refresh_plant()

func _exit_tree() -> void:
	GameState.unregister_zone(self)

func save_state() -> Dictionary:
	return {
		"tilled": tilled,
		"wet": wet,
		"crop": String(crop_id),
		"growth": growth,
		"grow_time": grow_time,
		"harvest": harvest_amount,
	}

func reset_zone() -> void:
	load_state(_initial_state)

func load_state(data: Dictionary) -> void:
	tilled = bool(data.get("tilled", false))
	wet = bool(data.get("wet", false))
	crop_id = StringName(data.get("crop", ""))
	growth = clampf(float(data.get("growth", 0.0)), 0.0, 1.0)
	grow_time = maxf(0.01, float(data.get("grow_time", grow_time)))
	harvest_amount = maxi(1, int(data.get("harvest", harvest_amount)))
	_refresh_soil()
	_refresh_plant()

func _process(delta: float) -> void:
	_update_cue()
	if crop_id == &"" or growth >= 1.0:
		return
	var speed := watered_speed if wet else 1.0
	speed *= GameState.growth_multiplier()
	growth = minf(1.0, growth + delta * speed / maxf(grow_time, 0.01))
	_refresh_plant()

func _tool_can_act_here() -> bool:
	var item: ItemData = GameState.selected_item()
	if item == null:
		return false
	if item.tool_kind == &"hoe":
		return not tilled
	if item.tool_kind == &"watering_can":
		return tilled and not wet
	if item.is_seed():
		return tilled and not is_planted()
	return false

## Synced to the engine clock so every eligible plot pulses together.
func _update_cue() -> void:
	var strength := 0.0
	if _tool_can_act_here() and cue_period > 0.0:
		var t := fmod(Time.get_ticks_msec() / 1000.0, cue_period)
		if t < cue_flash_seconds:
			strength = sin(PI * t / cue_flash_seconds)
	_soil.modulate = Color.WHITE.lerp(cue_shade, strength)

func is_planted() -> bool:
	return crop_id != &""

func is_ripe() -> bool:
	return is_planted() and growth >= 1.0

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		interact()
		get_viewport().set_input_as_handled()

func interact() -> bool:
	if is_ripe():
		return harvest()
	var item: ItemData = GameState.selected_item()
	if item == null:
		return false
	if item.tool_kind == &"hoe" or item.tool_kind == &"watering_can":
		var acted := false
		for zone in GameState.zones_around(self, item.tool_area):
			if item.tool_kind == &"hoe":
				acted = zone.till() or acted
			else:
				acted = zone.water() or acted
		return acted
	if item.is_seed():
		return plant(item)
	return false

func till() -> bool:
	if tilled:
		return false
	tilled = true
	_refresh_soil()
	return true

func water() -> bool:
	if wet:
		return false
	wet = true
	_refresh_soil()
	return true

func plant(seed_item: ItemData) -> bool:
	if not tilled or is_planted() or seed_item == null or not seed_item.is_seed():
		return false
	crop_id = seed_item.seed_for
	grow_time = seed_item.grow_time
	harvest_amount = seed_item.harvest_amount
	growth = 0.0
	GameState.consume_selected(1)
	_refresh_plant()
	return true

func harvest() -> bool:
	if not is_ripe():
		return false
	if not GameState.can_collect(crop_id):
		return false
	GameState.collect_item(crop_id, harvest_amount, get_global_transform_with_canvas().origin)
	# Harvesting spends the plot: it goes back to bare, dry soil.
	crop_id = &""
	growth = 0.0
	wet = false
	tilled = false
	_refresh_soil()
	_refresh_plant()
	return true

func _refresh_soil() -> void:
	if tilled and wet:
		_soil.play(anim_tilled_wet)
	elif tilled:
		_soil.play(anim_tilled_dry)
	elif wet:
		_soil.play(anim_bare_wet)
	else:
		_soil.play(anim_bare_dry)

func _stage_texture(stage: int) -> Texture2D:
	if _stage_cache_crop != crop_id:
		_stage_cache_crop = crop_id
		_stage_cache.clear()
	if not _stage_cache.has(stage):
		var texture: Texture2D = stage_textures[stage]
		if stage < crop_stage_names.size() and crop_stage_names[stage] != "":
			var path := crop_stage_path % [crop_id, crop_stage_names[stage]]
			if ResourceLoader.exists(path):
				texture = load(path)
		_stage_cache[stage] = texture
	return _stage_cache[stage]

func _refresh_plant() -> void:
	if not is_planted():
		_plant.texture = null
		_bar.visible = false
		return
	if growth >= 1.0:
		_plant.texture = load(ripe_texture_path % crop_id)
		_bar.visible = false
		return
	if stage_textures.is_empty():
		_plant.texture = null
	else:
		var stage := clampi(int(growth * stage_textures.size()), 0, stage_textures.size() - 1)
		_plant.texture = _stage_texture(stage)
	_bar.visible = true
	_bar.progress = growth
