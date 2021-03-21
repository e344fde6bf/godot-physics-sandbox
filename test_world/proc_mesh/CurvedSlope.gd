tool

extends "proc_mesh.gd"

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
export var random_seed: int = 0
## used for creating steps.
## * a -> stepping width
## * height_func is passed an integer used to calculate the current steps height
## * point_count is set automatically based on the `length/a`
export var step_mode: bool = false
export var material: SpatialMaterial = null

func linear(x):
	return gradient*x

func steps(i):
	return b*i

func steps_2(i):
	var mid = int(length/2)
	if i < mid:
		return b*i
	else:
		return b*(2*mid-(i+1))

func my_rand(i):
	return (1103515245 * (random_seed + int(i)) + 12345) % (1<<32)

func my_rand2(i):
	var r = (random_seed + i*12512423823)
	r ^= r << 13
	r ^= r >> 17
	r ^= r << 5 
	return r

func steps_rand(i):
	return my_rand(i) % int(b)
	
func steps_rand2(i):
	return my_rand2(i) % int(b)
	
func steps_pulses(i):
	return b * (i % 2)

func quadratic(x):
	return gradient*x*x
	
func cubic(x):
	return gradient*x*x*x
	
func sinusoidal(x):
	return gradient*abs(sin(PI*x/length))

func sinusoidal_inv(x):
	return gradient*(1 - abs(sin(PI*x/length)))

func setup_common():
	pass

func get_mesh_resource_path():
	return "res://assets/proc_meshes/" + "curve-" + self.name + ".mesh"

func get_material_path():
	if material != null:
		return material.get_path()
	else:
		return "res://assets/materials/curve-material.tres"

func create_mesh():
	var height_func = slope_type
	
	var st = SurfaceTool.new()

	var h = float(length) / point_count
	var x0 = 0
	var x1
	var z0 = call(height_func, x0)
	var z1
	var step_point: int = 0
	var is_stepping = false

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var norm = Vector3(-1, 0, 0)
	# first tri
	st.add_normal(norm)
	st.add_uv(Vector2(z0-thick, 0))
	st.add_vertex(Vector3(x0, z0-thick, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(z0, 0))
	st.add_vertex(Vector3(x0, z0, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(z0-thick, width))
	st.add_vertex(Vector3(x0, z0-thick, width))
	# second tri
	st.add_normal(norm)
	st.add_uv(Vector2(z0, 0))
	st.add_vertex(Vector3(x0, z0, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(z0, width))
	st.add_vertex(Vector3(x0, z0, width))
	st.add_normal(norm)
	st.add_uv(Vector2(z0-thick, width))
	st.add_vertex(Vector3(x0, z0-thick, width))

	var iterations
	if step_mode:
		iterations = 2 * int(length / a) - 1
	else:
		iterations = point_count

	for i in iterations:
		if not step_mode:
			x0 = i * h
			x1 = (i+1) * h
			z0 = call(height_func, x0)
			z1 = call(height_func, x1)
			
		var is_stepping_now = is_stepping
		if step_mode:
			if is_stepping:
				step_point += 1
				x0 = a*(step_point)
				x1 = x0
				z0 = call(height_func, step_point-1)
				z1 = call(height_func, step_point)
				is_stepping = false
				
				if is_equal_approx(z0, z1):
					# too small to make a step
					continue
			else:
				x0 = a*step_point
				x1 = a*(step_point+1)
				z0 = call(height_func, step_point)
				z1 = z0
				is_stepping = true

		if not is_stepping_now:
			norm = Vector3(-(z1 - z0), h, 0).normalized()
		else:
			norm = Vector3(-1, 0, 0)
		
		var z0_b = z0-thick
		var z1_b = z1-thick
		var u0 = 0
		var u1 = width
		var v0
		var v1
		if is_stepping_now:
			v0 = z0
			v1 = z1
		else:
			v0 = x0
			v1 = x1

		# first tri (top)
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v0))
		st.add_vertex(Vector3(x0, z0, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v1))
		st.add_vertex(Vector3(x1, z1, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v0))
		st.add_vertex(Vector3(x0, z0, width))
		# second tri (top)
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v0))
		st.add_vertex(Vector3(x0, z0, width))
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v1))
		st.add_vertex(Vector3(x1, z1, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v1))
		st.add_vertex(Vector3(x1, z1, width))
		
		norm = -norm
		# third tri (bottom)
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v1))
		st.add_vertex(Vector3(x1, z1_b, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v0))
		st.add_vertex(Vector3(x0, z0_b, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v0))
		st.add_vertex(Vector3(x0, z0_b, width))
		# fourth tri (bottom)
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v1))
		st.add_vertex(Vector3(x1, z1_b, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v0))
		st.add_vertex(Vector3(x0, z0_b, width))
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v1))
		st.add_vertex(Vector3(x1, z1_b, width))
		
		if not is_stepping_now:
			norm = Vector3(0, 0, -1.0)
			# side-tri tri 1
			st.add_normal(norm)
			st.add_uv(Vector2(x0, z0))
			st.add_vertex(Vector3(x0, z0, 0))
			st.add_normal(norm)
			st.add_uv(Vector2(x0, z0_b))
			st.add_vertex(Vector3(x0, z0_b, 0))
			st.add_normal(norm)
			st.add_uv(Vector2(x1, z1_b))
			st.add_vertex(Vector3(x1, z1_b, 0))
			# side-tri tri 2
			st.add_normal(norm)
			st.add_uv(Vector2(x1, z1))
			st.add_vertex(Vector3(x1, z1, 0))
			st.add_normal(norm)
			st.add_uv(Vector2(x0, z0))
			st.add_vertex(Vector3(x0, z0, 0))
			st.add_normal(norm)
			st.add_uv(Vector2(x1, z1_b))
			st.add_vertex(Vector3(x1, z1_b, 0))
			
			norm = -norm
			# side-tri tri 3
			st.add_normal(norm)
			st.add_uv(Vector2(x0, z0_b))
			st.add_vertex(Vector3(x0, z0_b, width))
			st.add_normal(norm)
			st.add_uv(Vector2(x0, z0))
			st.add_vertex(Vector3(x0, z0, width))
			st.add_normal(norm)
			st.add_uv(Vector2(x1, z1_b))
			st.add_vertex(Vector3(x1, z1_b, width))
			# side-tri tri 4
			st.add_normal(norm)
			st.add_uv(Vector2(x0, z0))
			st.add_vertex(Vector3(x0, z0, width))
			st.add_normal(norm)
			st.add_uv(Vector2(x1, z1))
			st.add_vertex(Vector3(x1, z1, width))
			st.add_normal(norm)
			st.add_uv(Vector2(x1, z1_b))
			st.add_vertex(Vector3(x1, z1_b, width))

	norm = Vector3(1, 0, 0)
	# end tri 1
	st.add_normal(norm)
	st.add_uv(Vector2(z1, 0))
	st.add_vertex(Vector3(x1, z1, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(z1-thick, 0))
	st.add_vertex(Vector3(x1, z1-thick, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(z1-thick, width))
	st.add_vertex(Vector3(x1, z1-thick, width))
	# end tri 2
	st.add_normal(norm)
	st.add_uv(Vector2(z1, width))
	st.add_vertex(Vector3(x1, z1, width))
	st.add_normal(norm)
	st.add_uv(Vector2(z1, 0))
	st.add_vertex(Vector3(x1, z1, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(z1-thick, width))
	st.add_vertex(Vector3(x1, z1-thick, width))
	
	# Create indices, indices are optional.
	st.index()

	# Commit to a mesh.
	# var mesh = st.commit()
	var mesh = st.commit()
	return mesh
