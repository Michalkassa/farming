class_name ItemStack
extends RefCounted

var item_id: StringName
var count: int = 0

func _init(_id: StringName = &"", _count: int = 0) -> void:
	item_id = _id
	count = _count
