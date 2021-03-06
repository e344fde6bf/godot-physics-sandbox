extends KinematicBody

enum MOVE_MODE {
	NORMAL = 0,
	NO_CLIP = 1,
}

const PHYSICS_SPEED = 1
const GRAVITY = -120 * PHYSICS_SPEED
const JUMP_SPEED = 50 * PHYSICS_SPEED
const PLAYER_SPEED = 30 * PHYSICS_SPEED
const SPEED_NO_CLIP = 100
const MAX_SLOPE_ANGLE = deg2rad(50)
const CAMERA_CLAMP_ANGLE = deg2rad(89)
const MAX_SLIDES = 4
var mouse_sensitivity = 0.01

export(float, 0.1, 100.0) var camera_distance = 12.0
export var camera_follows_rotation: bool = false

var use_improved_approximation = true

onready var player = $"."
onready var player_body = $PlayerBody
onready var model = $PlayerBody
onready var camera_helper = $CameraHelper
onready var camera = $CameraHelper/CameraPosition/Camera
onready var camera_position = $CameraHelper/CameraPosition
onready var ground_ray = $PlayerBody/RayCast
onready var debug_drawer = $DebugDrawer
onready var companion_cube = $".."/CompanionCube

const pos_marker = preload("res://PosMarker.tscn")

var dir: Vector3
var last_dir: Vector3 = Vector3(0, 0, 1)
var input_movement_vector: Vector2
var vel: Vector3 = Vector3()
var camera_rotation = Vector3()
var gravity_vel: Vector3 = Vector3()
const JUMP_BUFFER_FRAME_COUNT = 3
var jump_pressed: bool = false
var run_pressed: bool = false
var jump_frame_buffering: int = 0
var floor_node = null
var cube_hold_mode = false
var move_mode = MOVE_MODE.NORMAL

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_position.translate_object_local(Vector3(0, 0, camera_distance))
	DebugInfo.add("fps", 0)
	DebugInfo.add("time", 0)
	DebugInfo.add("move_mode", move_mode)
	DebugInfo.add("improved_velocity_calc", use_improved_approximation)
	
	process_priority = 100

func _process(_delta):
	pass

func _physics_process(delta):
	DebugInfo.add("fps", Engine.get_frames_per_second())
	DebugInfo.add("time", OS.get_ticks_msec() / 1000.0)
	DebugInfo.add("move_mode", MOVE_MODE.keys()[move_mode])
	DebugInfo.add("improved_velocity_calc", str(use_improved_approximation) + " (Press Q to toggle)") 
	process_input(delta)
	process_movement(delta)
	add_position_marker(delta)
	
func improved_floor_velocity_estimate(delta):
	"""
	This function returns an estimate of the floor velocity for use in
	move_and_slide(). The result should be added to the `velocity` argument of
	`move_and_slide()`.
	
	NOTE: since `move_and_slide()` adds `get_floor_velocity()` internally,
	this function includes `-get_floor_velocity()` in the result to cancel this
	out.
	"""
	if !is_on_floor():
		DebugInfo.add("angular_velocity", null)
		return Vector3()
	
	return -get_floor_velocity() + floor_velocity_due_to_rotation(delta) # + get_rigid_velocity(delta)

func get_rigid_velocity(delta):
	if not floor_node is RigidBody:
		return Vector3()
	return PhysicsServer.body_get_direct_state(floor_node.get_rid()).linear_velocity

func get_displacement(node):
	var start_pos = PhysicsServer.body_get_direct_state(node.get_rid()).transform.origin
	return node.global_transform.origin - start_pos

func get_linear_velocity(node, delta):
	return get_displacement(node) / delta

func get_floor_displacement():
	"""
	This function returns how much the floor has moved since the start of the frame
	"""
	return get_displacement(floor_node)
		
func floor_velocity_due_to_rotation(delta):
	"""
	This function returns the velocity due to the rotation of the current floor node.
	"""
	var ang_vel = PhysicsServer.body_get_direct_state(floor_node.get_rid()).angular_velocity
	DebugInfo.add("angular_velocity", ang_vel)
	
	if ang_vel == Vector3():
		return Vector3()
	
	# the origin point in global coordinates
	var rotation_origin = floor_node.global_transform.origin
	# rotate based on where our character is this frame,
	# updated based on how much the floor has moved already this frame
	var current_collision_pos = self.global_transform.origin + get_floor_displacement()
	var collision_pos_relative = current_collision_pos - rotation_origin
	var next_rotated_xform = Transform().rotated(ang_vel.normalized(), ang_vel.length()*delta)
	var collision_pos_relative_next = next_rotated_xform.xform(collision_pos_relative)
	var v_avg = (collision_pos_relative_next - collision_pos_relative) / delta
	return v_avg

func get_floor_node():
	""" a hacky function to find the floor node """
	assert(is_on_floor())
	for i in range(get_slide_count()):
		var collision = get_slide_collision(i)
		if collision.normal != get_floor_normal():
			continue
		if collision.collider_velocity != get_floor_velocity():
			continue
		return collision.collider
	assert(false)
	
func get_ceiling_collision() -> KinematicCollision:
	""" a hacky function to find the floor node """
	assert(is_on_ceiling())
	for i in range(get_slide_count()):
		var collision = get_slide_collision(i)
		if collision.normal == get_floor_normal():
			continue
		if collision.normal.dot(Vector3.UP) >= 0:
			continue
		return collision
	assert(false)
	return null

func apply_rotations(delta, player_dir: Vector3):
	if player_dir != Vector3():
		var basis = Basis()
		var dir_planar = Plane(Vector3.UP, 0).project(player_dir).normalized()
		if dir_planar != Vector3():
			basis.y = -dir_planar
			basis.z = Vector3.UP
			basis.x = basis.y.cross(basis.z)
			player_body.global_transform.basis = basis
		
	if !is_on_floor() or move_mode != MOVE_MODE.NORMAL:
		return

	var ang_vel = PhysicsServer.body_get_direct_state(floor_node.get_rid()).angular_velocity
	if ang_vel == Vector3():
		return
		
	var ang_vertical = ang_vel.project(Vector3.UP)
	var _ang_planar = ang_vel - ang_vertical

	# self.transform.basis = self.transform.basis.rotated(ang_vertical.normalized(), ang_vertical.length()*delta)
	player_body.transform.basis = player_body.transform.basis.rotated(ang_vertical.normalized(), ang_vertical.length()*delta)
	player_body.transform.basis.orthonormalized()
	
	if camera_follows_rotation:
		# Only rotate around UP-axis for camera
		camera_rotation += ang_vel.project(Vector3.UP)*delta
		camera_helper.rotation = camera_rotation

	
	
func move_normal(delta):
	var cam_transform = camera.get_global_transform()
	dir = Vector3.ZERO
	
	if input_movement_vector != Vector2():
		dir += cam_transform.basis.x * input_movement_vector[0]
		dir += -cam_transform.basis.z * input_movement_vector[1]
		dir.y = 0
		dir = dir.normalized()

		if is_on_floor():
			dir = Plane(ground_ray.get_collision_normal(), 0).project(dir)
			# Alternatively, could not normalise this to go slower on inclines
			dir = dir.normalized()
		
		last_dir = dir

	var player_vel = dir * PLAYER_SPEED
	var floor_vel_adjust = improved_floor_velocity_estimate(delta)
		
	if is_on_floor() and jump_frame_buffering > 0:
		gravity_vel.y = JUMP_SPEED
		# `move_and_slide()` adds `get_floor_velocity()` internally so we add
		# `-get_floor_velocity()` to counteract this in `floor_vel_adjust`.
		# However, now we are goin to jump, we won't collide with the floor,
		# so `move_and_slide()` won't add this value internally, so we don't
		# need to cancel it out this time
		floor_vel_adjust += get_floor_velocity()
		jump_frame_buffering = 0
	else:
		var chosen_normal = Vector3.UP
		if is_on_floor():
			# gravity_vel += ground_ray.get_collision_normal() * delta * GRAVITY
			var collision_normal = get_floor_normal()
			var center_normal = ground_ray.get_collision_normal()
			if collision_normal.dot(Vector3.UP) > center_normal.dot(Vector3.UP):
				chosen_normal = collision_normal
			else:
				chosen_normal = center_normal
			gravity_vel += chosen_normal * delta * GRAVITY
			debug_drawer.draw_vector("floor_normal", self, chosen_normal, Vector3(0, 2.5, 0))
		else:
			debug_drawer.draw_vector("floor_normal", self, Vector3(), Vector3(0, 2.5, 0))
		gravity_vel += chosen_normal * delta * GRAVITY
		jump_frame_buffering -= 1
	
	
	if !is_on_floor() and is_on_ceiling():
		var ceil_collision = get_ceiling_collision()
		gravity_vel = 0.5 * ceil_collision.normal * gravity_vel.length()

	vel = player_vel + gravity_vel + floor_vel_adjust * int(use_improved_approximation)
	vel = player.move_and_slide(vel, Vector3.UP, false, MAX_SLIDES, MAX_SLOPE_ANGLE, false)
	
	if is_on_floor():
		floor_node = get_floor_node()
		if use_improved_approximation:
			if floor_node is RigidBody:
				self.transform.origin -= get_floor_displacement()
			else:
				self.transform.origin += get_floor_displacement()
		gravity_vel = Vector3()
	else:
		floor_node = null

func move_no_clip(delta):
	var cam_transform = self.transform.inverse() * camera.global_transform
	dir = Vector3.ZERO
	
	if input_movement_vector != Vector2() or jump_pressed or run_pressed:
		dir += cam_transform.basis.x * input_movement_vector[0]
		dir += -cam_transform.basis.z * input_movement_vector[1]
		if jump_pressed:
			dir += Vector3.UP
		if run_pressed:
			dir -= Vector3.UP
		dir = dir.normalized()

		last_dir = dir
		
	global_transform = global_transform.translated(dir * SPEED_NO_CLIP * delta)

func process_movement(delta):
	
	match move_mode:
		MOVE_MODE.NORMAL:
			move_normal(delta)
		MOVE_MODE.NO_CLIP:
			move_no_clip(delta)

	
	if cube_hold_mode:
		var forward = -player_body.global_transform.basis.y
		var cube_pos = self.global_transform.translated(forward * 5)
		cube_pos.basis = self.player_body.transform.basis
		companion_cube.global_transform = cube_pos

	apply_rotations(delta, dir)
	
	debug_drawer.draw_vector("dir", self, dir, Vector3(0, 2.5, 0))
	DebugInfo.add("floor_node", floor_node.name if floor_node!=null else null)
	# floor_angle behaviour seems weird when the ray cast hits a moving object
	DebugInfo.plot_float("floor angle", rad2deg(acos(ground_ray.get_collision_normal().dot(Vector3.UP))), 0, MAX_SLOPE_ANGLE)
	DebugInfo.plot_float("slide count", get_slide_count(), 0, 4)
	DebugInfo.plot_bool("is_on_floor", is_on_floor())
	# DebugInfo.plot_bool("is_on_ceiling", is_on_ceiling())
	# DebugInfo.plot_bool("is_on_wall", is_on_wall())
	# DebugInfo.plot_float("floor speed", get_floor_velocity().length())
	DebugInfo.plot_float("player speed", get_linear_velocity(self, delta).length())
	
	
func process_input(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.is_action_just_pressed("toggle_vel_func"):
		use_improved_approximation = !use_improved_approximation
		
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

	if is_on_floor() and Input.is_action_just_pressed("movement_jump"):
		jump_frame_buffering = JUMP_BUFFER_FRAME_COUNT
	
	jump_pressed = Input.is_action_pressed("movement_jump")
	run_pressed = Input.is_action_pressed("movement_run")
#	elif Input.is
#	pa
	
	if Input.is_action_just_pressed("no_clip_mode"):
		move_mode = move_mode ^ 1
		gravity_vel = Vector3()
		

var marker_timer: float = 0.0
var last_marker_state = false
func add_position_marker(delta):
	marker_timer += delta
	var this_state = is_on_floor()
	var should_add_marker = marker_timer > 0.1 or (last_marker_state != this_state)
	if should_add_marker:
	
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
