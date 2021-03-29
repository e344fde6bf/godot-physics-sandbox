extends RigidBody

onready var shape_selector = $ShapeSelector
var current_shape
var current_shape_id

func _ready():
	process_priority = -1000
	set_shape(shape_selector.ObjectShape.BOX)

func set_shape(shape_id):
	if current_shape != null:
		current_shape.queue_free()
	current_shape = shape_selector.set_shape(self, shape_id)
	current_shape_id = shape_id

func get_displacement():
	var physics_pos = PhysicsServer.body_get_direct_state(get_rid()).transform.origin
	return global_transform.origin - physics_pos

func _physics_process(_delta):
#	var physics_pos = PhysicsServer.body_get_direct_state(get_rid()).transform.origin
#	DebugInfo.plot_bool("sleeping", sleeping)
	DebugInfo.plot_float("cube speed", linear_velocity.length())
#	DebugInfo.plot_float("cube speed.y", linear_velocity.y)
#	DebugInfo.plot_float("cube y", physics_pos.y)
	# var disp = get_displacement()
	# DebugInfo.plot_float("disp cube", disp.z)
	pass

func _input(event):
	if event.is_action_pressed("change_rigid_shape"):
		current_shape_id = shape_selector.next_shape_id(current_shape_id)
		set_shape(current_shape_id)

func _set_behavior(behavior):
	match behavior:
		RigidBody.MODE_KINEMATIC:
			mode = RigidBody.MODE_KINEMATIC
		RigidBody.MODE_RIGID:
			mode = RigidBody.MODE_RIGID
			sleeping = false
			linear_velocity = Vector3()
			angular_velocity = Vector3()

func set_cube_grabbed(grabbed: bool):
	if grabbed:
		_set_behavior(RigidBody.MODE_KINEMATIC)
	else:
		_set_behavior(RigidBody.MODE_RIGID)
