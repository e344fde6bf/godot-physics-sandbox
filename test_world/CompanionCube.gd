extends RigidBody

func _ready():
	process_priority = 100000
	
	call_deferred("ignore_player_collisions")

func ignore_player_collisions():
	# add_collision_exception_with(get_node("../Player"))
	pass

func get_displacement():
	var physics_pos = PhysicsServer.body_get_direct_state(get_rid()).transform.origin
	return global_transform.origin - physics_pos

func _physics_process(_delta):
	# DebugInfo.plot_bool("sleeping", sleeping)
	# DebugInfo.plot_float("cube speed", linear_velocity.length())
	# DebugInfo.plot_float("cube speed.z", linear_velocity.z)
	# var disp = get_displacement()
	# DebugInfo.plot_float("disp cube", disp.z)
	pass

func set_behavior(behavior):
	match behavior:
		RigidBody.MODE_KINEMATIC:
			mode = RigidBody.MODE_KINEMATIC
		RigidBody.MODE_RIGID:
			mode = RigidBody.MODE_RIGID
			sleeping = false
			linear_velocity = Vector3()
			angular_velocity = Vector3()
