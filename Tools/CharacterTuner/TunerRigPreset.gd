extends Resource
class_name TunerRigPreset

@export var preset_id: String = ""
@export var display_name: String = ""
@export var rig_scene: PackedScene
@export var adapter_script: Script
@export var rig_profile: TunerRigProfile

func get_display_name_or_default() -> String:
	if not display_name.is_empty():
		return display_name
	if not preset_id.is_empty():
		return preset_id.capitalize()
	if rig_scene != null and not rig_scene.resource_path.is_empty():
		return rig_scene.resource_path.get_file().get_basename()
	return "Rig Preset"
