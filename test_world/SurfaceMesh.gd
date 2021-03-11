tool

extends Spatial

export var a: float = 1.0
export var b: float = 1.0
export var c: float = 1.0
export var d: float = 1.0
export var noise_seed: int = 0
export var range_x: Vector2 = Vector2(-10, 10)
export var range_y: Vector2 = Vector2(-10, 10)
export var steps_x: int = 100
export var steps_y: int = 100
export var thick: float = 5.0
export var rebuild: bool = false setget _rebuild_now
export var surface_type: String = "linear"

const material_path = "res://assets/materials/surface_material.tres"

export var save_to_file: bool = true

var noise: OpenSimplexNoise
var size_x
var size_y

var last_edited_time

func linear(x, y):
	return a*x + b*y
	
func quadratic(x, y):
	return a*x*x/size_x + b*y*x + c*y*y/size_y
	
func pyramid(x, y):
	return c*(a-abs(x)) + d*(b-abs(y))
	
func dome(x, y):
	return sqrt(a*a - clamp(x*x + y*y, 0.0, a*a) )
	
func simplex(x, y):
	return a*noise.get_noise_2d(x*b, y*c)
	
func sinusoidal(x, y):
	return c*sin(2*PI*a*((x-range_x[0]) / size_x)) + d*cos(2*PI*b*((y-range_y[0])/size_y))

func _ready():
	setup_common()
	if Engine.editor_hint:
		return
	print("_ready() SurfaceMesh: ", OS.get_time())
	var collision_shape = CollisionShape.new()
	collision_shape.name = "CollisionShape"
	collision_shape.shape = $MeshInstance.mesh.create_trimesh_shape()
	add_child(collision_shape, true)
	
	# build_and_save_meshes()
func setup_common():
	size_x = range_x[1] - range_x[0] 
	size_y = range_y[1] - range_y[0]
	
	noise = OpenSimplexNoise.new()

	# Configure
	noise.seed = noise_seed
	noise.octaves = 4
	noise.period = 20.0
	noise.persistence = 0.8

func add_node_for_editor(node_name, node_type):
	var node = get_node_or_null("./" + node_name)
	if node == null:
		print("adding node: ", node_name)
		var new_node = node_type.new()
		new_node.set_name(node_name)
		self.add_child(new_node)
		new_node.owner = get_tree().edited_scene_root
		return new_node

func get_mesh_resource_path():
	return "res://assets/meshes/" + "surf-" + self.name + ".mesh"

func _rebuild_now(should_build):
	if not Engine.editor_hint or get_tree() == null:
		return
		
	if should_build:
		print("ToolScript: rebuilding mesh " + get_mesh_resource_path())
		var _new_mesh = add_node_for_editor("MeshInstance", MeshInstance)
#		if new_mesh != null:
#			var new_collision = add_node_for_editor("CollisionShape", CollisionShape)
		build_and_save_meshes()
		$MeshInstance.mesh = load(get_mesh_resource_path())
		$MeshInstance.material_override = load(material_path)

	rebuild = should_build
	
	return rebuild

func build_and_save_meshes():
	setup_common()
	#var new_mesh = create_mesh(length, width, slope_type, thickness, steps)
	var new_mesh = create_mesh(surface_type)
	
	# https://github.com/godotengine/godot/issues/24646
	var res
	if ResourceLoader.exists(get_mesh_resource_path()):
		res = ResourceLoader.load(get_mesh_resource_path())
	res = new_mesh
	
	if save_to_file:
		var fname = get_mesh_resource_path()
		new_mesh.take_over_path(fname)
		var flags = ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES | \
				ResourceSaver.FLAG_COMPRESS
		var err = ResourceSaver.save(fname, res, flags)
		if err:
			printerr("Error %d: Failed to save mesh %s" % [err, fname])

#func create_mesh(length, width, height_func, thick, steps=100):
func create_mesh(height_func) -> MeshInstance:
	var st = SurfaceTool.new()

	var dx = size_x / steps_x 
	var dy = size_y / steps_y 

	var normal = Vector3(0, 1, 0)

	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in steps_x-1:
		var x0 = range_x[0] + dx*i
		var x1 = range_x[0] + dx*(i+1)
		var u0 = float(i) / steps_x
		var u1 = float(i+1) / steps_x
		
		for j in steps_y-1:
			var y0 = range_y[0] + dy*j
			var y1 = range_y[0] + dy*(j+1)
			var v0 = float(j) / steps_y
			var v1 = float(j+1) / steps_y
			
			var z00 = call(height_func, x0, y0)
			var z10 = call(height_func, x1, y0)
			var z01 = call(height_func, x0, y1)
			var z11 = call(height_func, x1, y1)

			
			var p00 = Vector3(x0, z00, y0)
			var p10 = Vector3(x1, z10, y0)
			var p01 = Vector3(x0, z01, y1)
			var p11 = Vector3(x1, z11, y1)
			
			normal = ((p01 - p00).cross(p10 - p00)).normalized()
			# first tri
			st.add_normal(normal)
			st.add_uv(Vector2(u0, v0))
			st.add_vertex(p00)
			st.add_normal(normal)
			st.add_uv(Vector2(u1, v0))
			st.add_vertex(p10)
			st.add_normal(normal)
			st.add_uv(Vector2(u0, v1))
			st.add_vertex(p01)
			
			normal = -normal
			# first tri
			st.add_normal(normal)
			st.add_uv(Vector2(u1, v0))
			st.add_vertex(p10)
			st.add_normal(normal)
			st.add_uv(Vector2(u0, v0))
			st.add_vertex(p00)
			st.add_normal(normal)
			st.add_uv(Vector2(u0, v1))
			st.add_vertex(p01)
			
			normal = ((p10 - p11).cross(p01 - p11)).normalized()
			# second tri
			st.add_normal(normal)
			st.add_uv(Vector2(u1, v0))
			st.add_vertex(p10)
			st.add_normal(normal)
			st.add_uv(Vector2(u1, v1))
			st.add_vertex(p11)
			st.add_normal(normal)
			st.add_uv(Vector2(u0, v1))
			st.add_vertex(p01)
			normal = -normal
			# second tri
			st.add_normal(normal)
			st.add_uv(Vector2(u1, v1))
			st.add_vertex(p11)
			st.add_normal(normal)
			st.add_uv(Vector2(u1, v0))
			st.add_vertex(p10)
			st.add_normal(normal)
			st.add_uv(Vector2(u0, v1))
			st.add_vertex(p01)

	# Create indices, indices are optional.
	st.index()

	# Commit to a mesh.
	var mesh = st.commit()
	return mesh
