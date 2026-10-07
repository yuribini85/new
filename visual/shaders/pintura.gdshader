shader_type canvas_item;
// Pintura por programação (docs/arte_carros.md): a arte vem com a carroceria
// branca; a pintura é o pixel quase sem cor e claro. Cada pixel de pintura vira
// um tom da cor escolhida (sombra, meio-tom, luz) pela posição do brilho dele na
// faixa da pintura do sprite (v_lo, v_med, v_ref: medidos por
// tools/medir_pintura.gd). Cores escuras: menos grão, mais contraste entre
// facetas e reflexo levemente frio. Mesma conta da Oficina de Pintura aprovada.
// blend_disabled: grava cor e alfa como estão (a imagem vai para uma textura).
render_mode blend_disabled, unshaded;

uniform vec4 cor : source_color = vec4(0.78, 0.06, 0.18, 1.0);
uniform float tolerancia = 0.7;
uniform float v_lo = 0.63;
uniform float v_med = 0.85;
uniform float v_ref = 0.96;

float peso(vec3 c) {
	float v = max(c.r, max(c.g, c.b));
	float s = v > 0.0 ? (v - min(c.r, min(c.g, c.b))) / v : 0.0;
	float s_max = 0.06 + tolerancia * 0.16;
	float v_min = 0.75 - tolerancia * 0.35;
	return (1.0 - smoothstep(s_max, s_max + 0.06, s)) * smoothstep(v_min - 0.08, v_min, v);
}

float brilho(vec3 c) {
	return max(c.r, max(c.g, c.b));
}

void fragment() {
	vec4 px = texture(TEXTURE, UV);
	// Vizinhança (9 amostras a 3 px): brilho médio da pintura em volta, que separa a
	// faceta do grão, e quantos vizinhos são pintura, que recupera a borda
	// antisserrilhada entre pintura e friso (sem cor, mais escura que a pintura).
	float soma = 0.0;
	float n = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec4 q = texture(TEXTURE, UV + vec2(float(i), float(j)) * 3.0 * TEXTURE_PIXEL_SIZE);
			if (q.a > 0.0 && peso(q.rgb) > 0.5) {
				soma += brilho(q.rgb);
				n += 1.0;
			}
		}
	}
	float v = brilho(px.rgb);
	float s = v > 0.0 ? (v - min(px.r, min(px.g, px.b))) / v : 0.0;
	float s_max = 0.06 + tolerancia * 0.16;
	float borda = (1.0 - smoothstep(s_max, s_max + 0.06, s)) * smoothstep(0.25, 0.4, v) * smoothstep(1.0, 4.0, n);
	float p0 = peso(px.rgb);
	// Cercado de pintura, pintura parcial conta como inteira (não mistura com o branco).
	float w = px.a > 0.0 ? max(max(p0, borda), smoothstep(0.02, 0.25, p0) * smoothstep(2.0, 5.0, n)) : 0.0;
	if (w <= 0.0) {
		COLOR = px;
	} else {
		float vb = n > 0.0 ? soma / n : v;
		vec3 alvo = cor.rgb;
		float l = dot(alvo, vec3(0.2126, 0.7152, 0.0722));
		float escuro = (1.0 - l) * (1.0 - l);
		float meia = max(max(v_ref - v_med, v_med - v_lo), 0.02);
		float vv = vb + (v - vb) * (0.3 + 0.7 * l);
		float t = 0.5 + (vv - v_med) / (2.0 * meia) * (1.0 + 0.7 * escuro);
		vec3 sombra = alvo * 0.5 + 0.02 * (1.0 - l);
		vec3 meio = alvo + (1.0 - alvo) * 0.07 * escuro;
		vec3 luz = alvo + (1.0 - alvo) * (0.16 + 0.46 * escuro);
		vec3 x = t < 0.5 ? mix(sombra, meio, max(0.0, t * 2.0)) : mix(meio, luz, min(1.0, (t - 0.5) * 2.0));
		float reflexo = max(0.0, t - 1.0) * 0.6;
		x = clamp(x + (1.0 - x) * reflexo + vec3(-0.02, 0.0, 0.035) * escuro * max(0.0, t - 0.4), 0.0, 1.0);
		// Borda: escurece com o próprio brilho (é meio friso), na cor da pintura.
		x *= mix(1.0, clamp(v / max(vb, 0.01), 0.0, 1.0), step(p0, 0.5));
		COLOR = vec4(mix(px.rgb, x, w), px.a);
	}
}
