class_name InventorySlot
extends Panel

const ItemInfo := preload("res://scripts/item_info.gd")

signal clicked(container_id: String, index: int)
signal right_clicked(container_id: String, index: int)
signal shift_clicked(container_id: String, index: int)

@export_enum("inventory", "hotbar", "sell") var container_id: String = "inventory"
@export var index: int = 0
@export var slot_size: int = 48 : set = _set_slot_size
@export var is_sell: bool = false : set = _set_is_sell
@export var selected: bool = false : set = _set_selected

@export_group("Style")
@export var slot_texture: Texture2D = preload("res://static/ui/slot_inset.png")
@export var sell_texture: Texture2D = preload("res://static/ui/slot_sell.png")
@export var icon_padding_ratio: float = 0.12
@export var count_font_ratio: float = 0.25
@export var count_font_min_size: int = 16
@export var count_margin_ratio: Vector2 = Vector2(0.12, 0.06)

@export_group("Tooltip")
@export var show_tooltip: bool = true
@export var tooltip_sell_format: String = "Sells for €%d"
@export var tooltip_unsellable_text: String = "Cannot be sold"
@export var tooltip_name_font_size: int = 18
@export var tooltip_price_font_size: int = 18
@export var tooltip_background: Color = Color(0.18, 0.12, 0.08, 0.97)
@export var tooltip_border: Color = Color(0.48, 0.36, 0.24, 1)
@export var tooltip_name_color: Color = Color(1, 1, 1)
@export var tooltip_price_color: Color = Color(1, 0.8, 0.25)

@onready var _icon: TextureRect = $Icon
@onready var _count_label: Label = $Count
@onready var _highlight: Panel = $Highlight

var _click_pending: bool = false

func _set_slot_size(value: int) -> void:
	slot_size = value
	custom_minimum_size = Vector2(value, value)
	if is_node_ready():
		_apply_size()

func _set_is_sell(value: bool) -> void:
	is_sell = value
	if is_node_ready():
		_apply_tint()

func _set_selected(value: bool) -> void:
	selected = value
	if is_node_ready():
		_highlight.visible = value

func _ready() -> void:
	_apply_size()
	_apply_tint()
	_highlight.visible = selected
	refresh()

func _apply_size() -> void:
	custom_minimum_size = Vector2(slot_size, slot_size)
	var pad := int(slot_size * icon_padding_ratio)
	_icon.offset_left = pad
	_icon.offset_top = pad
	_icon.offset_right = -pad
	_icon.offset_bottom = -pad
	_count_label.offset_right = -int(slot_size * count_margin_ratio.x)
	_count_label.offset_bottom = -int(slot_size * count_margin_ratio.y)
	_count_label.add_theme_font_size_override("font_size",
		maxi(count_font_min_size, int(slot_size * count_font_ratio)))

## Each slot gets its own copy of the panel style, so changing one slot's
## texture (e.g. the barn's crates) never repaints every other slot.
func _apply_tint() -> void:
	var style := get_theme_stylebox("panel")
	if style is StyleBoxTexture:
		var own: StyleBoxTexture = style.duplicate()
		own.texture = sell_texture if is_sell else slot_texture
		add_theme_stylebox_override("panel", own)

func _stack() -> ItemStack:
	var cont := GameState.container(container_id)
	if index < 0 or index >= cont.size():
		return null
	return cont[index]

func refresh() -> void:
	if _icon == null:
		return
	var stack := _stack()
	if stack == null:
		_icon.texture = null
		_count_label.text = ""
		tooltip_text = ""
		return
	var item: ItemData = ItemDatabase.get_item(stack.item_id)
	_icon.texture = item.icon if item else null
	_count_label.text = str(stack.count) if stack.count > 1 else ""
	tooltip_text = item.display_name if (item and show_tooltip) else ""

func _make_custom_tooltip(_for_text: String) -> Object:
	if not show_tooltip:
		return null
	var stack := _stack()
	if stack == null:
		return null
	var item: ItemData = ItemDatabase.get_item(stack.item_id)
	if item == null:
		return null

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = tooltip_background
	sb.set_border_width_all(2)
	sb.border_color = tooltip_border
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)

	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.add_theme_font_size_override("font_size", tooltip_name_font_size)
	name_label.add_theme_color_override("font_color", tooltip_name_color)
	v.add_child(name_label)

	var blurb := ItemInfo.blurb(item)
	if blurb != "":
		var desc_label := Label.new()
		desc_label.text = blurb
		desc_label.add_theme_font_size_override("font_size", tooltip_price_font_size)
		desc_label.add_theme_color_override("font_color", tooltip_name_color.darkened(0.15))
		v.add_child(desc_label)

	var price_label := Label.new()
	if item.sell_price > 0:
		price_label.text = tooltip_sell_format % item.sell_price
	else:
		price_label.text = tooltip_unsellable_text
	price_label.add_theme_font_size_override("font_size", tooltip_price_font_size)
	price_label.add_theme_color_override("font_color", tooltip_price_color)
	v.add_child(price_label)

	return panel

func _get_drag_data(_at_position: Vector2) -> Variant:
	_click_pending = false
	if GameState.cursor != null:
		return null
	var stack := _stack()
	if stack == null:
		return null
	var item: ItemData = ItemDatabase.get_item(stack.item_id)
	var preview := TextureRect.new()
	preview.texture = item.icon if item else null
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(slot_size, slot_size)
	preview.size = Vector2(slot_size, slot_size)
	preview.position = -0.5 * Vector2(slot_size, slot_size)
	var wrapper := Control.new()
	wrapper.add_child(preview)
	set_drag_preview(wrapper)
	return {"source": "slot", "container": container_id, "index": index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("source") == "slot"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	GameState.move_item(data["container"], data["index"], container_id, index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT \
			and event.pressed:
		right_clicked.emit(container_id, index)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.shift_pressed:
				_click_pending = false
				shift_clicked.emit(container_id, index)
				accept_event()
			else:
				_click_pending = true
		elif _click_pending:
			_click_pending = false
			clicked.emit(container_id, index)
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		_click_pending = false
