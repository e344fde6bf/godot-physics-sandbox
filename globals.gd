extends Node

enum CollisionLayers {
	WALLS = 0,
	PLAYER = 1,
	RIGID = 2,
}

enum PhysicsEngine {
	BULLET,
	GODOT,
}

enum ProcessPriorities {
	Platforms = -100,
	Rigid = 0,
	Player = +100,
}

var physics_engine

func _ready():
	physics_engine = get_physics_engine()

func get_physics_engine():
	match ProjectSettings.get_setting("physics/3d/physics_engine"):
		"GodotPhysics":
			return PhysicsEngine.GODOT
		"Default", "Bullet":
			return PhysicsEngine.BULLET
		_:
			assert(false)

func collision_mask_set(node, layer):
	node.collision_mask |= (1 << layer)

func collision_mask_clear(node, layer):
	node.collision_mask &= ~(1 << layer)

func collision_layer_set(node, layer):
	node.collision_layer |= (1 << layer)

func collision_layer_clear(node, layer):
	node.collision_layer &= ~(1 << layer)
