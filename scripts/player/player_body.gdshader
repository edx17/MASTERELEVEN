shader_type spatial;
// Colores del jugador por zona del cuerpo. La zona viene "horneada" en el
// color de vértice (ver ModelVisual._bake_regions):
//   r: 0 camiseta, 1 short, 2 medias, 3 piel, 4 botines, 5 pelo, 6 manos
//   g: torso de la camiseta (la tela no marca los músculos)
//   b: ribetes (cuello, puños, ruedos) con el color secundario
// La ropa se "infla" un poco sobre el cuerpo y, en el torso, la normal se
// suaviza hacia la de un cilindro: así se lee como tela y no como piel pintada.

uniform vec3 shirt : source_color = vec3(1.0);
uniform vec3 shorts : source_color = vec3(0.1);
uniform vec3 socks : source_color = vec3(1.0);
uniform vec3 skin : source_color = vec3(0.9, 0.75, 0.6);
uniform vec3 boots : source_color = vec3(0.06);
uniform vec3 hair : source_color = vec3(0.08, 0.06, 0.05);
uniform vec3 hands : source_color = vec3(0.9, 0.75, 0.6);
uniform vec3 trim : source_color = vec3(1.0);
uniform float cloth_inflate = 0.012;
uniform float cloth_smooth = 0.8;

// Plano: entre la piel (3) y el pelo (5) no tiene que aparecer otra zona.
varying flat float v_region;
varying float v_torso;
varying float v_trim;
varying vec3 v_cyl_normal;
varying vec3 v_model_pos;

void vertex() {
	v_region = COLOR.r * 10.0;
	v_torso = COLOR.g;
	v_trim = COLOR.b;
	v_model_pos = VERTEX;
	float cloth = (v_region < 1.5) ? 1.0 : 0.0;
	VERTEX += NORMAL * cloth_inflate * cloth;
	// Normal de un cilindro vertical alrededor del eje del cuerpo (torso).
	vec3 c = vec3(VERTEX.x, 0.0, VERTEX.z - 0.02);
	vec3 cyl = length(c) > 0.001 ? normalize(c) : NORMAL;
	cyl = normalize(cyl + vec3(0.0, NORMAL.y * 0.6, 0.0));
	v_cyl_normal = (MODELVIEW_MATRIX * vec4(cyl, 0.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	int region = int(round(v_region));
	vec3 c = shirt;
	float rough = 0.85;
	float spec = 0.2;
	if (region == 1) { c = shorts; }
	else if (region == 2) { c = socks; }
	else if (region == 3) { c = skin; rough = 0.6; spec = 0.3; }
	else if (region == 4) { c = boots; rough = 0.4; spec = 0.4; }
	else if (region == 5) { c = hair; rough = 0.7; }
	else if (region == 6) { c = hands; rough = 0.6; }
	bool cloth = region <= 1;
	if (cloth) {
		if (v_trim > 0.5) {
			c = trim;
		}
		// Torso: la tela cae lisa (no se marcan los músculos).
		if (v_torso > 0.5) {
			NORMAL = normalize(mix(NORMAL, normalize(v_cyl_normal), cloth_smooth));
		}
		// Trama muy fina de la tela.
		float weave = hash(floor(v_model_pos.xy * 260.0)) * 0.06;
		c *= 0.97 + weave;
		rough = 0.95;
		spec = 0.12;
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
