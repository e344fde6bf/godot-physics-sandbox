extends StaticBody

export var gradient: float = 0.01
export var width: float = 10.0
# export var length: float = 100.0
export var length: float = 50.0
export var thick: float = 2.5
export var point_count: int = 200
export var slope_type: String = "quadratic"
export var a = 1.0
export var b = 1.0
export var c = 1.0

export var save_to_file: bool = true

func linear(x):
	return gradient*x

func steps(x):
	return b*floor(gradient*x/a)

func quadratic(x):
	return gradient*x*x
	
func cubic(x):
	return gradient*x*x*x
	
func sinusoidal(x):
	return gradient*abs(sin(PI*x/length))

func sinusoidal_inv(x):
	return gradient*(1 - abs(sin(PI*x/length)))

func _ready():
	print("_ready() CurvedSlope: ", OS.get_time())
	# todo
	build_and_save_meshes()

func build_and_save_meshes():
	#var new_mesh = create_mesh(length, width, slope_type, thickness, steps)
	var new_mesh = create_mesh(slope_type)
	$MeshInstance.mesh = new_mesh
	
	if save_to_file:
		var fname = "res://assets/meshes/" + self.name + ".mesh"
		var flags = ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES | ResourceSaver.FLAG_COMPRESS
		var err = ResourceSaver.save(fname, new_mesh, flags)
		if err:
			printerr("Error %d: Failed to save mesh %s" % [err, fname])
	
	var collosion_shape = CollisionShape.new()
	collosion_shape.shape = new_mesh.create_trimesh_shape()
	self.add_child(collosion_shape)

#func create_mesh(length, width, height_func, thick, steps=100):
func create_mesh(height_func):
	var st = SurfaceTool.new()

	var h = float(length) / point_count
	var x = 0
	var z0 = call(height_func, x)
	var z1 = call(height_func, x+h)

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var norm = Vector3(-1, 0, 0)
	# first tri
	st.add_normal(norm)
	st.add_uv(Vector2(1, 0))
	st.add_vertex(Vector3(x, z0-thick, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(x, z0, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(x, z0-thick, width))
	# second tri
	st.add_normal(norm)
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(x, z0, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(0, 1))
	st.add_vertex(Vector3(x, z0, width))
	st.add_normal(norm)
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(x, z0-thick, width))

	for i in point_count:
		x = i * h
		z0 = call(height_func, x)
		z1 = call(height_func, x + h)
		
		var v0 = float(i) / point_count
		var v1 = float(i+1) / point_count
		var u0 = 0.0
		var u1 = 1.0
		
		norm = Vector3(-(z1 - z0), h, 0).normalized()

		# first tri
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v0))
		st.add_vertex(Vector3(x, z0, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v1))
		st.add_vertex(Vector3(x+h, z1, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v0))
		st.add_vertex(Vector3(x, z0, width))
		# second tri
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v0))
		st.add_vertex(Vector3(x, z0, width))
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v1))
		st.add_vertex(Vector3(x+h, z1, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v1))
		st.add_vertex(Vector3(x+h, z1, width))
		
		
		# side-tri tri 1
		st.add_normal(norm)
		st.add_uv(Vector2(0, 0))
		st.add_vertex(Vector3(x, z0, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(0, 1))
		st.add_vertex(Vector3(x, z0-thick, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 1))
		st.add_vertex(Vector3(x+h, z1-thick, 0))
		# side-tri tri 2
		st.add_normal(norm)
		st.add_uv(Vector2(1, 0))
		st.add_vertex(Vector3(x+h, z1, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(0, 0))
		st.add_vertex(Vector3(x, z0, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 1))
		st.add_vertex(Vector3(x+h, z1-thick, 0))
		
		# side-tri tri 3
		st.add_normal(norm)
		st.add_uv(Vector2(0, 1))
		st.add_vertex(Vector3(x, z0-thick, width))
		st.add_normal(norm)
		st.add_uv(Vector2(0, 0))
		st.add_vertex(Vector3(x, z0, width))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 1))
		st.add_vertex(Vector3(x+h, z1-thick, width))
		# side-tri tri 4
		st.add_normal(norm)
		st.add_uv(Vector2(0, 0))
		st.add_vertex(Vector3(x, z0, width))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 0))
		st.add_vertex(Vector3(x+h, z1, width))
		st.add_normal(norm)
		st.add_uv(Vector2(1, 1))
		st.add_vertex(Vector3(x+h, z1-thick, width))
		
		# third tri
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v1))
		st.add_vertex(Vector3(x+h, z1 - thick, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v0))
		st.add_vertex(Vector3(x, z0 - thick, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v0))
		st.add_vertex(Vector3(x, z0 - thick, width))
		# fourth tri
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v1))
		st.add_vertex(Vector3(x+h, z1 - thick, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v0))
		st.add_vertex(Vector3(x, z0 - thick, width))
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v1))
		st.add_vertex(Vector3(x+h, z1 - thick, width))
		
		
	norm = Vector3(1, 0, 0)
	# end tri 1
	st.add_normal(norm)
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(x+h, z1, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(1, 0))
	st.add_vertex(Vector3(x+h, z1-thick, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(x+h, z1-thick, width))
	# end tri 2
	st.add_normal(norm)
	st.add_uv(Vector2(0, 1))
	st.add_vertex(Vector3(x+h, z1, width))
	st.add_normal(norm)
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(x+h, z1, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(x+h, z1-thick, width))
	
	# Create indices, indices are optional.
	st.index()

	# Commit to a mesh.
	# var mesh = st.commit()
	var mesh = st.commit()
	return mesh
