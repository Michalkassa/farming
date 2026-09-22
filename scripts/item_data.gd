class_name ItemData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D
@export var buy_price: int = 0
@export var sell_price: int = 0
@export var max_stack: int = 99
@export var for_sale: bool = false
@export_multiline var description: String = ""

@export_group("Farming")
@export var seed_for: StringName = &""
@export var grow_time: float = 20.0
@export var harvest_amount: int = 1
@export var tool_kind: StringName = &""
## Plots on a side that a tool affects per click (1 = just the clicked plot).
@export var tool_area: int = 1

@export_group("Animals")
@export var animal_kind: StringName = &""
@export var product_id: StringName = &""
@export var produce_time: float = 60.0

func is_animal() -> bool:
	return animal_kind != &""

func is_seed() -> bool:
	return seed_for != &""

func is_tool() -> bool:
	return tool_kind != &""
