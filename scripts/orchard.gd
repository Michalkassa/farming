extends Node
## The orchard's plots and the fruit plants growing in them (autoload `Orchard`).
##
## The orchard has three rows of plots: trees at the back, vines on trellises in
## the middle, bushes at the front. Each row only takes its own kind of plant.
## A sapling is bought straight into an empty plot and stays there for good: it
## grows up once, then keeps fruiting every so often. Click a fruiting plant to
## pick everything on it. Plants keep growing while the orchard screen is shut,
## and the plots travel with the save (GameState calls save_state/load_state).

signal plot_changed(index: int)

const ROWS := [&"tree", &"vine", &"bush"]
const PLOTS_PER_ROW := 5

## grow = seconds from sapling to first fruit, every = seconds between harvests,
## yield = fruit per harvest. Fruit ids match the fruit items and Brewing.FRUITS.
const PLANTS := {
	&"apple":        {"kind": &"tree", "sapling": 250,   "grow": 90.0,  "every": 120.0, "yield": 4},
	&"pear":         {"kind": &"tree", "sapling": 280,   "grow": 90.0,  "every": 120.0, "yield": 4},
	&"orange":       {"kind": &"tree", "sapling": 400,   "grow": 90.0,  "every": 120.0, "yield": 4},
	&"plum":         {"kind": &"tree", "sapling": 400,   "grow": 90.0,  "every": 120.0, "yield": 4},
	&"lemon":        {"kind": &"tree", "sapling": 550,   "grow": 90.0,  "every": 120.0, "yield": 4},
	&"cherry":       {"kind": &"tree", "sapling": 700,   "grow": 90.0,  "every": 120.0, "yield": 4},
	&"fig":          {"kind": &"tree", "sapling": 1300,  "grow": 90.0,  "every": 120.0, "yield": 4},
	&"peach":        {"kind": &"tree", "sapling": 1500,  "grow": 90.0,  "every": 120.0, "yield": 4},
	&"mango":        {"kind": &"tree", "sapling": 1600,  "grow": 120.0, "every": 150.0, "yield": 4},
	&"pomegranate":  {"kind": &"tree", "sapling": 3500,  "grow": 120.0, "every": 150.0, "yield": 4},
	&"golden_apple": {"kind": &"tree", "sapling": 30000, "grow": 300.0, "every": 600.0, "yield": 1},
	&"grape":        {"kind": &"vine", "sapling": 300,   "grow": 60.0,  "every": 90.0,  "yield": 3},
	&"passionfruit": {"kind": &"vine", "sapling": 900,   "grow": 60.0,  "every": 90.0,  "yield": 3},
	&"dragonfruit":  {"kind": &"vine", "sapling": 4000,  "grow": 80.0,  "every": 120.0, "yield": 2},
	&"blueberry":    {"kind": &"bush", "sapling": 250,   "grow": 40.0,  "every": 60.0,  "yield": 3},
	&"raspberry":    {"kind": &"bush", "sapling": 400,   "grow": 40.0,  "every": 60.0,  "yield": 3},
	&"elderberry":   {"kind": &"bush", "sapling": 450,   "grow": 40.0,  "every": 60.0,  "yield": 3},
	&"blackberry":   {"kind": &"bush", "sapling": 900,   "grow": 50.0,  "every": 75.0,  "yield": 3},
	&"pineapple":    {"kind": &"bush", "sapling": 1800,  "grow": 60.0,  "every": 90.0,  "yield": 2},
}

## One entry per plot: {plant: StringName, grown: 0..1, timer: seconds to next
## fruit, stock: fruit waiting to be picked}.
var plots: Array = []

func _ready() -> void:
	_clear()

func _process(delta: float) -> void:
	var speed: float = GameState.growth_multiplier() if is_instance_valid(GameState) else 1.0
	for i in plots.size():
		var plot: Dictionary = plots[i]
		if plot.plant == &"" or plot.stock > 0:
			continue
		var data: Dictionary = PLANTS[plot.plant]
		if plot.grown < 1.0:
			var before := stage(i)
			plot.grown = minf(1.0, plot.grown + delta * speed / data.grow)
			if plot.grown >= 1.0:
				plot.stock = data.yield
				plot.timer = data.every
			if stage(i) != before:
				plot_changed.emit(i)
		else:
			plot.timer -= delta * speed
			if plot.timer <= 0.0:
				plot.stock = data.yield
				plot_changed.emit(i)

func row_of(index: int) -> StringName:
	return ROWS[index / PLOTS_PER_ROW]

func plants_for(kind: StringName) -> Array:
	var result: Array = []
	for id in PLANTS:
		if PLANTS[id].kind == kind:
			result.append(id)
	return result

## 0-2 while growing up, 3 when fruit is waiting, -1 for an empty plot.
func stage(index: int) -> int:
	var plot: Dictionary = plots[index]
	if plot.plant == &"":
		return -1
	if plot.stock > 0:
		return 3
	if plot.grown >= 1.0:
		return 2
	return mini(2, int(plot.grown * 3.0))

## Seconds until the plant next has fruit (0 when it has some now).
func time_to_fruit(index: int) -> float:
	var plot: Dictionary = plots[index]
	if plot.plant == &"" or plot.stock > 0:
		return 0.0
	var data: Dictionary = PLANTS[plot.plant]
	if plot.grown < 1.0:
		return (1.0 - plot.grown) * data.grow
	return maxf(0.0, plot.timer)

## Buys a sapling of `plant` into an empty plot of the right row.
func plant(index: int, plant_id: StringName) -> bool:
	if index < 0 or index >= plots.size() or plots[index].plant != &"":
		return false
	if not PLANTS.has(plant_id) or PLANTS[plant_id].kind != row_of(index):
		return false
	var price: int = PLANTS[plant_id].sapling
	if not GameState.can_afford(price):
		return false
	GameState.add_money(-price)
	plots[index] = {"plant": plant_id, "grown": 0.0, "timer": 0.0, "stock": 0}
	plot_changed.emit(index)
	return true

## Picks as much fruit as fits in the bags. Returns how many were picked.
func harvest(index: int) -> int:
	var plot: Dictionary = plots[index]
	if plot.plant == &"" or plot.stock <= 0:
		return 0
	var leftover: int = GameState.collect_item(plot.plant, plot.stock)
	var picked: int = plot.stock - leftover
	plot.stock = leftover
	if leftover <= 0:
		plot.timer = PLANTS[plot.plant].every
	if picked > 0:
		plot_changed.emit(index)
	return picked

func _clear() -> void:
	plots.clear()
	for i in ROWS.size() * PLOTS_PER_ROW:
		plots.append({"plant": &"", "grown": 0.0, "timer": 0.0, "stock": 0})

# --- Saving -------------------------------------------------------------------

func save_state() -> Array:
	var packed: Array = []
	for plot in plots:
		packed.append({"plant": String(plot.plant), "grown": plot.grown, "timer": plot.timer, "stock": plot.stock})
	return packed

func load_state(data: Variant) -> void:
	_clear()
	if typeof(data) != TYPE_ARRAY:
		return
	for i in mini(data.size(), plots.size()):
		var entry: Variant = data[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := StringName(str(entry.get("plant", "")))
		if not PLANTS.has(id) or PLANTS[id].kind != row_of(i):
			continue
		plots[i] = {
			"plant": id,
			"grown": clampf(float(entry.get("grown", 0.0)), 0.0, 1.0),
			"timer": maxf(0.0, float(entry.get("timer", 0.0))),
			"stock": maxi(0, int(entry.get("stock", 0))),
		}
	for i in plots.size():
		plot_changed.emit(i)

func reset() -> void:
	_clear()
	for i in plots.size():
		plot_changed.emit(i)
