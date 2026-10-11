// Faixas da pintura personalizada (Oficina → PINTURA), compartilhadas pelos
// shaders da lataria. Coordenada do carro normalizada 0..1 pela caixa do
// modelo: X lado a lado, Y altura, Z da traseira à frente.
// padrao: 0 nenhuma, 1 dupla central, 2 larga central, 3 lateral, 4 dois tons.

uniform vec4 cor_faixa : source_color = vec4(1.0);
uniform vec4 cor_filete : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform int padrao = 0;
uniform vec3 caixa_min = vec3(-1.0);
uniform vec3 caixa_tam = vec3(2.0);

varying vec3 p_carro;

vec3 posicao_no_carro(vec3 vertice) {
	vec3 q = (vertice - caixa_min) / max(caixa_tam, vec3(0.001));
	// A malha pode vir girada no arquivo: o comprimento é o maior lado no chão.
	return caixa_tam.x > caixa_tam.z ? q.zyx : q;
}

// 1 dentro da faixa [a, b], com borda suave para não serrilhar.
float faixa(float x, float a, float b) {
	return smoothstep(a - 0.006, a + 0.006, x) * (1.0 - smoothstep(b - 0.006, b + 0.006, x));
}

vec3 aplicar_faixas(vec3 c, vec3 p) {
	float u = abs(p.x - 0.5) * 2.0;  // 0 no meio, 1 na lateral
	float v = p.y;
	float f = 0.0;
	float fil = 0.0;
	if (padrao == 1) {
		f = faixa(u, 0.10, 0.30);
		fil = faixa(u, 0.075, 0.10) + faixa(u, 0.30, 0.325);
	} else if (padrao == 2) {
		f = faixa(u, 0.0, 0.34);
		fil = faixa(u, 0.34, 0.38);
	} else if (padrao == 3) {
		float lado = smoothstep(0.66, 0.74, u);
		f = lado * faixa(v, 0.36, 0.50);
		fil = lado * (faixa(v, 0.33, 0.36) + faixa(v, 0.50, 0.53));
	} else if (padrao == 4) {
		f = 1.0 - smoothstep(0.415, 0.425, v);
		fil = faixa(v, 0.42, 0.45);
	}
	c = mix(c, cor_faixa.rgb, clamp(f, 0.0, 1.0));
	return mix(c, cor_filete.rgb, clamp(fil, 0.0, 1.0));
}
