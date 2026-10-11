// Faixas da pintura personalizada (Oficina → PINTURA), compartilhadas pelos
// shaders da lataria. Coordenada do carro normalizada 0..1 pela caixa do
// modelo: X lado a lado, Y altura, Z da traseira à frente.
// padrao: o índice de PinturaCarro.PADROES (0 = sem faixas). cor_faixa é a
// faixa ou a figura; cor_filete, o filete fino na borda (ou o segundo tom).

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
	float z = p.z;
	float lado = smoothstep(0.66, 0.74, u);  // as laterais
	float topo = 1.0 - lado;  // capô, teto e tampa
	float f = 0.0;
	float fil = 0.0;
	if (padrao == 1) {  // dupla central
		f = faixa(u, 0.10, 0.30);
		fil = faixa(u, 0.075, 0.10) + faixa(u, 0.30, 0.325);
	} else if (padrao == 2) {  // larga central
		f = faixa(u, 0.0, 0.34);
		fil = faixa(u, 0.34, 0.38);
	} else if (padrao == 3) {  // lateral
		f = lado * faixa(v, 0.36, 0.50);
		fil = lado * (faixa(v, 0.33, 0.36) + faixa(v, 0.50, 0.53));
	} else if (padrao == 4) {  // dois tons
		f = 1.0 - smoothstep(0.415, 0.425, v);
		fil = faixa(v, 0.42, 0.45);
	} else if (padrao == 5) {  // tripla fina
		f = faixa(u, 0.0, 0.06) + faixa(u, 0.15, 0.21) + faixa(u, 0.30, 0.36);
	} else if (padrao == 6) {  // assimétrica: uma faixa larga fora do centro
		f = faixa(p.x, 0.60, 0.76);
		fil = faixa(p.x, 0.575, 0.60) + faixa(p.x, 0.76, 0.785);
	} else if (padrao == 7) {  // capô pintado
		f = topo * smoothstep(0.64, 0.66, z);
		fil = topo * faixa(z, 0.60, 0.64);
	} else if (padrao == 8) {  // diagonal nas laterais
		float t = v + z * 0.9;
		f = lado * faixa(t, 0.78, 1.0);
		fil = lado * (faixa(t, 0.74, 0.78) + faixa(t, 1.0, 1.04));
	} else if (padrao == 9) {  // chevron (setas para a frente)
		float t = fract(z * 5.0 + u * 1.2);
		f = topo * faixa(t, 0.0, 0.32);
		fil = topo * faixa(t, 0.32, 0.38);
	} else if (padrao == 10) {  // xadrez no meio
		float cel = mod(floor(p.x * 10.0) + floor(z * 16.0), 2.0);
		f = cel * (1.0 - smoothstep(0.46, 0.48, u));
		fil = faixa(u, 0.48, 0.52);
	} else if (padrao == 11) {  // degradê da frente para a traseira
		f = smoothstep(0.2, 0.85, 1.0 - z);
	} else if (padrao == 12) {  // zigue-zague nas laterais
		float t = v - 0.09 * abs(fract(z * 8.0) * 2.0 - 1.0);
		f = lado * faixa(t, 0.30, 0.42);
		fil = lado * (faixa(t, 0.27, 0.30) + faixa(t, 0.42, 0.45));
	} else if (padrao == 13) {  // serrilha embaixo
		f = lado * (1.0 - smoothstep(0.0, 0.01, v - (0.16 + 0.16 * fract(z * 10.0))));
	} else if (padrao == 14) {  // círculo nas portas
		float d = length(vec2((z - 0.5) * 1.7, v - 0.48));
		f = lado * (1.0 - smoothstep(0.12, 0.13, d));
		fil = lado * faixa(d, 0.13, 0.155);
	} else if (padrao == 15) {  // três tons (embaixo a faixa, no meio o filete)
		f = 1.0 - smoothstep(0.27, 0.28, v);
		fil = faixa(v, 0.28, 0.44);
	}
	c = mix(c, cor_faixa.rgb, clamp(f, 0.0, 1.0));
	return mix(c, cor_filete.rgb, clamp(fil, 0.0, 1.0));
}
