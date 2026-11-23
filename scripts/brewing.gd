class_name Brewing
extends RefCounted
## Winery brewing: ingredient tables and the resolver that turns a pot into a brew.
## A pot is a Dictionary {ingredient_id: amount} that holds exactly one yeast type.
## Every unit adds effect points, and points for the same effect add up.
## Pure data and logic with no scene or GameState dependency.
## The same tables in readable form are in docs/winery.md.

## The barrel: a yeast slot, a fruit slot and 5 extra slots, one item per slot
## (nothing stacks), so a barrel holds at most 7 units.
const EXTRA_SLOTS := 5
const MAX_EFFECTS := 3            # a bottle keeps its 3 strongest effects
const LEVEL_POINTS := [2, 5, 9]   # points needed for Lv I / II / III
const YEAST_BASE_POINTS := 2      # first scoop; each extra scoop adds +1
const EXTRA_SCOOP_FERMENT := 0.2  # each extra scoop ferments 20% faster
const SUGAR_PER_SCOOP := 2        # less sugar than this per scoop -> vinegar
const BASE_DURATION := 60.0
const SECONDS_PER_SUGAR := 15.0
const MAX_DURATION := 900.0
const BASE_VINTAGE := 0.05
const STAR_VINTAGE := 0.05        # per minigame star (0-3)
const STAR_DURATION := 0.10       # per minigame star (0-3)
const UNITS_PER_BOTTLE := 3
const VINEGAR_VALUE := 5
## Bottles sell for a little more than their ingredients. The buffs are the real reward.
const LEVEL_VALUE := 0.1          # +10% per buff level in the bottle
const VINTAGE_VALUE := 1.5
const STRENGTH_NAMES := ["", "Light", "Fine", "Grand"]

## Buff values per level (index 0 = no buff).
const EFFECTS := {
	&"verdant":    {"name": "Growth",  "adjective": "Verdant",      "levels": [0.0, 0.15, 0.30, 0.50]},  # crops grow +%
	&"rainkeeper": {"name": "Rain",    "adjective": "Rainkeeper's", "levels": [2.0, 2.5, 3.0, 4.0]},     # watered speed
	&"bounty":     {"name": "Bounty",  "adjective": "Bountiful",    "levels": [0.0, 0.20, 0.40, 0.70]},  # +1 crop chance
	&"shepherd":   {"name": "Herd",    "adjective": "Shepherd's",   "levels": [0.0, 0.15, 0.30, 0.50]},  # animals faster +%
	&"merchant":   {"name": "Haggle",  "adjective": "Merchant's",   "levels": [0.0, 0.10, 0.20, 0.35]},  # sell price +%
	&"fortune":    {"name": "Luck",    "adjective": "Lucky",        "levels": [0.0, 0.08, 0.15, 0.25]},  # coin drop chance
	&"reach":      {"name": "Reach",   "adjective": "Far-Reaching", "levels": [0, 1, 1, 2]},             # tool area +n
}

## base = the effect every brew with this yeast gets, which is why plain wine
## always does something. &"" = Wild Yeast picks a random effect each brew.
const YEASTS := {
	&"bakers_yeast":    {"name": "Baker's Yeast",    "style": "Rustic Wine",    "base": &"verdant",  "ferment": 60.0,  "duration_mult": 1.0, "price": 20},
	&"wine_yeast":      {"name": "Wine Yeast",       "style": "Wine",           "base": &"merchant", "ferment": 120.0, "duration_mult": 1.0, "price": 150},
	&"ale_yeast":       {"name": "Kveik Ale Yeast",  "style": "Farmhouse Ale",  "base": &"shepherd", "ferment": 45.0,  "duration_mult": 0.75, "price": 300},
	&"mead_yeast":      {"name": "Mead Yeast",       "style": "Mead",           "base": &"bounty",   "ferment": 150.0, "duration_mult": 1.0, "price": 600},
	&"champagne_yeast": {"name": "Champagne Yeast",  "style": "Sparkling Wine", "base": &"fortune",  "ferment": 180.0, "duration_mult": 1.5, "price": 1500},
	&"wild_yeast":      {"name": "Wild Yeast",       "style": "Country Wine",   "base": &"",         "ferment": 90.0,  "duration_mult": 1.0, "price": 5,
		"vinegar_chance": 0.10, "vintage": 0.10},
}

## effects = points per unit. plant = where it grows (orchard screen unless field).
const FRUITS := {
	&"grape":        {"name": "Grape",        "plant": "vine",  "effects": {},                              "sugar": 4, "value": 50},
	&"apple":        {"name": "Apple",        "plant": "tree",  "effects": {&"verdant": 1},                 "sugar": 3, "value": 40},
	&"pear":         {"name": "Pear",         "plant": "tree",  "effects": {&"shepherd": 1},                "sugar": 3, "value": 45},
	&"tomato":       {"name": "Tomato",       "plant": "field", "effects": {&"verdant": 1},                 "sugar": 1, "value": 75},
	&"lemon":        {"name": "Lemon",        "plant": "tree",  "effects": {&"verdant": 2},                 "sugar": 1, "value": 90},
	&"blueberry":    {"name": "Blueberry",    "plant": "bush",  "effects": {&"rainkeeper": 1},              "sugar": 2, "value": 60},
	&"elderberry":   {"name": "Elderberry",   "plant": "bush",  "effects": {&"rainkeeper": 1, &"shepherd": 1}, "sugar": 1, "value": 110},
	&"watermelon":   {"name": "Watermelon",   "plant": "field", "effects": {&"rainkeeper": 3},              "sugar": 3, "value": 750},
	&"plum":         {"name": "Plum",         "plant": "tree",  "effects": {&"bounty": 1},                  "sugar": 3, "value": 70},
	&"fig":          {"name": "Fig",          "plant": "tree",  "effects": {&"bounty": 2},                  "sugar": 3, "value": 230},
	&"pomegranate":  {"name": "Pomegranate",  "plant": "tree",  "effects": {&"bounty": 2, &"fortune": 1},   "sugar": 2, "value": 600},
	&"raspberry":    {"name": "Raspberry",    "plant": "bush",  "effects": {&"shepherd": 1, &"verdant": 1}, "sugar": 2, "value": 100},
	&"blackberry":   {"name": "Blackberry",   "plant": "bush",  "effects": {&"shepherd": 2},                "sugar": 2, "value": 220},
	&"strawberry":   {"name": "Strawberry",   "plant": "field", "effects": {&"merchant": 1, &"bounty": 1},  "sugar": 2, "value": 240},
	&"cherry":       {"name": "Cherry",       "plant": "tree",  "effects": {&"merchant": 1, &"fortune": 1}, "sugar": 2, "value": 120},
	&"peach":        {"name": "Peach",        "plant": "tree",  "effects": {&"merchant": 2},                "sugar": 3, "value": 260},
	&"orange":       {"name": "Orange",       "plant": "tree",  "effects": {&"fortune": 1},                 "sugar": 2, "value": 70},
	&"mango":        {"name": "Mango",        "plant": "tree",  "effects": {&"fortune": 2},                 "sugar": 3, "value": 280},
	&"passionfruit": {"name": "Passionfruit", "plant": "vine",  "effects": {&"reach": 1, &"fortune": 1},    "sugar": 2, "value": 200},
	&"pineapple":    {"name": "Pineapple",    "plant": "bush",  "effects": {&"reach": 2},                   "sugar": 3, "value": 450},
	&"dragonfruit":  {"name": "Dragonfruit",  "plant": "vine",  "effects": {&"reach": 3},                   "sugar": 2, "value": 800},
	&"golden_apple": {"name": "Golden Apple", "plant": "tree",  "effects": {},                              "sugar": 4, "value": 3000,
		"special": &"amplify"},
}

## Additions are the farm's other produce. value = the item's sell price.
## "special" covers effects that aren't plain points.
const ADDITIONS := {
	&"wheat":  {"name": "Wheat",  "effects": {},                                 "sugar": 2, "value": 3,   "special": &"feed_base"},
	&"carrot": {"name": "Carrot", "effects": {&"verdant": 1, &"rainkeeper": 1}, "sugar": 1, "value": 12},
	&"corn":   {"name": "Corn",   "effects": {&"bounty": 1},                    "sugar": 3, "value": 36},
	&"egg":    {"name": "Egg",    "effects": {},                                 "sugar": 0, "value": 20,  "special": &"clarify"},
	&"milk":   {"name": "Milk",   "effects": {&"shepherd": 1},                  "sugar": 1, "value": 500, "special": &"longer"},
	&"bacon":  {"name": "Bacon",  "effects": {},                                 "sugar": 0, "value": 150, "special": &"amplify"},
}

static func ingredient(id: StringName) -> Dictionary:
	if YEASTS.has(id):
		return YEASTS[id]
	return FRUITS.get(id, ADDITIONS.get(id, {}))

static func is_fruit(id: StringName) -> bool:
	return FRUITS.has(id)

static func is_ingredient(id: StringName) -> bool:
	return not ingredient(id).is_empty()

## One line per thing this ingredient does, for tooltips.
static func describe(id: StringName) -> PackedStringArray:
	var lines := PackedStringArray()
	if YEASTS.has(id):
		var y: Dictionary = YEASTS[id]
		var base: String = EFFECTS[y.base].name if y.base != &"" else "random"
		lines.append("Yeast: %s, base %s" % [y.style, base])
		lines.append("Ferments in %ds" % int(y.ferment))
		return lines
	var data := ingredient(id)
	if data.is_empty():
		return lines
	for effect in data.effects:
		lines.append("+%d %s" % [data.effects[effect], EFFECTS[effect].name])
	if int(data.sugar) > 0:
		lines.append("Sugar %d" % data.sugar)
	match data.get("special", &""):
		&"feed_base": lines.append("Boosts the yeast's effect")
		&"amplify": lines.append("+1 to every effect")
		&"longer": lines.append("+20% duration")
		&"vintage": lines.append("+10% Vintage chance")
		&"spicy": lines.append("Strongest effect +1 level, half duration")
		&"clarify": lines.append("Drops the weakest effect")
	return lines

## Extra scoops ferment faster, down to a quarter of the yeast's time.
static func ferment_time(yeast_id: StringName, scoops: int) -> float:
	var y: Dictionary = YEASTS[yeast_id]
	return y.ferment * maxf(0.25, 1.0 - EXTRA_SCOOP_FERMENT * (scoops - 1))

static func level_for_points(points: int) -> int:
	var level := 0
	for i in LEVEL_POINTS.size():
		if points >= LEVEL_POINTS[i]:
			level = i + 1
	return level

## Why this pot can't ferment, or "" when it's ready.
static func validate(pot: Dictionary) -> String:
	var yeasts := 0
	var fruits := 0
	var units := 0
	for id in pot:
		var amount: int = pot[id]
		if amount <= 0:
			continue
		units += amount
		if ingredient(id).is_empty():
			return "%s can't go in the barrel" % id
		if YEASTS.has(id):
			yeasts += 1
		elif FRUITS.has(id):
			fruits += 1
	if yeasts == 0:
		return "Add a yeast"
	if yeasts > 1:
		return "Only one kind of yeast per pot"
	if fruits == 0:
		return "Add some fruit"
	if units > EXTRA_SLOTS + 2:
		return "The barrel is full"
	return ""

## Turns a pot into a brew.
## stars: 0-3 from the stir / ferment / bottling minigames (0 = waited it out).
## rng: null = preview. Nothing random happens, so no Vintage, no Wild Yeast
## spoilage, and Wild Yeast's base effect stays unknown.
## Returns { ok, error, kind (&"brew"/&"vinegar"), name, style,
##   effects: [{effect, level, points, duration}], vintage, ferment, bottles,
##   value (per bottle), sugar, trace (effects too weak to keep or crowded out) }
static func brew(pot: Dictionary, stars: int = 0, rng: RandomNumberGenerator = null) -> Dictionary:
	var error := validate(pot)
	if error != "":
		return {"ok": false, "error": error}

	var yeast_id: StringName = &""
	for id in pot:
		if YEASTS.has(id) and int(pot[id]) > 0:
			yeast_id = id
	var y: Dictionary = YEASTS[yeast_id]
	var scoops: int = pot[yeast_id]
	stars = clampi(stars, 0, 3)

	var result := {
		"ok": true, "error": "", "kind": &"brew", "name": "", "style": y.style,
		"effects": [], "vintage": false, "bottles": 1, "value": 0, "sugar": 0, "trace": [],
		"ferment": ferment_time(yeast_id, scoops),
	}

	# The yeast's base effect goes in first, so it wins ties.
	var base: StringName = y.base
	if base == &"" and rng != null:
		base = EFFECTS.keys()[rng.randi_range(0, EFFECTS.size() - 1)]
	var points := {}
	if base != &"":
		points[base] = YEAST_BASE_POINTS + (scoops - 1)

	var sugar := 0
	var units := 0
	var value := 0
	var specials := {}
	for id in pot:
		var amount: int = pot[id]
		if amount <= 0:
			continue
		units += amount
		if YEASTS.has(id):
			continue
		var data := ingredient(id)
		for effect in data.effects:
			points[effect] = int(points.get(effect, 0)) + int(data.effects[effect]) * amount
		sugar += int(data.sugar) * amount
		value += int(data.get("value", int(data.get("price", 0)) / 2)) * amount
		var special: StringName = data.get("special", &"")
		if special != &"":
			specials[special] = int(specials.get(special, 0)) + amount
	result.sugar = sugar
	result.bottles = maxi(1, units / UNITS_PER_BOTTLE)

	# Honey feeds the yeast. It boosts the base effect, double with Mead Yeast.
	if base != &"" and specials.has(&"feed_base"):
		var per := 2 if yeast_id == &"mead_yeast" else 1
		points[base] += per * int(specials[&"feed_base"])

	# Amplifiers (Golden Apple, Oak Chips) add +1 per unit to every effect present.
	var amp := int(specials.get(&"amplify", 0))
	if amp > 0:
		for effect in points:
			if points[effect] > 0:
				points[effect] += amp

	# Spoiled: too little sugar for the yeast, or Wild Yeast going bad.
	var spoiled := sugar < SUGAR_PER_SCOOP * scoops
	if rng != null and rng.randf() < float(y.get("vinegar_chance", 0.0)):
		spoiled = true
	if spoiled:
		result.kind = &"vinegar"
		result.name = "Vinegar"
		result.value = VINEGAR_VALUE
		return result

	# Strongest first. sort_custom isn't stable, so break ties by insertion order.
	var order: Array = points.keys()
	var ranked: Array = []
	for i in order.size():
		ranked.append([order[i], points[order[i]], i])
	ranked.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[2] < b[2]))
	var active: Array = []
	for entry in ranked:
		if level_for_points(entry[1]) > 0:
			active.append(entry)
		else:
			result.trace.append(entry[0])
	# Egg White clarifies: each unit drops the weakest effect, but always keeps one.
	for i in int(specials.get(&"clarify", 0)):
		if active.size() > 1:
			result.trace.append(active.pop_back()[0])
	while active.size() > MAX_EFFECTS:
		result.trace.append(active.pop_back()[0])

	var vintage := false
	if rng != null:
		var chance := BASE_VINTAGE + float(y.get("vintage", 0.0)) \
			+ 0.10 * int(specials.get(&"vintage", 0)) + STAR_VINTAGE * stars
		vintage = rng.randf() < chance
	result.vintage = vintage

	var duration := (BASE_DURATION + sugar * SECONDS_PER_SUGAR) * float(y.duration_mult)
	duration *= 1.0 + 0.2 * int(specials.get(&"longer", 0))
	duration *= 1.0 + STAR_DURATION * stars
	if specials.has(&"spicy"):
		duration *= 0.5
	duration = minf(duration, MAX_DURATION)

	var level_sum := 0
	for i in active.size():
		var level := level_for_points(active[i][1])
		if i == 0 and specials.has(&"spicy"):
			level += 1
		if vintage:
			level += 1
		level = mini(level, 3)
		level_sum += level
		result.effects.append({"effect": active[i][0], "level": level, "points": active[i][1], "duration": duration})

	var bottle_value: float = float(value) / result.bottles * (1.0 + LEVEL_VALUE * level_sum)
	if vintage:
		bottle_value *= VINTAGE_VALUE
	result.value = maxi(1, int(bottle_value))
	result.name = _name(result, pot, y)
	return result

static func _name(result: Dictionary, pot: Dictionary, y: Dictionary) -> String:
	var fruit := _main_fruit(pot)
	var prefix := "Vintage " if result.vintage else ""
	if result.effects.is_empty():
		return "%sMystery %s %s" % [prefix, fruit, y.style]  # Wild Yeast preview
	var top: Dictionary = result.effects[0]
	return "%s%s %s %s %s" % [prefix, STRENGTH_NAMES[top.level],
		EFFECTS[top.effect].adjective, fruit, y.style]

## The fruit with the most units. Ties go to whichever was added first.
static func _main_fruit(pot: Dictionary) -> String:
	var best: StringName = &""
	for id in pot:
		if FRUITS.has(id) and int(pot[id]) > 0 and (best == &"" or int(pot[id]) > int(pot[best])):
			best = id
	return FRUITS[best].name
