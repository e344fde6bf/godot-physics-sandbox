extends Control

export var label = "variable"

onready var graph = $HBoxContainer/Graph
onready var name_node = $HBoxContainer/VBoxContainer/VariableName
onready var current_value_label = $HBoxContainer/VBoxContainer/CurrentValue
onready var min_label = $HBoxContainer/VBoxMinMax/MinLabel
onready var max_label = $HBoxContainer/VBoxMinMax/MaxLabel

var data: Array

export var line_color = Color(1.0, 1.0, 1.0, 1)
export var rect_color = Color(0.0, 0.0, 0.0, 0.5) 
export var name_min_width: float = 0.0

var TOP_Y = 2
var BOT_Y = 40
var write_pos = 0
var max_size = 120
var num_data_points_collected = 0


var y_min = 0.0
var y_max = 1.0
var plot_min = y_min
var plot_max = y_max

func _ready():
	name_node.text = label
	name_node.rect_min_size.x = max(name_node.rect_min_size.x, name_min_width)
	graph.rect_min_size = Vector2(max_size, BOT_Y)
	self.rect_min_size = graph.rect_min_size
	
	min_label.text = "-"
	max_label.text = "-"
	
	data.resize(max_size)
	for i in range(max_size):
		data[i] = null
	
func add_data_point(value: float, y_min_ = 0.0, y_max_ = 1.0):
	data[write_pos] = value
	write_pos = (write_pos + 1) % max_size
	self.y_min = y_min_
	self.y_max = y_max_
	num_data_points_collected += 1

func _draw():
	var last_i = 0
	var last_val = data[(write_pos - 1) % max_size]
	var min_value = INF
	var max_value = -INF
	var scale = BOT_Y / (plot_max - plot_min)
	var rec = graph.rect_position
	var final_i
	if num_data_points_collected < max_size:
		final_i = (num_data_points_collected-1) % max_size
	else:
		final_i = (max_size - 1)
	
	
	if num_data_points_collected < 2:
		return
	
	current_value_label.text = str(last_val)
	
	draw_rect(Rect2(rec, graph.rect_min_size), rect_color)
	
	for i in range(data.size()):
		var this_val = data[(write_pos - i - 1) % max_size]
		
		if this_val == last_val and i != final_i:
			continue
		if this_val == null:
			break

		var y1 = BOT_Y + -(clamp(last_val, plot_min, plot_max) - plot_min) * scale
		var y2 = BOT_Y + -(clamp(this_val, plot_min, plot_max) - plot_min) * scale
		if i - last_i > 1:
			draw_line(rec+Vector2(last_i, y1), rec+Vector2(i, y1), line_color)
		draw_line(rec+Vector2(i-1, y1), rec+Vector2(i, y2), line_color)
		
		min_value = min(min_value, this_val)
		max_value = max(max_value, this_val)

		last_i = i
		last_val = this_val
	
	min_label.text = str(min_value)
	max_label.text = str(max_value)
	
	plot_min = min(y_min, min_value)
	plot_max = max(y_max, max_value)
