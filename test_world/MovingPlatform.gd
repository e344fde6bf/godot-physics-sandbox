extends KinematicBody

enum MOTION_TYPE {
	LINEAR,
	STEP,
	QUADRATIC,
	SINUSOIDAL,
}

export var accel: float = 2.0
export(MOTION_TYPE) var motion_type = MOTION_TYPE.SINUSOIDAL
export var move_dir: Vector3 = Vector3(0, 0, 1)
export var step: float = 5.0

export var move_limit: float = 50.0
export var enabled: bool = true
export var is_printing: bool = false

var vel = 0.0
var start_pos: Vector3
var t = 0.0

func _ready():
	start_pos = transform.origin
	move_dir = move_dir.normalized()
	
	

func _physics_process(delta):
	if !enabled:
		return
	t += delta
		
	var current_pos = (transform.origin - start_pos).dot(move_dir)
	if (current_pos > move_limit and accel > 0) or (current_pos < -move_limit and accel < 0):
		vel = 0
		accel *= -1.0
	elif motion_type == MOTION_TYPE.SINUSOIDAL:
		transform.origin = start_pos + move_dir * move_limit * sin(t * accel)
	elif motion_type == MOTION_TYPE.QUADRATIC:
		vel += accel * delta
		var _unused = move_and_slide(move_dir * vel, Vector3.UP)
	elif motion_type == MOTION_TYPE.LINEAR:
		vel = accel
		transform.origin += move_dir * vel * delta
	elif motion_type == MOTION_TYPE.STEP:
		vel += accel * delta
		var vel_step
		if accel < 0.0:
			vel_step = ceil(vel / step) * step 
		else:
			vel_step = floor(vel / step) * step 
		transform.origin += move_dir * vel_step * delta
