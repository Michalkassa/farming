extends CanvasLayer

@export var inventory_slot_scene: PackedScene
## Slots inside the barn window look like little wooden crates.
@export var barn_slot_texture: Texture2D

@export_group("Slot Sizes")
@export var inventory_slot_size: int = 92
@export var hand_slot_size: int = 84
@export var hotbar_slot_size: int = 96

@export_group("Fit")
@export var screen_padding: float = 32.0
@export var hud_edge_padding: float = 16.0
@export var auto_fit_bottom_hud: bool = true
@export var auto_fit_inventory: bool = true

@export_group("Text")
@export var money_format: String = "€%d"

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
## Backpack pickups fly to the first node in this group (the hub's barn).
@export var barn_group: StringName = &"barn"

@export_group("Settings")
@export var settings_hover_tint: Color = Color(1.2, 1.15, 1.05)

@export_group("Barn Interior")
## Size the barn backdrop is designed at; it's scaled to cover the window.
@export var barn_design_size: Vector2 = Vector2(1152, 648)

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
@onready var _inv_grid: GridContainer = %InvGrid
@onready var _hotbar_row: HBoxContainer = %HotbarRow
@onready var _hand_row: HBoxContainer = %HandRow
@onready var _bottom_bar: Control = %BottomBar
@onready var _close_button: Button = %CloseButton
@onready var _reset_button: Button = %ResetButton
@onready var _cursor_view: Control = %CursorView
@onready var _barn_stage: Control = %Stage
@onready var _settings_button: TextureButton = %SettingsButton
@onready var _settings_screen: Control = %SettingsScreen
@onready var _settings_close: Button = %SettingsClose
@onready var _cursor_icon: TextureRect = %CursorIcon
@onready var _cursor_count: Label = %CursorCount

var _hotbar_slots: Array[InventorySlot] = []
var _hand_slots: Array[InventorySlot] = []
var _inv_slots: Array[InventorySlot] = []
var _reset_armed_left: float = 0.0

func _ready() -> void:
	_inventory_screen.visible = false
	_cursor_view.visible = false

	_inv_grid.columns = GameState.inventory_columns

	for i in GameState.hotbar_size:
		_hotbar_slots.append(_add_slot(_hotbar_row, "hotbar", i, hotbar_slot_size))
		_hand_slots.append(_add_slot(_hand_row, "hotbar", i, hand_slot_size, barn_slot_texture))
	for i in GameState.inventory_size():
		_inv_slots.append(_add_slot(_inv_grid, "inventory", i, inventory_slot_size, barn_slot_texture))

	_close_button.pressed.connect(_set_inventory_open.bind(false))
	_reset_button.pressed.connect(_on_reset_pressed)
	_settings_button.pressed.connect(_set_settings_open.bind(true))
	_settings_close.pressed.connect(_set_settings_open.bind(false))
	_settings_button.mouse_entered.connect(func(): _settings_button.modulate = settings_hover_tint)
	_settings_button.mouse_exited.connect(func(): _settings_button.modulate = Color.WHITE)
	_disarm_reset()

	GameState.money_changed.connect(_on_money_changed)
	GameState.inventory_changed.connect(_refresh_inventory)
	GameState.hotbar_changed.connect(_refresh_hotbar)
	GameState.hotbar_selection_changed.connect(_on_hotbar_selection_changed)
	GameState.cursor_changed.connect(_on_cursor_changed)
	GameState.item_collected.connect(_on_item_collected)
	get_viewport().size_changed.connect(_fit_ui)

	_on_money_changed(GameState.money)
	_fit_ui()
	_on_hotbar_selection_changed(GameState.selected_hotbar)
	_refresh_hotbar()
	_refresh_inventory()

func _add_slot(parent: Node, container_id: String, index: int, size: int,
		texture: Texture2D = null) -> InventorySlot:
	var slot: InventorySlot = inventory_slot_scene.instantiate()
	if texture:
		slot.slot_texture = texture
	slot.container_id = container_id
	slot.index = index
	slot.slot_size = size
	slot.shift_clicked.connect(_on_slot_shift_clicked)
	slot.clicked.connect(_on_slot_clicked)
	slot.right_clicked.connect(_on_slot_right_clicked)
	parent.add_child(slot)
	return slot

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

## Shift-click swaps a stack between the hand and the backpack.
func _on_slot_shift_clicked(container_id: String, index: int) -> void:
	if not _inventory_screen.visible:
		return
	GameState.quick_move(container_id, index, "inventory" if container_id == "hotbar" else "hotbar")

## First press arms the button, a second press within the timeout wipes the save.
func _on_reset_pressed() -> void:
	if _reset_armed_left > 0.0:
		_disarm_reset()
		_set_settings_open(false)
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
## the barn in the hub (any node in the `barn_group` group) when it went into
## the backpack.
func _on_item_collected(item_id: StringName, container_name: String, index: int,
		from_screen: Vector2) -> void:
	if from_screen == Vector2.INF or _inventory_screen.visible:
		return
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null or item.icon == null:
		return
	var landing_point := Vector2.INF
	var on_land: Callable
	if container_name == "hotbar" and index >= 0 and index < _hotbar_slots.size():
		var slot: Control = _hotbar_slots[index]
		landing_point = slot.get_global_rect().get_center()
		on_land = _bump.bind(slot)
	else:
		var barn := get_tree().get_first_node_in_group(barn_group) as Node2D
		if barn == null:
			return
		var height: float = barn.texture.get_size().y if barn.get("texture") else 0.0
		landing_point = barn.get_global_transform_with_canvas() * Vector2(0, -height * 0.5)
		on_land = barn.bump if barn.has_method("bump") else Callable()

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

	var landing := landing_point - icon.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(icon, "position", landing, fly_seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(icon, "scale", Vector2.ONE * fly_land_scale, fly_seconds)
	tween.chain().tween_callback(icon.queue_free)
	if on_land.is_valid():
		tween.chain().tween_callback(on_land)

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
	if not _inventory_screen.visible:
		return
	_fit_barn_backdrop()
	if not auto_fit_inventory:
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
	# The centre container may not have re-laid out yet, so work out where it
	# will put the window instead of reading the window's (possibly stale) position.
	_inv_center.size = screen
	var window_offset := (screen - natural) * 0.5
	_inv_center.scale = Vector2(factor, factor)
	_inv_center.position = (screen - natural * factor) * 0.5 - window_offset * factor
	_cursor_view.scale = Vector2(factor, factor)

func _set_settings_open(open: bool) -> void:
	if not open:
		_disarm_reset()
	_settings_screen.visible = open

## Opens the barn storage window; the barn building in the hub calls this.
func open_inventory() -> void:
	_set_inventory_open(true)

## Scales the barn interior to fill the window (cropping the edges rather
## than letterboxing, so it always feels like you're standing inside).
func _fit_barn_backdrop() -> void:
	var screen := get_viewport().get_visible_rect().size
	var factor := maxf(screen.x / barn_design_size.x, screen.y / barn_design_size.y)
	_barn_stage.scale = Vector2(factor, factor)
	_barn_stage.position = ((screen - barn_design_size * factor) * 0.5).floor()

func _toggle_inventory() -> void:
	_set_inventory_open(not _inventory_screen.visible)

func _set_inventory_open(open: bool) -> void:
	if not open and _inventory_screen.visible:
		_disarm_reset()
		GameState.return_cursor()
	_inventory_screen.visible = open
	_settings_button.visible = not open
	if open:
		_refresh_inventory()
		_refresh_hotbar()
		_fit_inventory_screen()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.keycode
	if key >= hotbar_first_key and key < hotbar_first_key + GameState.hotbar_size:
		GameState.select_hotbar(key - hotbar_first_key)
		get_viewport().set_input_as_handled()
		return
	if _settings_screen.visible:
		if key == close_inventory_key:
			_set_settings_open(false)
		get_viewport().set_input_as_handled()
		return
	if key == open_inventory_key or key == open_inventory_alt_key:
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif key == close_inventory_key and _inventory_screen.visible:
		_set_inventory_open(false)
		get_viewport().set_input_as_handled()
