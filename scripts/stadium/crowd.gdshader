shader_type spatial;
// Público: cada persona es una instancia (MultiMesh) con el color de su ropa y
// su tono de piel en INSTANCE_CUSTOM (rgb = ropa, a = piel). En el modelo, el
// canal rojo del color de vértice marca la cabeza. `cheer` (0..1) los hace
// saltar (gol); en reposo se mueven apenas.

uniform float cheer = 0.0;
uniform vec3 skin_light : source_color = vec3(0.92, 0.75, 0.62);
uniform vec3 skin_dark : source_color = vec3(0.38, 0.26, 0.18);

varying vec3 cloth;
varying float head;
varying float skin;

void vertex() {
	cloth = INSTANCE_CUSTOM.rgb;
	skin = INSTANCE_CUSTOM.a;
	head = COLOR.r;
	float seed = float(INSTANCE_ID) * 0.6180339;
	float idle = sin(TIME * 1.3 + seed * 17.0) * 0.015;
	float jump = max(0.0, sin(TIME * (7.0 + fract(seed) * 3.0) + seed * 31.0)) * 0.35 * cheer;
	VERTEX.y += idle + jump;
	// Brazos arriba no hay: al festejar el cuerpo se estira un poco.
	VERTEX.y += VERTEX.y * 0.12 * cheer;
}

void fragment() {
	vec3 skin_c = mix(skin_light, skin_dark, skin);
	ALBEDO = mix(cloth, skin_c, head);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
