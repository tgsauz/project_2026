extends Control

class_name ItemInspectUI

var viewport_container: SubViewportContainer
var sub_viewport: SubViewport
var camera: Camera3D
var anchor_node: Node3D

var current_item_model: Node3D
var active: bool = false
var dragging: bool = false

var style_profile: UIStyleProfile
var fade_controller: UIFadeController

func _ready() -> void:
	visible = false
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Close label
	var label = Label.new()
	label.text = "[Click Background or Press ESC to close Inspector]"
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.offset_bottom = -50
	add_child(label)
	
	# 3D Viewport
	viewport_container = SubViewportContainer.new()
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	viewport_container.offset_left = -300
	viewport_container.offset_top = -300
	viewport_container.offset_right = 300
	viewport_container.offset_bottom = 300
	viewport_container.stretch = true
	add_child(viewport_container)
	
	sub_viewport = SubViewport.new()
	sub_viewport.own_world_3d = true
	sub_viewport.transparent_bg = true
	sub_viewport.msaa_3d = Viewport.MSAA_4X
	viewport_container.add_child(sub_viewport)
	
	camera = Camera3D.new()
	camera.position = Vector3(0, 0, 1.5)
	sub_viewport.add_child(camera)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	sub_viewport.add_child(light)
	
	anchor_node = Node3D.new()
	sub_viewport.add_child(anchor_node)
	
	# Input blocking bg
	var close_btn = Button.new()
	close_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close_btn.flat = true
	close_btn.button_down.connect(_close)
	add_child(close_btn)
	move_child(close_btn, 1) # Put under viewport but over bg

func apply_style(style: UIStyleProfile) -> void:
	style_profile = style
	if fade_controller == null:
		fade_controller = UIFadeController.new(self, style)
	else:
		fade_controller.style_profile = style

func inspect_item(item_definition: Resource) -> void:
	if item_definition == null or not item_definition.get("equipped_visual_scene"):
		push_error("Cannot inspect item: No visual scene.")
		return
		
	# Clear old
	for c in anchor_node.get_children():
		c.queue_free()
		
	var scene = item_definition.equipped_visual_scene as PackedScene
	if scene:
		current_item_model = scene.instantiate()
		anchor_node.add_child(current_item_model)
	
	# Reset rotation
	anchor_node.rotation_degrees = Vector3.ZERO
	
	active = true
	if fade_controller: fade_controller.fade_in()
	visible = true

func _close() -> void:
	active = false
	if fade_controller: 
		fade_controller.fade_out()
		if not fade_controller.fade_completed.is_connected(_on_fade_out):
			fade_controller.fade_completed.connect(_on_fade_out)
	else:
		visible = false

func _on_fade_out(dir: String) -> void:
	if dir == "out":
		visible = false

func _input(event: InputEvent) -> void:
	if not active or not visible:
		return
		
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_tree().root.set_input_as_handled()
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			
	if event is InputEventMouseMotion and dragging:
		# Rotate anchor node
		anchor_node.rotation_degrees.y -= event.relative.x * 0.5
		anchor_node.rotation_degrees.x -= event.relative.y * 0.5
		# Clamp X
		anchor_node.rotation_degrees.x = clamp(anchor_node.rotation_degrees.x, -80, 80)
