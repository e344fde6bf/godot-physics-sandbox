extends Control

var data: Array

export var label = "variable"
export var line_color = Color(1.0, 1.0, 1.0, 1)
export var rect_color = Color(0.0, 0.0, 0.0, 0.5) 
export var name_min_width: float = 0.0

var top_y = 2
var bot_y = 20
var write_pos = 0
var max_size = 120
var num_data_points_collected = 0
var y_min
var y_max
var plot_min
var plot_max

func set_default_bounds(y_min_, y_max_):
	y_min = y_min_
	y_max = y_max_

func set_graph_size(height = 20,  top_margin = 1):
	top_y = top_margin
	bot_y = height

func add_data_point(value):
	data[write_pos] = value
	write_pos = (write_pos + 1) % max_size
	num_data_points_collected += 1
