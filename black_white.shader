shader_type spatial;
// render_mode unshaded;

void fragment() {
	float a = 10.0;
	float b = 10.0;
	// int stuff = int(a*UV.x + b*UV.y);
	int stuff = int(UV.x < 0.5);
	if (stuff % 2 == 0) {
		ALBEDO = vec3(1.0, 1.0, 1.0);
	} else {
		float s = 0.05;
		ALBEDO = vec3(s, s, s);
	}
	
}