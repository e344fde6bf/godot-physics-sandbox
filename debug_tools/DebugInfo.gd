extends Container

enum UpdateMethod {
	PHYSICS_PROCESS,
	PROCESS,
	MANUAL,
	NONE,
}

const bool_plot = preload("plot/BoolPlot.tscn")
const float_plot = preload("plot/FloatPlot.tscn")

const debug_helpers = preload("helpers.gd")
const OrderedMap = debug_helpers.OrderedMap

export var label_min_width: float = 100.0
export var text_bg_color = Color(0.0, 0.0, 0.0, 0.2)

var active_node = null
var is_in_tree = false
var is_singleton = false
var text_bg_node: Node = null
var text_info_node: Node = null
var item_list_node: Node = null
var panel_style: StyleBoxFlat
var update_method
var info_data
var plot_data

func _ready():
	# check if this script is autoloaded / the global singleton
	if get_parent() == get_tree().root and self != get_tree().current_scene:
		is_singleton = true
		set_process_method(UpdateMethod.PHYSICS_PROCESS)
	else:
		panel_style = StyleBoxFlat.new()
		panel_style.bg_color = text_bg_color
		text_bg_node = $TextPanel
		text_bg_node.add_stylebox_override("panel", panel_style)
		text_info_node = $TextPanel/VBoxContainer/TextInfo
		item_list_node = $TextPanel/VBoxContainer/DebugPlots
		set_process_method(UpdateMethod.NONE)
		
		# if we aren't the singleton and it exists, add ourself as its active node
		if get_tree().root.get_node("DebugInfo") != null:
			DebugInfo.active_node = self
		self.active_node = self
		
	info_data = OrderedMap.new()
	plot_data = OrderedMap.new()
	
func set_process_method(method):
	set_physics_process(false)
	set_process(false)
	update_method = method
	match method:
		UpdateMethod.PHYSICS_PROCESS:
			set_physics_process(true)
		UpdateMethod.PROCESS:
			set_process(true)
		UpdateMethod.NONE, \
		UpdateMethod.MANUAL:
			pass
		_:
			assert(false)

func _process(_delta):
	update()

func _physics_process(_delta):
	update()

func add(label: String, value):
	info_data.add(label, str(value))

func plot_bool(label: String, value: bool):
	if plot_data.has_label(label):
		plot_data.get(label).add_data_point(value)
	else:
		var plot = bool_plot.instance()
		plot.label = label
		plot.name_min_width = label_min_width
		active_node.item_list_node.add_child(plot)
		plot.add_data_point(value)
		plot_data.add(label, plot)
		
func plot_float(label: String, value: float, y_min = 0.0, y_max = 1.0):
	if plot_data.has_label(label):
		var plot = plot_data.get(label)
		plot.set_default_bounds(y_min, y_max)
		plot.add_data_point(value)
	else:
		var plot = float_plot.instance()
		plot.label = label
		plot.name_min_width = label_min_width
		plot.set_default_bounds(y_min, y_max)
		active_node.item_list_node.add_child(plot)
		plot.add_data_point(value)
		plot_data.add(label, plot)
		
func plot_vec3(label: String, value: Vector3, y_min = 0.0, y_max = 1.0):
	if plot_data.has_label(label+".x"):
		plot_data.get(label+".x").add_data_point(value.x, y_min, y_max)
		plot_data.get(label+".y").add_data_point(value.y, y_min, y_max)
		plot_data.get(label+".z").add_data_point(value.z, y_min, y_max)
	else:
		var plot_x = float_plot.instance()
		var plot_y = float_plot.instance()
		var plot_z = float_plot.instance()
		plot_x.label = label + ".x"
		plot_y.label = label + ".y"
		plot_z.label = label + ".z"
		plot_x.name_min_width = label_min_width
		plot_y.name_min_width = label_min_width
		plot_z.name_min_width = label_min_width
		active_node.item_list_node.add_child(plot_x)
		active_node.item_list_node.add_child(plot_y)
		active_node.item_list_node.add_child(plot_z)
		plot_x.add_data_point(value.x, y_min, y_max)
		plot_y.add_data_point(value.y, y_min, y_max)
		plot_z.add_data_point(value.z, y_min, y_max)
		plot_data.add(label+".x", plot_x)
		plot_data.add(label+".y", plot_y)
		plot_data.add(label+".z", plot_z)

func update():
	var result = ""
	if info_data.data.size() >= 1:
		var label = info_data.index_to_label[0]
		result += "%s: %s" % [label, info_data.data[info_data.label_to_index[label]]]
	for i in info_data.data.size()-1:
		var label = info_data.index_to_label[i+1]
		result += "\n%s: %s" % [label, info_data.data[info_data.label_to_index[label]]]
	

	active_node.text_info_node.text = result
	# active_node.text_bg_node.rect_size = active_node.text_info_node.rect_size
	# active_node.text_bg_node.rect_min_size = active_node.text_bg_node.rect_size
	# active_node.text_bg_node.rect_size.y += 3
	
	for i in plot_data.data.size():
		plot_data.data[i].update()

