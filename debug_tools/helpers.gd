# Helper for storing 

class OrderedMap:
	var data = []
	var label_to_index = {}
	var index_to_label = {}
	
	func clear():
		data = []
		label_to_index = {}
		index_to_label = {}
	
	func get(label: String):
		return data[label_to_index[label]]
	
	func add(label: String, value):
		if label in label_to_index:
			data[label_to_index[label]] = value
		else:
			var new_index = data.size()
			label_to_index[label] = new_index
			index_to_label[new_index] = label
			data.append(value)
	
	func has_label(label: String):
		return label in label_to_index
