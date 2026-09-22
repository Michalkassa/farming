extends Node2D

@export var animal_scene: PackedScene
@export var kinds: Array[AnimalKind] = []
@export var herd_spread: Array[float] = [0.0, -18.0, 18.0, -32.0, 32.0]
@export var fallback_spot: Vector2 = Vector2(216, 80)
@export var sort_by_depth: bool = true

var _spawned: Dictionary = {}

func _ready() -> void:
	y_sort_enabled = sort_by_depth
	GameState.animals_changed.connect(_sync)
	_sync()

func config_for(kind: StringName) -> AnimalKind:
	for entry in kinds:
		if entry != null and entry.kind == kind:
			return entry
	return null

func _sync() -> void:
	for kind in _spawned:
		var herd: Array = _spawned[kind]
		while herd.size() > GameState.animal_count(kind):
			var sold: Node = herd.pop_back()
			if is_instance_valid(sold):
				sold.queue_free()
	for kind in GameState.animals:
		var herd: Array = _spawned.get(kind, [])
		_spawned[kind] = herd
		if herd.size() >= GameState.animal_count(kind):
			continue
		var animal := _spawn(kind, herd.size())
		if animal != null:
			herd.append(animal)

func _spawn(kind: StringName, index: int) -> Animal:
	var config := config_for(kind)
	if config == null or animal_scene == null:
		push_warning("AnimalPen: no scene or config for animal kind %s" % kind)
		return null
	var animal: Animal = animal_scene.instantiate()
	animal.config = config
	var spot := config.spawn_spot
	if not herd_spread.is_empty():
		spot.x += herd_spread[index % herd_spread.size()]
	if config.roam.size != Vector2.ZERO:
		if not config.roam.has_point(spot):
			spot = config.roam.get_center()
		spot.x = clampf(spot.x, config.roam.position.x, config.roam.end.x)
		spot.y = clampf(spot.y, config.roam.position.y, config.roam.end.y)
	elif config.spawn_spot == Vector2.ZERO:
		spot = fallback_spot
	animal.position = spot
	add_child(animal)
	return animal
