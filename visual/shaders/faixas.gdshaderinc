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
// Número de corrida (aba IDENTIDADE): -1 = sem; locais_numero soma 1 (portas),
// 2 (capô) e 4 (teto). Os algarismos vêm de digitos (R = algarismo, G =
// contorno; tools/gerar_digitos.py), medidos em metros para não esticar.
uniform sampler2D digitos : filter_linear, repeat_disable, hint_default_black;
uniform int numero = -1;
uniform int locais_numero = 1;
uniform vec4 cor_numero : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 cor_contorno : source_color = vec4(1.0);
// Acabamento (aba ACABAMENTO): 0 fosco, 1 acetinado, 2 brilhante, 3 metálico.
uniform int acabamento = 1;

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

// Tamanho do carro em metros na ordem de p (X lado a lado, Y altura, Z comprimento).
vec3 tamanho_carro() {
	return caixa_tam.x > caixa_tam.z ? caixa_tam.zyx : caixa_tam;
}

// O número num quadro de altura h (m), centrado em (a, b) = (0, 0): x = (algarismo, contorno).
vec2 numero_em(float a, float b, float h) {
	if (numero < 0 || abs(b) > h * 0.5) {
		return vec2(0.0);
	}
	int n = numero >= 10 ? 2 : 1;
	float w = h * 0.62 * float(n);  // os algarismos um pouco mais juntos que a célula
	float u = a / w + 0.5;
	if (u < 0.0 || u > 1.0) {
		return vec2(0.0);
	}
	float k = u * float(n);
	int i = min(int(k), n - 1);
	int d = n == 2 ? (i == 0 ? numero / 10 : numero % 10) : numero;
	float fu = (fract(k) - 0.5) * 0.93 + 0.5;  // 0.62 / (2/3)
	vec2 uv = vec2((float(d) + fu) / 10.0, 0.5 - b / h);
	return texture(digitos, uv).rg;
}

vec3 aplicar_numero(vec3 c, vec3 p, float lado, float topo) {
	if (numero < 0) {
		return c;
	}
	vec3 m = tamanho_carro();
	vec2 r = vec2(0.0);
	if (locais_numero % 2 == 1) {  // portas: lido de fora dos dois lados
		float s = p.x > 0.5 ? -1.0 : 1.0;
		float h = min(m.y * 0.34, 0.5);
		r = max(r, lado * numero_em((p.z - 0.47) * m.z * s, (p.y - 0.44) * m.y, h));
	}
	if ((locais_numero / 2) % 2 == 1) {  // capô: lido de frente
		float h = min(m.z * 0.13, 0.5);
		r = max(r, topo * step(0.62, p.z) * numero_em((p.x - 0.5) * m.x, (0.8 - p.z) * m.z, h));
	}
	if ((locais_numero / 4) % 2 == 1) {  // teto: lido de frente
		float h = min(m.z * 0.12, 0.45);
		r = max(r, topo * step(0.8, p.y) * numero_em((p.x - 0.5) * m.x, (0.45 - p.z) * m.z, h));
	}
	c = mix(c, cor_contorno.rgb, clamp(r.y, 0.0, 1.0));
	return mix(c, cor_numero.rgb, clamp(r.x, 0.0, 1.0));
}

float rugosidade_pintura() {
	return acabamento == 0 ? 0.85 : (acabamento == 2 ? 0.18 : (acabamento == 3 ? 0.3 : 0.55));
}

float especular_pintura() {
	return acabamento == 0 ? 0.15 : (acabamento == 2 ? 0.6 : (acabamento == 3 ? 0.5 : 0.35));
}

float metalico_pintura() {
	return acabamento == 3 ? 0.65 : 0.0;
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
	c = mix(c, cor_filete.rgb, clamp(fil, 0.0, 1.0));
	return aplicar_numero(c, p, lado, topo);
}
