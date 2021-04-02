extends KinematicBody

export var start_angular_velocity: float = 0.25
export var use_angular_accel: bool = false
export var angular_velocity_limit: float = 0.25
export var angular_accel: float = 0.0
export var rotation_axis: Vector3 = Vector3.UP
export var rotate_limit: int = 0
export var enabled: bool = true

var start_pos: Vector3
var t = 0.0
var current_angle = 0.0
var angular_velocity
var dir = 1.0

func _ready():
	start_pos = self.transform.origin
	rotation_axis = rotation_axis.normalized()
	angular_velocity = start_angular_velocity
	if use_angular_accel:
		assert(rotate_limit == 0)

	process_priority = Globals.ProcessPriorities.Platforms

func _physics_process(delta):
	t += delta

	if not enabled:
		return

	if rotate_limit != 0:
		if current_angle > deg2rad(rotate_limit):
			dir *= -1
			current_angle = deg2rad(rotate_limit)
		elif current_angle < 0.0:
			dir *= -1
			current_angle = 0.0

	if use_angular_accel:
		angular_velocity += dir * angular_accel * delta
		if dir*angular_velocity > angular_velocity_limit:
			angular_velocity = angular_velocity_limit
			dir *= -1

	var rotate_delta = 2 * PI * dir * angular_velocity * delta
	current_angle += rotate_delta
	self.transform.basis = self.transform.basis.rotated(rotation_axis, rotate_delta)
