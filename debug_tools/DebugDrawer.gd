extends Spatial

const debug_helpers = preload("helpers.gd")
const OrderedMap = debug_helpers.OrderedMap

const DebugVector = preload("geometry/DebugVector.tscn")

var vector_data

func _ready():
	vector_data = OrderedMap.new()
	
func draw_vector(label: String, parent: Node, vector: Vector3, offset=Vector3(), scale=1.0, color=null):
	if !vector_data.has_label(label):
		var vec = DebugVector.instance()
		parent.add_child(vec)
		vector_data.add(label, vec)
	vector_data.get(label).orient_vector(vector, offset, scale, color)
