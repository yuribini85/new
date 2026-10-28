shader_type canvas_item;
// Efeito do modo velocidade (decisão 31) sobre a imagem da corrida: borrão
// radial que cresce para as bordas, com o centro (o carro) nítido, linhas de
// velocidade discretas nas bordas e um pouco mais de contraste.
// The Fastfather (golpes visuais, 2026-10-28): "filme de 1937" (cor quente e
// gasta, grão e um tremor leve de projetor), tilt-shift (o alto e o pé da tela
// desfocados: a pista vira maquete) e o clarão dos momentos fortes.

uniform float intensidade : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centro = vec2(0.5, 0.52);
// Bordas escurecidas do tema (luz de fim de tarde da referência), sempre ativas.
uniform float vinheta : hint_range(0.0, 1.0) = 0.0;
uniform float filme : hint_range(0.0, 1.0) = 0.0;
uniform float grao : hint_range(0.0, 1.0) = 0.0;
uniform float tilt : hint_range(0.0, 1.0) = 0.0;
uniform float foco_y = 0.55;  // a faixa nítida (o carro)
uniform float clarao : hint_range(0.0, 1.0) = 0.0;

float acaso(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 amostra(sampler2D t, vec2 uv, vec2 px) {
	if (tilt <= 0.001) {
		return texture(t, uv);
	}
	// Tilt-shift: desfoque que cresce longe da faixa do foco.
	float b = tilt * smoothstep(0.1, 0.42, abs(uv.y - foco_y)) * 4.0;
	if (b <= 0.05) {
		return texture(t, uv);
	}
	// Cruz de 5 leituras (barata o bastante para o navegador).
	vec4 s = texture(t, uv) * 2.0;
	s += texture(t, uv + vec2(px.x * b, 0.0));
	s += texture(t, uv - vec2(px.x * b, 0.0));
	s += texture(t, uv + vec2(0.0, px.y * b));
	s += texture(t, uv - vec2(0.0, px.y * b));
	return s / 6.0;
}

void fragment() {
	vec4 base = amostra(TEXTURE, UV, TEXTURE_PIXEL_SIZE);
	float escuro = 1.0 - vinheta * smoothstep(0.35, 0.85, length((UV - vec2(0.5)) * vec2(1.0, 0.8)));
	vec4 c = base;
	if (intensidade > 0.001) {
		vec2 d = UV - centro;
		float r = length(d * vec2(1.0, 1.4));
		float m = smoothstep(0.16, 0.62, r) * intensidade;
		vec4 soma = base;
		for (int k = 1; k <= 6; k++) {
			soma += texture(TEXTURE, UV - d * (0.03 * m) * float(k));
		}
		c = soma / 7.0;
		float ang = atan(d.y, d.x);
		float linha = step(0.975, fract(sin(floor(ang * 90.0) * 43758.5453 + floor(TIME * 14.0)) * 0.5 + 0.5));
		c.rgb += linha * m * 0.07 * smoothstep(0.45, 0.8, r);
		c.rgb = mix(c.rgb, (c.rgb - 0.5) * 1.08 + 0.5, intensidade * 0.7);
	}
	if (filme > 0.001) {
		// Cor de filme gasto: um tanto de sépia, pretos levantados, luz quente.
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		vec3 sepia = vec3(l * 1.07, l * 0.92, l * 0.72);
		vec3 g = mix(c.rgb, sepia, 0.38 * filme);
		g = mix(g, g * vec3(1.06, 1.0, 0.9), filme);
		g = mix(g, vec3(0.08, 0.06, 0.04) + g * 0.92, 0.6 * filme);
		g *= 1.0 + 0.012 * sin(TIME * 41.0) * filme;  // o projetor
		c.rgb = g;
	}
	if (grao > 0.001) {
		float n = acaso(floor(UV / TEXTURE_PIXEL_SIZE / 2.0) + floor(TIME * 24.0) * 1.37) - 0.5;
		c.rgb += n * 0.06 * grao;
	}
	c.rgb *= escuro;
	c.rgb = mix(c.rgb, vec3(1.0, 0.97, 0.9), clarao);
	COLOR = vec4(c.rgb, base.a);
}
