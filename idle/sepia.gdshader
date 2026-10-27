shader_type canvas_item;
// Foto de jornal dos anos 1930 (JornalIdle): tons de sépia, contraste alto e
// retícula de impressão.

uniform float passo = 4.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	l = clamp((l - 0.5) * 1.35 + 0.5, 0.0, 1.0);
	// Retícula: pontos pretos que crescem nas sombras.
	vec2 g = fract(FRAGCOORD.xy / passo) - 0.5;
	float ponto = step(length(g), (1.0 - l) * 0.62);
	vec3 papel = vec3(0.86, 0.79, 0.64);
	vec3 tinta = vec3(0.16, 0.12, 0.08);
	COLOR = vec4(mix(papel, tinta, max(ponto * 0.85, (1.0 - l) * 0.35)), c.a);
}
