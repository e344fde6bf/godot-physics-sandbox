extends "Plot.gd"

onready var graph = $HBoxContainer/Graph
onready var name_node = $HBoxContainer/VariableName
onready var pulse_label = $HBoxContainer/PulseLabel

func _ready():
	name_node.text = label
	name_node.rect_min_size.x = max(name_node.rect_min_size.x, name_min_width)
	graph.rect_min_size = Vector2(max_size, bot_y)
	self.rect_min_size = graph.rect_min_size
	
	pulse_label.text = "-"
	
	data.resize(max_size)
	for i in range(max_size):
		data[i] = null
	
func _draw():
	var last_i = 0
	var last_val = data[(write_pos - 1) % max_size]
	var pulse = max_size
	var pulse_started = false
	var rec = graph.rect_position
	
	draw_rect(Rect2(rec, graph.rect_min_size), rect_color)
	
	for i in range(data.size()):
		var this_val = data[(write_pos - i - 1) % max_size]
		
		if this_val == last_val:
			continue
		if this_val == null:
			break
		
		var y1 = int(!last_val) * bot_y + int(last_val) * top_y
		var y2 = int(last_val) * bot_y + int(!last_val) * top_y
		draw_line(rec+Vector2(last_i, y1), rec+Vector2(i, y1), line_color)
		draw_line(rec+Vector2(i, y1), rec+Vector2(i, y2), line_color)
		var hold = i - last_i
		if pulse_started and pulse == max_size:
			pulse = hold
		else:
			pulse_started = true
		last_i = i
		last_val = this_val
	
	var y = int(!last_val) * bot_y + int(last_val) * top_y
	var x2 = max_size-1
	draw_line(rec+Vector2(last_i, y), rec+Vector2(x2, y), line_color)
	
	if pulse == max_size:
		pulse_label.text = "-"
	else:
		pulse_label.text = str(pulse)
