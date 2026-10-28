shader_type spatial;
render_mode cull_disabled;
// A bandeira do fiscal da largada no cenário de época (2026-10-28): pano
// numa malha subdividida, preso na haste (UV.x = 0), ondas correndo para a
// ponta; verde na largada, quadriculada na chegada.

uniform bool quadriculada = false;
uniform bool parado = false;
varying float dobra;

void vertex() {
	float fase = UV.x * 6.0 - TIME * 8.0;
	if (!parado) {
		VERTEX.z += sin(fase) * 0.16 * UV.x;
		VERTEX.y += sin(fase * 0.5) * 0.04 * UV.x;
	}
	dobra = cos(fase) * UV.x;
}

void fragment() {
	vec3 c = vec3(0.2, 0.4, 0.23);
	if (quadriculada) {
		float xadrez = mod(floor(UV.x * 6.0) + floor(UV.y * 4.0), 2.0);
		c = mix(vec3(0.07, 0.07, 0.08), vec3(0.95, 0.94, 0.9), xadrez);
	}
	ALBEDO = c * (0.85 + 0.2 * dobra);
	ROUGHNESS = 0.9;
}
