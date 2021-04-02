extends RigidBody

onready var shape_selector = $ShapeSelector
var current_shape
var current_shape_id
var is_clone = false

func _ready():
	if not is_clone:
		set_shape(shape_selector.ObjectShape.BOX)

	process_priority = Globals.ProcessPriorities.Rigid

func set_shape(shape_id):
	if current_shape != null:
		current_shape.queue_free()
	current_shape = shape_selector.set_shape(self, shape_id)
	current_shape_id = shape_id

func get_displacement():
	var physics_pos = PhysicsServer.body_get_direct_state(get_rid()).transform.origin
	return global_transform.origin - physics_pos

func _physics_process(_delta):
	if is_clone:
		return
#	var physics_pos = PhysicsServer.body_get_direct_state(get_rid()).transform.origin
#	DebugInfo.plot_bool("sleeping", sleeping)
	DebugInfo.plot_float("cube speed", linear_velocity.length(), 0, 100)
#	DebugInfo.plot_float("cube speed.y", linear_velocity.y)
#	DebugInfo.plot_float("cube y", physics_pos.y)
	# var disp = get_displacement()
	# DebugInfo.plot_float("disp cube", disp.z)
	pass

func next_shape():
	assert(!is_clone)
	current_shape_id = shape_selector.next_shape_id(current_shape_id)
	set_shape(current_shape_id)

func clone():
	var new_copy = self.duplicate()
	new_copy.is_clone = true
	# new_copy.remove_child(new_copy.get_node("ShapeSelector"))
	new_copy._set_behavior(RigidBody.MODE_RIGID)
	new_copy.set_physics_process(false)
	self.get_parent().add_child(new_copy, true)

func _set_behavior(behavior):
	match behavior:
		RigidBody.MODE_KINEMATIC:
			mode = RigidBody.MODE_KINEMATIC
			set_collision_layer_bit(Globals.CollisionLayers.RIGID, false)
			set_collision_mask_bit(Globals.CollisionLayers.RIGID, false)
		RigidBody.MODE_RIGID:
			mode = RigidBody.MODE_RIGID
			sleeping = false
			linear_velocity = Vector3()
			angular_velocity = Vector3()
			set_collision_layer_bit(Globals.CollisionLayers.RIGID, true)
			set_collision_mask_bit(Globals.CollisionLayers.RIGID, true)

func set_cube_grabbed(grabbed: bool):
	if grabbed:
		_set_behavior(RigidBody.MODE_KINEMATIC)
	else:
		_set_behavior(RigidBody.MODE_RIGID)
