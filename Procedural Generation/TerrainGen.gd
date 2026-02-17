class_name TerrainGen
extends Node

var mesh : MeshInstance3D
var size_depth : int = 180
var size_width : int = 180
var mesh_resolution : int = 2
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generate()

func generate ():
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(size_width, size_depth)
	plane_mesh.subdivide_depth = size_depth * mesh_resolution
	plane_mesh.subdivide_width = size_width * mesh_resolution
	# plane_mesh.material = preload()
	
	var surface = SurfaceTool.new()
	surface.create_from(plane_mesh, 0)
	
	
