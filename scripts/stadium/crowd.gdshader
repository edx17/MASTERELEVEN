shader_type spatial;
// Público con volumen: cada hincha es una persona sentada de pocos polígonos
// (MultiMesh). Ropa y tono de piel por instancia en INSTANCE_CUSTOM (rgb =
// ropa, a = piel). En el modelo, el color de vértice marca las zonas:
// r = piel, g = pelo, b = pantalón. `cheer` los hace saltar en los goles.

uniform float cheer = 0.0;
// Fracción del público que ya se fue (final del partido): esos no se dibujan.
uniform float empty = 0.0;
// Qué parte del vaciado dura la salida de cada persona (≈7 s de 90).
const float LEAVE_WINDOW = 0.08;
// Pasillos y bocas de salida de la tribuna (StadiumBuilder._stand); sin
// esto (layout_on = 0) suben derecho hasta arriba.
instance uniform float layout_on = 0.0;
instance uniform vec3 st_origin = vec3(0.0);
instance uniform vec3 st_x = vec3(1.0, 0.0, 0.0);
instance uniform vec3 st_z = vec3(0.0, 0.0, 1.0);
instance uniform vec4 tier_z = vec4(100000.0);
instance uniform vec4 vom_z = vec4(100000.0);
instance uniform vec4 vom_y = vec4(0.0);
instance uniform float vom_x0 = 0.0;
instance uniform float vom_step = 26.4;
// Óvalo (layout_on = 2): A0, B0 y forma del contorno (OvalStadiumBuilder).
instance uniform vec3 oval = vec3(64.5, 45.0, 4.5);
vec3 ring_point(float t, float off) {
	float e = 2.0 / oval.z;
	float c = cos(t);
	float s = sin(t);
	return vec3(sign(c) * pow(abs(c), e) * (oval.x + off), 0.0, sign(s) * pow(abs(s), e) * (oval.y + off));
}

// Punto de la fila en el ángulo polar phi (OvalStadiumBuilder.polar_point).
vec3 polar_point(float phi, float off) {
	float a = oval.x + off;
	float b = oval.y + off;
	float c = cos(phi);
	float s = sin(phi);
	float t = atan(pow(abs(s) * a / max(abs(c) * b, 1e-6), oval.z * 0.5));
	return ring_point(atan(sign(s) * sin(t), sign(c) * cos(t)), off);
}

// Cuánto hacia afuera del borde interno está un punto (bisección).
float ring_offset(vec3 p) {
	float lo = 0.0;
	float hi = 90.0;
	for (int i = 0; i < 14; i++) {
		float m = (lo + hi) * 0.5;
		float f = pow(abs(p.x) / (oval.x + m), oval.z) + pow(abs(p.z) / (oval.y + m), oval.z);
		if (f > 1.0) { lo = m; } else { hi = m; }
	}
	return (lo + hi) * 0.5;
}

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
	// Se van del estadio: cuando `empty` pasa su turno, se paran, caminan por
	// la fila hasta el pasillo y suben por la tribuna hacia la salida (+Z
	// local, de espaldas a la cancha); recién arriba desaparecen.
	float p = clamp((empty - seed) / LEAVE_WINDOW, 0.0, 1.0);
	// Al irse se paran: las piernas (zona pantalón) pasan de sentadas a
	// estiradas debajo del torso (el resto sube 0,22 m más abajo) y caminan.
	if (p > 0.0 && p < 1.0 && zone.b > 0.5) {
		float stand = smoothstep(0.0, 0.08, p);
		float walk = smoothstep(0.08, 0.12, p) * sin(TIME * 8.0 + seed * 20.0) * sign(VERTEX.x);
		float ly = (VERTEX.y - 0.06) / 0.47 * 0.77 - 0.22;
		float lz = clamp(VERTEX.z + 0.2, -0.07, 0.07) + walk * 0.12 * (1.0 - clamp(ly / 0.55, 0.0, 1.0));
		VERTEX.y = mix(VERTEX.y, ly, stand);
		VERTEX.z = mix(VERTEX.z, lz, stand);
	}
	if (p >= 1.0) {
		VERTEX = vec3(0.0);
	} else if (p > 0.0 && layout_on > 1.5) {
		// Óvalo: por la fila hasta la escalera con boca, por la escalera
		// hasta la boca y adentro (desplazamientos en el mundo, llevados al
		// espacio de la persona).
		vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float off = ring_offset(w);
		int t = int(off > tier_z.y) + int(off > tier_z.z) + int(off > tier_z.w);
		float vo = vom_z[t];
		float sit = smoothstep(0.0, 0.08, p);
		vec3 d = vec3(0.0);
		d.y = 0.22 * sit;
		vec3 n = normalize(vec3(w.x / (oval.x * oval.x), 0.0, w.z / (oval.y * oval.y)));
		if (vo > 90000.0) {
			float up = smoothstep(0.3, 1.0, p);
			d += n * up * 7.0 + vec3(0.0, up * 3.5, 0.0);
		} else {
			float phi = atan(w.z, w.x);
			float k = round((phi / vom_step - 1.0) * 0.5) * 2.0 + 1.0;
			float pv = k * vom_step;
			vec3 aisle = polar_point(pv, off);
			vec3 mouth = polar_point(pv, vo + 0.4);
			float along = smoothstep(0.08, 0.45, p);
			float stairs = smoothstep(0.45, 0.85, p);
			float enter = smoothstep(0.85, 1.0, p);
			d.xz += (aisle.xz - w.xz) * along + (mouth.xz - aisle.xz) * stairs + n.xz * enter * 2.2;
			d.y += (vom_y[t] - w.y) * stairs - enter * 0.4;
		}
		d.y += abs(sin(TIME * 7.0 + seed * 20.0)) * 0.05 * sit;
		VERTEX += inverse(mat3(MODEL_MATRIX)) * d;
	} else if (p > 0.0 && layout_on > 0.5) {
		// Dónde está sentado (en la tribuna) y a qué boca de salida va.
		vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz - st_origin;
		float lx = dot(w, st_x);
		float lz = dot(w, st_z);
		float ly = w.y;
		int t = int(lz > tier_z.y) + int(lz > tier_z.z) + int(lz > tier_z.w);
		float vz = vom_z[t];
		float vy = vom_y[t];
		float sit = smoothstep(0.0, 0.08, p);
		VERTEX.y += 0.22 * sit;
		if (vz > 90000.0) {
			// Bandeja sin boca: sube por el pasillo hasta arriba.
			float up = smoothstep(0.3, 1.0, p);
			VERTEX.z += up * 7.0;
			VERTEX.y += up * 3.5;
		} else {
			float xa = vom_x0 + round((lx - vom_x0) / vom_step) * vom_step;
			float along = smoothstep(0.08, 0.45, p);
			float stairs = smoothstep(0.45, 0.85, p);
			float enter = smoothstep(0.85, 1.0, p);
			// Por la fila hasta el pasillo, por la escalera hasta la boca y
			// adentro (hacia atrás y abajo, al túnel de la tribuna).
			VERTEX.x += (xa - lx) * along;
			VERTEX.z += (vz + 0.4 - lz) * stairs + enter * 2.2;
			VERTEX.y += (vy - ly) * stairs - enter * 0.4;
		}
		VERTEX.y += abs(sin(TIME * 7.0 + seed * 20.0)) * 0.05 * sit;
	} else if (p > 0.0) {
		float aisle = (0.6 + fract(seed * 13.7) * 3.0) * (fract(seed * 7.3) < 0.5 ? -1.0 : 1.0);
		float along = smoothstep(0.0, 0.4, p);
		float up = smoothstep(0.4, 1.0, p);
		VERTEX.y += 0.22 * smoothstep(0.0, 0.08, p);
		VERTEX.x += aisle * along;
		VERTEX.z += up * 7.0;
		VERTEX.y += up * 3.5 + abs(sin(TIME * 7.0 + seed * 20.0)) * 0.05;
	}
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
