extends Node

@export var items: Array[ItemData] = []

var _items: Dictionary = {}

func _ready() -> void:
	for item in items:
		register_item(item)

func register_item(item: ItemData) -> void:
	if item == null or item.id == &"":
		push_warning("ItemDatabase: tried to register an invalid item")
		return
	_items[item.id] = item

func add_item(id: StringName, display_name: String, icon: Texture2D,
		buy_price: int = 0, sell_price: int = 0, for_sale: bool = false,
		max_stack: int = 99) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	item.icon = icon
	item.buy_price = buy_price
	item.sell_price = sell_price
	item.for_sale = for_sale
	item.max_stack = max_stack
	register_item(item)
	return item

func get_item(id: StringName) -> ItemData:
	return _items.get(id)

func all_items() -> Array:
	return _items.values()

## Cheapest first, so the shop reads as the progression ladder.
func shop_items() -> Array:
	var result: Array = []
	for item in _items.values():
		if item.for_sale and item.buy_price > 0:
			result.append(item)
	result.sort_custom(func(a, b): return a.buy_price < b.buy_price)
	return result

func animal_items() -> Array:
	var result: Array = []
	for item in _items.values():
		if item.is_animal():
			result.append(item)
	return result

func seed_items() -> Array:
	var result: Array = []
	for item in _items.values():
		if item.is_seed():
			result.append(item)
	return result
