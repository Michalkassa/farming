extends Node
## The winery barrel and the bottles it has made (autoload `Winery`).
##
## The barrel has a yeast slot, a fruit slot and 5 extra slots. Nothing stacks:
## each slot holds exactly one item, so adding the same ingredient again takes
## the next free extra slot, and once every slot is taken nothing more goes in.
## Ingredients leave the player's bags as they go in, and come back out if
## removed before sealing. Sealing resolves the brew straight away (so it
## survives a save), then the barrel ferments for the yeast's time and the
## bottles wait to be collected.
##
## Each distinct brew becomes its own bottle item ("brew_<hash>"), registered
## with the ItemDatabase at runtime. The brews are saved so bottles in your bags
## still exist after a reload. GameState loads this before unpacking containers.

signal barrel_changed

const Brewing := preload("res://scripts/brewing.gd")
const BOTTLE_ICON := "res://static/winery/bottle_%s.png"
const LEVEL_NUMERALS := ["", "I", "II", "III"]

enum State { FILLING, FERMENTING, READY }

var yeast_id: StringName = &""
var fruit_id: StringName = &""
var extras: Array[StringName] = []
var state: State = State.FILLING
var ferment_total: float = 0.0
var ferment_left: float = 0.0
## The resolved brew while fermenting or waiting to be bottled.
var result: Dictionary = {}
var bottle_id: StringName = &""
var bottles_left: int = 0
## bottle item id -> JSON-safe brew summary, so bottle items can be rebuilt on load.
var brews: Dictionary = {}

func _ready() -> void:
	_clear_slots()

func _process(delta: float) -> void:
	if state != State.FERMENTING:
		return
	ferment_left = maxf(0.0, ferment_left - delta)
	if ferment_left <= 0.0:
		state = State.READY
		barrel_changed.emit()

# --- Filling ------------------------------------------------------------------

## What's in the barrel as a Brewing pot {id: units}: yeast, fruit, then extras.
func pot() -> Dictionary:
	var result_pot := {}
	for id in [yeast_id, fruit_id] + Array(extras):
		if id != &"":
			result_pot[id] = int(result_pot.get(id, 0)) + 1
	return result_pot

## Why the barrel can't be sealed yet, or "" when it can.
func seal_block_reason() -> String:
	if state != State.FILLING:
		return "The barrel is busy"
	if yeast_id == &"":
		return "Add a yeast"
	if fruit_id == &"":
		return "Add some fruit"
	return Brewing.validate(pot())

## The slot `id` would go into next ("yeast", "fruit" or "extra"), or "" if none is free.
func _free_slot_for(id: StringName) -> String:
	if Brewing.YEASTS.has(id):
		return "yeast" if yeast_id == &"" else ""
	if Brewing.is_fruit(id) and fruit_id == &"":
		return "fruit"
	return "extra" if extras.has(&"") else ""

## Why `id` can't go in right now, or "" when it can.
func add_block_reason(id: StringName) -> String:
	if state != State.FILLING:
		return "The barrel is sealed"
	if not Brewing.is_ingredient(id):
		return "That doesn't go in a barrel"
	if GameState.count_owned(id) <= 0:
		return "You don't have any"
	if _free_slot_for(id) == "":
		return "No free slot"
	return ""

## Puts up to `count` of `id` into the barrel, one per free slot.
## Returns how many went in.
func add(id: StringName, count: int = 1) -> int:
	var moved := 0
	while moved < count and add_block_reason(id) == "":
		if GameState.take_item(id, 1) <= 0:
			break
		match _free_slot_for(id):
			"yeast": yeast_id = id
			"fruit": fruit_id = id
			"extra": extras[extras.find(&"")] = id
		moved += 1
	if moved > 0:
		barrel_changed.emit()
	return moved

## Hands the item in a slot ("yeast", "fruit" or "extra" + index) back to the
## player's bags. False when the slot is empty or the bags are full.
func remove(slot: String, index: int = -1) -> bool:
	if state != State.FILLING:
		return false
	var id: StringName = &""
	match slot:
		"yeast": id = yeast_id
		"fruit": id = fruit_id
		"extra": id = extras[index] if index >= 0 and index < extras.size() else &""
	if id == &"" or GameState.collect_item(id, 1) > 0:
		return false
	match slot:
		"yeast": yeast_id = &""
		"fruit": fruit_id = &""
		"extra": extras[index] = &""
	barrel_changed.emit()
	return true

# --- Fermenting and bottling --------------------------------------------------

func seal() -> bool:
	if seal_block_reason() != "":
		return false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	result = Brewing.brew(pot(), 0, rng)
	if not result.get("ok", false):
		return false
	bottle_id = _register_bottle(result)
	bottles_left = int(result.bottles)
	ferment_total = float(result.ferment)
	ferment_left = ferment_total
	state = State.FERMENTING
	barrel_changed.emit()
	return true

## Moves as many finished bottles as fit into the player's bags. Returns how many.
func collect_bottles() -> int:
	if state != State.READY or bottles_left <= 0:
		return 0
	var leftover: int = GameState.collect_item(bottle_id, bottles_left)
	var moved: int = bottles_left - leftover
	bottles_left = leftover
	if bottles_left <= 0:
		_clear_slots()
	barrel_changed.emit()
	return moved

func ferment_progress() -> float:
	if state == State.READY:
		return 1.0
	if state != State.FERMENTING or ferment_total <= 0.0:
		return 0.0
	return 1.0 - ferment_left / ferment_total

func _clear_slots() -> void:
	yeast_id = &""
	fruit_id = &""
	extras.clear()
	extras.resize(Brewing.EXTRA_SLOTS)
	extras.fill(&"")
	state = State.FILLING
	ferment_total = 0.0
	ferment_left = 0.0
	result = {}
	bottle_id = &""
	bottles_left = 0

# --- Bottle items -------------------------------------------------------------

## One item per distinct brew, so identical bottles stack.
func _register_bottle(brew: Dictionary) -> StringName:
	var summary := {
		"name": brew.name, "kind": String(brew.kind), "value": int(brew.value),
		"vintage": bool(brew.vintage), "effects": [],
	}
	for e in brew.effects:
		summary.effects.append({"effect": String(e.effect), "level": int(e.level), "duration": int(e.duration)})
	var id := StringName("brew_%x" % (hash(JSON.stringify(summary)) & 0x7fffffff))
	brews[String(id)] = summary
	_make_bottle_item(id, summary)
	return id

func _make_bottle_item(id: StringName, summary: Dictionary) -> void:
	if ItemDatabase.get_item(id) != null:
		return
	var effects: Array = summary.get("effects", [])
	var colour := "vinegar" if effects.is_empty() else String(effects[0].effect)
	var item := ItemData.new()
	item.id = id
	item.display_name = String(summary.get("name", "Wine"))
	item.icon = load(BOTTLE_ICON % colour)
	item.sell_price = maxi(1, int(summary.get("value", 1)))
	item.max_stack = 99
	item.description = describe_effects(effects)
	ItemDatabase.register_item(item)

## "Haggle II, Luck I · 4:00", or a note for vinegar.
static func describe_effects(effects: Array) -> String:
	if effects.is_empty():
		return "Spoiled. No effect"
	var parts := PackedStringArray()
	for e in effects:
		parts.append("%s %s" % [Brewing.EFFECTS[StringName(e.effect)].name, LEVEL_NUMERALS[int(e.level)]])
	var seconds := int(effects[0].duration)
	return "%s · %d:%02d" % [", ".join(parts), seconds / 60, seconds % 60]

# --- Saving -------------------------------------------------------------------

func save_state() -> Dictionary:
	var packed_extras: Array = []
	for id in extras:
		packed_extras.append(String(id))
	return {
		"yeast": String(yeast_id), "fruit": String(fruit_id),
		"extras": packed_extras, "state": int(state),
		"ferment_total": ferment_total, "ferment_left": ferment_left,
		"result": _json_safe(result), "bottle": String(bottle_id), "bottles_left": bottles_left,
		"brews": brews,
	}

func load_state(data: Variant) -> void:
	_clear_slots()
	if typeof(data) != TYPE_DICTIONARY:
		return
	var saved_brews: Variant = data.get("brews", {})
	if typeof(saved_brews) == TYPE_DICTIONARY:
		for id in saved_brews:
			if typeof(saved_brews[id]) == TYPE_DICTIONARY:
				brews[String(id)] = saved_brews[id]
				_make_bottle_item(StringName(id), saved_brews[id])
	yeast_id = _known(data.get("yeast", ""))
	fruit_id = _known(data.get("fruit", ""))
	var saved_extras: Variant = data.get("extras", [])
	if typeof(saved_extras) == TYPE_ARRAY:
		for i in mini(saved_extras.size(), extras.size()):
			extras[i] = _known(saved_extras[i])
	bottle_id = StringName(data.get("bottle", ""))
	var resolved: Variant = data.get("result", {})
	if int(data.get("state", 0)) != State.FILLING and typeof(resolved) == TYPE_DICTIONARY \
			and ItemDatabase.get_item(bottle_id) != null:
		state = int(data.get("state", 0)) as State
		result = resolved
		ferment_total = float(data.get("ferment_total", 0.0))
		ferment_left = clampf(float(data.get("ferment_left", 0.0)), 0.0, ferment_total)
		bottles_left = maxi(0, int(data.get("bottles_left", 0)))
	barrel_changed.emit()

func reset() -> void:
	_clear_slots()
	barrel_changed.emit()

func _known(raw: Variant) -> StringName:
	var id := StringName(str(raw))
	return id if Brewing.is_ingredient(id) else &""

## StringNames survive JSON as plain strings anyway; this just keeps the saved
## shape predictable.
func _json_safe(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value)) if value != null else {}
