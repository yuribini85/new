shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
// Sprite isométrico do carro na vitrine (decisão 31): um feixe de luz passa
// devagar pela carroceria, de tempos em tempos. `reflexo` > 0 desenha o mesmo
// sprite como reflexo no piso: cada coluna é espelhada na linha do chão (a reta
// que passa pelo apoio das rodas, inclinada como o carro), borrada, mais fraca e
// sumindo para longe do carro, sobre uma sombra de contato. O quadro do reflexo tem o dobro da altura do
// sprite; a metade de cima coincide com ele.

uniform sampler2D textura : source_color, filter_linear_mipmap;
uniform float reflexo = 0.0;
uniform float brilho = 1.0;
// Linha do chão em UV do sprite: dois pontos (apoio das rodas).
uniform vec2 chao_a = vec2(0.0, 1.0);
uniform vec2 chao_b = vec2(1.0, 1.0);
// Até onde o reflexo vai abaixo do chão (fração da altura do sprite).
uniform float alcance = 0.22;

void fragment() {
	if (reflexo > 0.0) {
		vec2 uv = vec2(UV.x, UV.y * 2.0);
		float t = (uv.x - chao_a.x) / max(chao_b.x - chao_a.x, 1e-4);
		float linha = mix(chao_a.y, chao_b.y, t);
		float d = uv.y - linha;
		// Reflexo: a coluna espelhada na linha do chão, borrada e mais fraca.
		vec4 r = vec4(0.0);
		if (d > 0.0 && linha - d > 0.0) {
			r = textureLod(textura, vec2(uv.x, linha - d), 1.5);
			r.a *= reflexo * (1.0 - smoothstep(0.0, alcance, d));
		}
		// Sombra de contato: faixa escura colada ao chão, onde há carro na
		// coluna (silhueta borrada logo acima da linha), sumindo para baixo.
		// Acima da linha só aparece no vão entre a carroceria e o piso.
		float corpo = textureLod(textura, vec2(uv.x, linha - 0.06), 4.0).a;
		float sombra = corpo * 0.85 * (1.0 - smoothstep(0.0, 0.045, d)) * smoothstep(-0.22, -0.08, d);
		// As duas camadas num só quadro: reflexo sobre a sombra.
		float a = 1.0 - (1.0 - sombra) * (1.0 - r.a);
		if (a <= 0.001) {
			discard;
		}
		ALBEDO = r.rgb * 0.75 * r.a / a;
		ALPHA = a;
	} else {
		vec4 c = texture(textura, UV);
		// Feixe diagonal que atravessa a imagem a cada ~5 s.
		float fase = mod(TIME * 0.22, 1.6) - 0.3;
		float feixe = smoothstep(0.09, 0.0, abs(UV.x * 0.8 + UV.y * 0.35 - fase));
		ALBEDO = c.rgb + vec3(feixe * 0.35 * brilho);
		ALPHA = c.a;
	}
}
