shader_type canvas_item;
// Retícula de impressão (pontos de meio-tom) que escurece as bordas da cena em
// quadrinho (CenaQuadrinho), como a página impressa dos gibis da época.

uniform float passo = 10.0;
uniform vec4 cor : source_color = vec4(0.08, 0.05, 0.03, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	float borda = smoothstep(0.32, 0.78, length(uv * vec2(1.25, 1.0)));
	// Grade a 45°, pontos que crescem para a borda.
	vec2 q = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * FRAGCOORD.xy / passo;
	float r = sqrt(borda) * 0.62;
	float ponto = 1.0 - smoothstep(r - 0.07, r, length(fract(q) - 0.5));
	COLOR = vec4(cor.rgb, ponto * borda * 0.75);
}
