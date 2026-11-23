extends RefCounted
## Very short, friendly one-liners saying what an item is for, used by the hover
## info blocks in the shop and the inventory tooltips. Keep them tiny.

const Brewing := preload("res://scripts/brewing.gd")

const PLURALS := {
	&"wheat": "wheat", &"carrot": "carrots", &"corn": "corn", &"tomato": "tomatoes",
	&"strawberry": "strawberries", &"watermelon": "watermelons",
}

## Hand-written lines that beat the generic ones.
const BLURBS := {
	&"chicken": "Lays eggs",
	&"pig": "Gives bacon",
	&"cow": "Gives milk",
	&"dog": "Crops grow faster",
	&"shovel": "Digs up orchard plants",
	&"egg": "Wine helper: clears weak flavours",
	&"milk": "Wine helper: longer buffs",
	&"bacon": "Wine helper: boosts every buff",
	&"wheat": "Wine helper: feeds the yeast",
	&"corn": "Wine helper: lots of sugar",
	&"carrot": "Wine helper: growth & rain",
	&"wild_yeast": "Makes wine. Unpredictable!",
	&"golden_apple": "A rare, magical fruit",
}

static func blurb(item: ItemData) -> String:
	if item == null:
		return ""
	if BLURBS.has(item.id):
		return BLURBS[item.id]
	if String(item.id).begins_with("brew_"):
		return item.description          # a bottle's buffs, e.g. "Haggle II · 4:15"
	if item.is_seed():
		var crop: ItemData = ItemDatabase.get_item(item.seed_for)
		return "Plant to grow %s" % PLURALS.get(item.seed_for, crop.display_name.to_lower() if crop else "crops")
	if Brewing.YEASTS.has(item.id):
		return "Turns fruit into wine"
	if item.is_tool():
		var size := " (%d×%d)" % [item.tool_area, item.tool_area] if item.tool_area > 1 else ""
		match item.tool_kind:
			&"hoe": return "Tills the soil" + size
			&"watering_can": return "Waters crops" + size
	if Brewing.FRUITS.has(item.id):
		return "Fruit for wine"
	return item.description
