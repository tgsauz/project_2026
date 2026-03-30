extends Node3D
class_name WorldInteractable

# Base helper for in-world interactable objects.
# Place on any interactable object for strong typing / readability.

func interact(_actor: Node) -> void:
	# Override in child classes for interaction behavior.
	pass

func get_interaction_prompt_data() -> Dictionary:
	# Override to provide prompt info (title, labels, tooltip). 
	return {
		"title": "INTERACT",
		"interact_label": "[e] Interact",
		"tooltip": ""
	}

func get_interaction_actions(_actor: Node) -> Array:
	return []

func perform_interaction_action(_actor: Node, _action_id: String) -> void:
	pass
