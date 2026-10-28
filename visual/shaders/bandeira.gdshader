shader_type canvas_item;
// Bandeira de pano (largada e chegada do The Fastfather, 2026-10-28): uma
// malha subdividida presa na haste à esquerda (UV.x = 0); as ondas correm da
// haste para a ponta, mais fortes longe dela, e as dobras escurecem.

uniform float amplitude = 14.0;  // px na ponta
uniform float velocidade = 7.0;
uniform bool quadriculada = false;
uniform vec4 cor : source_color = vec4(0.2, 0.4, 0.23, 1.0);  // verde de pano gasto
uniform float casas = 8.0;  // colunas do xadrez
varying float dobra;

void vertex() {
	float solto = UV.x;  // 0 na haste, 1 na ponta
	float fase = UV.x * 7.0 - TIME * velocidade;
	VERTEX.y += sin(fase) * amplitude * solto;
	VERTEX.x -= (1.0 - cos(fase)) * amplitude * 0.25 * solto;
	dobra = cos(fase) * solto;
}

void fragment() {
	vec3 c = cor.rgb;
	if (quadriculada) {
		float linhas = casas * 0.66;
		float xadrez = mod(floor(UV.x * casas) + floor(UV.y * linhas), 2.0);
		c = mix(vec3(0.07, 0.07, 0.08), vec3(0.95, 0.94, 0.9), xadrez);
	}
	c *= 0.82 + 0.25 * dobra;  // dobras: luz de um lado, sombra do outro
	COLOR = vec4(c, COLOR.a);
}
