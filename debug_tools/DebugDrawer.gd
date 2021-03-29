extends Spatial

const debug_helpers = preload("helpers.gd")
const OrderedMap = debug_helpers.OrderedMap

const DebugVector = preload("geometry/DebugVector.tscn")

var vector_data

func _ready():
	vector_data = OrderedMap.new()

func draw_vector(label: String, parent: Node, vector: Vector3, offset=Vector3(), color=null, scale_=1.0, max_size=null):
	if !vector_data.has_label(label):
		var vec = DebugVector.instance()
		parent.add_child(vec)
		vector_data.add(label, vec)
	vector_data.get(label).orient_vector(vector, offset, color, scale_, max_size)

func draw_basis(label: String, parent: Node, basis: Basis, offset=Vector3(), _color=null, scale_=1.0, max_size=null):
	draw_vector(label+".x", parent, basis.x, offset+basis.x*0.5, Color(1, 0, 0), scale_, max_size)
	draw_vector(label+".y", parent, basis.y, offset+basis.y*0.5, Color(0, 1, 0), scale_, max_size)
	draw_vector(label+".z", parent, basis.z, offset+basis.z*0.5, Color(0, 0, 1), scale_, max_size)
