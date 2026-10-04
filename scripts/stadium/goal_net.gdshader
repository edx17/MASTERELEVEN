shader_type spatial;
render_mode unshaded, cull_disabled;
// Red del arco: grilla de líneas que se infla donde pega la pelota. El bulto
// es una campana alrededor del punto de impacto, empujando cada paño hacia
// afuera (fondo hacia atrás, costados hacia el costado, techo hacia arriba).
// Los bordes fijos (los palos y el piso) no se mueven.

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.55);
uniform vec3 hit_pos = vec3(0.0);
uniform float bulge = 0.0;
uniform float radius = 0.9;
uniform float side = 1.0;
uniform float front_x = 52.5;
uniform float back_x = 54.5;
uniform float half_w = 3.66;
uniform float height = 2.44;

void vertex() {
	vec3 v = VERTEX;
	float d = distance(v, hit_pos);
	float w = exp(-d * d / (radius * radius));
	// Anclado al frente (palos y travesaño) y al piso.
	float anchor = clamp(abs(v.x - front_x) / 0.6, 0.0, 1.0) * clamp(v.y / 0.35, 0.0, 1.0);
	vec3 n = vec3(0.0, 1.0, 0.0);
	if (abs(v.x - back_x) < 0.02) {
		n = vec3(side, 0.0, 0.0);
	} else if (abs(abs(v.z) - half_w) < 0.02) {
		n = vec3(0.0, 0.0, sign(v.z));
	}
	VERTEX += n * bulge * w * anchor;
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
