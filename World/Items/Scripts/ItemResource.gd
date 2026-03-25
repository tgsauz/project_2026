extends Resource
class_name ItemResource

@export var id: String
@export var display_name: String
@export var weight: float = 1.0

# Future-ready fields
@export var size: Vector2i = Vector2i.ONE
@export var stackable: bool = false
@export var max_stack: int = 1
