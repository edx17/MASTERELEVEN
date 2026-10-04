shader_type spatial;
render_mode unshaded, cull_disabled;
// Anillo / cinta LED del estadio: franjas de los dos colores del club que
// corren a lo largo (UV.x = recorrido en decenas de metros) y un pulso suave.

uniform vec3 color_a : source_color = vec3(0.2, 0.5, 1.0);
uniform vec3 color_b : source_color = vec3(1.0);
uniform float speed = 0.8;
uniform float stripes = 60.0;
uniform float energy = 2.2;

void fragment() {
	float t = UV.x * 10.0 / stripes + TIME * speed * 0.05;
	float band = smoothstep(0.35, 0.65, fract(t * 4.0));
	vec3 c = mix(color_a, color_b, band);
	// Puntos del LED (se ven de cerca; de lejos se funden).
	float dots = 0.85 + 0.15 * step(0.5, fract(UV.x * 120.0)) * step(0.5, fract(UV.y * 6.0));
	ALBEDO = c * energy * dots;
}
