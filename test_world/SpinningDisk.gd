extends KinematicBody

export var angular_velocity: float = 0.25
export var rotation_axis: Vector3 = Vector3.UP
export var rotate_limit: int = 0
export var enabled: bool = true

var start_pos: Vector3
var t = 0.0
var current_angle = 0.0
var dir = 1.0

func _ready():
	start_pos = self.transform.origin
	rotation_axis = rotation_axis.normalized()

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
	current_angle += dir * delta * 2 * PI * angular_velocity
		
	self.transform.basis = self.transform.basis.rotated(rotation_axis, dir * delta * 2 * PI * angular_velocity)
