class_name ItemGrant
extends Resource

@export var item_id: StringName = &""
@export var count: int = 1
@export_enum("inventory", "hotbar", "sell") var container: String = "inventory"
