shader_type spatial;
// Público con volumen: cada hincha es una persona sentada de pocos polígonos
// (MultiMesh). Ropa y tono de piel por instancia en INSTANCE_CUSTOM (rgb =
// ropa, a = piel). En el modelo, el color de vértice marca las zonas:
// r = piel, g = pelo, b = pantalón. `cheer` los hace saltar en los goles.

uniform float cheer = 0.0;
uniform vec3 skin_light : source_color = vec3(0.93, 0.76, 0.63);
uniform vec3 skin_dark : source_color = vec3(0.4, 0.27, 0.19);

varying vec3 cloth;
varying float skin;
varying float seed;
varying vec3 zone;

void vertex() {
	cloth = INSTANCE_CUSTOM.rgb;
	skin = INSTANCE_CUSTOM.a;
	seed = fract(float(INSTANCE_ID) * 0.6180339);
	zone = COLOR.rgb;
	float idle = sin(TIME * 1.3 + seed * 17.0) * 0.012;
	float jump = max(0.0, sin(TIME * (7.0 + seed * 3.0) + seed * 31.0)) * 0.3 * cheer;
	VERTEX.y += (idle + jump) * step(0.45, VERTEX.y);
}

void fragment() {
	vec3 skin_c = mix(skin_light, skin_dark, skin);
	vec3 hair_c = mix(vec3(0.06, 0.045, 0.035), vec3(0.42, 0.3, 0.14), step(0.82, seed));
	vec3 pants = mix(vec3(0.12, 0.13, 0.17), vec3(0.22, 0.26, 0.38), step(0.5, seed));
	vec3 c = cloth;
	c = mix(c, pants, zone.b);
	c = mix(c, skin_c, zone.r);
	c = mix(c, hair_c, zone.g);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
}
