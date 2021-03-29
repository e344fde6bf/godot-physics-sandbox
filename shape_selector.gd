extends Spatial

enum ObjectShape {
	CAPSULE,
	BOX,
	CYLINDER,
	SPHERE,
	WEDGE,
	COMPOUND1,
	COMPOUND2,
	COMPOUND3,
}

var current_shape: int
var max_shape_number: int

func _ready():
	max_shape_number = self.get_child_count()
	assert(max_shape_number <= ObjectShape.size())

func delete_old_shapes(parent: Node):
	for child in parent.get_children():
		if child is CollisionShape:
			child.queue_free()

func copy_shape(parent: Node, node):
	var new_copy = node.duplicate()
	new_copy.show()
	parent.add_child(new_copy)
	return new_copy

func set_shape(parent, player_shape: int):
	assert(player_shape in ObjectShape.values())
	delete_old_shapes(parent)
	var new_shape_name = (ObjectShape.keys()[player_shape]).capitalize().replace(" ", "")
	var node_name = "Shape" + new_shape_name
	if node_name.find("Compound") != -1:
		print(node_name)
		var compound_shape = get_node(node_name)
		for child in compound_shape.get_children():
			copy_shape(parent, child)
	else:
		return copy_shape(parent, get_node(node_name))

func _next_shape_id(shape_id):
	return (shape_id+1) % max_shape_number

func next_shape_id(shape_id):
	var next_shape = _next_shape_id(shape_id)
	if (next_shape == ObjectShape.CYLINDER
		and (ProjectSettings.get_setting("physics/3d/physics_engine") == "GodotPhysics")
		and (Engine.get_version_info()["hex"] < 0x030204)
	):
	# skip cylinder shape if it is unsupported
			next_shape = _next_shape_id(next_shape)
	return next_shape
