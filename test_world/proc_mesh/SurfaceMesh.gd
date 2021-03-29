tool

extends "proc_mesh.gd"

export var a: float = 1.0
export var b: float = 1.0
export var c: float = 1.0
export var d: float = 1.0
export var noise_seed: int = 0
export var range_x: Vector2 = Vector2(-10, 10)
export var range_y: Vector2 = Vector2(-10, 10)
export var segments_x: int = 100
export var segments_y: int = 100
export var thick: float = 5.0
export var surface_type: String = "linear"

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

func setup_common():
	size_x = range_x[1] - range_x[0]
	size_y = range_y[1] - range_y[0]

	noise = OpenSimplexNoise.new()

	# Configure
	noise.seed = noise_seed
	noise.octaves = 4
	noise.period = 20.0
	noise.persistence = 0.8

func get_mesh_resource_path():
	return "res://assets/proc_meshes/" + "surf-" + self.name + ".mesh"

func get_material_path():
	return "res://assets/materials/surface_material.tres"

func create_mesh() -> MeshInstance:
	var st = SurfaceTool.new()

	var height_func = surface_type

	assert(segments_x > 0)
	assert(segments_y > 0)

	var dx = size_x / segments_x
	var dy = size_y / segments_y

	var normal = Vector3(0, 1, 0)

	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in segments_x:
		var x0 = range_x[0] + dx*i
		var x1 = range_x[0] + dx*(i+1)
		# var u0 = float(i) / segments_x
		# var u1 = float(i+1) / segments_x
		var u0 = x0
		var u1 = x1

		for j in segments_y:
			var y0 = range_y[0] + dy*j
			var y1 = range_y[0] + dy*(j+1)
			# var v0 = float(j) / segments_y
			# var v1 = float(j+1) / segments_y
			var v0 = y0
			var v1 = y1

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

	# Create indices, indices are optional.
	st.index()

	# Commit to a mesh.
	var mesh = st.commit()
	return mesh
