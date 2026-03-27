extends Resource
class_name InteractionPromptData

@export var target_id: String = ""
@export var title: String = ""
@export var tooltip: String = ""
@export var interact_label: String = ""
@export var interact_key_hint: String = ""
@export var category: String = ""
@export var actions: Array[Dictionary] = []

func to_dictionary() -> Dictionary:
	return {
		"target_id": target_id,
		"title": title,
		"tooltip": tooltip,
		"interact_label": interact_label,
		"interact_key_hint": interact_key_hint,
		"category": category,
		"actions": actions.duplicate(true)
	}
