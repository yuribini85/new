shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
// Sprite isométrico do carro na vitrine (decisão 31): um feixe de luz passa
// devagar pela carroceria, de tempos em tempos. `reflexo` > 0 desenha o mesmo
// sprite como reflexo no piso, mais fraco e sumindo para baixo.

uniform sampler2D textura : source_color, filter_linear_mipmap;
uniform float reflexo = 0.0;
uniform float brilho = 1.0;

void fragment() {
	if (reflexo > 0.0) {
		// Espelhado na vertical; mais forte perto das rodas, sumindo para baixo.
		vec4 r = texture(textura, vec2(UV.x, 1.0 - UV.y));
		ALBEDO = r.rgb * 0.8;
		ALPHA = r.a * reflexo * smoothstep(0.75, 0.25, UV.y);
	} else {
		vec4 c = texture(textura, UV);
		// Feixe diagonal que atravessa a imagem a cada ~5 s.
		float fase = mod(TIME * 0.22, 1.6) - 0.3;
		float feixe = smoothstep(0.09, 0.0, abs(UV.x * 0.8 + UV.y * 0.35 - fase));
		ALBEDO = c.rgb + vec3(feixe * 0.35 * brilho);
		ALPHA = c.a;
	}
}
