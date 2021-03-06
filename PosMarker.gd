extends MeshInstance

onready var time_to_live = $TimeToLive

func _ready():
	time_to_live.start()
	
func set_color(color: Color):
	var new_material = SpatialMaterial.new()
	new_material.albedo_color = color
	self.material_override = new_material

func _on_TimeToLive_timeout():
	queue_free()
