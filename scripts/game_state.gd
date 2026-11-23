extends Node

signal money_changed(new_amount: int)
signal inventory_changed()
signal hotbar_changed()
signal sell_changed()
signal hotbar_selection_changed(index: int)
signal cursor_changed()
signal animals_changed()
signal tools_changed()
## Something picked up off the farm landed in a slot (first slot it reached).
signal item_collected(item_id: StringName, container_name: String, index: int, from_screen: Vector2)

const SaveStore := preload("res://scripts/save_store.gd")
const SAVE_VERSION := 1

@export var starting_money: int = 40

@export_group("Container Sizes")
@export var inventory_columns: int = 5
@export var inventory_rows: int = 3
@export var hotbar_size: int = 6
@export var sell_columns: int = 1
@export var sell_rows: int = 3

@export_group("Starting Kit")
@export var starter_items: Array[ItemGrant] = []

@export_group("Animals")
@export var dog_growth_bonus: float = 0.5
@export var animal_capacity: int = 5
@export var dog_capacity: int = 1

@export_group("Farm")
## Distance between neighbouring plots, used to find a tool's area of effect.
@export var zone_spacing: float = 16.0

@export_group("Codes")
## Codes the player can type into Settings, each usable once per save.
## "money_for" grants exactly the buy price of that item.
@export var codes: Dictionary = {
	"astoria": {"money_for": "dog"},
}

@export_group("Retired Items")
## Items that no longer exist, with what they cost. Stacks of them found in a
## save are turned back into money instead of silently vanishing.
@export var retired_item_refunds: Dictionary = {
	"honey": 60,
	"cane_sugar": 15,
	"mint": 30,
	"lavender": 40,
	"rosemary": 40,
	"chamomile": 40,
	"rose_petal": 90,
	"saffron": 800,
	"ginger": 50,
	"cinnamon": 120,
	"oak_chips": 80,
	"vanilla_bean": 300,
	"chili": 35,
}

@export_group("Saving")
@export var autosave_seconds: float = 3.0

var money: int = 0
var inventory: Array = []
var hotbar: Array = []
var sell_grid: Array = []
var selected_hotbar: int = 0
var cursor: ItemStack = null
var animals: Array = []
var redeemed_codes: Array = []

var _zones: Array = []
var _zone_states: Dictionary = {}
var _autosave_left: float = 0.0
var _save_enabled: bool = false

func inventory_size() -> int:
	return inventory_columns * inventory_rows

func sell_size() -> int:
	return sell_columns * sell_rows

func _ready() -> void:
	inventory.resize(inventory_size())
	hotbar.resize(hotbar_size)
	sell_grid.resize(sell_size())
	if not _load_game():
		money = starting_money
		call_deferred("_grant_starter_items")
	else:
		# Selling moved to the shop stall; hand back anything left in the old sell box.
		return_staged()
	_save_enabled = true
	_autosave_left = autosave_seconds

func _grant_starter_items() -> void:
	for grant in starter_items:
		if grant == null or grant.item_id == &"":
			continue
		add_item(grant.item_id, grant.count, grant.container)

func select_hotbar(index: int) -> void:
	if index < 0 or index >= hotbar_size or index == selected_hotbar:
		return
	selected_hotbar = index
	hotbar_selection_changed.emit(index)

func selected_item() -> ItemData:
	var stack: ItemStack = hotbar[selected_hotbar]
	if stack == null:
		return null
	return ItemDatabase.get_item(stack.item_id)

func consume_selected(count: int = 1) -> void:
	var stack: ItemStack = hotbar[selected_hotbar]
	if stack == null:
		return
	stack.count -= count
	if stack.count <= 0:
		hotbar[selected_hotbar] = null
	hotbar_changed.emit()

func set_money(value: int) -> void:
	money = max(0, value)
	money_changed.emit(money)

func add_money(delta: int) -> void:
	set_money(money + delta)

func can_afford(cost: int) -> bool:
	return money >= cost

func container(name: String) -> Array:
	match name:
		"hotbar": return hotbar
		"sell": return sell_grid
		_: return inventory

func _emit_changed(name: String) -> void:
	match name:
		"hotbar": hotbar_changed.emit()
		"sell": sell_changed.emit()
		_: inventory_changed.emit()

func has_space_for(item_id: StringName, container_name: String = "inventory") -> bool:
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null:
		return false
	var cont := container(container_name)
	for slot in cont:
		if slot == null:
			return true
		if slot.item_id == item_id and slot.count < item.max_stack:
			return true
	return false

func add_item(item_id: StringName, count: int, container_name: String = "inventory") -> int:
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null or count <= 0:
		return count
	var cont := container(container_name)
	count = _merge_into(cont, item, count)
	count = _fill_empty(cont, item, count)
	_emit_changed(container_name)
	return count

## Picks something up off the farm: tops up existing piles wherever they are,
## then takes a free hand slot (so the player sees it arrive), then the backpack.
func collect_item(item_id: StringName, count: int, from_screen: Vector2 = Vector2.INF) -> int:
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null or count <= 0:
		return count
	var in_hand: Array = []
	var in_pack: Array = []
	count = _merge_into(hotbar, item, count, in_hand)
	count = _merge_into(inventory, item, count, in_pack)
	count = _fill_empty(hotbar, item, count, in_hand)
	count = _fill_empty(inventory, item, count, in_pack)
	inventory_changed.emit()
	hotbar_changed.emit()
	if not in_hand.is_empty():
		item_collected.emit(item_id, "hotbar", in_hand[0], from_screen)
	elif not in_pack.is_empty():
		item_collected.emit(item_id, "inventory", in_pack[0], from_screen)
	return count

func can_collect(item_id: StringName) -> bool:
	return has_space_for(item_id, "inventory") or has_space_for(item_id, "hotbar")

## `placed` collects the indices that received items, in order.
func _merge_into(cont: Array, item: ItemData, count: int, placed: Array = []) -> int:
	for i in cont.size():
		if count <= 0:
			break
		var slot: ItemStack = cont[i]
		if slot != null and slot.item_id == item.id and slot.count < item.max_stack:
			var moved: int = mini(item.max_stack - slot.count, count)
			slot.count += moved
			count -= moved
			placed.append(i)
	return count

func _fill_empty(cont: Array, item: ItemData, count: int, placed: Array = []) -> int:
	for i in cont.size():
		if count <= 0:
			break
		if cont[i] == null:
			var moved: int = mini(item.max_stack, count)
			cont[i] = ItemStack.new(item.id, moved)
			count -= moved
			placed.append(i)
	return count

func click_slot(container_name: String, index: int, half: bool) -> void:
	var cont := container(container_name)
	if index < 0 or index >= cont.size():
		return
	var slot: ItemStack = cont[index]

	if cursor == null:
		if slot == null:
			return
		if half:
			var taken: int = int(ceil(slot.count * 0.5))
			cursor = ItemStack.new(slot.item_id, taken)
			slot.count -= taken
			if slot.count <= 0:
				cont[index] = null
		else:
			cursor = slot
			cont[index] = null
	else:
		var item: ItemData = ItemDatabase.get_item(cursor.item_id)
		var max_stack: int = item.max_stack if item else 1
		if slot == null:
			var dropped: int = mini(1 if half else cursor.count, max_stack)
			cont[index] = ItemStack.new(cursor.item_id, dropped)
			cursor.count -= dropped
			if cursor.count <= 0:
				cursor = null
		elif slot.item_id == cursor.item_id:
			var room: int = max_stack - slot.count
			if room <= 0:
				return
			var dropped: int = mini(room, 1 if half else cursor.count)
			slot.count += dropped
			cursor.count -= dropped
			if cursor.count <= 0:
				cursor = null
		else:
			cont[index] = cursor
			cursor = slot
	_emit_changed(container_name)
	cursor_changed.emit()

func return_cursor() -> void:
	if cursor == null:
		return
	var leftover := add_item(cursor.item_id, cursor.count, "inventory")
	if leftover > 0:
		leftover = add_item(cursor.item_id, leftover, "hotbar")
	if leftover <= 0:
		cursor = null
	else:
		cursor.count = leftover
	cursor_changed.emit()

func move_item(from_container: String, from_index: int,
		to_container: String, to_index: int) -> void:
	if from_container == to_container and from_index == to_index:
		return
	var src_cont := container(from_container)
	var dst_cont := container(to_container)
	var src: ItemStack = src_cont[from_index]
	if src == null:
		return
	var dst: ItemStack = dst_cont[to_index]
	if dst == null:
		dst_cont[to_index] = src
		src_cont[from_index] = null
	elif dst.item_id == src.item_id:
		var item: ItemData = ItemDatabase.get_item(src.item_id)
		var room: int = item.max_stack - dst.count
		var moved: int = min(room, src.count)
		dst.count += moved
		src.count -= moved
		if src.count <= 0:
			src_cont[from_index] = null
	else:
		src_cont[from_index] = dst
		dst_cont[to_index] = src
	_emit_changed(from_container)
	if to_container != from_container:
		_emit_changed(to_container)

func animal_limit(kind: StringName) -> int:
	return dog_capacity if kind == &"dog" else animal_capacity

func animal_count(kind: StringName) -> int:
	return animals.count(kind)

func can_buy_animal(kind: StringName) -> bool:
	return animal_count(kind) < animal_limit(kind)

func has_animal(kind: StringName) -> bool:
	return animals.has(kind)

func growth_multiplier() -> float:
	return (1.0 + dog_growth_bonus) if has_animal(&"dog") else 1.0

## Why a purchase would fail right now, or &"" when it would go through:
## &"unknown", &"owned", &"pen_full", &"money" or &"pack_full".
func buy_block_reason(item_id: StringName) -> StringName:
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null or item.buy_price <= 0:
		return &"unknown"
	if item.is_tool() and tool_area_owned(item.tool_kind) >= item.tool_area:
		return &"owned"
	if item.is_animal() and not can_buy_animal(item.animal_kind):
		return &"pen_full"
	if not can_afford(item.buy_price):
		return &"money"
	if item.is_tool():
		if tool_area_owned(item.tool_kind) == 0 and not can_collect(item_id):
			return &"pack_full"
	elif not item.is_animal() and not can_collect(item_id):
		return &"pack_full"
	return &""

func buy(item_id: StringName) -> bool:
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null or item.buy_price <= 0:
		return false
	if not can_afford(item.buy_price):
		return false
	if item.is_animal():
		if not can_buy_animal(item.animal_kind):
			return false
		set_money(money - item.buy_price)
		animals.append(item.animal_kind)
		animals_changed.emit()
		return true
	if item.is_tool():
		return _buy_tool(item)
	if not can_collect(item_id):
		return false
	set_money(money - item.buy_price)
	_add_bought(item_id, 1)
	return true

## Bought things go straight to the hotbar (topping up a matching stack or
## taking a free slot) and only spill into the backpack when the hand is full.
func _add_bought(item_id: StringName, count: int) -> void:
	var leftover := add_item(item_id, count, "hotbar")
	if leftover > 0:
		add_item(item_id, leftover, "inventory")

## The largest area any owned tool of this kind covers (0 when none is owned).
func tool_area_owned(kind: StringName) -> int:
	var best := 0
	for cont in [hotbar, inventory]:
		for slot: ItemStack in cont:
			if slot == null:
				continue
			var item: ItemData = ItemDatabase.get_item(slot.item_id)
			if item and item.tool_kind == kind:
				best = maxi(best, item.tool_area)
	return best

## A better tool replaces the one you have, in the slot it sits in.
func _buy_tool(item: ItemData) -> bool:
	if tool_area_owned(item.tool_kind) >= item.tool_area:
		return false
	var old_cont := ""
	var old_index := -1
	for cont_name in ["hotbar", "inventory"]:
		var cont := container(cont_name)
		for i in cont.size():
			var slot: ItemStack = cont[i]
			if slot == null:
				continue
			var owned: ItemData = ItemDatabase.get_item(slot.item_id)
			if owned and owned.tool_kind == item.tool_kind:
				old_cont = cont_name
				old_index = i
				break
		if old_index >= 0:
			break
	if old_index < 0 and not can_collect(item.id):
		return false
	set_money(money - item.buy_price)
	if old_index >= 0:
		container(old_cont)[old_index] = ItemStack.new(item.id, 1)
		_emit_changed(old_cont)
	else:
		_add_bought(item.id, 1)
	tools_changed.emit()
	return true

## The square of plots a tool click covers, anchored so bigger tools reach
## right/down: 2 covers the clicked plot plus right/down, 3 is centred, 4 reaches one further.
func zones_around(center: Node2D, size: int) -> Array:
	if size <= 1:
		return [center]
	var start := -int((size - 1) / 2.0)
	var result: Array = []
	for zone in _zones:
		if not is_instance_valid(zone):
			continue
		var d: Vector2 = (zone.global_position - center.global_position) / zone_spacing
		var dx := roundi(d.x)
		var dy := roundi(d.y)
		if dx >= start and dx < start + size and dy >= start and dy < start + size:
			result.append(zone)
	return result

func quick_move(from_container: String, from_index: int, to_container: String) -> bool:
	var from := container(from_container)
	var src: ItemStack = from[from_index]
	if src == null:
		return false
	var leftover := add_item(src.item_id, src.count, to_container)
	var moved := src.count - leftover
	if moved <= 0:
		return false
	src.count -= moved
	if src.count <= 0:
		from[from_index] = null
	_emit_changed(from_container)
	return true

## How many of an item sit in the hand and backpack together.
func count_owned(item_id: StringName) -> int:
	var total := 0
	for cont in [hotbar, inventory]:
		for slot: ItemStack in cont:
			if slot != null and slot.item_id == item_id:
				total += slot.count
	return total

## Removes up to `count` of an item, backpack first so the hand keeps what the
## player is holding. Returns how many were taken.
func take_item(item_id: StringName, count: int) -> int:
	var taken := 0
	for cont_name in ["inventory", "hotbar"]:
		var cont := container(cont_name)
		var touched := false
		for i in range(cont.size() - 1, -1, -1):
			if taken >= count:
				break
			var slot: ItemStack = cont[i]
			if slot == null or slot.item_id != item_id:
				continue
			var moved: int = mini(slot.count, count - taken)
			slot.count -= moved
			taken += moved
			touched = true
			if slot.count <= 0:
				cont[i] = null
		if touched:
			_emit_changed(cont_name)
	return taken

## Things the stall farmer will buy off you: anything with a price except tools.
func sellable_items() -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	for cont in [hotbar, inventory]:
		for slot: ItemStack in cont:
			if slot == null or seen.has(slot.item_id):
				continue
			var item: ItemData = ItemDatabase.get_item(slot.item_id)
			if item and item.sell_price > 0 and not item.is_tool():
				seen[slot.item_id] = true
				result.append(item)
	result.sort_custom(func(a, b): return a.sell_price > b.sell_price)
	return result

## Sells up to `count` of an item to the stall, backpack first so the hand
## keeps what the player is holding. Returns the money earned.
func sell_item(item_id: StringName, count: int) -> int:
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null or item.sell_price <= 0 or item.is_tool() or count <= 0:
		return 0
	var sold := 0
	for cont_name in ["inventory", "hotbar"]:
		var cont := container(cont_name)
		var touched := false
		for i in range(cont.size() - 1, -1, -1):
			if sold >= count:
				break
			var slot: ItemStack = cont[i]
			if slot == null or slot.item_id != item_id:
				continue
			var taken: int = mini(slot.count, count - sold)
			slot.count -= taken
			sold += taken
			touched = true
			if slot.count <= 0:
				cont[i] = null
		if touched:
			_emit_changed(cont_name)
	if sold <= 0:
		return 0
	var earned := sold * item.sell_price
	set_money(money + earned)
	return earned

## Tries a code from the settings menu. Returns {ok, message}.
func redeem_code(raw: String) -> Dictionary:
	var code := raw.strip_edges().to_lower()
	if code == "" or not codes.has(code):
		return {"ok": false, "message": "Unknown code"}
	if redeemed_codes.has(code):
		return {"ok": false, "message": "Already used on this farm"}
	var reward: Dictionary = codes[code]
	var amount := 0
	if reward.has("money_for"):
		var item: ItemData = ItemDatabase.get_item(StringName(reward["money_for"]))
		amount = item.buy_price if item else 0
	amount += int(reward.get("money", 0))
	if amount <= 0:
		return {"ok": false, "message": "Unknown code"}
	redeemed_codes.append(code)
	add_money(amount)
	save_game()
	return {"ok": true, "message": "Code redeemed! +€%d" % amount}

func sell_all_staged() -> int:
	var total := 0
	for i in sell_grid.size():
		var slot: ItemStack = sell_grid[i]
		if slot == null:
			continue
		var item: ItemData = ItemDatabase.get_item(slot.item_id)
		if item == null or item.sell_price <= 0:
			continue
		total += item.sell_price * slot.count
		sell_grid[i] = null
	if total > 0:
		set_money(money + total)
		_emit_changed("sell")
	return total

func staged_value() -> int:
	var total := 0
	for slot: ItemStack in sell_grid:
		if slot == null:
			continue
		var item: ItemData = ItemDatabase.get_item(slot.item_id)
		if item and item.sell_price > 0:
			total += item.sell_price * slot.count
	return total

func return_staged() -> void:
	var returned := false
	for i in sell_grid.size():
		var slot: ItemStack = sell_grid[i]
		if slot == null:
			continue
		var leftover := add_item(slot.item_id, slot.count, "inventory")
		if leftover < slot.count:
			returned = true
		if leftover <= 0:
			sell_grid[i] = null
		else:
			slot.count = leftover
	if returned:
		_emit_changed("sell")

# --- Saving -----------------------------------------------------------------

func _process(delta: float) -> void:
	if not _save_enabled or autosave_seconds <= 0.0:
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = autosave_seconds
		save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST \
			or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_EXIT_TREE:
		save_game()

## Growing zones announce themselves so their soil and crops travel with the save.
func register_zone(zone: Node) -> void:
	if not _zones.has(zone):
		_zones.append(zone)
	var key := String(zone.get_path())
	if _zone_states.has(key):
		zone.load_state(_zone_states[key])

## Keeps the zone's last state, so a save during shutdown still has the whole farm.
func unregister_zone(zone: Node) -> void:
	_zones.erase(zone)
	if is_instance_valid(zone):
		_zone_states[String(zone.get_path())] = zone.save_state()

func save_game() -> bool:
	if not _save_enabled:
		return false
	return SaveStore.write_text(JSON.stringify(save_data()))

## Wipes the save and starts the farm over from the starting kit.
func reset_progress() -> void:
	SaveStore.clear()
	_zone_states.clear()
	for zone in _zones:
		if is_instance_valid(zone):
			zone.reset_zone()
	cursor = null
	animals.clear()
	redeemed_codes.clear()
	Winery.reset()
	Orchard.reset()
	for i in inventory.size():
		inventory[i] = null
	for i in hotbar.size():
		hotbar[i] = null
	for i in sell_grid.size():
		sell_grid[i] = null
	selected_hotbar = 0
	money = starting_money
	_grant_starter_items()
	money_changed.emit(money)
	inventory_changed.emit()
	hotbar_changed.emit()
	sell_changed.emit()
	cursor_changed.emit()
	animals_changed.emit()
	hotbar_selection_changed.emit(selected_hotbar)
	_autosave_left = autosave_seconds
	save_game()

func save_data() -> Dictionary:
	for zone in _zones:
		if is_instance_valid(zone):
			_zone_states[String(zone.get_path())] = zone.save_state()
	return {
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"money": money,
		"selected_hotbar": selected_hotbar,
		"inventory": _pack_container(inventory),
		"hotbar": _pack_container(hotbar),
		"sell": _pack_container(sell_grid),
		"animals": _pack_animals(),
		"codes": redeemed_codes.duplicate(),
		"zones": _zone_states,
		"winery": Winery.save_state(),
		"orchard": Orchard.save_state(),
	}

func _load_game() -> bool:
	var text := SaveStore.read_text()
	if text.strip_edges() == "":
		return false
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("GameState: save data is not valid JSON, starting a new farm")
		return false
	if int(data.get("version", 0)) > SAVE_VERSION:
		push_warning("GameState: save comes from a newer build, starting a new farm")
		return false

	money = maxi(0, int(data.get("money", starting_money)))
	selected_hotbar = clampi(int(data.get("selected_hotbar", 0)), 0, hotbar_size - 1)
	# Bottle items are registered at runtime, so they must exist before the bags unpack.
	Winery.load_state(data.get("winery", {}))
	Orchard.load_state(data.get("orchard", []))
	_unpack_container(inventory, data.get("inventory"))
	_unpack_container(hotbar, data.get("hotbar"))
	_unpack_container(sell_grid, data.get("sell"))

	animals.clear()
	var saved_animals: Variant = data.get("animals", [])
	if typeof(saved_animals) == TYPE_ARRAY:
		for entry in saved_animals:
			var kind := StringName(entry)
			if ItemDatabase.get_item(kind) != null and can_buy_animal(kind):
				animals.append(kind)

	redeemed_codes.clear()
	var saved_codes: Variant = data.get("codes", [])
	if typeof(saved_codes) == TYPE_ARRAY:
		for c in saved_codes:
			redeemed_codes.append(String(c))

	# Zones live in the main scene, so they pick this up when they register.
	var saved_zones: Variant = data.get("zones", {})
	if typeof(saved_zones) == TYPE_DICTIONARY:
		_zone_states = saved_zones.duplicate()
	return true

func _pack_container(cont: Array) -> Array:
	var packed: Array = []
	for slot: ItemStack in cont:
		if slot == null or slot.count <= 0:
			packed.append(null)
		else:
			packed.append({"id": String(slot.item_id), "n": slot.count})
	return packed

func _unpack_container(cont: Array, packed: Variant) -> void:
	for i in cont.size():
		cont[i] = null
	if typeof(packed) != TYPE_ARRAY:
		return
	for i in mini(cont.size(), packed.size()):
		cont[i] = _to_stack(packed[i])

func _to_stack(data: Variant) -> ItemStack:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var item_id := StringName(data.get("id", ""))
	var count := int(data.get("n", 0))
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null and count > 0 and retired_item_refunds.has(String(item_id)):
		money += int(retired_item_refunds[String(item_id)]) * count
		return null
	if item == null or count <= 0:
		return null
	return ItemStack.new(item_id, mini(count, item.max_stack))

func _pack_animals() -> Array:
	var kinds: Array = []
	for kind in animals:
		kinds.append(String(kind))
	return kinds
