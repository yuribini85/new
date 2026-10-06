shader_type canvas_item;
// Efeito do modo velocidade (decisão 31) sobre a imagem da corrida: borrão
// radial que cresce para as bordas, com o centro (o carro) nítido, linhas de
// velocidade discretas nas bordas e um pouco mais de contraste.

uniform float intensidade : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centro = vec2(0.5, 0.52);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (intensidade <= 0.001) {
		COLOR = base;
	} else {
		vec2 d = UV - centro;
		float r = length(d * vec2(1.0, 1.4));
		float m = smoothstep(0.16, 0.62, r) * intensidade;
		vec4 soma = base;
		for (int k = 1; k <= 6; k++) {
			soma += texture(TEXTURE, UV - d * (0.03 * m) * float(k));
		}
		vec4 c = soma / 7.0;
		float ang = atan(d.y, d.x);
		float linha = step(0.975, fract(sin(floor(ang * 90.0) * 43758.5453 + floor(TIME * 14.0)) * 0.5 + 0.5));
		c.rgb += linha * m * 0.07 * smoothstep(0.45, 0.8, r);
		c.rgb = mix(c.rgb, (c.rgb - 0.5) * 1.08 + 0.5, intensidade * 0.7);
		COLOR = c;
	}
}
