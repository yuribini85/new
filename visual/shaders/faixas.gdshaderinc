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
uniform float escala_numero = 1.0;
uniform bool suporte_numero = false;  // círculo atrás do número (na cor do contorno)
// Logo da equipe em encaixes fixos (soma): 1 paralamas dianteiros, 2 laterais
// traseiras, 4 capô (pequeno), 8 traseira. A imagem não tem texto.
uniform sampler2D logo : source_color, filter_linear_mipmap, repeat_disable, hint_default_transparent;
uniform int locais_logo = 0;
uniform float escala_logo = 1.0;
// Desenho: largura das faixas (multiplica) e espelhado (troca os lados).
uniform float largura_faixas = 1.0;
// Teto em segunda cor (padrão "teto"): altura relativa onde a cabine começa.
uniform float corte_teto = 0.64;
uniform bool espelhar = false;
// Desgaste em camada separada (0..1): poeira embaixo e arranhões; não muda a cor salva.
uniform float poeira = 0.0;
uniform float arranhoes = 0.0;

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
	float disco = 0.0;
	if (locais_numero % 2 == 1) {  // portas: lido de fora dos dois lados
		float s = p.x > 0.5 ? -1.0 : 1.0;
		float h = min(m.y * 0.34, 0.5) * escala_numero;
		vec2 q = vec2((p.z - 0.47) * m.z * s, (p.y - 0.44) * m.y);
		r = max(r, lado * numero_em(q.x, q.y, h));
		disco = max(disco, lado * (1.0 - smoothstep(h * 0.7, h * 0.72, length(q))));
	}
	if ((locais_numero / 2) % 2 == 1) {  // capô: lido de frente
		float h = min(m.z * 0.13, 0.5) * escala_numero;
		vec2 q = vec2((p.x - 0.5) * m.x, (0.8 - p.z) * m.z);
		r = max(r, topo * step(0.62, p.z) * numero_em(q.x, q.y, h));
		disco = max(disco, topo * step(0.62, p.z) * (1.0 - smoothstep(h * 0.7, h * 0.72, length(q))));
	}
	if ((locais_numero / 4) % 2 == 1) {  // teto: lido de frente
		float h = min(m.z * 0.12, 0.45) * escala_numero;
		vec2 q = vec2((p.x - 0.5) * m.x, (0.45 - p.z) * m.z);
		r = max(r, topo * step(0.8, p.y) * numero_em(q.x, q.y, h));
		disco = max(disco, topo * step(0.8, p.y) * (1.0 - smoothstep(h * 0.7, h * 0.72, length(q))));
	}
	if (suporte_numero) {
		c = mix(c, cor_contorno.rgb, disco);
	}
	c = mix(c, cor_contorno.rgb, clamp(r.y, 0.0, 1.0));
	return mix(c, cor_numero.rgb, clamp(r.x, 0.0, 1.0));
}

// O logo num quadro de lado h (m) centrado em (a, b): a cor com alfa.
vec4 logo_em(float a, float b, float h) {
	vec2 uv = vec2(a / h + 0.5, 0.5 - b / h);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(logo, uv);
}

vec3 aplicar_logo(vec3 c, vec3 p, float lado, float topo) {
	if (locais_logo == 0) {
		return c;
	}
	vec3 m = tamanho_carro();
	vec4 l = vec4(0.0);
	float s = p.x > 0.5 ? -1.0 : 1.0;
	float hl = min(m.y * 0.36, 0.5) * escala_logo;
	if (locais_logo % 2 == 1) {  // paralamas dianteiros
		vec4 k = logo_em((p.z - 0.82) * m.z * s, (p.y - 0.5) * m.y, hl);
		l = mix(l, k, k.a * lado);
	}
	if ((locais_logo / 2) % 2 == 1) {  // laterais traseiras
		vec4 k = logo_em((p.z - 0.15) * m.z * s, (p.y - 0.52) * m.y, hl);
		l = mix(l, k, k.a * lado);
	}
	if ((locais_logo / 4) % 2 == 1) {  // capô, pequeno, perto do para-brisa
		vec4 k = logo_em((p.x - 0.5) * m.x, (0.7 - p.z) * m.z, hl * 0.8);
		l = mix(l, k, k.a * topo * step(0.62, p.z) * step(p.y, 0.8));
	}
	if ((locais_logo / 8) % 2 == 1) {  // traseira (o painel de trás)
		vec4 k = logo_em((0.5 - p.x) * m.x, (p.y - 0.45) * m.y, hl * 0.8);
		l = mix(l, k, k.a * (1.0 - smoothstep(0.02, 0.05, p.z)));
	}
	return mix(c, l.rgb, clamp(l.a, 0.0, 1.0));
}

float ruido(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float n = dot(i, vec3(1.0, 57.0, 113.0));
	vec4 h = fract(sin(vec4(n, n + 1.0, n + 57.0, n + 58.0)) * 43758.5453);
	vec4 h2 = fract(sin(vec4(n + 113.0, n + 114.0, n + 170.0, n + 171.0)) * 43758.5453);
	return mix(mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y),
			mix(mix(h2.x, h2.y, f.x), mix(h2.z, h2.w, f.x), f.y), f.z);
}

// Poeira (mais embaixo) e arranhões (riscos finos que mostram o primer), por cima de tudo.
vec3 aplicar_desgaste(vec3 c, vec3 p) {
	if (poeira <= 0.0 && arranhoes <= 0.0) {
		return c;
	}
	vec3 pm = p * tamanho_carro();
	float n = ruido(pm * 3.0) * 0.6 + ruido(pm * 9.0) * 0.4;
	float baixo = 1.0 - smoothstep(0.1, 0.85, p.y);
	float d = poeira * clamp(baixo * 1.4 + n * 0.6 - 0.2, 0.0, 1.0);
	c = mix(c, vec3(0.47, 0.4, 0.31), d * 0.85);
	// Riscos: linhas finas e compridas no sentido do carro, em manchas.
	float faixa_r = abs(fract(pm.y * 9.0 + pm.z * 0.8 + ruido(pm * 1.7) * 2.0) - 0.5);
	float r = arranhoes * (1.0 - smoothstep(0.02, 0.06, faixa_r)) * smoothstep(0.45, 0.6, ruido(pm * 1.1 + 7.0));
	return mix(c, vec3(0.7, 0.7, 0.68), clamp(r, 0.0, 1.0) * 0.85);
}

// Acabamento: 0 fosco, 1 padrão (verniz), 2 brilho, 3 metálico. O padrão
// tem verniz: brilho firme e o reflexo do céu (CarroBloco.reflexo).
float rugosidade_pintura() {
	return acabamento == 0 ? 0.85 : (acabamento == 2 ? 0.16 : (acabamento == 3 ? 0.28 : 0.32));
}

float especular_pintura() {
	return acabamento == 0 ? 0.15 : (acabamento == 2 ? 0.75 : (acabamento == 3 ? 0.6 : 0.6));
}

// Sombra de contato falsa: a parte de baixo da lataria escurece (Y 0..1 do carro).
float oclusao_pintura(float y) {
	return mix(0.55, 1.0, smoothstep(0.05, 0.45, y));
}

// Luz de borda do verniz (nada no fosco).
float borda_pintura() {
	return acabamento == 0 ? 0.0 : 0.35;
}

float metalico_pintura() {
	return acabamento == 3 ? 0.65 : 0.0;
}

vec3 aplicar_faixas(vec3 c, vec3 p_orig) {
	vec3 p = p_orig;
	if (espelhar) {
		p.x = 1.0 - p.x;
	}
	float u = abs(p.x - 0.5) * 2.0 / max(largura_faixas, 0.2);  // 0 no meio, 1 na lateral
	float v = p.y;
	float z = p.z;
	float lado = smoothstep(0.66, 0.74, abs(p.x - 0.5) * 2.0);  // as laterais (sem a largura)
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
} else if (padrao == 16) {  // teto em segunda cor (anos 1940–1950), filete na linha
		f = smoothstep(corte_teto, corte_teto + 0.01, v);
		fil = faixa(v, corte_teto - 0.012, corte_teto);
	}
	c = mix(c, cor_faixa.rgb, clamp(f, 0.0, 1.0));
	c = mix(c, cor_filete.rgb, clamp(fil, 0.0, 1.0));
	// Logo, número e desgaste no carro de verdade (sem o espelho do desenho).
	float lado_r = smoothstep(0.66, 0.74, abs(p_orig.x - 0.5) * 2.0);
	c = aplicar_logo(c, p_orig, lado_r, 1.0 - lado_r);
	c = aplicar_numero(c, p_orig, lado_r, 1.0 - lado_r);
	return aplicar_desgaste(c, p_orig);
}
