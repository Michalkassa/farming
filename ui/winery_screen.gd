extends CanvasLayer
## Inside the winery. There's no explanatory text: players work it out by trying.
## A big barrel with a yeast slot, a fruit slot and five extra slots sits on the
## left with one action under it (seal -> ferment bar -> bottle). Your brewing
## ingredients fill the right.
##   Ingredient: left click puts one in the next free slot, right click fills
##   every free slot it can. Nothing stacks: one item per slot.
##   Barrel slot: click to take its item back.
## The layout is built in code on a fixed design stage that's scaled to fit,
## like the shop.

const Brewing := preload("res://scripts/brewing.gd")

@export_group("Layout")
@export var design_size: Vector2 = Vector2(1152, 648)
@export var fade_seconds: float = 0.18
@export var barrel_scale: float = 7.0
@export var barrel_origin: Vector2 = Vector2(96, 110)
@export var main_slot_size: int = 76
@export var extra_slot_size: int = 52
@export var pantry_button_size: int = 68
@export var action_size: Vector2 = Vector2(200, 72)

@export_group("Art")
@export var barrel_texture: Texture2D = preload("res://static/winery/barrel.png")
@export var wall_texture: Texture2D = preload("res://static/shop/barn_wall.png")
@export var slot_texture: Texture2D = preload("res://static/ui/slot_inset.png")
@export var seal_icon: Texture2D = preload("res://static/winery/barrel.png")
@export var wall_tint: Color = Color(0.42, 0.34, 0.3)

@export_group("Text")
@export var money_format: String = "€%d"
@export var gold_color: Color = Color(1, 0.84, 0.35)

var _screen: Control
var _stage: Control
var _barrel: TextureRect
var _yeast_slot: Panel
var _fruit_slot: Panel
var _extra_slots: Array[Panel] = []
var _action: Control
var _pantry_grid: GridContainer
var _money_label: Label
var _fade: Tween
var _ferment_bar: ProgressBar

func _ready() -> void:
	layer = 20
	visible = false
	_build()
	Winery.barrel_changed.connect(_refresh)
	GameState.inventory_changed.connect(_refresh_pantry)
	GameState.hotbar_changed.connect(_refresh_pantry)
	GameState.money_changed.connect(func(m): _money_label.text = money_format % m)
	get_viewport().size_changed.connect(_fit)

func open() -> void:
	if visible:
		return
	visible = true
	_fit()
	_money_label.text = money_format % GameState.money
	_refresh()
	if _fade:
		_fade.kill()
	_screen.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(_screen, "modulate:a", 1.0, fade_seconds)

func close() -> void:
	if not visible:
		return
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_screen, "modulate:a", 0.0, fade_seconds)
	_fade.tween_callback(func(): visible = false)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	# Keys belong to the winery while it's open, so the farm behind stays put.
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()

func _process(_delta: float) -> void:
	if visible and _ferment_bar and Winery.state == Winery.State.FERMENTING:
		_ferment_bar.value = Winery.ferment_progress()

func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	var factor := minf(screen.x / design_size.x, screen.y / design_size.y)
	_stage.scale = Vector2(factor, factor)
	_stage.position = ((screen - design_size * factor) * 0.5).floor()

# --- Building the layout ------------------------------------------------------

func _build() -> void:
	_screen = Control.new()
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)

	var cellar := ColorRect.new()
	cellar.color = Color(0.13, 0.09, 0.07)
	cellar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(cellar)
	var wall := TextureRect.new()
	wall.texture = wall_texture
	wall.stretch_mode = TextureRect.STRETCH_TILE
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.modulate = wall_tint
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(wall)

	_stage = Control.new()
	_stage.size = design_size
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_stage)

	var back := Button.new()
	back.text = "<"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 24)
	back.position = Vector2(16, 14)
	back.custom_minimum_size = Vector2(64, 52)
	back.pressed.connect(close)
	_stage.add_child(back)

	var money := PanelContainer.new()
	money.theme_type_variation = &"Badge"
	money.position = Vector2(design_size.x - 180, 16)
	money.custom_minimum_size = Vector2(160, 44)
	_money_label = _label("", 22, gold_color)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money.add_child(_money_label)
	_stage.add_child(money)

	_build_barrel()
	_build_pantry()

func _build_barrel() -> void:
	_barrel = TextureRect.new()
	_barrel.texture = barrel_texture
	_barrel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_barrel.stretch_mode = TextureRect.STRETCH_SCALE
	_barrel.size = barrel_texture.get_size() * barrel_scale
	_barrel.position = barrel_origin
	_barrel.pivot_offset = Vector2(_barrel.size.x * 0.5, _barrel.size.y)
	_stage.add_child(_barrel)

	var w := _barrel.size.x
	var gap := 6
	var top := 80.0
	var pair := main_slot_size * 2 + 40
	_yeast_slot = _make_slot(main_slot_size, "yeast", -1)
	_yeast_slot.position = Vector2((w - pair) * 0.5, top)
	_fruit_slot = _make_slot(main_slot_size, "fruit", -1)
	_fruit_slot.position = Vector2((w + pair) * 0.5 - main_slot_size, top)
	_barrel.add_child(_yeast_slot)
	_barrel.add_child(_fruit_slot)

	var row := extra_slot_size * Brewing.EXTRA_SLOTS + gap * (Brewing.EXTRA_SLOTS - 1)
	var extra_y := top + main_slot_size + 40
	for i in Brewing.EXTRA_SLOTS:
		var slot := _make_slot(extra_slot_size, "extra", i)
		slot.position = Vector2((w - row) * 0.5 + i * (extra_slot_size + gap), extra_y)
		_barrel.add_child(slot)
		_extra_slots.append(slot)

	# One action under the barrel: seal, the ferment bar, or the bottles.
	_action = CenterContainer.new()
	_action.position = Vector2(barrel_origin.x, barrel_origin.y + _barrel.size.y + 14)
	_action.custom_minimum_size = Vector2(w, action_size.y)
	_action.size = _action.custom_minimum_size
	_stage.add_child(_action)

func _build_pantry() -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WindowPanel"
	panel.position = Vector2(560, 96)
	panel.custom_minimum_size = Vector2(576, 520)
	panel.size = panel.custom_minimum_size
	_stage.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_pantry_grid = GridContainer.new()
	_pantry_grid.columns = 7
	_pantry_grid.add_theme_constant_override("h_separation", 8)
	_pantry_grid.add_theme_constant_override("v_separation", 8)
	_pantry_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_pantry_grid)

# --- Small widgets ------------------------------------------------------------

func _label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	label.add_theme_constant_override("outline_size", 5)
	return label

## A count pinned to the bottom-right corner of its parent.
func _corner_count(size: int) -> Label:
	var count := _label("", size, Color.WHITE)
	count.anchor_left = 1.0
	count.anchor_top = 1.0
	count.anchor_right = 1.0
	count.anchor_bottom = 1.0
	count.offset_left = -60
	count.offset_top = -size - 10
	count.offset_right = -6
	count.offset_bottom = -2
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return count

func _make_slot(size: int, kind: String, index: int) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(size, size)
	slot.size = slot.custom_minimum_size
	var style := StyleBoxTexture.new()
	style.texture = slot_texture
	style.set_texture_margin_all(12)
	slot.add_theme_stylebox_override("panel", style)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pad := int(size * 0.14)
	icon.offset_left = pad
	icon.offset_top = pad
	icon.offset_right = -pad
	icon.offset_bottom = -pad
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	slot.gui_input.connect(_on_slot_input.bind(kind, index))
	return slot

func _set_slot(slot: Panel, id: StringName) -> void:
	var icon: TextureRect = slot.get_node("Icon")
	var item: ItemData = ItemDatabase.get_item(id) if id != &"" else null
	icon.texture = item.icon if item else null
	var sealed := Winery.state != Winery.State.FILLING
	slot.modulate = Color(0.8, 0.8, 0.8) if sealed else Color.WHITE
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if item and not sealed else Control.CURSOR_ARROW

func _pantry_button(item: ItemData, owned: int) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(pantry_button_size, pantry_button_size)
	button.icon = item.icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", pantry_button_size - 24)
	var count := _corner_count(15)
	count.text = str(owned)
	button.add_child(count)
	button.modulate = Color.WHITE if Winery.add_block_reason(item.id) == "" else Color(1, 1, 1, 0.45)
	button.pressed.connect(_on_pantry_add.bind(item.id, button, 1))
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_on_pantry_add(item.id, button, GameState.count_owned(item.id)))
	return button

func _icon_button(icon: Texture2D) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"GoldButton"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = action_size
	button.icon = icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", int(action_size.y) - 22)
	return button

# --- Refreshing ---------------------------------------------------------------

func _refresh() -> void:
	if not visible:
		return
	_set_slot(_yeast_slot, Winery.yeast_id)
	_set_slot(_fruit_slot, Winery.fruit_id)
	for i in _extra_slots.size():
		_set_slot(_extra_slots[i], Winery.extras[i])
	_refresh_action()
	_refresh_pantry()

func _refresh_pantry() -> void:
	if not visible:
		return
	for child in _pantry_grid.get_children():
		_pantry_grid.remove_child(child)
		child.queue_free()
	# Yeasts, then fruit, then additions, each in table order.
	for table in [Brewing.YEASTS, Brewing.FRUITS, Brewing.ADDITIONS]:
		for id in table:
			var owned := GameState.count_owned(id)
			var item: ItemData = ItemDatabase.get_item(id)
			if owned > 0 and item != null:
				_pantry_grid.add_child(_pantry_button(item, owned))

func _refresh_action() -> void:
	for child in _action.get_children():
		_action.remove_child(child)
		child.queue_free()
	_ferment_bar = null
	match Winery.state:
		Winery.State.FILLING:
			var seal := _icon_button(seal_icon)
			seal.disabled = Winery.seal_block_reason() != ""
			seal.pressed.connect(_on_seal)
			_action.add_child(seal)
		Winery.State.FERMENTING:
			_ferment_bar = ProgressBar.new()
			_ferment_bar.min_value = 0.0
			_ferment_bar.max_value = 1.0
			_ferment_bar.show_percentage = false
			_ferment_bar.custom_minimum_size = Vector2(_barrel.size.x - 40, 32)
			_ferment_bar.value = Winery.ferment_progress()
			var fill := StyleBoxFlat.new()
			fill.bg_color = Color(0.62, 0.2, 0.36)
			fill.border_color = Color(0.85, 0.4, 0.55)
			fill.border_width_top = 3
			var track := StyleBoxFlat.new()
			track.bg_color = Color(0.1, 0.06, 0.05)
			track.set_border_width_all(2)
			track.border_color = Color(0.48, 0.36, 0.24)
			_ferment_bar.add_theme_stylebox_override("fill", fill)
			_ferment_bar.add_theme_stylebox_override("background", track)
			_action.add_child(_ferment_bar)
		Winery.State.READY:
			var item: ItemData = ItemDatabase.get_item(Winery.bottle_id)
			var bottle := _icon_button(item.icon if item else null)
			var count := _corner_count(20)
			count.text = str(Winery.bottles_left) if Winery.bottles_left > 1 else ""
			bottle.add_child(count)
			bottle.pressed.connect(_on_bottle.bind(bottle))
			_action.add_child(bottle)
			_bounce(bottle)

# --- Actions ------------------------------------------------------------------

func _on_pantry_add(id: StringName, button: Button, count: int) -> void:
	if Winery.add(id, count) <= 0:
		_wobble(button)
		return
	_splash()

func _on_slot_input(event: InputEvent, kind: String, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if Winery.state != Winery.State.FILLING:
		return
	var slot := _yeast_slot if kind == "yeast" else (_fruit_slot if kind == "fruit" else _extra_slots[index])
	var has_item := (kind == "yeast" and Winery.yeast_id != &"") \
		or (kind == "fruit" and Winery.fruit_id != &"") \
		or (kind == "extra" and Winery.extras[index] != &"")
	if has_item and not Winery.remove(kind, index):
		_wobble(slot)

func _on_seal() -> void:
	if Winery.seal():
		_thump()

func _on_bottle(button: Button) -> void:
	if Winery.collect_bottles() <= 0:
		_wobble(button)

# --- Juice --------------------------------------------------------------------

## A little squash when something drops in.
func _splash() -> void:
	var tween := create_tween()
	tween.tween_property(_barrel, "scale", Vector2(1.03, 0.97), 0.06)
	tween.tween_property(_barrel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The lid going on.
func _thump() -> void:
	var tween := create_tween()
	tween.tween_property(_barrel, "scale", Vector2(1.06, 0.94), 0.08)
	tween.tween_property(_barrel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _wobble(target: Control) -> void:
	target.pivot_offset = target.size * 0.5
	var tween := create_tween()
	for angle in [0.12, -0.12, 0.06, 0.0]:
		tween.tween_property(target, "rotation", angle, 0.05)

## The finished bottles bob so you notice them.
func _bounce(target: Control) -> void:
	target.pivot_offset = action_size * 0.5
	var tween := target.create_tween().set_loops()
	tween.tween_property(target, "scale", Vector2(1.06, 1.06), 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
