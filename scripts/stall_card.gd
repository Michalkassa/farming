class_name StallCard
extends PanelContainer
## One crate of goods on the stall counter. In buy mode it shows the price;
## in sell mode it shows how many you carry and offers to sell one or all.

signal buy_pressed(card: StallCard)
signal sell_pressed(card: StallCard, count: int)

@export var price_format: String = "€%d"
@export var each_format: String = "€%d each"
@export var carry_format: String = "×%d"
@export var sell_all_format: String = "All €%d"
@export var sell_one_text: String = "1"
@export var owned_text: String = "Owned"
@export var full_text: String = "Full"
@export var animal_count_format: String = "%d/%d"
@export var tool_area_format: String = "%d×%d"
@export var affordable_variation: StringName = &"AccentButton"
@export var sell_variation: StringName = &"GoldButton"
## The tallest the icon may be; it's drawn at the largest whole-number
## scale of its art that fits, so pixels stay even.
@export var max_icon_height: int = 88

@onready var _icon: TextureRect = %CardIcon
@onready var _name_label: Label = %CardName
@onready var _info_label: Label = %CardInfo
@onready var _main_button: Button = %CardButton
@onready var _one_button: Button = %CardOneButton

var item: ItemData
var selling: bool = false

func setup(new_item: ItemData, sell_mode: bool) -> void:
	item = new_item
	selling = sell_mode
	if is_node_ready():
		refresh()

func _ready() -> void:
	_main_button.pressed.connect(_on_main_pressed)
	_one_button.pressed.connect(func(): sell_pressed.emit(self, 1))
	refresh()

func _on_main_pressed() -> void:
	if selling:
		sell_pressed.emit(self, GameState.count_owned(item.id))
	else:
		buy_pressed.emit(self)

func refresh() -> void:
	if item == null:
		return
	_icon.texture = item.icon
	# The tab already says "Seeds", so the crate just names the crop.
	_name_label.text = item.display_name.trim_suffix(" Seeds") if item.is_seed() else item.display_name
	_one_button.visible = selling
	if selling:
		var have := GameState.count_owned(item.id)
		_info_label.text = carry_format % have
		_info_label.visible = true
		_fit_icon()
		_main_button.text = sell_all_format % (have * item.sell_price)
		_main_button.theme_type_variation = sell_variation
		_main_button.disabled = have <= 0
		_one_button.disabled = have <= 0
		_one_button.tooltip_text = each_format % item.sell_price
		return

	_info_label.text = ""
	if item.is_animal():
		_info_label.text = animal_count_format % [GameState.animal_count(item.animal_kind),
			GameState.animal_limit(item.animal_kind)]
	elif item.is_tool():
		_info_label.text = tool_area_format % [item.tool_area, item.tool_area]
	_info_label.visible = _info_label.text != ""
	_fit_icon()
	var reason := GameState.buy_block_reason(item.id)
	match reason:
		&"owned":
			_main_button.text = owned_text
			_main_button.disabled = true
		&"pen_full":
			_main_button.text = full_text
			_main_button.disabled = true
		_:
			_main_button.text = price_format % item.buy_price
			_main_button.disabled = false
	# Still clickable when you can't afford it, so the farmer can tell you so;
	# the plain brown button says "not yet" at a glance.
	_main_button.theme_type_variation = affordable_variation if reason == &"" else &""

func _fit_icon() -> void:
	var art := item.icon.get_size() if item.icon else Vector2(16, 16)
	var scale := maxi(1, floori(max_icon_height / maxf(art.y, 1.0)))
	_icon.custom_minimum_size = Vector2(0, art.y * scale)

## A little hop when something is bought or sold, or a shake when it can't be.
func bump(ok: bool = true) -> void:
	pivot_offset = size * 0.5
	var tween := create_tween()
	if ok:
		tween.tween_property(self, "scale", Vector2.ONE * 1.08, 0.07)
		tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	else:
		var x := position.x
		for offset in [-6.0, 6.0, -4.0, 4.0, 0.0]:
			tween.tween_property(self, "position:x", x + offset, 0.04)
