extends Spatial

func _ready():
	DebugInfo.add("godot", godot_version_string())
	DebugInfo.add("Physics", Globals.PhysicsEngine.keys()[Globals.physics_engine].capitalize())


func _physics_process(_delta):
	DebugInfo.add("fps", Engine.get_frames_per_second())
#	DebugInfo.plot_float("fps", Engine.get_frames_per_second())
	DebugInfo.add("time", OS.get_ticks_msec() / 1000.0)

	if Globals.physics_engine == Globals.PhysicsEngine.GODOT:
		# Currently this is only implemented in Godot physics backend
		DebugInfo.add(
			"active/islands/pairs", "%s/%s/%s" %[
				PhysicsServer.get_process_info(PhysicsServer.INFO_ACTIVE_OBJECTS),
				PhysicsServer.get_process_info(PhysicsServer.INFO_ISLAND_COUNT),
				PhysicsServer.get_process_info(PhysicsServer.INFO_COLLISION_PAIRS),
			]
		)

func godot_version_string():
	var version = Engine.get_version_info()
	return "%s-%s"% [
		version["string"],
		version["hash"].substr(0, 8)
	]
