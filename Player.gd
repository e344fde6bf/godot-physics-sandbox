extends KinematicBody

enum MOVE_MODE {
	BASIC = 0,
	NO_CLIP = 1,
}

enum PlayerShape {
	CAPSULE,
	BOX,
	CYLINDER,
	SPHERE,
	WEDGE,
}

const FPS = 60
const JUMP_BUFFER_FRAME_COUNT = int(FPS * 0.08)
const FLOOR_BUFFER_FRAME_COUNT = int(FPS * 0.2)

const PHYSICS_SPEED = 1.0
const GRAVITY = -60 * PHYSICS_SPEED
const JUMP_SPEED = 25 * PHYSICS_SPEED
const PLAYER_MAX_SPEED = 15 * PHYSICS_SPEED
const PLAYER_ACCEL = 30 * PHYSICS_SPEED
const PLAYER_STOPPING_TIME = 0.75 # in seconds
const SPEED_NO_CLIP = 100
# const MAX_SLOPE_ANGLE = deg2rad(1)
# const MAX_SLOPE_ANGLE = deg2rad(40)
const FLOOR_ANGLE_THRESHOLD = 0.01 # radians, this value is used internally by move_and_slide
const MAX_SLOPE_ANGLE = deg2rad(50)
# const MAX_SLOPE_ANGLE = deg2rad(60)
const CAMERA_CLAMP_ANGLE = deg2rad(89)
const MAX_SLIDES = 4
var mouse_sensitivity = 0.01

const pos_marker = preload("res://PosMarker.tscn")

export(float, 0.1, 300.0) var camera_distance = 8.0 setget set_camera_distance
export var camera_follows_rotation: bool = false
export var use_pos_marker = false
export var enable_fixes = true

onready var player = $"."
# onready var player_body = $PlayerBody
onready var camera_helper = $CameraHelper
onready var camera = $CameraHelper/CameraPosition/Camera
onready var camera_position = $CameraHelper/CameraPosition
onready var debug_drawer = $DebugDrawer
onready var companion_cube = $".."/CompanionCube

var player_body: CollisionShape
var current_player_shape: int

var dir: Vector3
var last_dir: Vector3 = Vector3(0, 0, 0)
var input_movement_vector: Vector2
var fake_speed: float = 0.0
var gravity_vel: Vector3 = Vector3()
var camera_rotation = Vector3()
var jump_pressed: bool = false
var run_pressed: bool = false
var jump_frame_buffering: int = 0
var floor_node = null
var cube_hold_mode = false
var move_mode = MOVE_MODE.BASIC
var buffered_is_on_floor: int = 0
var is_squished
var last_floor_rotation: Basis
var model_should_rotate = false

var marker_timer: float = 0.0
var last_marker_state = false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	call_deferred("set_camera_distance", camera_distance)
	DebugInfo.add("fps", 0)
	DebugInfo.add("time", 0)
	DebugInfo.add("godot", godot_version_string())
	DebugInfo.add("Physics", ProjectSettings.get_setting("physics/3d/physics_engine"))
	DebugInfo.add("move_mode", move_mode)
	
	set_player_shape(PlayerShape.CAPSULE)
	
	var steepness_mat = load("res://assets/materials/steepness_material.tres")
	steepness_mat.set_shader_param("limit_angle_deg", rad2deg(MAX_SLOPE_ANGLE + FLOOR_ANGLE_THRESHOLD))
	DebugInfo.add("max slope deg", rad2deg(MAX_SLOPE_ANGLE + FLOOR_ANGLE_THRESHOLD))
	
	process_priority = 100
	
	assert(player_body != null)

func godot_version_string():
	var version = Engine.get_version_info()
	return "%s-%s"% [
		version["string"],
		version["hash"].substr(0, 8)
	]

func set_player_shape(player_shape: int):
	assert(player_shape in PlayerShape.values())
	var body_name = "ObjectHolder/PlayerBody" + (PlayerShape.keys()[player_shape]).capitalize()
	var new_body = get_node(body_name)
	if player_body != null:
		player_body.queue_free()
	player_body = new_body.duplicate()
	player_body.show()
	self.add_child(player_body)
	current_player_shape = player_shape

func set_camera_distance(new_distance):
	assert(new_distance > 0)
	camera_distance = new_distance
	if camera_position != null:
		camera_position.transform.origin.z = camera_distance
	return camera_distance

func _process(_delta):
	pass
	
func _physics_process(delta):
	DebugInfo.add("fps", Engine.get_frames_per_second())
	DebugInfo.add("time", OS.get_ticks_msec() / 1000.0)
	DebugInfo.add("move_mode", MOVE_MODE.keys()[move_mode])
	DebugInfo.add("enable_fixes", enable_fixes)
	process_input()
	process_movement(delta)
	add_position_marker(delta)

func get_angular_velocity(node):
	return PhysicsServer.body_get_direct_state(node.get_rid()).angular_velocity

func get_rigid_velocity(_delta):
	if not floor_node is RigidBody:
		return Vector3()
	return PhysicsServer.body_get_direct_state(floor_node.get_rid()).linear_velocity

func get_linear_displacement(node):
	var start_pos = PhysicsServer.body_get_direct_state(node.get_rid()).transform.origin
	return node.global_transform.origin - start_pos
	
func get_rotation_difference(node):
	var start_basis = PhysicsServer.body_get_direct_state(node.get_rid()).transform.basis
	var end_basis = node.global_transform.basis
	return end_basis.orthonormalized() * start_basis.orthonormalized().transposed() 

func get_rotation_displacement(node):
	var rot = get_rotation_difference(node)
	
	# centre of rotation at start of frame
	var rotation_origin = PhysicsServer.body_get_direct_state(node.get_rid()).transform.origin
	# our current position
	var current_collision_pos = self.global_transform.origin
	var collision_pos_relative = current_collision_pos - rotation_origin
	var collision_pos_relative_next = rot.xform(collision_pos_relative)
	return collision_pos_relative_next - collision_pos_relative

func get_total_displacement(node):
	return get_linear_displacement(node) + get_rotation_displacement(node)

func get_linear_velocity(node, delta):
	return get_linear_displacement(node) / delta

func get_floor_node():
	# a hacky function to find the floor node
	assert(is_on_floor())
	for i in range(get_slide_count()):
		var collision = get_slide_collision(i)
		if collision.normal != get_floor_normal():
			continue
		if collision.collider_velocity != get_floor_velocity():
			continue
		return collision.collider
	assert(false)

func get_floor_normal_fixed():
	return last_floor_rotation.xform(get_floor_normal())

func apply_rotations(delta, player_dir: Vector3):
	var start_rot = Quat(player_body.transform.basis)
	var desired_rot
	if player_dir == Vector3() or abs(player_dir.dot(Vector3.UP))>= 0.99:
		desired_rot = start_rot
	elif player_dir != Vector3():
		var basis = Basis()
		var dir_planar = Plane(Vector3.UP, 0).project(player_dir).normalized()
		if dir_planar != Vector3():
			if current_player_shape == PlayerShape.CAPSULE:
				basis.y = -dir_planar
				basis.z = -Vector3.UP
				basis.x = basis.y.cross(basis.z)
			else:
				basis.z = -dir_planar
				basis.y = Vector3.UP
				basis.x = basis.y.cross(basis.z)
		desired_rot = Quat(basis)
	
	player_body.transform.basis = Basis(start_rot.slerp(desired_rot, 20*delta))
	
	# player_body.global_transform.basis = basis
		
	if !is_on_floor() or move_mode != MOVE_MODE.BASIC:
		return

	var ang_vel = PhysicsServer.body_get_direct_state(floor_node.get_rid()).angular_velocity
	if ang_vel == Vector3():
		return
		
	var ang_vertical = ang_vel.project(Vector3.UP)
	
	DebugInfo.add("angular_velocity", ang_vel)
	
	if ang_vertical != Vector3() and model_should_rotate:
		player_body.transform.basis = player_body.transform.basis.rotated(ang_vertical.normalized(), ang_vertical.length()*delta)
		player_body.transform.basis = player_body.transform.basis.orthonormalized()
	
	if camera_follows_rotation:
		# Only rotate around UP-axis for camera
		camera_rotation += ang_vel.project(Vector3.UP)*delta
		camera_helper.rotation = camera_rotation

func move_basic(delta):
	var cam_basis = camera.get_global_transform().basis
	dir = Vector3.ZERO
	model_should_rotate = true
	
	# compute the players movement unit vector
	if input_movement_vector != Vector2():
		# players desired direction in xz plane
		dir += cam_basis.x * input_movement_vector[0]
		dir += -cam_basis.z * input_movement_vector[1]
		dir.y = 0
		dir = dir.normalized()
		
		if is_on_floor():
			var floor_plane = get_floor_normal_fixed()
			# players desired direction in xz plane
			var d = dir
			# use partial derivatives of floor plane to figure out the change in altitude
			var dydx = -floor_plane.x / floor_plane.y
			var dydz = -floor_plane.z / floor_plane.y
			dir = Vector3(d.x, dydx * d.x + dydz * d.z, d.z)
			dir = dir.normalized()
		last_dir = dir
		
	if buffered_is_on_floor > 0 and jump_frame_buffering > 0:
		# The player is jumping
		gravity_vel.y = JUMP_SPEED
		jump_frame_buffering = 0
		buffered_is_on_floor = 0
	else:
		# The player is not jumping
		var chosen_normal = Vector3.UP
		if is_on_floor():
			chosen_normal = get_floor_normal_fixed()
		gravity_vel += chosen_normal * delta * GRAVITY
		jump_frame_buffering -= 1
		
	if !is_on_floor() and is_on_ceiling():
		# if we jump and hit our head on a ceiling
		# TODO: need to unify this behaviour between walls and ceilings.
		gravity_vel = -Vector3.UP * 1 * gravity_vel.length()
		fake_speed = fake_speed * 0.5

	var stop_on_slope = !is_on_floor()
	var start_transform = global_transform
	
	var floor_vel_adjust = -get_floor_velocity() if enable_fixes else Vector3()
	var this_dir
	if dir != Vector3():
		this_dir = dir
		fake_speed = min(fake_speed+PLAYER_ACCEL * delta, PLAYER_MAX_SPEED)
	else:
		fake_speed *= pow(1e-6, delta / PLAYER_STOPPING_TIME)
		this_dir = last_dir
	var player_vel = fake_speed * this_dir
#	if not is_on_floor():
#		player_vel *= 0.8
	var start_vel = player_vel + gravity_vel
	var vel = start_vel + floor_vel_adjust
	var _out_vel = player.move_and_slide(\
			vel,
			Vector3.UP,
			stop_on_slope,
			MAX_SLIDES,
			MAX_SLOPE_ANGLE,
			false
	)
	
	if enable_fixes:
		var retry_without_vel_adjust = !is_on_floor() and floor_node != null
		# DebugInfo.plot_bool("retrying", retry_without_vel_adjust)
		if retry_without_vel_adjust:
			# `move_and_slide()` adds `get_floor_velocity()` internally so we add
			# `-get_floor_velocity()` to counteract this in `floor_vel_adjust`.
			# However, we aren't on the floor anymore, so we need to retry without setting this
			global_transform = start_transform
			floor_vel_adjust = Vector3()
			vel = start_vel
			_out_vel = player.move_and_slide(vel, Vector3.UP, stop_on_slope, MAX_SLIDES, MAX_SLOPE_ANGLE, false)#		out_vel = player.move_and_slidevel, Vector3.UP, stop_on_slope, MAX_SLIDES, MAX_SLOPE_ANGLE, false)
	
	# we 'corrupted' the velocity value with floor_vel_adjust, so remove its effect here
	_out_vel += -Plane(get_floor_normal(),0).project(floor_vel_adjust)
	
	var follow_platform = (floor_node != null) or is_on_floor()
	
	if is_on_floor():
		buffered_is_on_floor = FLOOR_BUFFER_FRAME_COUNT
		floor_node = get_floor_node()
		gravity_vel = Vector3()
		
	is_squished = false
	if follow_platform and enable_fixes:
		last_floor_rotation = get_rotation_difference(floor_node)
		var disp
		if floor_node is RigidBody:
			# TODO: is this really right?
			# Behaviour seems to be different between bullet and godot physics
			disp = -get_total_displacement(floor_node)
		else:
			disp = +get_total_displacement(floor_node)
		add_collision_exception_with(floor_node)
		var collision = move_and_collide(disp, false)
		remove_collision_exception_with(floor_node)
		
		if is_on_wall() or collision != null:
			model_should_rotate = false
	
		if is_on_floor() and collision != null:
			var col_dot_prod = collision.normal.dot(last_floor_rotation * get_floor_normal())
			is_squished = bool(col_dot_prod < -0.9) and \
					(collision.collider_velocity-get_floor_velocity()).length_squared() > 0.01
		
	if !is_on_floor():
		buffered_is_on_floor -= 1
		floor_node = null

func move_no_clip(delta):
	var cam_transform = self.transform.inverse() * camera.global_transform
	dir = Vector3.ZERO
	
	if input_movement_vector != Vector2() or jump_pressed or run_pressed:
		dir += cam_transform.basis.x * input_movement_vector[0]
		dir += -cam_transform.basis.z * input_movement_vector[1]
		dir.y = 0
		dir = dir.normalized()
		if jump_pressed:
			dir += Vector3.UP
		if run_pressed:
			dir -= Vector3.UP
		dir = dir.normalized()

		last_dir = dir
		
	global_transform = global_transform.translated(dir * SPEED_NO_CLIP * delta)

func process_movement(delta):
	
	match move_mode:
		MOVE_MODE.BASIC:
			move_basic(delta)
		MOVE_MODE.NO_CLIP:
			move_no_clip(delta)

	if cube_hold_mode:
		var forward = -camera_helper.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		var cube_pos = self.global_transform.translated(forward * 5)
		cube_pos.basis = self.player_body.transform.basis
		companion_cube.global_transform = cube_pos

	apply_rotations(delta, dir)
	
	# debug_drawer.draw_vector("dir", self, dir, Vector3(0, 2.5, 0))
	DebugInfo.add("floor_node", floor_node.name if floor_node!=null else null)
	if floor_node != null:
		DebugInfo.plot_float("floor angular vel", get_angular_velocity(floor_node).length(), 0, 20)
	else:
		DebugInfo.plot_float("floor angular vel", 0.0, 0, 20)
		
	
	# floor_angle behaviour seems weird when the ray cast hits a moving object
	var floor_angle = rad2deg(acos(get_floor_normal().dot(Vector3.UP))) if is_on_floor() else 0.0
	DebugInfo.plot_float("floor angle", floor_angle, 0, 90)
	
	DebugInfo.plot_float("slide count", get_slide_count(), 0, 4)
	DebugInfo.plot_bool("is_on_floor", is_on_floor())
#	DebugInfo.plot_bool("is_squished", is_squished)
	DebugInfo.plot_bool("is_on_ceiling", is_on_ceiling())
	DebugInfo.plot_bool("is_on_wall", is_on_wall())
	DebugInfo.plot_float("floor speed", get_floor_velocity().length(), 0, 30)
	DebugInfo.plot_float("fake_speed", fake_speed, 0, 20)
	DebugInfo.plot_float("player speed", get_linear_velocity(self, delta).length(), 0, 30)
#	DebugInfo.plot_float("buffered on floor", clamp(buffered_is_on_floor, 0, FLOOR_BUFFER_FRAME_COUNT))
#	DebugInfo.plot_float("buffered jump", clamp(jump_frame_buffering, 0, JUMP_BUFFER_FRAME_COUNT))
	
	
func process_input():
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.is_action_just_pressed("cube_hold_mode"):
		cube_hold_mode = !cube_hold_mode
		if cube_hold_mode:
			companion_cube.set_behavior(RigidBody.MODE_KINEMATIC)
		else:
			companion_cube.set_behavior(RigidBody.MODE_RIGID)
	
	input_movement_vector = Vector2()
	if Input.is_action_pressed("movement_forward"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("movement_backward"):
		input_movement_vector.y -= 1
	if Input.is_action_pressed("movement_left"):
		input_movement_vector.x -= 1
	if Input.is_action_pressed("movement_right"):
		input_movement_vector.x += 1

	input_movement_vector = input_movement_vector.normalized()

	if Input.is_action_just_pressed("movement_jump"):
		jump_frame_buffering = JUMP_BUFFER_FRAME_COUNT
	
	jump_pressed = Input.is_action_pressed("movement_jump")
	run_pressed = Input.is_action_pressed("movement_run")
#	elif Input.is
#	pa
	
	if Input.is_action_just_pressed("no_clip_mode"):
		move_mode = move_mode ^ 1
		gravity_vel = Vector3()
	
	if Input.is_action_just_pressed("debug_button_1"):
		current_player_shape = (current_player_shape+1) % PlayerShape.size()
		if (current_player_shape == PlayerShape.CYLINDER
				and (ProjectSettings.get_setting("physics/3d/physics_engine") == "GodotPhysics")
				and (Engine.get_version_info()["hex"] < 0x030300)
			):
			# skip cylinder shape if it is unsupported
			current_player_shape = (current_player_shape+1) % PlayerShape.size()
		set_player_shape(current_player_shape)
		
#	if Input.is_action_just_pressed("debug_button_1"):
#		camera_rotation.x = 0
#		camera_rotation.y = PI/2 * floor((camera_rotation.y + PI/4) / (PI/2))
#		camera_helper.rotation = camera_rotation
#	if Input.is_action_just_pressed("debug_button_2"):
#		camera_rotation.y = PI/2 * floor((camera_rotation.y + PI/4) / (PI/2))
#		camera_helper.rotation = camera_rotation
	if Input.is_action_just_pressed("debug_button_3"):
		use_pos_marker = !use_pos_marker
	if Input.is_action_just_pressed("toggle_fixes"):
		last_floor_rotation = Basis()
		enable_fixes = !enable_fixes

func add_position_marker(delta):
	marker_timer += delta
	var this_state = is_on_floor()
	var should_add_marker = marker_timer > 0.1 or (last_marker_state != this_state)
	if should_add_marker and move_mode != MOVE_MODE.NO_CLIP and use_pos_marker:
	
		var new_marker = pos_marker.instance()
		new_marker.transform = self.transform
		if !is_on_floor():
			new_marker.set_color(Color(0, 0, 0, 1))
		$"..".add_child(new_marker)
		
	if marker_timer > 0.1:
		marker_timer = 0.0
	last_marker_state = this_state

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var yaw = camera_rotation.y + event.relative.x * mouse_sensitivity * -1
		var pitch = camera_rotation.x + -event.relative.y * mouse_sensitivity
		yaw = fmod(yaw, 2*PI)
		pitch = clamp(pitch, -CAMERA_CLAMP_ANGLE, CAMERA_CLAMP_ANGLE)
		camera_rotation = Vector3(pitch, yaw, 0)
		
		camera_helper.rotation = camera_rotation
	# process_input()
