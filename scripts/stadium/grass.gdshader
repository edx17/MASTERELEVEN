shader_type spatial;
// Césped: franjas de corte, variación natural en varias escalas, relieve fino
// (normal procedural), desgaste en las áreas y el círculo central, y el efecto
// del clima (mojado: más oscuro y con brillo; nieve: se cubre de blanco).
// Si hay texturas fotográficas (GrassTextures) se usan para el detalle.

uniform vec3 color_a : source_color = vec3(0.235, 0.375, 0.13);
uniform vec3 color_b : source_color = vec3(0.17, 0.29, 0.095);
uniform vec3 worn_color : source_color = vec3(0.33, 0.30, 0.17);
uniform float stripe_width = 5.25;
uniform float variation = 0.18;
uniform float wear = 0.55;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform float half_length = 52.5;
uniform float bump = 0.22;
// Nieve: surcos limpios al costado de las líneas (1 = recién limpiadas; baja
// a medida que nieva durante el tiempo; en el entretiempo se vuelven a limpiar).
uniform float groove_clear : hint_range(0.0, 1.0) = 1.0;

uniform bool use_textures = false;
uniform bool use_normal_tex = false;
uniform bool use_roughness_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_scale = 0.35;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Distancia a las líneas de la cancha (medidas FIFA), para los surcos.
float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float line_dist(vec2 p) {
	float hl = half_length;
	float hw = 34.0;
	vec2 q = vec2(abs(p.x), p.y);
	float d = abs(abs(p.y) - hw);
	if (abs(p.x) > hl) d = 1e3;
	d = min(d, seg_dist(q, vec2(hl, -hw), vec2(hl, hw)));
	d = min(d, seg_dist(p, vec2(0.0, -hw), vec2(0.0, hw)));
	d = min(d, abs(length(p) - 9.15));
	// Área grande y chica.
	d = min(d, seg_dist(q, vec2(hl - 16.5, -20.16), vec2(hl - 16.5, 20.16)));
	d = min(d, seg_dist(vec2(q.x, abs(q.y)), vec2(hl - 16.5, 20.16), vec2(hl, 20.16)));
	d = min(d, seg_dist(q, vec2(hl - 5.5, -9.16), vec2(hl - 5.5, 9.16)));
	d = min(d, seg_dist(vec2(q.x, abs(q.y)), vec2(hl - 5.5, 9.16), vec2(hl, 9.16)));
	// Medialuna (fuera del área).
	if (q.x < hl - 16.5) d = min(d, abs(length(q - vec2(hl - 11.0, 0.0)) - 9.15));
	return d;
}

// Desgaste: áreas chicas (donde se para el arquero) y círculo central.
float wear_mask(vec2 p) {
	float m = 0.0;
	float gx = half_length - 3.0;
	m = max(m, 1.0 - smoothstep(1.5, 6.5, length((p - vec2(gx, 0.0)) * vec2(1.4, 0.55))));
	m = max(m, 1.0 - smoothstep(1.5, 6.5, length((p - vec2(-gx, 0.0)) * vec2(1.4, 0.55))));
	m = max(m, 0.6 * (1.0 - smoothstep(2.0, 9.0, length(p))));
	return m * smoothstep(0.35, 0.75, fbm(p * 0.9));
}

void fragment() {
	vec2 p = world_pos.xz;
	float stripe = step(0.5, fract(world_pos.x / (stripe_width * 2.0)));
	vec3 c = mix(color_a, color_b, stripe);
	// Variación: manchas grandes, parches medianos y textura fina de hojas.
	// El detalle fino se apaga con la distancia (si no, "chisporrotea").
	float fine = 1.0 - smoothstep(20.0, 65.0, length(VERTEX));
	float n = fbm(p * 0.08) * 0.5 + fbm(p * 0.6) * 0.3 + mix(0.5, noise(p * 18.0), fine) * 0.2;
	c *= (1.0 - variation * 0.5) + n * variation;
	float roughness = mix(0.82, 0.92, stripe);
	if (use_textures) {
		vec3 t = texture(albedo_tex, p * tex_scale).rgb;
		// La textura aporta el detalle; el tono lo siguen dando las franjas.
		c *= t / max(dot(t, vec3(0.333)), 0.05) * 0.9;
		if (use_roughness_tex) {
			roughness = texture(roughness_tex, p * tex_scale).r;
		}
	}
	// Desgaste (pasto pisado, algo de tierra).
	c = mix(c, worn_color, wear * wear_mask(p) * 0.6);
	// Relieve fino: normal a partir del gradiente del ruido.
	vec3 nmap = vec3(0.5, 0.5, 1.0);
	if (use_textures && use_normal_tex) {
		nmap = texture(normal_tex, p * tex_scale).rgb;
	} else {
		float e = 0.04;
		float h0 = noise(p * 14.0) + 0.5 * noise(p * 40.0);
		float hx = noise((p + vec2(e, 0.0)) * 14.0) + 0.5 * noise((p + vec2(e, 0.0)) * 40.0);
		float hz = noise((p + vec2(0.0, e)) * 14.0) + 0.5 * noise((p + vec2(0.0, e)) * 40.0);
		nmap = normalize(vec3((h0 - hx) * bump * 4.0 * fine, (h0 - hz) * bump * 4.0 * fine, 1.0)) * 0.5 + 0.5;
	}
	// Mojado: más oscuro y con reflejos.
	c *= 1.0 - 0.28 * wetness;
	roughness = mix(roughness, 0.28, wetness);
	float spec = mix(0.2, 0.6, wetness);
	// Nieve: cubre el césped (menos donde se juega más: el centro y las áreas).
	// Más nieve hacia las bandas y los fondos; en el medio, donde se juega, el
	// pasto se ve (como una cancha nevada que se fue pisando).
	vec2 edge = abs(p) / vec2(half_length, 34.0);
	float outer = smoothstep(0.35, 1.0, max(edge.x, edge.y));
	float patches = smoothstep(0.42, 0.7, fbm(p * 0.22) + 0.15 * outer);
	float snow_mask = snow * clamp(patches * (0.55 + 0.6 * outer), 0.0, 1.0) * (1.0 - 0.8 * wear_mask(p));
	// Surco limpio de ~0,5 m al lado de cada línea (se va tapando).
	float groove = 1.0 - smoothstep(0.12, 0.55, line_dist(p));
	snow_mask *= 1.0 - groove * groove_clear;
	c = mix(c, vec3(0.97, 0.98, 1.0), snow_mask);
	roughness = mix(roughness, 0.6, snow_mask);
	ALBEDO = c;
	ROUGHNESS = roughness;
	SPECULAR = spec;
	NORMAL_MAP = nmap;
	NORMAL_MAP_DEPTH = mix(1.0, 0.3, snow_mask);
}
