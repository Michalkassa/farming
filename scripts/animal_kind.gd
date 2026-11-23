class_name AnimalKind
extends Resource

@export var kind: StringName = &""
@export var idle_textures: Array[Texture2D] = []
@export var walk_textures: Array[Texture2D] = []
@export var idle_fps: float = 1.0
@export var walk_fps: float = 7.0

@export_group("Wandering")
@export var walk_speed: float = 9.0
@export var pause_seconds: Vector2 = Vector2(1.5, 5.0)
@export var step_length: Vector2 = Vector2(10.0, 30.0)
@export var target_candidates: int = 6
@export var elbow_room: float = 20.0

@export_group("Pen")
@export var spawn_spot: Vector2 = Vector2.ZERO
@export var roam: Rect2 = Rect2()

func frames_for(anim: String) -> Array[Texture2D]:
	if anim == "walk" and not walk_textures.is_empty():
		return walk_textures
	return idle_textures
