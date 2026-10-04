shader_type spatial;
// Colores del jugador por zona del cuerpo. La zona viene "horneada" en el
// color de vértice (ver ModelVisual._bake_regions):
//   r: 0 camiseta, 1 short, 2 medias, 3 piel, 4 botines, 5 pelo, 6 manos
//   g: torso de la camiseta (la tela no marca los músculos)
//   b: ribetes (cuello, puños, ruedos) con el color secundario
// y en CUSTOM0 la posición de cada vértice en la pose de reposo: con ella el
// diseño de la camiseta, el número y el escudo se pintan EN la tela (se
// mueven y se doblan con el cuerpo; no son carteles pegados).
// La ropa se "infla" un poco sobre el cuerpo y, en el torso, la normal se
// suaviza hacia la de un cilindro: así se lee como tela y no como piel pintada.

uniform vec3 shirt : source_color = vec3(1.0);
uniform vec3 shirt2 : source_color = vec3(0.0);
uniform vec3 shorts : source_color = vec3(0.1);
uniform vec3 socks : source_color = vec3(1.0);
uniform vec3 skin : source_color = vec3(0.9, 0.75, 0.6);
uniform vec3 boots : source_color = vec3(0.06);
uniform vec3 hair : source_color = vec3(0.08, 0.06, 0.05);
uniform vec3 hands : source_color = vec3(0.9, 0.75, 0.6);
uniform vec3 trim : source_color = vec3(1.0);
// Diseño: 0 lisa, 1 rayas verticales, 2 rayas finitas, 3 aros, 4 mitades,
// 5 banda diagonal.
uniform int pattern = 0;
// Número (0 = sin número): dígitos de una tipografía de píxeles (atlas de 10
// dígitos; r = relleno, g = contorno) y sus colores.
uniform int number = 0;
uniform sampler2D digits : filter_nearest;
uniform vec3 number_color : source_color = vec3(1.0);
uniform vec3 number_outline : source_color = vec3(0.0);
// Escudo del club en el pecho (dos colores).
uniform bool crest = true;
uniform float cloth_inflate = 0.012;
uniform float cloth_smooth = 0.8;

// Plano: entre la piel (3) y el pelo (5) no tiene que aparecer otra zona.
varying flat float v_region;
varying float v_torso;
varying float v_trim;
varying vec3 v_cyl_normal;
varying vec3 v_rest;

void vertex() {
	v_region = COLOR.r * 10.0;
	v_torso = COLOR.g;
	v_trim = COLOR.b;
	v_rest = CUSTOM0.xyz;
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

// Banda suavizada: 1 dentro de la franja [0, ancho) de cada período, con el
// borde difuminado según cuánto ocupa un píxel (sin dientes ni titileo
// cuando el jugador se ve chico).
float band(float coord, float period, float width) {
	float t = coord / period;
	float aa = max(fwidth(t), 0.0005) * 1.2;
	float f = fract(t);
	return smoothstep(0.0, aa, f) * (1.0 - smoothstep(width - aa, width, f))
		+ (1.0 - smoothstep(0.0, aa, f - (1.0 - aa)) ) * step(1.0 - aa, f) * 0.0;
}

// Diseño de la camiseta según la posición de reposo (x: ancho, y: alto).
vec3 kit_pattern(vec3 p) {
	float k = 0.0;
	if (pattern == 1) {
		k = band(p.x + 1.0, 0.15, 0.5);
	} else if (pattern == 2) {
		k = band(p.x + 1.0, 0.06, 0.18);
	} else if (pattern == 3) {
		k = band(p.y - 0.95, 0.18, 0.5);
	} else if (pattern == 4) {
		float aa = max(fwidth(p.x), 0.0005);
		k = 1.0 - smoothstep(-aa, aa, p.x);
	} else if (pattern == 5) {
		float d = abs(p.x * 0.9 - (p.y - 1.25));
		float aa = max(fwidth(d), 0.0005);
		k = 1.0 - smoothstep(0.06 - aa, 0.06 + aa, d);
	}
	return mix(shirt, shirt2, k);
}

// Relleno (x) y contorno (y) del número en un recuadro (uv 0..1, v hacia
// abajo).
vec2 number_mask(vec2 uv) {
	if (number <= 0 || uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec2(0.0);
	}
	int tens = number / 10;
	int ones = number - tens * 10;
	int count = tens > 0 ? 2 : 1;
	float w = 1.0 / float(count);
	int slot = int(floor(uv.x / w));
	float lu = (uv.x - float(slot) * w) / w;
	int d = (count == 2 && slot == 0) ? tens : ones;
	// Cada dígito ocupa una columna de 1/10 del atlas.
	vec4 t = texture(digits, vec2((float(d) + lu) / 10.0, uv.y));
	return t.rg;
}

void fragment() {
	int region = int(round(v_region));
	vec3 c = shirt;
	float rough = 0.85;
	float spec = 0.2;
	if (region == 0) { c = kit_pattern(v_rest); }
	else if (region == 1) { c = shorts; }
	else if (region == 2) {
		// Medias con una franja arriba (el color secundario de la camiseta).
		c = (v_rest.y > 0.40) ? (pattern > 0 ? shirt2 : trim) : socks;
	}
	else if (region == 3) { c = skin; rough = 0.6; spec = 0.3; }
	else if (region == 4) { c = boots; rough = 0.4; spec = 0.4; }
	else if (region == 5) { c = hair; rough = 0.7; }
	else if (region == 6) { c = hands; rough = 0.6; }
	bool cloth = region <= 1;
	if (cloth) {
		if (v_trim > 0.5) {
			c = trim;
		}
		if (region == 0 && v_torso > 0.5) {
			vec3 p = v_rest;
			// Espalda (la espalda mira a -Z): número grande al centro. Visto
			// desde atrás, la derecha de la pantalla es -X.
			if (p.z < 0.0) {
				vec2 m = number_mask(vec2((0.12 - p.x) / 0.24, (1.42 - p.y) / 0.30));
				c = mix(c, number_outline, m.y);
				c = mix(c, number_color, m.x);
			} else {
				// Pecho: número chico al centro y escudo sobre el corazón (+X).
				vec2 m = number_mask(vec2((p.x + 0.06) / 0.12, (1.27 - p.y) / 0.15));
				c = mix(c, number_outline, m.y);
				c = mix(c, number_color, m.x);
				if (crest) {
					vec2 q = vec2(p.x - 0.105, p.y - 1.335);
					// Escudo: óvalo con borde y una franja diagonal.
					float e = length(q / vec2(0.035, 0.042));
					if (e < 1.0) {
						vec3 inner = abs(q.x + q.y * 0.6) < 0.012 ? shirt : shirt2;
						c = e > 0.78 ? trim : inner;
						if (e < 0.78 && length(q) < 0.006) { c = number_color; }
					}
				}
			}
		}
		// Torso: la tela cae lisa (no se marcan los músculos).
		if (v_torso > 0.5) {
			NORMAL = normalize(mix(NORMAL, normalize(v_cyl_normal), cloth_smooth));
		}
		// Trama muy fina de la tela.
		float weave = hash(floor(v_rest.xy * 260.0)) * 0.06;
		c *= 0.97 + weave;
		rough = 0.95;
		spec = 0.12;
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
