shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;
// Sprite isométrico do carro (docs/arte_carros.md) virado para a câmera, com as
// rodas girando: dentro da elipse de cada roda (arte/carros/rodas.json), a
// imagem é girada em torno do cubo pelo ângulo andado (só devagar) e borrada
// pela velocidade. Sem teste de profundidade: o desenho fica de pé e a parte de
// baixo (a frente do carro) atravessaria o chão.

uniform sampler2D textura : source_color, filter_linear_mipmap;
uniform vec4 modulacao : source_color = vec4(1.0);
uniform vec2 tela = vec2(1120.0, 800.0);
uniform vec2 roda_c[2];
uniform vec2 roda_a[2];
uniform vec2 roda_b[2];
uniform float usar_rodas = 0.0;
uniform float giro = 0.0;    // ângulo andado (rad)
uniform float borrao = 0.0;  // abertura do borrão de movimento (rad)

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

vec4 roda(vec2 px, vec2 c, vec2 a, vec2 b, vec4 base) {
	mat2 m = mat2(a, b);
	vec2 q = inverse(m) * (px - c);
	float r = length(q);
	// Só o miolo (aro e raios) gira; a borda do pneu fica parada, sem bambolear
	// se a elipse medida não for exata.
	if (r >= 0.86) {
		return base;
	}
	// Em velocidade não há giro visível (a roda giraria rápido demais para
	// ver): só o borrão em volta do ângulo fixo. Devagar, o ângulo andado.
	float lento = 1.0 - smoothstep(0.15, 0.5, borrao);
	float centro = giro * lento;
	float abre = max(borrao, 0.0);
	vec4 soma = vec4(0.0);
	const int N = 12;
	for (int i = 0; i < N; i++) {
		float ang = -(centro + abre * (float(i) / float(N - 1) - 0.5));
		vec2 qr = vec2(q.x * cos(ang) - q.y * sin(ang), q.x * sin(ang) + q.y * cos(ang));
		soma += texture(textura, (c + m * qr) / tela);
	}
	return mix(base, soma / float(N), smoothstep(0.86, 0.7, r));
}

void fragment() {
	vec2 px = UV * tela;
	vec4 c = texture(textura, UV);
	if (usar_rodas > 0.0) {
		c = roda(px, roda_c[0], roda_a[0], roda_b[0], c);
		c = roda(px, roda_c[1], roda_a[1], roda_b[1], c);
	}
	ALBEDO = c.rgb * modulacao.rgb;
	ALPHA = c.a * modulacao.a;
}
