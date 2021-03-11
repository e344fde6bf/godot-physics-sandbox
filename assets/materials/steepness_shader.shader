shader_type spatial;
// render_mode unshaded;

const float PI = 3.14159265358979;
uniform float limit_angle_deg = 60.0;
uniform float color_change_rate = 4.0;
uniform vec4 steep_color = vec4(1.0, 0.0, 0.0, 1.0);

varying vec3 slope_normal;

void vertex() {
	slope_normal = (WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	float limit = limit_angle_deg * (PI / 180.0);
	float slope_dot = dot(slope_normal, vec3(0.0, 1.0, 0.0));
	float slope_angle = acos(slope_dot);
	float steepness = (slope_angle - limit) / (PI/2.0 - limit);
	ALBEDO.rgb = steep_color.rgb * exp(-steepness * color_change_rate);
	// ALBEDO.rgb = steep_color.rgb * smoothstep(1.0, 0.0, steepness);
	// ALPHA = steep_color.a * float((slope_angle > limit) && (slope_dot > 0.0));
	ALPHA = steep_color.a * float(!(slope_angle < limit));
}