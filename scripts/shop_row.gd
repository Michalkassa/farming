class_name ShopRow
extends PanelContainer

signal buy_pressed(item_id: StringName)

@export var price_format: String = "€%d"
@export var buy_text: String = "Buy"
@export var full_text: String = "Full"
@export var owned_text: String = "Owned"
@export var tool_area_format: String = "  %d×%d"
@export var animal_count_format: String = "  %d/%d"

@onready var _icon: TextureRect = %RowIcon
@onready var _name_label: Label = %RowName
@onready var _price_label: Label = %RowPrice
@onready var _buy_button: Button = %RowBuyButton

var item: ItemData : set = _set_item

func _set_item(value: ItemData) -> void:
	item = value
	if is_node_ready():
		refresh()

func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_pressed)
	refresh()

func _on_buy_pressed() -> void:
	if item:
		buy_pressed.emit(item.id)

func refresh() -> void:
	if item == null:
		return
	_icon.texture = item.icon
	var label := item.display_name
	if item.is_animal():
		label += animal_count_format % [GameState.animal_count(item.animal_kind),
			GameState.animal_limit(item.animal_kind)]
	if item.is_tool():
		label += tool_area_format % [item.tool_area, item.tool_area]
	_name_label.text = label
	_price_label.text = price_format % item.buy_price
	if item.is_tool():
		var owned: bool = GameState.tool_area_owned(item.tool_kind) >= item.tool_area
		_buy_button.text = owned_text if owned else buy_text
		_buy_button.disabled = owned
		return
	var full: bool = item.is_animal() and not GameState.can_buy_animal(item.animal_kind)
	_buy_button.text = full_text if full else buy_text
	_buy_button.disabled = full
