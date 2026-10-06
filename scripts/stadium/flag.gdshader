shader_type spatial;
render_mode cull_disabled;
// Bandera que flamea: la orilla del mástil (UV.x = 0) queda fija y la ola
// crece hacia la punta.

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float phase = 0.0;

void vertex() {
	float k = UV.x;
	VERTEX.z += sin(TIME * 4.0 + UV.x * 5.0 + phase) * 0.14 * k;
	VERTEX.y += sin(TIME * 3.1 + UV.x * 3.0 + phase) * 0.04 * k;
}

void fragment() {
	ALBEDO = texture(tex, UV).rgb;
	ROUGHNESS = 0.85;
}
