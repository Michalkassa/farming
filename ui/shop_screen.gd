extends CanvasLayer
## The shop stall, seen from the customer's side of the counter, its back
## shelves packed with goods. It sells seeds, animals, tools and yeast, and
## buys your produce back.

const Brewing := preload("res://scripts/brewing.gd")

@export var card_scene: PackedScene

@export_group("Layout")
@export var design_size: Vector2 = Vector2(1152, 648)
## Where the grass starts behind the stall, in design pixels.
@export var horizon_y: float = 470.0
@export var fade_seconds: float = 0.18

@export_group("Text")
@export var money_format: String = "€%d"
@export var sell_all_format: String = "Sell produce €%d"
@export var active_tab_variation: StringName = &"GoldButton"

@onready var _screen: Control = $Screen
@onready var _grass: Control = $Screen/Grass
@onready var _stage: Control = $Screen/Stage
@onready var _tabs: HBoxContainer = %Tabs
@onready var _sell_all: Button = %SellAll
@onready var _goods: HBoxContainer = %Goods
@onready var _goods_scroll: ScrollContainer = %GoodsScroll
@onready var _empty_hint: Label = %EmptyHint
@onready var _money_label: Label = %MoneyLabel
@onready var _back_button: Button = %BackButton
@onready var _shelf_rows: Array[Node] = [%ShelfGoods1, %ShelfGoods2, %ShelfGoods3]

var _tab: String = "seeds"
var _fade: Tween

func _ready() -> void:
	visible = false
	for tab in _tabs.get_children():
		if tab is Button and tab.toggle_mode:
			tab.pressed.connect(_on_tab.bind(tab.name.to_lower()))
	_sell_all.pressed.connect(_on_sell_all)
	_back_button.pressed.connect(close)
	GameState.money_changed.connect(_on_money_changed)
	GameState.inventory_changed.connect(_on_goods_changed)
	GameState.hotbar_changed.connect(_on_goods_changed)
	GameState.animals_changed.connect(_on_goods_changed)
	GameState.tools_changed.connect(_on_goods_changed)
	get_viewport().size_changed.connect(_fit)
	_stock_shelves()
	_on_money_changed(GameState.money)

func open() -> void:
	if visible:
		return
	visible = true
	_fit()
	_on_money_changed(GameState.money)
	_show_tab(_tab)
	_fade_to(1.0)

func close() -> void:
	if not visible:
		return
	_fade_to(0.0)
	_fade.tween_callback(func(): visible = false)

func _fade_to(alpha: float) -> void:
	if _fade:
		_fade.kill()
	if alpha > 0.0:
		_screen.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(_screen, "modulate:a", alpha, fade_seconds)

## Scales the fixed-size stage to fit the window and lines up the grass behind it.
func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	var factor := minf(screen.x / design_size.x, screen.y / design_size.y)
	_stage.scale = Vector2(factor, factor)
	_stage.position = ((screen - design_size * factor) * 0.5).floor()
	_grass.position = Vector2(0, _stage.position.y + horizon_y * factor)
	_grass.size = Vector2(screen.x, maxf(0.0, screen.y - _grass.position.y))

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	# Keys belong to the stall while it's open, so the farm behind stays put.
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()

func _on_tab(tab: String) -> void:
	_show_tab(tab)

func _show_tab(tab: String) -> void:
	_tab = tab
	for button in _tabs.get_children():
		if button is Button and button.toggle_mode:
			var active: bool = button.name.to_lower() == tab
			button.set_pressed_no_signal(active)
			button.theme_type_variation = active_tab_variation if active else &""
	_populate()

func _items_for_tab() -> Array:
	if _tab == "sell":
		return GameState.sellable_items()
	var result: Array = []
	for item in ItemDatabase.shop_items():
		var keep: bool
		match _tab:
			"animals": keep = item.is_animal()
			"tools": keep = item.is_tool()
			"wine": keep = Brewing.YEASTS.has(item.id)
			_: keep = item.is_seed()
		if keep:
			result.append(item)
	return result

func _populate() -> void:
	for child in _goods.get_children():
		_goods.remove_child(child)
		child.queue_free()
	var selling := _tab == "sell"
	var items := _items_for_tab()
	for item in items:
		var card: StallCard = card_scene.instantiate()
		card.setup(item, selling)
		card.buy_pressed.connect(_on_buy)
		card.sell_pressed.connect(_on_sell)
		_goods.add_child(card)
	_empty_hint.visible = selling and items.is_empty()
	_goods_scroll.visible = not _empty_hint.visible
	_refresh_sell_all()

func _refresh_cards() -> void:
	for card in _goods.get_children():
		if card is StallCard:
			card.refresh()
	_refresh_sell_all()

func _produce_value() -> int:
	var total := 0
	for item in GameState.sellable_items():
		if not item.for_sale:  # keep seeds, yeasts and additions you bought
			total += item.sell_price * GameState.count_owned(item.id)
	return total

func _refresh_sell_all() -> void:
	var value := _produce_value()
	_sell_all.visible = _tab == "sell"
	_sell_all.disabled = value <= 0
	_sell_all.text = sell_all_format % value

func _on_buy(card: StallCard) -> void:
	var reason := GameState.buy_block_reason(card.item.id)
	if reason == &"" and GameState.buy(card.item.id):
		_coin_popup(card, -card.item.buy_price)
		card.bump(true)
		_refresh_cards()
		return
	card.bump(false)

func _on_sell(card: StallCard, count: int) -> void:
	var earned := GameState.sell_item(card.item.id, count)
	if earned <= 0:
		return
	_coin_popup(card, earned)
	if GameState.count_owned(card.item.id) <= 0:
		_populate()
	else:
		card.bump(true)
		_refresh_cards()

func _on_sell_all() -> void:
	var earned := 0
	for item in GameState.sellable_items():
		if not item.for_sale:  # keep seeds, yeasts and additions you bought
			earned += GameState.sell_item(item.id, GameState.count_owned(item.id))
	if earned <= 0:
		return
	_coin_popup(_sell_all, earned)
	_populate()

## "+€12" / "-€4" floating up from where the money changed hands.
func _coin_popup(from: Control, amount: int) -> void:
	var label := Label.new()
	label.text = ("+" if amount > 0 else "-") + money_format % absi(amount)
	label.add_theme_font_size_override("font_size", 27)
	label.add_theme_color_override("font_color",
		Color(1, 0.85, 0.3) if amount > 0 else Color(1, 0.55, 0.45))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(label)
	var rect := from.get_global_rect()
	var start := _stage.get_global_transform().affine_inverse() * rect.get_center()
	label.position = start - Vector2(40, 30)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)

func _on_money_changed(amount: int) -> void:
	_money_label.text = money_format % amount
	if visible:
		_refresh_cards()

func _on_goods_changed() -> void:
	if visible:
		_refresh_cards()

## Decorative goods packing the back shelves: seeds and yeast on top, farm
## produce in the middle, orchard fruit at the bottom.
func _stock_shelves() -> void:
	var rows := [
		[&"wheat_seeds", &"carrot_seeds", &"corn_seeds", &"tomato_seeds", &"strawberry_seeds", &"watermelon_seeds",
			&"wine_yeast", &"bakers_yeast", &"ale_yeast", &"mead_yeast", &"champagne_yeast", &"wild_yeast"],
		[&"carrot", &"tomato", &"strawberry", &"corn", &"watermelon", &"wheat",
			&"egg", &"milk", &"bacon", &"egg", &"milk", &"tomato"],
		[&"apple", &"pear", &"orange", &"lemon", &"cherry", &"peach",
			&"plum", &"grape", &"blueberry", &"raspberry", &"mango", &"pineapple"],
	]
	for i in mini(rows.size(), _shelf_rows.size()):
		for id in rows[i]:
			var item: ItemData = ItemDatabase.get_item(id)
			if item == null:
				continue
			var icon := TextureRect.new()
			icon.texture = item.icon
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.custom_minimum_size = Vector2(56, 56)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_shelf_rows[i].add_child(icon)
