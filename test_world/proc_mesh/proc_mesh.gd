tool

extends Node
class_name ProcMesh

export var rebuild: bool = false setget _rebuild_now
export var convex_collision_shape: bool = false
export var collision_margin: float = 0.04

# TODO: find out how to stop instances from running this script, yet still
# allow the master copy to run this script
export var instance_locked: bool = false

func _enter_tree():
	if Engine.editor_hint:
		_rebuild_now(not ResourceLoader.exists(get_mesh_resource_path()))

func _ready():
	setup_common()
	if Engine.editor_hint:
		_rebuild_now(not ResourceLoader.exists(get_mesh_resource_path()))
		return
	create_collision_mesh()

func setup_common():
	assert(false)

func create_mesh() -> MeshInstance:
	assert(false)
	return MeshInstance.new()

func get_mesh_resource_path() -> String:
	assert(false)
	return ""
	# return "res://assets/meshes/" + "surf-" + self.name + ".mesh"

func get_material_path() -> String:
	assert(false)
	return ""

func create_collision_mesh():
	var collision_shape = CollisionShape.new()
	collision_shape.name = "CollisionShape"
	if convex_collision_shape:
		collision_shape.shape = $MeshInstance.mesh.create_convex_shape()
		collision_shape.shape.margin = collision_margin
	else:
		collision_shape.shape = $MeshInstance.mesh.create_trimesh_shape()
		collision_shape.shape.margin = collision_margin
	# collision_shape.shape = $MeshInstance.mesh.smooth_trimesh_shape()

	add_child(collision_shape, true)

func add_node_for_editor(node_name, node_type):
	if get_tree() == null:
		return
	var node = get_node_or_null("./" + node_name)
	if node == null:
		var new_node = node_type.new()
		new_node.set_name(node_name)
		self.add_child(new_node)
		new_node.owner = get_tree().edited_scene_root
		# new_node.owner = self
		return new_node

func _rebuild_now(should_build):
	if not Engine.editor_hint: # or get_tree() == null:
		return

	if (should_build \
			or not ResourceLoader.exists(get_mesh_resource_path()) \
			or get_node_or_null("MeshInstance") == null \
			or $MeshInstance.mesh == null \
			or $MeshInstance.mesh.get_path() != get_mesh_resource_path() \
			) and (not instance_locked):
		setup_common()
		print("ToolScript: rebuilding mesh " + get_mesh_resource_path())
		var _new_mesh = add_node_for_editor("MeshInstance", MeshInstance)
#		if new_mesh != null:
#			var new_collision = add_node_for_editor("CollisionShape", CollisionShape)
		build_and_save_meshes()
		$MeshInstance.mesh = load(get_mesh_resource_path())
		$MeshInstance.material_override = load(get_material_path())

	# rebuild = should_build
	# rebuild=false

	return rebuild

func build_and_save_meshes():
	setup_common()
	#var new_mesh = create_mesh(length, width, slope_type, thickness, steps)
	# var new_mesh = create_mesh(surface_type)
	var new_mesh = create_mesh()


	# https://github.com/godotengine/godot/issues/24646
	var res
	if ResourceLoader.exists(get_mesh_resource_path()):
		res = ResourceLoader.load(get_mesh_resource_path())
	res = new_mesh

	var fname = get_mesh_resource_path()
	new_mesh.take_over_path(fname)
	var flags = ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES | \
			ResourceSaver.FLAG_COMPRESS
	var err = ResourceSaver.save(fname, res, flags)
	if err:
		printerr("Error %d: Failed to save mesh %s" % [err, fname])
