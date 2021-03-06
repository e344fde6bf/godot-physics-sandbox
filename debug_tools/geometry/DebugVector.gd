extends Spatial

var material

onready var cylinder = $Cylinder
onready var arrow_head = $Arrowhead

func _ready():
	material = SpatialMaterial.new()
	cylinder.material_override = material
	arrow_head.material_override = material

func orient_vector(vector: Vector3, offset=Vector3(), scale=1.0, max_size=null, color=null):
	var unit_vec = vector.normalized()
	if vector == Vector3():
		hide()
	else:
		show()
	if color == null:
		color = Color(abs(unit_vec.x), abs(unit_vec.y), abs(unit_vec.z), 1.0)
	material.albedo_color = color
	
	var magnitude = vector.length() if max_size == null else clamp(vector.length()*scale, 0.0, max_size)
	cylinder.scale.y = magnitude
	arrow_head.transform.origin.y = magnitude/2
	
	var basis = Basis()
	if unit_vec != Vector3.UP:
		basis.y = unit_vec
		basis.z = unit_vec.cross(Vector3.UP)
		basis.x = basis.y.cross(basis.z)
	global_transform.basis = basis
	transform.origin = offset
	self.scale = Vector3(scale, scale, scale)
