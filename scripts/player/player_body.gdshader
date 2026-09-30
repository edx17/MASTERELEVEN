shader_type spatial;
// Colores del jugador por zona del cuerpo. La zona viene "horneada" en el
// canal rojo del color de vértice (ver ModelVisual._bake_regions):
// 0 camiseta, 1 short, 2 medias, 3 piel, 4 botines, 5 pelo, 6 manos.

uniform vec3 shirt : source_color = vec3(1.0);
uniform vec3 shorts : source_color = vec3(0.1);
uniform vec3 socks : source_color = vec3(1.0);
uniform vec3 skin : source_color = vec3(0.9, 0.75, 0.6);
uniform vec3 boots : source_color = vec3(0.06);
uniform vec3 hair : source_color = vec3(0.08, 0.06, 0.05);
uniform vec3 hands : source_color = vec3(0.9, 0.75, 0.6);

void fragment() {
	int region = int(round(COLOR.r * 10.0));
	vec3 c = shirt;
	float rough = 0.85;
	if (region == 1) { c = shorts; }
	else if (region == 2) { c = socks; }
	else if (region == 3) { c = skin; rough = 0.6; }
	else if (region == 4) { c = boots; rough = 0.4; }
	else if (region == 5) { c = hair; rough = 0.7; }
	else if (region == 6) { c = hands; rough = 0.6; }
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.25;
}
