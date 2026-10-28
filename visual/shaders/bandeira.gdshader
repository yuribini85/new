shader_type canvas_item;
// Bandeira do fiscal (The Fastfather, 2026-10-28), no estilo da arte: pano
// facetado como os personagens low poly (cada triângulo num tom chapado, três
// tons de luz), sem contorno. Presa pela borda esquerda (UV.x = 0); as ondas
// correm para a ponta.

uniform float amplitude = 14.0;  // px na ponta
uniform float velocidade = 7.0;
uniform bool quadriculada = false;
uniform vec4 cor : source_color = vec4(0.2, 0.42, 0.24, 1.0);
uniform float casas = 6.0;  // colunas do xadrez
varying flat float dobra;
varying vec2 uv_pano;

void vertex() {
	float solto = UV.x;
	float fase = UV.x * 6.0 - TIME * velocidade;
	VERTEX.y += sin(fase) * amplitude * solto;
	VERTEX.x -= (1.0 - cos(fase)) * amplitude * 0.22 * solto;
	dobra = cos(fase + UV.y * 1.3) * (0.35 + solto);
	uv_pano = UV;
}

void fragment() {
	vec3 c = cor.rgb;
	if (quadriculada) {
		float xadrez = mod(floor(uv_pano.x * casas) + floor(uv_pano.y * casas * 0.66), 2.0);
		c = mix(vec3(0.1, 0.09, 0.08), vec3(0.95, 0.92, 0.84), xadrez);
	} else {
		// Barra art déco: dois filetes creme junto da borda presa e na barra de baixo.
		float filete = step(0.08, uv_pano.x) * step(uv_pano.x, 0.11) + step(0.14, uv_pano.x) * step(uv_pano.x, 0.155);
		filete += step(0.84, uv_pano.y) * step(uv_pano.y, 0.88);
		c = mix(c, vec3(0.93, 0.86, 0.7), clamp(filete, 0.0, 1.0));
	}
	// Três tons chapados por face: sombra, meio, luz.
	float tom = floor(clamp(dobra * 0.5 + 0.5, 0.0, 0.999) * 3.0) / 2.0;
	c *= mix(0.68, 1.12, tom);
	COLOR = vec4(c, COLOR.a);
}
