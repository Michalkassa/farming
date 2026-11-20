class_name HubBuilding
extends Node2D
## A building in the hub you can click to go inside. It perks up when hovered
## and emits `activated` on click. Locked buildings just say they're coming soon.
## The node's position is where the building stands (bottom centre of the art).

signal activated

@export var texture: Texture2D : set = _set_texture
@export var locked: bool = false
@export var locked_message: String = "Coming soon!"

@export_group("Hover")
@export var hover_tint: Color = Color(1.12, 1.12, 1.05)
@export var hover_scale: float = 1.05
@export var hover_seconds: float = 0.12
@export var sign_bob_pixels: float = 1.0
@export var sign_bob_speed: float = 3.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _area: Area2D = $Area
@onready var _shape: CollisionShape2D = $Area/Shape
@onready var _sign: Node2D = get_node_or_null("Sign")

var _hovered := false
var _tween: Tween
var _sign_rest := Vector2.ZERO

func _set_texture(value: Texture2D) -> void:
	texture = value
	if is_node_ready():
		_fit_to_texture()

func _ready() -> void:
	_fit_to_texture()
	if _sign:
		_sign_rest = _sign.position
	_area.input_event.connect(_on_input_event)
	_area.mouse_entered.connect(_set_hovered.bind(true))
	_area.mouse_exited.connect(_set_hovered.bind(false))

## The art hangs up from the node's origin and the click box matches it.
func _fit_to_texture() -> void:
	_sprite.texture = texture
	if texture == null:
		return
	var size := texture.get_size()
	_sprite.centered = false
	_sprite.position = Vector2(-floorf(size.x / 2.0), -size.y)
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = Vector2(0, -size.y / 2.0)

func _process(_delta: float) -> void:
	if _sign == null:
		return
	var bob := 0.0
	if _hovered:
		bob = roundf(sin(Time.get_ticks_msec() / 1000.0 * sign_bob_speed * TAU) * sign_bob_pixels) - sign_bob_pixels
	_sign.position = _sign_rest + Vector2(0, bob)

func _set_hovered(on: bool) -> void:
	if _hovered == on:
		return
	_hovered = on
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if on else Input.CURSOR_ARROW)
	_animate(Vector2.ONE * (hover_scale if on else 1.0), hover_tint if on else Color.WHITE)

func _animate(to_scale: Vector2, to_tint: Color) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sprite, "scale", to_scale, hover_seconds)
	_tween.tween_property(_sprite, "modulate", to_tint, hover_seconds)
	# Scale around the bottom centre so the building stays planted.
	var size := texture.get_size() if texture else Vector2.ZERO
	var base := Vector2(-floorf(size.x / 2.0), -size.y)
	_tween.tween_property(_sprite, "position", base * to_scale, hover_seconds)

## A quick squash when something is delivered here (e.g. a harvest landing in the barn).
func bump() -> void:
	var resting := Vector2.ONE * (hover_scale if _hovered else 1.0)
	_animate(resting * 1.1, hover_tint if _hovered else Color.WHITE)
	_tween.chain().tween_callback(_animate.bind(resting, hover_tint if _hovered else Color.WHITE))

## Called when the player has gone inside, so the hover look doesn't stick.
func reset_hover() -> void:
	_set_hovered(false)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	get_viewport().set_input_as_handled()
	if locked:
		_say(locked_message)
		return
	reset_hover()
	activated.emit()

## A short line of text that floats up from the roof and fades.
func _say(message: String) -> void:
	var popup := HubSign.new()
	popup.text = message
	popup.z_index = 20
	var top := -(texture.get_size().y if texture else 16.0)
	popup.position = Vector2(0, top - 2)
	add_child(popup)
	var tween := popup.create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 10.0, 1.2)
	tween.tween_property(popup, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tween.chain().tween_callback(popup.queue_free)
