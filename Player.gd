extends KinematicBody

enum MoveMode {
	BASIC = 0,
	NO_CLIP = 1,
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
const NO_CLIP_ACCEL = 150
const NO_CLIP_SPEED = 100

const CUBE_GRAB_DISTANCE_MIN = 4
const CUBE_GRAB_DISTANCE_MAX = 50
const CUBE_PUSH_PULL_SPEED = 1
const CUBE_CLONE_REPEAT_DELAY = 0.5
const CUBE_CLONE_REPEAT_RATE = 0.1
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
export var enable_slide_collision_printing = false

onready var player = $"."
# onready var player_body = $PlayerBody
onready var camera_helper = $CameraHelper
onready var camera = $CameraHelper/CameraPosition/Camera
onready var camera_position = $CameraHelper/CameraPosition
onready var shape_selector = $ShapeSelector
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
var buffered_is_on_floor: int = 0

var floor_node = null
var floor_normal_fixup_rotation: Basis
var floor_last_transform

var cube_grabbed = false
var cube_grab_distance = 5.0
var cube_grab_height = 0.0
var cube_clone_repeat_time = 0.0
var cube_clone_pressed = false
var move_mode = MoveMode.BASIC
var is_squished
var model_should_rotate = false

var marker_timer: float = 0.0
var last_marker_state = false
var ignored_floor_body = null

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	call_deferred("set_camera_distance", camera_distance)
	set_shape(shape_selector.ObjectShape.CAPSULE)

	var steepness_mat = load("res://assets/materials/steepness_material.tres")
	steepness_mat.set_shader_param("limit_angle_deg", rad2deg(MAX_SLOPE_ANGLE + FLOOR_ANGLE_THRESHOLD))

	process_priority = Globals.ProcessPriorities.Player
	assert(player_body != null)

func _physics_process(delta):
	DebugInfo.add("enable_fixes", enable_fixes)
	DebugInfo.add("max slope deg", rad2deg(MAX_SLOPE_ANGLE + FLOOR_ANGLE_THRESHOLD))
	process_input()
	process_movement(delta)
	add_position_marker(delta)

func set_shape(shape_id):
	player_body = shape_selector.set_shape(self, shape_id)

func set_camera_distance(new_distance):
	assert(new_distance > 0)
	camera_distance = new_distance
	if camera_position != null:
		camera_position.transform.origin.z = camera_distance
	return camera_distance

## Get the PhysicsServer's angular velocity for the given node
func get_angular_velocity(node):
	return PhysicsServer.body_get_direct_state(node.get_rid()).angular_velocity

## How much a kinematic body has moved since the start of frame
func get_linear_displacement_kinematic(node):
	var start_pos = PhysicsServer.body_get_direct_state(node.get_rid()).transform.origin
	return node.global_transform.origin - start_pos

## How much a kinematic body has rotated since the start of frame
func get_rotation_difference_kinematic(kinematic):
	var start_basis = PhysicsServer.body_get_direct_state(kinematic.get_rid()).transform.basis
	var end_basis = kinematic.global_transform.basis
	return get_rotation_difference(start_basis, end_basis)

func get_linear_velocity_kinematic(node, delta):
	return get_linear_displacement_kinematic(node) / delta

func get_rotation_difference(start_basis, end_basis):
	return end_basis.orthonormalized() * start_basis.orthonormalized().transposed()

## The distance a point rotates in a refrence frame (without linear displacement)
## between sof_transform and new_transform
func get_rotation_displacement(sof_transform, new_transform, point):
	var rot = get_rotation_difference(sof_transform.basis, new_transform.basis)

	# centre of rotation at start of frame
	var rotation_origin = sof_transform.origin
	# our current position
	var position_relative = point - rotation_origin
	var position_relative_next = rot.xform(position_relative)
	return position_relative_next - position_relative

## Calculates total linear displacement a point will move as if it was in another
## reference frame.
## sof_transform: the start of frame transform (global) of the refrence frame
## new_transform: the updated transform (global) of the reference frame
## position: the global position of the point
func get_refrence_frame_displacement(sof_transform, new_transform, point):
	var linear_disp = new_transform.origin - sof_transform.origin
	var rotate_disp = get_rotation_displacement(sof_transform, new_transform, point)
	return linear_disp + rotate_disp

## Get the distance a point will move in the kinematic bodies reference frame
## NOTE: works with StaticBody as well as KinematicBody
## NOTE: can't compute this by storing the `floor_last_transform` like the rigid body
## calculation does because of this bug: https://github.com/godotengine/godot/issues/30481
func get_floor_displacement_kinematic(body, point):
	# Kinematic bodies don't update their transform in the physics server until the end of the frame
	var sof_transform = PhysicsServer.body_get_direct_state(body.get_rid()).transform
	# Kinematic bodies update their global_transform property immediately
	var new_transform = body.global_transform
	return get_refrence_frame_displacement(sof_transform, new_transform, point)

## Calculates the distance the floor has moved since last frame if it is a rigid body
func get_floor_displacement_rigid(point):
	var new_transform = PhysicsServer.body_get_direct_state(floor_node.get_rid()).transform
	return get_refrence_frame_displacement(floor_last_transform, new_transform, point)

## Follow the floors movement using the given displacement
func move_with_floor_displacement(disp):
	add_collision_exception_with(floor_node)
	var collision = move_and_collide(disp, false)
	remove_collision_exception_with(floor_node)

	if is_on_wall() or collision != null:
		model_should_rotate = false

	if is_on_floor() and collision != null:
		var col_dot_prod = collision.normal.dot(get_floor_normal_fixed())
		is_squished = bool(col_dot_prod < -0.9) and \
				(collision.collider_velocity-get_floor_velocity()).length_squared() > 0.01

## a hacky function to find the floor node
func get_floor_node():
	assert(is_on_floor())
	for i in range(get_slide_count()):
		var collision = get_slide_collision(i)
		if collision.normal != get_floor_normal():
			continue
		if collision.collider_velocity != get_floor_velocity():
			continue
		return collision.collider
	assert(false)

func ignore_rigid_collisions():
	set_collision_mask_bit(Globals.CollisionLayers.RIGID, false)

func enable_rigid_collisions():
	set_collision_mask_bit(Globals.CollisionLayers.RIGID, true)

func apply_rigid_forces():
	for i in get_slide_count():
		var col = get_slide_collision(i)
		if col.collider is RigidBody:
			var collider := (col.collider as RigidBody)
			var pos = (col.position - collider.global_transform.origin)
			# TODO: do this better
			# take into account collision angle
			# our velocity etc
			collider.add_force(Vector3(0, -10 * 50, 0), pos)

## Since we collided with the floor using its start of frame position, need to
## rotate the floor normal to match the floors new orientation
func get_floor_normal_fixed():
	return floor_normal_fixup_rotation.xform(get_floor_normal())

## The rotation the floor under went from the start of frame
func set_floor_normal_fixup_rotation():
	if floor_node is  RigidBody:
		# rigid body
		var old_basis = floor_last_transform.basis
		var new_basis = PhysicsServer.body_get_direct_state(floor_node.get_rid()).transform.basis
		floor_normal_fixup_rotation = get_rotation_difference(old_basis, new_basis)
	else:
		floor_normal_fixup_rotation = get_rotation_difference_kinematic(floor_node)

## Rotate the players model, and rotate the camera if we are standing on a floor that is rotating
func apply_rotations(delta, player_dir: Vector3):
	var start_rot = Quat(player_body.transform.basis)
	var desired_rot
	if player_dir == Vector3() or abs(player_dir.dot(Vector3.UP))>= 0.99:
		desired_rot = start_rot
	elif player_dir != Vector3():
		var basis = Basis()
		var dir_planar = Plane(Vector3.UP, 0).project(player_dir).normalized()
		if dir_planar != Vector3():
			if current_player_shape == shape_selector.ObjectShape.CAPSULE:
				basis.y = -dir_planar
				basis.z = -Vector3.UP
				basis.x = basis.y.cross(basis.z)
			else:
				basis.z = -dir_planar
				basis.y = Vector3.UP
				basis.x = basis.y.cross(basis.z)
		desired_rot = Quat(basis)

	player_body.transform.basis = Basis(start_rot.slerp(desired_rot, 20*delta))

	if !is_on_floor() or move_mode != MoveMode.BASIC:
		return

	var ang_vel = Vector3()
	if floor_node is RigidBody:
		ang_vel = floor_node.angular_velocity
	else:
		ang_vel = get_angular_velocity(floor_node)

	DebugInfo.add("angular_velocity", ang_vel)
	if ang_vel == Vector3() or not model_should_rotate or floor_node is RigidBody:
		return

	# TODO: can't really handle angular velocity of rigid bodies this way since
	# the amount that they have rotate doesn't correspond to angular_velocity * delta
	# Instead should use the differece between their bases between frames to figure
	# out how much to rotate the player/camera

	var ang_vertical = ang_vel.project(Vector3.UP)
	if not ang_vertical.is_equal_approx(Vector3()):
		player_body.transform.basis = player_body.transform.basis.rotated(ang_vertical.normalized(), ang_vertical.length()*delta)
		player_body.transform.basis = player_body.transform.basis.orthonormalized()

	if camera_follows_rotation:
		camera_rotation += ang_vertical*delta
		camera_helper.rotation = camera_rotation

func move_basic(delta):
	var cam_basis = camera.get_global_transform().basis
	dir = Vector3.ZERO
	model_should_rotate = true

	enable_rigid_collisions()

	var floor_vel_adjust = -get_floor_velocity()
	if !enable_fixes:
		floor_vel_adjust = Vector3()
	else:
		if floor_node is RigidBody and not cube_grabbed:
			set_floor_normal_fixup_rotation()
			var disp = get_floor_displacement_rigid(self.global_transform.origin)
			move_with_floor_displacement(disp)

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

	var this_dir
	if dir != Vector3():
		this_dir = dir
		fake_speed = min(fake_speed+PLAYER_ACCEL * delta, PLAYER_MAX_SPEED)
	else:
		fake_speed *= pow(1e-6, delta / PLAYER_STOPPING_TIME)
		this_dir = last_dir
	var player_vel = fake_speed * this_dir
	var start_vel = player_vel + gravity_vel
	var vel = start_vel + floor_vel_adjust

	var _out_vel = move_and_slide(\
			vel,
			Vector3.UP,
			stop_on_slope,
			MAX_SLIDES,
			MAX_SLOPE_ANGLE,
			false # infinite inertia
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
		DebugInfo.plot_bool("retrying", retry_without_vel_adjust)

	# we 'corrupted' the velocity value with floor_vel_adjust, so remove its effect here
	_out_vel += -Plane(get_floor_normal(),0).project(floor_vel_adjust)

	var follow_platform = (floor_node != null) or is_on_floor()

	if is_on_floor():
		buffered_is_on_floor = FLOOR_BUFFER_FRAME_COUNT
		floor_node = get_floor_node()
		floor_last_transform = PhysicsServer.body_get_direct_state(floor_node.get_rid()).transform
		gravity_vel = Vector3()

	is_squished = false
	if follow_platform and enable_fixes:
		if not (floor_node is RigidBody):
			# Since we collided with the kinematic/static body using its start
			# of frame position, we need to update our position based on where
			# the floor node moved to this frame
			set_floor_normal_fixup_rotation()
			var disp = get_floor_displacement_kinematic(floor_node, self.global_transform.origin)
			move_with_floor_displacement(disp)

	if !is_on_floor():
		buffered_is_on_floor -= 1
		floor_node = null
		floor_last_transform = null

	# apply rigid forces
	apply_rigid_forces()

	ignore_rigid_collisions()

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

	if dir != Vector3():
		fake_speed += NO_CLIP_ACCEL * delta
	else:
		fake_speed = 0
	fake_speed = clamp(fake_speed, 0, NO_CLIP_SPEED)
	global_transform = global_transform.translated(dir * fake_speed * delta)

func print_slide_collisions():
	if move_mode == MoveMode.NO_CLIP:
		return

	var start_position = PhysicsServer.body_get_direct_state(get_rid()).transform.origin
	for i in MAX_SLIDES:
		var slide_pos_rel = ""
		var slide_normal = ""
		var slide_remainder = ""
		var slide_travel = ""
		if i < get_slide_count():
			var collision = get_slide_collision(i)
			slide_pos_rel = (collision.position - start_position)
			slide_normal = (collision.normal)
			slide_remainder = (collision.remainder)
			slide_travel = (collision.travel)

		DebugInfo.add("slide%d.col_pos" % [i], slide_pos_rel)
		DebugInfo.add("slide%d.remainder" % [i], slide_remainder)
		DebugInfo.add("slide%d.travel" % [i], slide_travel)
		DebugInfo.add("slide%d.normal" % [i], slide_normal)

func toggle_cube_grabbed():
	cube_grabbed = !cube_grabbed
	companion_cube.set_cube_grabbed(cube_grabbed)
	if cube_grabbed and floor_node == companion_cube:
		floor_node = null
		floor_last_transform = null

func drag_cube():
	if not cube_grabbed:
		return

	var forward = -camera_helper.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var cube_pos = self.global_transform.translated(forward * cube_grab_distance + Vector3.UP * cube_grab_height)
	cube_pos.basis = self.player_body.transform.basis
	companion_cube.global_transform = cube_pos

func clone_cube(delta):
	if not cube_clone_pressed:
		return

	cube_clone_repeat_time -= delta
	if cube_clone_repeat_time < 0.0:
		companion_cube.clone()
		cube_clone_repeat_time = CUBE_CLONE_REPEAT_RATE

func process_movement(delta):
	match move_mode:
		MoveMode.BASIC:
			move_basic(delta)
		MoveMode.NO_CLIP:
			move_no_clip(delta)

	drag_cube()
	clone_cube(delta)
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

	if enable_slide_collision_printing:
		print_slide_collisions()

	DebugInfo.plot_float("slide count", get_slide_count(), 0, 4)
	DebugInfo.plot_bool("is_on_floor", is_on_floor())
#	DebugInfo.plot_bool("is_squished", is_squished)
	DebugInfo.plot_bool("is_on_ceiling", is_on_ceiling())
	DebugInfo.plot_bool("is_on_wall", is_on_wall())
	DebugInfo.plot_float("floor speed", get_floor_velocity().length(), 0, 30)
	DebugInfo.plot_float("fake_speed", fake_speed, 0, 20)
	DebugInfo.plot_float("player speed", get_linear_velocity_kinematic(self, delta).length(), 0, 30)
#	DebugInfo.plot_float("buffered on floor", clamp(buffered_is_on_floor, 0, FLOOR_BUFFER_FRAME_COUNT))
#	DebugInfo.plot_float("buffered jump", clamp(jump_frame_buffering, 0, JUMP_BUFFER_FRAME_COUNT))


func process_input():
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

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

	if Input.is_action_just_pressed("cube_hold_mode"):
		toggle_cube_grabbed()
		cube_grab_height = 0.0
	if Input.is_action_just_pressed("cube_hold_clone"):
		if cube_grabbed:
			companion_cube.clone()
			cube_clone_repeat_time = CUBE_CLONE_REPEAT_DELAY
			cube_clone_pressed = true
	if Input.is_action_just_released("cube_hold_clone"):
		cube_clone_pressed = false
	if Input.is_action_just_pressed("change_rigid_shape"):
		companion_cube.next_shape()
	if Input.is_action_just_pressed("no_clip_mode"):
		move_mode = move_mode ^ 1
		gravity_vel = Vector3()
		floor_node = null
		var _ignore = move_and_slide(Vector3()) # clear move_and_slide is_on_floor() etc

	if Input.is_action_just_pressed("debug_button_1"):
		current_player_shape = shape_selector.next_shape_id(current_player_shape)
		set_shape(current_player_shape)
	if Input.is_action_just_pressed("debug_button_2"):
		camera_rotation.y = PI/2 * floor((camera_rotation.y + PI/4) / (PI/2))
		camera_helper.rotation = camera_rotation
#		camera_rotation.x = 0
#		camera_rotation.y = PI/2 * floor((camera_rotation.y + PI/4) / (PI/2))
#		camera_helper.rotation = camera_rotation
	if Input.is_action_just_pressed("debug_button_3"):
		use_pos_marker = !use_pos_marker
	if Input.is_action_just_pressed("debug_button_4"):
		floor_normal_fixup_rotation = Basis()
		enable_fixes = !enable_fixes

## Add a markers to track the players position and is_on_floor() state
func add_position_marker(delta):
	marker_timer += delta
	var this_state = is_on_floor()
	var should_add_marker = marker_timer > 0.1 or (last_marker_state != this_state)
	if should_add_marker and move_mode != MoveMode.NO_CLIP and use_pos_marker:

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
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_WHEEL_DOWN:
			if Input.is_action_pressed("cube_hold_push_pull_vertical_modifier"):
				cube_grab_height -= CUBE_PUSH_PULL_SPEED
			else:
				cube_grab_distance -= CUBE_PUSH_PULL_SPEED
				cube_grab_distance = clamp(cube_grab_distance, CUBE_GRAB_DISTANCE_MIN, CUBE_GRAB_DISTANCE_MAX)
		if event.button_index == BUTTON_WHEEL_UP:
			if Input.is_action_pressed("cube_hold_push_pull_vertical_modifier"):
				cube_grab_height += CUBE_PUSH_PULL_SPEED
			else:
				cube_grab_distance += CUBE_PUSH_PULL_SPEED
				cube_grab_distance = clamp(cube_grab_distance, CUBE_GRAB_DISTANCE_MIN, CUBE_GRAB_DISTANCE_MAX)
