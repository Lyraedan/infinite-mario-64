shader_type spatial;

render_mode unshaded;

uniform vec3 death_color : source_color = vec3(1.0, 0.2, 0.2);

void vertex() {
}

void fragment() {
	ALBEDO = death_color;
	ALPHA = max(0.0, 0.5 - length(VERTEX) * 0.01);
}
