extends CanvasLayer

@export var inventory_slot_scene: PackedScene
@export var shop_row_scene: PackedScene

@export_group("Slot Sizes")
@export var inventory_slot_size: int = 92
@export var hand_slot_size: int = 84
@export var hotbar_slot_size: int = 96
@export var sell_slot_size: int = 84

@export_group("Fit")
@export var screen_padding: float = 32.0
@export var hud_edge_padding: float = 16.0
@export var auto_fit_bottom_hud: bool = true
@export var auto_fit_inventory: bool = true

@export_group("Text")
@export var money_format: String = "€%d"
@export var sell_idle_text: String = "Sell"
@export var sell_value_format: String = "Sell €%d"

@export_group("New Game Button")
@export var reset_label: String = "New Game"
@export var reset_confirm_label: String = "Erase save?"
@export var reset_confirm_seconds: float = 4.0
@export var reset_confirm_font_color: Color = Color(1, 0.95, 0.6)

@export_group("Pickup Flight")
@export var fly_seconds: float = 0.45
@export var fly_icon_size: int = 56
@export var fly_land_scale: float = 0.55
@export var fly_target_bump: float = 1.18

@export_group("Keys")
@export var open_inventory_key: Key = KEY_I
@export var open_inventory_alt_key: Key = KEY_E
@export var close_inventory_key: Key = KEY_ESCAPE
@export var hotbar_first_key: Key = KEY_1

@onready var _inventory_screen: Control = %InventoryScreen
@onready var _inv_center: Control = %Center
@onready var _inv_window: Control = %Window
@onready var _hud_money_label: Label = %HudMoneyLabel
@onready var _inv_money_label: Label = %InvMoneyLabel
@onready var _shop_list: VBoxContainer = %ShopList
@onready var _shop_tabs: HBoxContainer = %ShopTabs
@onready var _sell_grid: GridContainer = %SellGrid
@onready var _inv_grid: GridContainer = %InvGrid
@onready var _hotbar_row: HBoxContainer = %HotbarRow
@onready var _hand_row: HBoxContainer = %HandRow
@onready var _bottom_bar: Control = %BottomBar
@onready var _sell_button: Button = %SellButton
@onready var _barn_button: Button = %BarnButton
@onready var _close_button: Button = %CloseButton
@onready var _reset_button: Button = %ResetButton
@onready var _cursor_view: Control = %CursorView
@onready var _cursor_icon: TextureRect = %CursorIcon
@onready var _cursor_count: Label = %CursorCount

var _hotbar_slots: Array[InventorySlot] = []
var _hand_slots: Array[InventorySlot] = []
var _inv_slots: Array[InventorySlot] = []
var _sell_slots: Array[InventorySlot] = []
var _reset_armed_left: float = 0.0
var _shop_category: String = "seeds"

func _ready() -> void:
	_inventory_screen.visible = false
	_cursor_view.visible = false

	_inv_grid.columns = GameState.inventory_columns
	_sell_grid.columns = GameState.sell_columns

	for i in GameState.hotbar_size:
		_hotbar_slots.append(_add_slot(_hotbar_row, "hotbar", i, hotbar_slot_size))
		_hand_slots.append(_add_slot(_hand_row, "hotbar", i, hand_slot_size))
	for i in GameState.inventory_size():
		_inv_slots.append(_add_slot(_inv_grid, "inventory", i, inventory_slot_size))
	for i in GameState.sell_size():
		_sell_slots.append(_add_slot(_sell_grid, "sell", i, sell_slot_size, true))
	for tab in _shop_tabs.get_children():
		tab.pressed.connect(_on_shop_tab.bind(tab.name.to_lower()))
	_populate_shop()

	_barn_button.pressed.connect(_toggle_inventory)
	_close_button.pressed.connect(_set_inventory_open.bind(false))
	_sell_button.pressed.connect(_on_sell_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_disarm_reset()

	GameState.money_changed.connect(_on_money_changed)
	GameState.inventory_changed.connect(_refresh_inventory)
	GameState.hotbar_changed.connect(_refresh_hotbar)
	GameState.sell_changed.connect(_refresh_sell)
	GameState.hotbar_selection_changed.connect(_on_hotbar_selection_changed)
	GameState.cursor_changed.connect(_on_cursor_changed)
	GameState.animals_changed.connect(_populate_shop)
	GameState.tools_changed.connect(_populate_shop)
	GameState.item_collected.connect(_on_item_collected)
	get_viewport().size_changed.connect(_fit_ui)

	_on_money_changed(GameState.money)
	_fit_ui()
	_on_hotbar_selection_changed(GameState.selected_hotbar)
	_refresh_hotbar()
	_refresh_inventory()
	_refresh_sell()

func _add_slot(parent: Node, container_id: String, index: int, size: int,
		is_sell := false) -> InventorySlot:
	var slot: InventorySlot = inventory_slot_scene.instantiate()
	slot.container_id = container_id
	slot.index = index
	slot.slot_size = size
	slot.is_sell = is_sell
	slot.shift_clicked.connect(_on_slot_shift_clicked)
	slot.clicked.connect(_on_slot_clicked)
	slot.right_clicked.connect(_on_slot_right_clicked)
	parent.add_child(slot)
	return slot

func _on_shop_tab(category: String) -> void:
	_shop_category = category
	_populate_shop()

func _in_shop_category(item: ItemData) -> bool:
	match _shop_category:
		"animals": return item.is_animal()
		"tools": return item.is_tool()
		_: return item.is_seed()

func _populate_shop() -> void:
	for child in _shop_list.get_children():
		child.queue_free()
	for item in ItemDatabase.shop_items():
		if not _in_shop_category(item):
			continue
		var row: ShopRow = shop_row_scene.instantiate()
		row.item = item
		row.buy_pressed.connect(_on_buy_pressed)
		_shop_list.add_child(row)

func _on_cursor_changed() -> void:
	var stack: ItemStack = GameState.cursor
	_cursor_view.visible = stack != null
	if stack == null:
		return
	var item: ItemData = ItemDatabase.get_item(stack.item_id)
	_cursor_icon.texture = item.icon if item else null
	_cursor_count.text = str(stack.count) if stack.count > 1 else ""

func _process(delta: float) -> void:
	if _cursor_view.visible:
		_cursor_view.position = get_viewport().get_mouse_position()
	if _reset_armed_left > 0.0:
		_reset_armed_left -= delta
		if _reset_armed_left <= 0.0:
			_disarm_reset()

func _on_buy_pressed(item_id: StringName) -> void:
	GameState.buy(item_id)

func _on_slot_clicked(container_id: String, index: int) -> void:
	if _inventory_screen.visible:
		GameState.click_slot(container_id, index, false)
	elif container_id == "hotbar":
		GameState.select_hotbar(index)

func _on_slot_right_clicked(container_id: String, index: int) -> void:
	if _inventory_screen.visible:
		GameState.click_slot(container_id, index, true)

func _on_hotbar_selection_changed(index: int) -> void:
	for i in _hotbar_slots.size():
		_hotbar_slots[i].selected = (i == index)
		_hand_slots[i].selected = (i == index)

func _on_slot_shift_clicked(container_id: String, index: int) -> void:
	if not _inventory_screen.visible or container_id == "sell":
		return
	GameState.quick_move(container_id, index, "sell")

func _on_sell_pressed() -> void:
	GameState.sell_all_staged()

## First press arms the button, a second press within the timeout wipes the save.
func _on_reset_pressed() -> void:
	if _reset_armed_left > 0.0:
		_disarm_reset()
		_set_inventory_open(false)
		GameState.reset_progress()
		return
	_reset_armed_left = reset_confirm_seconds
	_reset_button.text = reset_confirm_label
	_reset_button.add_theme_color_override("font_color", reset_confirm_font_color)

func _disarm_reset() -> void:
	_reset_armed_left = 0.0
	_reset_button.text = reset_label
	_reset_button.remove_theme_color_override("font_color")

## Shows where a harvest went: it flies to the hand slot it landed in, or to
## the barn button when it went into the backpack.
func _on_item_collected(item_id: StringName, container_name: String, index: int,
		from_screen: Vector2) -> void:
	if from_screen == Vector2.INF or _inventory_screen.visible:
		return
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null or item.icon == null:
		return
	var target: Control = _barn_button
	if container_name == "hotbar" and index >= 0 and index < _hotbar_slots.size():
		target = _hotbar_slots[index]

	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2.ONE * fly_icon_size
	icon.pivot_offset = icon.size * 0.5
	icon.position = from_screen - icon.size * 0.5
	icon.z_index = 50
	add_child(icon)

	var landing := target.get_global_rect().get_center() - icon.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(icon, "position", landing, fly_seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(icon, "scale", Vector2.ONE * fly_land_scale, fly_seconds)
	tween.chain().tween_callback(icon.queue_free)
	tween.chain().tween_callback(_bump.bind(target))

func _bump(target: Control) -> void:
	if not is_instance_valid(target):
		return
	target.pivot_offset = target.size * 0.5
	var tween := create_tween()
	tween.tween_property(target, "scale", Vector2.ONE * fly_target_bump, 0.08)
	tween.tween_property(target, "scale", Vector2.ONE, 0.14)

func _on_money_changed(amount: int) -> void:
	_hud_money_label.text = money_format % amount
	if _inv_money_label:
		_inv_money_label.text = money_format % amount

func _refresh_hotbar() -> void:
	for slot in _hotbar_slots:
		slot.refresh()
	for slot in _hand_slots:
		slot.refresh()

func _refresh_inventory() -> void:
	for slot in _inv_slots:
		slot.refresh()

func _refresh_sell() -> void:
	for slot in _sell_slots:
		slot.refresh()
	var has_items := false
	for s in GameState.sell_grid:
		if s != null:
			has_items = true
			break
	_sell_button.disabled = not has_items
	_sell_button.text = sell_value_format % GameState.staged_value() if has_items else sell_idle_text

func _fit_ui() -> void:
	_fit_bottom_hud()
	_fit_inventory_screen()

func _fit_bottom_hud() -> void:
	if not auto_fit_bottom_hud:
		return
	_bottom_bar.scale = Vector2.ONE
	await get_tree().process_frame
	var screen_width := get_viewport().get_visible_rect().size.x
	var needed := _bottom_bar.position.x \
		+ _bottom_bar.get_combined_minimum_size().x + hud_edge_padding
	if needed <= 0.0:
		return
	var factor := minf(1.0, screen_width / needed)
	_bottom_bar.pivot_offset = Vector2(0.0, _bottom_bar.size.y)
	_bottom_bar.scale = Vector2(factor, factor)

func _fit_inventory_screen() -> void:
	if not auto_fit_inventory or not _inventory_screen.visible:
		return
	_inv_center.scale = Vector2.ONE
	_inv_center.position = Vector2.ZERO
	_inv_center.pivot_offset = Vector2.ZERO
	await get_tree().process_frame
	if not _inventory_screen.visible:
		return
	var natural := _inv_window.size
	if natural.x <= 0.0 or natural.y <= 0.0:
		return
	var screen := get_viewport().get_visible_rect().size
	var room := screen - Vector2.ONE * screen_padding
	var factor := minf(1.0, minf(room.x / natural.x, room.y / natural.y))
	_inv_center.scale = Vector2(factor, factor)
	_inv_center.position = (screen - natural * factor) * 0.5 - _inv_window.position * factor
	_cursor_view.scale = Vector2(factor, factor)

func _toggle_inventory() -> void:
	_set_inventory_open(not _inventory_screen.visible)

func _set_inventory_open(open: bool) -> void:
	if not open and _inventory_screen.visible:
		_disarm_reset()
		GameState.return_staged()
		GameState.return_cursor()
	_inventory_screen.visible = open
	if open:
		_refresh_inventory()
		_refresh_hotbar()
		_refresh_sell()
		_fit_inventory_screen()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.keycode
	if key >= hotbar_first_key and key < hotbar_first_key + GameState.hotbar_size:
		GameState.select_hotbar(key - hotbar_first_key)
		get_viewport().set_input_as_handled()
		return
	if key == open_inventory_key or key == open_inventory_alt_key:
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif key == close_inventory_key and _inventory_screen.visible:
		_set_inventory_open(false)
		get_viewport().set_input_as_handled()
