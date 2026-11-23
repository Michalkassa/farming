extends CanvasLayer
## The orchard: a separate sunny field reached from the farm's signpost.
## Three rows of plots (trees at the back, vines on trellises, bushes in front)
## sit in a little fenced meadow under a blue sky with drifting clouds, with a
## shed (with a smiling girl in pink and her taller friend in a blonde cap
## standing hand in hand in front of it), a pond, a few flowers and butterflies.
##   Empty plot: click to pick a sapling to buy and plant.
##   Fruiting plant (sparkling): click to pick the fruit into your bags.
##   Holding the shovel: click a plant, confirm, and it's dug up to free the plot.
## It sits under the HUD layer so the hotbar stays visible while you pick.
## The scene is drawn on a fixed design stage scaled to cover the window; the
## buttons and the sapling picker sit on a separate stage scaled to fit.

const ART := "res://static/orchard/%s.png"
const S := 3.0                                  # art pixels -> design pixels

@export_group("Layout")
@export var design_size: Vector2 = Vector2(1152, 648)
@export var fade_seconds: float = 0.2
@export var columns: PackedFloat32Array = [300.0, 440.0, 580.0, 720.0, 860.0]
## Ground line (bottom of the plant) for each row: trees, vines, bushes.
@export var row_bases: PackedFloat32Array = [332.0, 432.0, 518.0]
## Matches the pack's grass, so the pond tile blends in.
@export var ground_color: Color = Color8(65, 205, 115)
@export var sky_top: Color = Color8(108, 188, 240)
@export var sky_bottom: Color = Color8(196, 232, 250)

@export_group("Text")
@export var money_format: String = "€%d"
@export var gold_color: Color = Color(1, 0.84, 0.35)

var _screen: Control
var _stage: Control
var _ui: Control
var _plots: Array[Control] = []
var _plants: Array[TextureRect] = []
var _sparkles: Array[Control] = []
var _clouds: Array[Dictionary] = []
var _butterflies: Array[Dictionary] = []
## The two orchard keepers by the shed: {node, art, foot, hop, phase}.
var _keepers: Array[Dictionary] = []
var _picker: Control
## The picker floats above the HUD (this screen sits below it) on its own layer.
var _picker_layer: CanvasLayer
var _picker_root: Control
var _fade: Tween
var _textures: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	layer = 5
	visible = false
	_rng.seed = 20261123
	_build()
	Orchard.plot_changed.connect(_refresh_plot)
	get_viewport().size_changed.connect(_fit)

func open() -> void:
	if visible:
		return
	visible = true
	_fit()
	for i in _plots.size():
		_refresh_plot(i)
	if _fade:
		_fade.kill()
	_screen.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(_screen, "modulate:a", 1.0, fade_seconds)

func close() -> void:
	if not visible:
		return
	_close_picker()
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_screen, "modulate:a", 0.0, fade_seconds)
	_fade.tween_callback(func(): visible = false)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _picker:
			_close_picker()
		else:
			close()

## The scene covers the window (cropping edges); the UI fits inside it.
func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	var cover := maxf(screen.x / design_size.x, screen.y / design_size.y)
	_stage.scale = Vector2(cover, cover)
	_stage.position = ((screen - design_size * cover) * 0.5).floor()
	var contain := minf(screen.x / design_size.x, screen.y / design_size.y)
	_ui.scale = Vector2(contain, contain)
	_ui.position = ((screen - design_size * contain) * 0.5).floor()
	_picker_root.scale = _ui.scale
	_picker_root.position = _ui.position

func _tex(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(ART % name)
	return _textures[name]

## A pixel-art sprite at `pos` (top-left, design px), drawn at `scale` art pixels.
func _sprite(parent: Control, name: String, pos: Vector2, scale: float = S) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _tex(name) if name.find("/") < 0 else load(name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = rect.texture.get_size() * scale
	rect.position = pos
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

## Same, but positioned by its bottom-centre (where it touches the ground).
func _planted(parent: Control, name: String, foot: Vector2, scale: float = S) -> TextureRect:
	var rect := _sprite(parent, name, Vector2.ZERO, scale)
	rect.position = foot - Vector2(rect.size.x * 0.5, rect.size.y)
	rect.pivot_offset = Vector2(rect.size.x * 0.5, rect.size.y)
	return rect

# --- Building the scene -------------------------------------------------------

func _build() -> void:
	_screen = Control.new()
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen)
	var under := ColorRect.new()
	under.color = ground_color
	under.set_anchors_preset(Control.PRESET_FULL_RECT)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(under)

	_stage = Control.new()
	_stage.size = design_size
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_stage)

	_build_sky()
	_build_ground()
	_build_plots()
	_build_critters()

	_ui = Control.new()
	_ui.size = design_size
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_ui)
	_build_ui()

	_picker_layer = CanvasLayer.new()
	_picker_layer.layer = 25
	add_child(_picker_layer)
	_picker_root = Control.new()
	_picker_root.size = design_size
	_picker_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picker_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picker_layer.add_child(_picker_root)

func _build_sky() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([sky_top, sky_bottom])
	var sky_tex := GradientTexture2D.new()
	sky_tex.gradient = gradient
	sky_tex.width = 4
	sky_tex.height = 64
	sky_tex.fill_to = Vector2(0, 1)
	var sky := TextureRect.new()
	sky.texture = sky_tex
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.size = Vector2(design_size.x, 290)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(sky)

	for i in 5:
		var cloud := _sprite(_stage, "cloud_%d" % (i % 2), Vector2(_rng.randf_range(-100, design_size.x), _rng.randf_range(18, 190)), _rng.randf_range(2.5, 3.5))
		cloud.modulate.a = 0.95
		_clouds.append({"node": cloud, "speed": _rng.randf_range(6.0, 16.0)})

func _build_ground() -> void:
	var ground := ColorRect.new()
	ground.color = ground_color
	ground.position = Vector2(0, 262)
	ground.size = Vector2(design_size.x, design_size.y - 262)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(ground)

	# Grass tufts and tiny bushes sprinkled everywhere for texture.
	var decor_sheet := "res://Clover Valley V2 Free/Enviroment/Decor/Natural_Decor_free.png"
	for i in 22:
		var tuft := AtlasTexture.new()
		tuft.atlas = load(decor_sheet)
		tuft.region = Rect2(0, 17, 16, 15) if i % 4 else Rect2(1, 1, 13, 14)
		var rect := TextureRect.new()
		rect.texture = tuft
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.size = tuft.region.size * (2.0 if i % 4 else 2.4)
		rect.position = Vector2(_rng.randf_range(-10, design_size.x - 20), _rng.randf_range(280, design_size.y - 20))
		rect.modulate = Color(1, 1, 1, 0.9)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(rect)

	# Back fence, with the entrance arch on the left.
	var x := 232.0
	while x < design_size.x:
		_sprite(_stage, "fence", Vector2(x, 254))
		x += 16 * S
	_sprite(_stage, "fence", Vector2(-20, 254))
	var arch := _sprite(_stage, "arch", Vector2(24, 170))
	var title := Label.new()
	title.text = "ORCHARD"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.97, 0.86))
	title.add_theme_color_override("font_outline_color", Color8(55, 10, 20))
	title.add_theme_constant_override("outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = arch.position + Vector2(0, 6 * S + 2)
	title.custom_minimum_size = Vector2(arch.size.x, 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(title)

	# The shed and wheelbarrow on the right; the pond below them.
	_planted(_stage, "shed", Vector2(1056, 300))
	# The orchard keepers, hand in hand in front of the shed. They stand exactly
	# side by side (both sprites are 16 art pixels wide) so their hands meet.
	# Click either one and they hop together, with a heart.
	for keeper in [{"art": "boy", "foot": Vector2(990, 324), "phase": 1.6},
			{"art": "girl", "foot": Vector2(990 + 16 * S, 324), "phase": 0.0}]:
		var node := _planted(_stage, keeper.art + "_0", keeper.foot)
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		keeper["node"] = node
		keeper["hop"] = null
		node.gui_input.connect(_on_keeper_input.bind(_keepers.size()))
		_keepers.append(keeper)
	_planted(_stage, "wheelbarrow", Vector2(1010, 380))
	var pond := AtlasTexture.new()
	pond.atlas = load("res://Clover Valley V2 Free/Tilesets/Water_free.png")
	pond.region = Rect2(0, 0, 48, 48)
	var pond_rect := TextureRect.new()
	pond_rect.texture = pond
	pond_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pond_rect.size = Vector2(48, 48) * S
	pond_rect.position = Vector2(980, 390)
	pond_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(pond_rect)

	# A tidy dirt path along each row.
	for base in row_bases:
		var path := ColorRect.new()
		path.color = Color8(214, 180, 112, 110)
		path.position = Vector2(columns[0] - 80, base - 6)
		path.size = Vector2(columns[columns.size() - 1] - columns[0] + 160, 14)
		path.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(path)

	# A few flowers and mushrooms around the edges.
	var spots := []
	for i in 12:
		var edge := i % 3
		var pos := Vector2(_rng.randf_range(10, 230), _rng.randf_range(320, 600)) if edge == 0 \
			else (Vector2(_rng.randf_range(940, 1140), _rng.randf_range(540, 640)) if edge == 1 \
			else Vector2(_rng.randf_range(220, 940), _rng.randf_range(540, 640)))
		spots.append(pos)
	for i in spots.size():
		var name := "mushroom" if i % 6 == 0 else "flower_%d" % (i % 6)
		_planted(_stage, name, spots[i], 2.5)
func _build_plots() -> void:
	for i in Orchard.plots.size():
		var row := i / Orchard.PLOTS_PER_ROW
		var col := i % Orchard.PLOTS_PER_ROW
		var foot := Vector2(columns[col], row_bases[row])
		var kind: StringName = Orchard.ROWS[row]
		var box_size := Vector2(110, 170) if kind == &"tree" else (Vector2(84, 106) if kind == &"vine" else Vector2(84, 66))
		var plot := Control.new()
		plot.size = box_size
		plot.position = foot - Vector2(box_size.x * 0.5, box_size.y)
		plot.mouse_filter = Control.MOUSE_FILTER_STOP
		plot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_stage.add_child(plot)
		_planted(plot, "mound", Vector2(box_size.x * 0.5, box_size.y + 8))
		var plant := _planted(plot, "tree_0", Vector2(box_size.x * 0.5, box_size.y))
		var sparkle := Control.new()
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sparkle.size = box_size
		plot.add_child(sparkle)
		for s in 3:
			var star := _sprite(sparkle, "sparkle", Vector2(_rng.randf_range(8, box_size.x - 24), _rng.randf_range(4, box_size.y * 0.6)), 2.5)
			star.pivot_offset = star.size * 0.5
		plot.gui_input.connect(_on_plot_input.bind(i))
		plot.mouse_entered.connect(_hover.bind(i, true))
		plot.mouse_exited.connect(_hover.bind(i, false))
		_plots.append(plot)
		_plants.append(plant)
		_sparkles.append(sparkle)

func _build_critters() -> void:
	for i in 2:
		var node := _sprite(_stage, "butterfly_%d_0" % (i % 3), Vector2.ZERO, 3.0)
		node.pivot_offset = node.size * 0.5
		_butterflies.append({
			"node": node, "colour": i % 3, "centre": Vector2(_rng.randf_range(200, 950), _rng.randf_range(300, 520)),
			"radius": Vector2(_rng.randf_range(80, 220), _rng.randf_range(30, 80)),
			"speed": _rng.randf_range(0.15, 0.35), "phase": _rng.randf() * TAU,
		})
func _build_ui() -> void:
	var back := Button.new()
	back.text = "< Farm"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 18)
	back.position = Vector2(16, 14)
	back.custom_minimum_size = Vector2(134, 48)
	back.pressed.connect(close)
	_ui.add_child(back)

# --- Animation ----------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	var t := Time.get_ticks_msec() / 1000.0
	# The keepers breathe gently and blink every few seconds, not quite in step.
	for keeper in _keepers:
		var node: TextureRect = keeper.node
		var hop: Tween = keeper.hop
		if not (hop and hop.is_running()):
			node.scale = Vector2(1.0, 1.0 + sin(t * 2.4) * 0.015)   # in step, so the hands stay joined
		node.texture = _tex(keeper.art + ("_1" if fmod(t + keeper.phase, 3.7) < 0.14 else "_0"))
	for cloud in _clouds:
		var node: TextureRect = cloud.node
		node.position.x += cloud.speed * delta
		if node.position.x > design_size.x + 20:
			node.position.x = -node.size.x - 20
	for i in _plants.size():
		var plant := _plants[i]
		var kind: StringName = Orchard.row_of(i)
		var sway := 0.012 if kind == &"tree" else 0.03
		plant.rotation = sin(t * 1.3 + i * 0.7) * sway
		var sparkle := _sparkles[i]
		if sparkle.visible:
			for j in sparkle.get_child_count():
				var star: Control = sparkle.get_child(j)
				var pulse := 0.5 + 0.5 * sin(t * 3.0 + j * 2.1 + i)
				star.scale = Vector2.ONE * (0.4 + pulse * 0.8)
				star.modulate.a = pulse
	var frame := int(t * 7.0) % 2
	for b in _butterflies:
		var node: TextureRect = b.node
		var a: float = t * b.speed + b.phase
		var pos: Vector2 = b.centre + Vector2(cos(a) * b.radius.x, sin(a * 2.0) * b.radius.y)
		node.flip_h = -sin(a) < 0.0
		node.position = pos
		node.texture = _tex("butterfly_%d_%d" % [b.colour, frame])

# --- Plots --------------------------------------------------------------------

func _plant_texture(index: int) -> String:
	var plot: Dictionary = Orchard.plots[index]
	var kind := String(Orchard.row_of(index))
	var stage := Orchard.stage(index)
	if stage == 3:
		return "%s_%s" % [kind, plot.plant]
	if stage == 2 and plot.plant == &"pineapple":
		return "pineapple_2"
	return "%s_%d" % [kind, maxi(stage, 0)]

func _refresh_plot(index: int) -> void:
	if index < 0 or index >= _plots.size():
		return
	var plant := _plants[index]
	var stage := Orchard.stage(index)
	var empty := stage < 0
	plant.texture = _tex(_plant_texture(index))
	plant.size = plant.texture.get_size() * S
	var box := _plots[index].size
	plant.position = Vector2(box.x * 0.5 - plant.size.x * 0.5, box.y - plant.size.y)
	plant.pivot_offset = Vector2(plant.size.x * 0.5, plant.size.y)
	plant.visible = not empty
	plant.modulate = Color.WHITE
	_sparkles[index].visible = stage == 3
	_plots[index].tooltip_text = _plot_tooltip(index)
	if visible and stage >= 0:
		_pop(plant)

func _plot_tooltip(index: int) -> String:
	var plot: Dictionary = Orchard.plots[index]
	if plot.plant == &"":
		return "Plant a %s" % Orchard.row_of(index)
	var item: ItemData = ItemDatabase.get_item(plot.plant)
	var name: String = item.display_name if item else String(plot.plant)
	return name

## An empty plot shows a ghostly sprout while hovered, to say "plant here".
func _hover(index: int, on: bool) -> void:
	var plant := _plants[index]
	if on and Orchard.stage(index) >= 0 and _holding_shovel():
		plant.modulate = Color(1.25, 0.8, 0.75)   # about to be dug up
		return
	if Orchard.stage(index) < 0:
		plant.texture = _tex("%s_0" % Orchard.row_of(index))
		plant.size = plant.texture.get_size() * S
		var box := _plots[index].size
		plant.position = Vector2(box.x * 0.5 - plant.size.x * 0.5, box.y - plant.size.y)
		plant.visible = on
		plant.modulate = Color(1, 1, 1, 0.55)
	else:
		plant.modulate = Color(1.12, 1.12, 1.05) if on else Color.WHITE

func _on_plot_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_plots[index].accept_event()
	var stage := Orchard.stage(index)
	if stage >= 0 and _holding_shovel():
		_confirm_dig(index)
		return
	if stage < 0:
		_open_picker(index)
	elif stage == 3:
		var fruit: StringName = Orchard.plots[index].plant
		var picked := Orchard.harvest(index)
		if picked > 0:
			_fruit_burst(index, fruit, picked)
		else:
			_wobble(_plants[index])
	else:
		_wobble(_plants[index])

func _holding_shovel() -> bool:
	var item: ItemData = GameState.selected_item()
	return item != null and item.tool_kind == &"shovel"

## The plant pops out of the ground with a little spray of dirt, freeing the plot.
func _dig(index: int) -> void:
	var plant := _plants[index]
	var ghost := TextureRect.new()
	ghost.texture = plant.texture
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.size = plant.size
	ghost.position = _plots[index].position + plant.position
	ghost.pivot_offset = Vector2(ghost.size.x * 0.5, ghost.size.y)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(ghost)
	if not Orchard.dig_up(index):
		ghost.queue_free()
		return
	var tween := ghost.create_tween().set_parallel(true)
	tween.tween_property(ghost, "position:y", ghost.position.y - 40, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "rotation", 0.5, 0.45)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3).set_delay(0.15)
	tween.chain().tween_callback(ghost.queue_free)
	var foot := _plots[index].position + Vector2(_plots[index].size.x * 0.5, _plots[index].size.y)
	for n in 6:
		var clod := ColorRect.new()
		clod.color = Color8(120, 72, 46) if n % 2 else Color8(150, 94, 60)
		clod.size = Vector2(9, 9)
		clod.position = foot - clod.size * 0.5
		clod.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(clod)
		var out := foot + Vector2(_rng.randf_range(-55, 55), _rng.randf_range(-50, -15))
		var t2 := clod.create_tween()
		t2.tween_property(clod, "position", out, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t2.tween_property(clod, "position:y", foot.y - 4, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t2.tween_property(clod, "modulate:a", 0.0, 0.3)
		t2.tween_callback(clod.queue_free)

# --- Sapling picker -----------------------------------------------------------

## Opens a centred window over a dimmed screen (above the HUD) and returns its
## content box. Clicking outside it or pressing Esc closes it.
func _open_modal() -> VBoxContainer:
	_close_picker()
	_picker = Control.new()
	_picker.size = design_size
	_picker_root.add_child(_picker)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	# Reaches well past the design stage so the whole window dims.
	dim.position = -design_size
	dim.size = design_size * 3.0
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close_picker())
	_picker.add_child(dim)
	var centre := CenterContainer.new()
	centre.size = design_size
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picker.add_child(centre)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WindowPanel"
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_picker.modulate.a = 0.0
	create_tween().tween_property(_picker, "modulate:a", 1.0, 0.15)
	return box

## "Dig up the Apple?" with the plant's icon, a red Dig up button and Keep.
func _confirm_dig(index: int) -> void:
	var plant_id: StringName = Orchard.plots[index].plant
	var item: ItemData = ItemDatabase.get_item(plant_id)
	var box := _open_modal()
	box.add_theme_constant_override("separation", 14)
	var icon := TextureRect.new()
	icon.texture = item.icon if item else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(0, 64)
	box.add_child(icon)
	var title := Label.new()
	title.text = "Dig up the %s?" % (item.display_name if item else "plant")
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", gold_color)
	title.add_theme_color_override("font_outline_color", Color8(46, 26, 18))
	title.add_theme_constant_override("outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var dig := Button.new()
	dig.text = "Dig up"
	dig.theme_type_variation = &"DangerButton"
	dig.focus_mode = Control.FOCUS_NONE
	dig.custom_minimum_size = Vector2(160, 52)
	dig.add_theme_font_size_override("font_size", 18)
	dig.pressed.connect(func():
		_close_picker()
		_dig(index))
	buttons.add_child(dig)
	var keep := Button.new()
	keep.text = "Keep"
	keep.focus_mode = Control.FOCUS_NONE
	keep.custom_minimum_size = Vector2(160, 52)
	keep.add_theme_font_size_override("font_size", 18)
	keep.pressed.connect(_close_picker)
	buttons.add_child(keep)

func _open_picker(index: int) -> void:
	var kind: StringName = Orchard.row_of(index)
	var box := _open_modal()
	var title := Label.new()
	title.text = {&"tree": "Plant a tree", &"vine": "Plant a vine", &"bush": "Plant a bush"}[kind]
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", gold_color)
	title.add_theme_color_override("font_outline_color", Color8(46, 26, 18))
	title.add_theme_constant_override("outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 6 if kind == &"tree" else 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for id in Orchard.plants_for(kind):
		grid.add_child(_sapling_card(index, id))
	var cancel := Button.new()
	cancel.text = "Not now"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.add_theme_font_size_override("font_size", 18)
	cancel.pressed.connect(_close_picker)
	box.add_child(cancel)

func _sapling_card(index: int, id: StringName) -> Control:
	var item: ItemData = ItemDatabase.get_item(id)
	var data: Dictionary = Orchard.PLANTS[id]
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(128, 0)
	card.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(0, 56)
	card.add_child(icon)
	var name := Label.new()
	name.text = item.display_name
	name.add_theme_font_size_override("font_size", 18)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name)
	var info := Label.new()
	info.text = "×%d" % data.yield
	info.tooltip_text = "Fruit per harvest"
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(info)
	var buy := Button.new()
	buy.text = money_format % data.sapling
	buy.theme_type_variation = &"AccentButton"
	buy.focus_mode = Control.FOCUS_NONE
	buy.add_theme_font_size_override("font_size", 18)
	buy.disabled = not GameState.can_afford(data.sapling)
	buy.pressed.connect(func():
		if Orchard.plant(index, id):
			_close_picker()
			_pop(_plants[index]))
	card.add_child(buy)
	return card

func _close_picker() -> void:
	if _picker:
		_picker.queue_free()
		_picker = null

# --- Juice --------------------------------------------------------------------

func _on_keeper_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var clicked: TextureRect = _keepers[index].node
	clicked.accept_event()
	for keeper in _keepers:
		var running: Tween = keeper.hop
		if running and running.is_running():
			return
	# They're holding hands, so they hop together.
	for keeper in _keepers:
		var node: TextureRect = keeper.node
		var rest_y: float = keeper.foot.y - node.size.y
		node.scale = Vector2.ONE
		var hop := create_tween()
		hop.tween_property(node, "position:y", rest_y - 24, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(node, "position:y", rest_y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		keeper["hop"] = hop
	var left: TextureRect = _keepers[0].node
	var right: TextureRect = _keepers[_keepers.size() - 1].node
	var between := Vector2((left.position.x + right.position.x + right.size.x) * 0.5, minf(left.position.y, right.position.y))
	var heart := _sprite(_stage, "heart", between + Vector2(-13, -30), 3.0)
	heart.pivot_offset = heart.size * 0.5
	heart.scale = Vector2(0.3, 0.3)
	var float_up := heart.create_tween().set_parallel(true)
	float_up.tween_property(heart, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	float_up.tween_property(heart, "position:y", heart.position.y - 50, 1.0)
	float_up.tween_property(heart, "modulate:a", 0.0, 0.5).set_delay(0.5)
	float_up.chain().tween_callback(heart.queue_free)


func _pop(target: Control) -> void:
	var tween := create_tween()
	tween.tween_property(target, "scale", Vector2(1.12, 0.9), 0.08)
	tween.tween_property(target, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _wobble(target: Control) -> void:
	var tween := create_tween()
	for angle in [0.06, -0.06, 0.03, 0.0]:
		tween.tween_property(target, "rotation", angle, 0.06)

## Fruit hops out of the plant and tumbles down toward your bags.
func _fruit_burst(index: int, fruit: StringName, count: int) -> void:
	var item: ItemData = ItemDatabase.get_item(fruit)
	if item == null:
		return
	var plot := _plots[index]
	var origin := plot.position + Vector2(plot.size.x * 0.5, plot.size.y * 0.35)
	_pop(_plants[index])
	for n in mini(count, 6):
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = Vector2(36, 36)
		icon.pivot_offset = icon.size * 0.5
		icon.position = origin - icon.size * 0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(icon)
		var up := origin + Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-90, -50))
		var down := Vector2(origin.x * 0.4 + 120, design_size.y + 40)
		var tween := icon.create_tween()
		tween.tween_interval(n * 0.05)
		tween.tween_property(icon, "position", up - icon.size * 0.5, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(icon, "rotation", _rng.randf_range(-1.0, 1.0), 0.25)
		tween.tween_property(icon, "position", down, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(icon, "modulate:a", 0.0, 0.5).set_delay(0.2)
		tween.tween_callback(icon.queue_free)
