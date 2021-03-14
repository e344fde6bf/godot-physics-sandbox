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
export var step_mode: bool = false

func linear(x):
	return gradient*x

func steps(x):
	return b*floor(gradient*x/a)

func steps_2(x):
	var mid = (length/2-0.01)
	if x <= mid:
		return b*floor(gradient*x/a)
	else:
		return b*floor(gradient*(mid-x + mid)/a)

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
	return "res://assets/materials/curve-material.tres"

func create_mesh():
	var height_func = slope_type
	
	var st = SurfaceTool.new()

	var h = float(length) / point_count
	var x0 = 0
	var x1 = h
	var z0 = call(height_func, x0)
	var z1 = call(height_func, x1)
	var last_step_point = 0

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var norm = Vector3(-1, 0, 0)
	# first tri
	st.add_normal(norm)
	st.add_uv(Vector2(1, 0))
	st.add_vertex(Vector3(x0, z0-thick, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(x0, z0, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(x0, z0-thick, width))
	# second tri
	st.add_normal(norm)
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(x0, z0, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(0, 1))
	st.add_vertex(Vector3(x0, z0, width))
	st.add_normal(norm)
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(x0, z0-thick, width))

	for i in point_count:
		x0 = i * h
		x1 = (i+1) * h
		z0 = call(height_func, x0)
		z1 = call(height_func, x1)
					
		var v0 = float(i) / point_count
		var v1 = float(i+1) / point_count
		var u0 = 0.0
		var u1 = 1.0
		
		var is_stepping_now = step_mode and (z0 != z1)
		if step_mode and not is_stepping_now:
			var x2 = (i+2) * h
			var z2 = call(height_func, x2)
			
			if z2 != z1:
				x0 = last_step_point*h
				x1 = x1
				v0 = float(last_step_point) / point_count
				v1 = float(i+1) / point_count
			else:
				continue
		elif is_stepping_now:
			x1 = x0
			last_step_point = i

		if not is_stepping_now:
			norm = Vector3(-(z1 - z0), h, 0).normalized()
		else:
			norm = Vector3(-1, 0, 0)

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
		st.add_vertex(Vector3(x1, z1 - thick, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v0))
		st.add_vertex(Vector3(x0, z0 - thick, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v0))
		st.add_vertex(Vector3(x0, z0 - thick, width))
		# fourth tri (bottom)
		st.add_normal(norm)
		st.add_uv(Vector2(u0, v1))
		st.add_vertex(Vector3(x1, z1 - thick, 0))
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v0))
		st.add_vertex(Vector3(x0, z0 - thick, width))
		st.add_normal(norm)
		st.add_uv(Vector2(u1, v1))
		st.add_vertex(Vector3(x1, z1 - thick, width))
		
		if not is_stepping_now:
			norm = Vector3(0, 0, -1.0)
			# side-tri tri 1
			st.add_normal(norm)
			st.add_uv(Vector2(0, 0))
			st.add_vertex(Vector3(x0, z0, 0))
			st.add_normal(norm)
			st.add_uv(Vector2(0, 1))
			st.add_vertex(Vector3(x0, z0-thick, 0))
			st.add_normal(norm)
			st.add_uv(Vector2(1, 1))
			st.add_vertex(Vector3(x1, z1-thick, 0))
			# side-tri tri 2
			st.add_normal(norm)
			st.add_uv(Vector2(1, 0))
			st.add_vertex(Vector3(x1, z1, 0))
			st.add_normal(norm)
			st.add_uv(Vector2(0, 0))
			st.add_vertex(Vector3(x0, z0, 0))
			st.add_normal(norm)
			st.add_uv(Vector2(1, 1))
			st.add_vertex(Vector3(x1, z1-thick, 0))
			
			norm = -norm
			# side-tri tri 3
			st.add_normal(norm)
			st.add_uv(Vector2(0, 1))
			st.add_vertex(Vector3(x0, z0-thick, width))
			st.add_normal(norm)
			st.add_uv(Vector2(0, 0))
			st.add_vertex(Vector3(x0, z0, width))
			st.add_normal(norm)
			st.add_uv(Vector2(1, 1))
			st.add_vertex(Vector3(x1, z1-thick, width))
			# side-tri tri 4
			st.add_normal(norm)
			st.add_uv(Vector2(0, 0))
			st.add_vertex(Vector3(x0, z0, width))
			st.add_normal(norm)
			st.add_uv(Vector2(1, 0))
			st.add_vertex(Vector3(x1, z1, width))
			st.add_normal(norm)
			st.add_uv(Vector2(1, 1))
			st.add_vertex(Vector3(x1, z1-thick, width))
		
		
	norm = Vector3(1, 0, 0)
	# end tri 1
	st.add_normal(norm)
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(x1, z1, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(1, 0))
	st.add_vertex(Vector3(x1, z1-thick, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(x1, z1-thick, width))
	# end tri 2
	st.add_normal(norm)
	st.add_uv(Vector2(0, 1))
	st.add_vertex(Vector3(x1, z1, width))
	st.add_normal(norm)
	st.add_uv(Vector2(0, 0))
	st.add_vertex(Vector3(x1, z1, 0))
	st.add_normal(norm)
	st.add_uv(Vector2(1, 1))
	st.add_vertex(Vector3(x1, z1-thick, width))
	
	# Create indices, indices are optional.
	st.index()

	# Commit to a mesh.
	# var mesh = st.commit()
	var mesh = st.commit()
	return mesh
