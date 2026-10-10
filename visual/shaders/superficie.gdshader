shader_type spatial;
render_mode unshaded, cull_disabled;
// Superfícies das pistas montadas a partir do kit (docs/arte_pistas.md).
// modo_uv 0: textura repetível pelo mundo (chão, asfalto, escape, areia), com
//            mistura opcional de uma segunda textura por ruído (manchas).
// modo_uv 1: textura ao longo da faixa (UV da malha: zebra).
// O alfa do vértice (COLOR.a) apaga bordas e pontas; o ruído deixa a borda
// irregular, com cara de pintura, em vez de um corte reto.

uniform sampler2D textura : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D textura_b : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform float metros = 16.0;
uniform float usar_b = 0.0;
uniform float escala_manchas = 90.0;
uniform int modo_uv = 0;
uniform vec4 tinta : source_color = vec4(1.0);
uniform float borda_irregular = 0.0;
// Estilo chapado: borda seca (o alfa vira 0 ou 1), sem degradê.
uniform float borda_seca = 0.0;
// Máscara do chão (montador): R = água (cais), G = chão de floresta.
uniform float usar_mascara = 0.0;
uniform sampler2D mascara : filter_linear, repeat_disable;
uniform vec2 mascara_origem = vec2(0.0);
uniform vec2 mascara_tam = vec2(1.0);
uniform sampler2D textura_mata : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D textura_agua : source_color, filter_linear_mipmap, repeat_enable;

varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv = modo_uv == 0 ? mundo / metros : UV;
	vec3 c = texture(textura, uv).rgb;
	if (usar_b > 0.0) {
		float m = texture(ruido, mundo / escala_manchas).r;
		c = mix(c, texture(textura_b, uv * 0.73 + 0.31).rgb, smoothstep(0.42, 0.62, m) * usar_b);
	}
	if (usar_mascara > 0.0) {
		vec4 m = texture(mascara, (vec2(mundo.x, -mundo.y) - mascara_origem) / mascara_tam);
		c = mix(c, texture(textura_mata, uv * 0.9 + 0.17).rgb, m.g * 0.9);
		float agua = smoothstep(0.45, 0.55, m.r);
		// Borda do cais: faixa escura do lado de terra.
		float cais = smoothstep(0.08, 0.3, m.r) * (1.0 - agua);
		c = mix(c, c * 0.4, cais);
		c = mix(c, texture(textura_agua, mundo / (metros * 2.0)).rgb, agua);
		// B: claridade (ilhas de luz): longe da pista, o chão apaga.
		c *= m.b;
	}
	ALBEDO = c * tinta.rgb;
	float a = COLOR.a;
	if (borda_irregular > 0.0) {
		float n = texture(ruido, mundo / 9.0).r;
		a = smoothstep(n * borda_irregular, n * borda_irregular + 0.15, a);
	}
	if (borda_seca > 0.0) {
		a = step(0.5, a);
	}
	if (a < 0.999) {
		ALPHA = a;
	}
}
