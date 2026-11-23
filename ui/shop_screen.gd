extends CanvasLayer
## The shop: the whole farm stall fills the screen and the stall *is* the UI.
##   Back shelves: everything for sale with a little price tag. Click to buy.
##     Top shelf seeds and yeast, middle shelf tools, bottom shelf animals.
##     Things you can't afford have a red price; owned tools show a tick;
##     full pens show the count.
##   Counter: your produce, fruit and wine. Click one to sell one, right-click
##     to sell the whole stack, or press the coin button to sell everything.
## Hovering anything pops up a tiny info block: its name and one short line on
## what it's for. The layout is built in code on a fixed design stage scaled to
## fit the window. Text sizes are multiples of 9 so the pixel font stays crisp.

const Brewing := preload("res://scripts/brewing.gd")
const ItemInfo := preload("res://scripts/item_info.gd")
const ART := "res://static/shop/%s.png"
const PX := 5.0                                 # stall art pixels -> design pixels

@export_group("Layout")
@export var design_size: Vector2 = Vector2(1152, 648)
@export var fade_seconds: float = 0.18
## Where each shelf board sits (its top edge), top to bottom.
@export var shelf_y: PackedFloat32Array = [196.0, 296.0, 396.0]
@export var shelf_icon_size: int = 64
@export var sell_slot_size: int = 76

@export_group("Colours")
@export var sky_top: Color = Color8(124, 196, 236)
@export var sky_bottom: Color = Color8(181, 226, 244)
@export var tag_color: Color = Color8(255, 244, 222)
@export var price_color: Color = Color8(60, 36, 24)
@export var too_dear_color: Color = Color8(200, 50, 50)
@export var gold_color: Color = Color(1, 0.84, 0.35)

@export_group("Text")
@export var money_format: String = "€%d"

var _screen: Control
var _stage: Control
var _shelf_rows: Array[HBoxContainer] = []
var _shelf_items: Array[Dictionary] = []      # {item, root, icon, tag, price, badge}
var _sell_row: HBoxContainer
var _sell_all: Button
var _money_label: Label
var _fade: Tween
var _info: PanelContainer
var _info_name: Label
var _info_line: Label
var _info_target: Control

func _ready() -> void:
	layer = 20
	visible = false
	_build()
	GameState.money_changed.connect(_on_changed.unbind(1))
	GameState.inventory_changed.connect(_on_changed)
	GameState.hotbar_changed.connect(_on_changed)
	GameState.animals_changed.connect(_on_changed)
	GameState.tools_changed.connect(_on_changed)
	get_viewport().size_changed.connect(_fit)

func open() -> void:
	if visible:
		return
	visible = true
	_fit()
	_stock_shelves()
	_refresh()
	if _fade:
		_fade.kill()
	_screen.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(_screen, "modulate:a", 1.0, fade_seconds)

func close() -> void:
	if not visible:
		return
	_info.visible = false
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_screen, "modulate:a", 0.0, fade_seconds)
	_fade.tween_callback(func(): visible = false)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	# Keys belong to the stall while it's open, so the farm behind stays put.
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()

func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	var factor := minf(screen.x / design_size.x, screen.y / design_size.y)
	_stage.scale = Vector2(factor, factor)
	_stage.position = ((screen - design_size * factor) * 0.5).floor()

func _on_changed() -> void:
	if visible:
		_refresh()

# --- Building the stall -------------------------------------------------------

## A strip of tiled stall art covering `rect` (design px).
func _tiles(name: String, rect: Rect2) -> TextureRect:
	var tiles := TextureRect.new()
	tiles.texture = load(ART % name)
	tiles.stretch_mode = TextureRect.STRETCH_TILE
	tiles.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tiles.position = rect.position
	tiles.size = rect.size / PX
	tiles.scale = Vector2(PX, PX)
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(tiles)
	return tiles

func _label(text: String, size: int, colour: Color, outline: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	if outline:
		label.add_theme_color_override("font_outline_color", Color8(46, 26, 18))
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _build() -> void:
	_screen = Control.new()
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([sky_top, sky_bottom])
	var sky_tex := GradientTexture2D.new()
	sky_tex.gradient = gradient
	sky_tex.width = 4
	sky_tex.height = 64
	sky_tex.fill_to = Vector2(0, 1)
	var sky := TextureRect.new()
	sky.texture = sky_tex
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(sky)

	_stage = Control.new()
	_stage.size = design_size
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_stage)

	var w := design_size.x
	_tiles("back_wall", Rect2(40, 80, w - 80, 380))
	for y in shelf_y:
		_tiles("shelf", Rect2(40, y, w - 80, 30))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		row.position = Vector2(40, y - shelf_icon_size - 8)
		row.size = Vector2(w - 80, shelf_icon_size + 40)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(row)
		_shelf_rows.append(row)
	_tiles("post", Rect2(0, 40, 40, design_size.y - 40))
	_tiles("post", Rect2(w - 40, 40, 40, design_size.y - 40))
	var ridge := ColorRect.new()
	ridge.color = Color(0.204, 0.118, 0.118)
	ridge.size = Vector2(w, 26)
	ridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(ridge)
	var ridge_red := ColorRect.new()
	ridge_red.color = Color(0.667, 0.18, 0.188)
	ridge_red.position = Vector2(0, 3)
	ridge_red.size = Vector2(w, 20)
	ridge_red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(ridge_red)
	_tiles("awning", Rect2(0, 22, w, 70))
	_tiles("counter_top", Rect2(0, 436, w, 40))
	_tiles("counter_front", Rect2(0, 472, w, design_size.y - 472))

	# Counter: your goods to sell, and the sell-everything coin button.
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(48, 494)
	scroll.size = Vector2(w - 300, sell_slot_size + 24)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stage.add_child(scroll)
	_sell_row = HBoxContainer.new()
	_sell_row.add_theme_constant_override("separation", 8)
	scroll.add_child(_sell_row)
	_sell_all = Button.new()
	_sell_all.theme_type_variation = &"GoldButton"
	_sell_all.focus_mode = Control.FOCUS_NONE
	_sell_all.icon = load(ART % "coin")
	_sell_all.expand_icon = true
	_sell_all.add_theme_constant_override("icon_max_width", 44)
	_sell_all.add_theme_font_size_override("font_size", 27)
	_sell_all.mouse_entered.connect(func(): _show_info(_sell_all, "Sell everything", "All your produce, fruit and wine"))
	_sell_all.mouse_exited.connect(_hide_info.bind(_sell_all))
	_sell_all.position = Vector2(w - 236, 498)
	_sell_all.size = Vector2(196, sell_slot_size)
	_sell_all.pressed.connect(_on_sell_all)
	_stage.add_child(_sell_all)

	var back := Button.new()
	back.text = "<"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 27)
	back.position = Vector2(12, 30)
	back.custom_minimum_size = Vector2(64, 52)
	back.pressed.connect(close)
	_stage.add_child(back)
	var money := PanelContainer.new()
	money.theme_type_variation = &"Badge"
	money.position = Vector2(w - 176, 32)
	money.custom_minimum_size = Vector2(164, 48)
	_money_label = _label("", 27, gold_color)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money.add_child(_money_label)
	_stage.add_child(money)
	_build_info()

## The little hover card: name in gold, one short line underneath.
func _build_info() -> void:
	_info = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color8(46, 30, 22, 245)
	style.border_color = Color8(214, 160, 90)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	_info.add_theme_stylebox_override("panel", style)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	_info.z_index = 10
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(box)
	_info_name = _label("", 18, gold_color)
	box.add_child(_info_name)
	_info_line = _label("", 18, Color8(255, 244, 222), false)
	box.add_child(_info_line)
	_stage.add_child(_info)

## Pops the info card up just above `target` (or below, near the top edge).
func _show_info(target: Control, title: String, line: String) -> void:
	_info_target = target
	_info_name.text = title
	_info_line.text = line
	_info_line.visible = line != ""
	_info.visible = true
	_info.reset_size()
	var card := _info.get_combined_minimum_size()
	var to_stage := _stage.get_global_transform().affine_inverse()
	var rect := target.get_global_rect()
	var top: Vector2 = to_stage * rect.position
	var bottom: Vector2 = to_stage * rect.end
	var x := clampf((top.x + bottom.x - card.x) * 0.5, 8.0, design_size.x - card.x - 8.0)
	var y := top.y - card.y - 8.0
	if y < 8.0:
		y = bottom.y + 8.0
	_info.position = Vector2(x, y).floor()
	_info.modulate.a = 0.0
	create_tween().tween_property(_info, "modulate:a", 1.0, 0.1)

func _hide_info(target: Control) -> void:
	if _info_target == target:
		_info.visible = false
		_info_target = null

# --- Shelves ------------------------------------------------------------------

## Top: seeds then yeast. Middle: tools by kind and size. Bottom: animals.
func _shelf_contents() -> Array:
	var seeds: Array = []
	var yeasts: Array = []
	var tools: Array = []
	var animals: Array = []
	for item in ItemDatabase.shop_items():
		if item.is_seed():
			seeds.append(item)
		elif Brewing.YEASTS.has(item.id):
			yeasts.append(item)
		elif item.is_tool():
			tools.append(item)
		elif item.is_animal():
			animals.append(item)
	tools.sort_custom(func(a, b): return [a.tool_kind, a.tool_area] < [b.tool_kind, b.tool_area])
	return [seeds + yeasts, tools, animals]

func _stock_shelves() -> void:
	if not _shelf_items.is_empty():
		return
	var rows := _shelf_contents()
	for r in mini(rows.size(), _shelf_rows.size()):
		# Roomy shelves get more space between goods, so big price tags don't touch.
		_shelf_rows[r].add_theme_constant_override("separation", 4 if rows[r].size() > 9 else 26)
		for item in rows[r]:
			_shelf_rows[r].add_child(_make_shelf_item(item))

func _make_shelf_item(item: ItemData) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(shelf_icon_size + 16, shelf_icon_size + 40)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(8, 0)
	icon.size = Vector2(shelf_icon_size, shelf_icon_size)
	icon.pivot_offset = Vector2(shelf_icon_size * 0.5, shelf_icon_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	# A little cream price tag hanging off the shelf edge.
	var tag := PanelContainer.new()
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = tag_color
	tag_style.set_border_width_all(2)
	tag_style.border_color = Color8(92, 56, 36)
	tag_style.set_corner_radius_all(3)
	tag_style.content_margin_top = 1
	tag_style.content_margin_bottom = 2
	tag_style.content_margin_left = 7
	tag_style.content_margin_right = 7
	tag_style.shadow_color = Color(0, 0, 0, 0.25)
	tag_style.shadow_offset = Vector2(0, 2)
	tag_style.shadow_size = 1
	tag.add_theme_stylebox_override("panel", tag_style)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tag)
	var price := _label("", 18, price_color, false)
	# The theme gives every label a drop shadow; price tags read cleaner without.
	price.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_child(price)
	var tick := TextureRect.new()
	tick.texture = load(ART % "check")
	tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tick.size = Vector2(33, 27)
	tick.position = Vector2((shelf_icon_size + 16 - 33) * 0.5, shelf_icon_size + 8)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tick)
	var badge := _label("", 18, Color.WHITE)
	badge.position = Vector2(shelf_icon_size - 18, shelf_icon_size - 26)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(badge)
	var entry := {"item": item, "root": root, "icon": icon, "tag": tag, "price": price, "tick": tick, "badge": badge}
	root.gui_input.connect(_on_shelf_input.bind(entry))
	root.mouse_entered.connect(func():
		_lift(entry, true)
		_show_info(root, _item_name(item), ItemInfo.blurb(item)))
	root.mouse_exited.connect(func():
		_lift(entry, false)
		_hide_info(root))
	_shelf_items.append(entry)
	return root

func _item_name(item: ItemData) -> String:
	return item.display_name

func _refresh_shelf_item(entry: Dictionary) -> void:
	var item: ItemData = entry.item
	var icon: TextureRect = entry.icon
	var tag: PanelContainer = entry.tag
	var price: Label = entry.price
	var tick: TextureRect = entry.tick
	var badge: Label = entry.badge
	var reason := GameState.buy_block_reason(item.id)
	price.text = money_format % item.buy_price
	price.add_theme_color_override("font_color", too_dear_color if reason == &"money" else price_color)
	var owned := reason == &"owned"
	var full := reason == &"pen_full"
	tag.visible = not owned
	tick.visible = owned
	icon.modulate = Color(1, 1, 1, 0.45) if owned or full else Color.WHITE
	badge.text = ""
	if item.is_animal():
		var have := GameState.animal_count(item.animal_kind)
		if have > 0:
			badge.text = "%d/%d" % [have, GameState.animal_limit(item.animal_kind)]
	entry.root.mouse_default_cursor_shape = Control.CURSOR_ARROW if owned or full else Control.CURSOR_POINTING_HAND
	# Centre the tag under the icon once it knows its size.
	tag.reset_size()
	tag.position = Vector2((shelf_icon_size + 16 - tag.get_combined_minimum_size().x) * 0.5, shelf_icon_size + 10)

func _lift(entry: Dictionary, on: bool) -> void:
	var icon: TextureRect = entry.icon
	var tween := create_tween()
	tween.tween_property(icon, "position:y", -6.0 if on else 0.0, 0.08)

func _on_shelf_input(event: InputEvent, entry: Dictionary) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var item: ItemData = entry.item
	var root: Control = entry.root
	if GameState.buy_block_reason(item.id) == &"" and GameState.buy(item.id):
		_coin_popup(root, -item.buy_price)
		_bump(entry.icon)
	else:
		_shake(root)

# --- Counter ------------------------------------------------------------------

## What you can sell here: produce, fruit, wine. Bought things like seeds and
## yeast stay in your bags.
func _goods_to_sell() -> Array:
	var result: Array = []
	for item in GameState.sellable_items():
		if not item.for_sale:
			result.append(item)
	return result

func _refresh_counter() -> void:
	if _info_target and _info_target.get_parent() == _sell_row:
		_hide_info(_info_target)
	for child in _sell_row.get_children():
		_sell_row.remove_child(child)
		child.queue_free()
	var total := 0
	for item in _goods_to_sell():
		var have := GameState.count_owned(item.id)
		total += have * item.sell_price
		_sell_row.add_child(_make_sell_slot(item, have))
	_sell_all.text = money_format % total
	_sell_all.disabled = total <= 0

func _make_sell_slot(item: ItemData, have: int) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(sell_slot_size, sell_slot_size)
	var style := StyleBoxTexture.new()
	style.texture = load("res://static/ui/slot_inset.png")
	style.set_texture_margin_all(12)
	slot.add_theme_stylebox_override("panel", style)
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.mouse_entered.connect(func():
		var line := ItemInfo.blurb(item)
		var each := "Sells for %s" % (money_format % item.sell_price)
		_show_info(slot, item.display_name, each if line == "" else "%s\n%s" % [line, each]))
	slot.mouse_exited.connect(_hide_info.bind(slot))
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10
	icon.offset_top = 10
	icon.offset_right = -10
	icon.offset_bottom = -10
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	var count := _label(str(have), 18, Color.WHITE)
	count.anchor_left = 1.0
	count.anchor_top = 1.0
	count.anchor_right = 1.0
	count.anchor_bottom = 1.0
	count.offset_left = -50
	count.offset_top = -28
	count.offset_right = -7
	count.offset_bottom = -3
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slot.add_child(count)
	slot.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_sell(item, 1, slot)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_sell(item, GameState.count_owned(item.id), slot))
	return slot

func _sell(item: ItemData, count: int, from: Control) -> void:
	var earned := GameState.sell_item(item.id, count)
	if earned > 0:
		_coin_popup(from, earned)

func _on_sell_all() -> void:
	var earned := 0
	for item in _goods_to_sell():
		earned += GameState.sell_item(item.id, GameState.count_owned(item.id))
	if earned > 0:
		_coin_popup(_sell_all, earned)
		_bump(_sell_all)

# --- Refresh & juice ----------------------------------------------------------

func _refresh() -> void:
	_money_label.text = money_format % GameState.money
	for entry in _shelf_items:
		_refresh_shelf_item(entry)
	_refresh_counter()

func _bump(target: Control) -> void:
	target.pivot_offset = target.size * Vector2(0.5, 1.0)
	var tween := create_tween()
	tween.tween_property(target, "scale", Vector2(1.15, 0.9), 0.07)
	tween.tween_property(target, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _shake(target: Control) -> void:
	target.pivot_offset = target.size * 0.5
	var tween := create_tween()
	for angle in [0.1, -0.1, 0.05, 0.0]:
		tween.tween_property(target, "rotation", angle, 0.05)

## "+€12" / "-€4" floating up from where the money changed hands.
func _coin_popup(from: Control, amount: int) -> void:
	var label := _label(("+" if amount > 0 else "-") + money_format % absi(amount), 27,
		Color(1, 0.85, 0.3) if amount > 0 else Color(1, 0.55, 0.45))
	label.add_theme_constant_override("outline_size", 6)
	_stage.add_child(label)
	var start := _stage.get_global_transform().affine_inverse() * from.get_global_rect().get_center()
	label.position = start - Vector2(40, 40)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)
