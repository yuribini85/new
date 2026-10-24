shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Sombra dos objetos do kit (docs/arte_pistas.md): a silhueta do sprite
// arrastada no chão na direção da luz, presa à base do objeto, como sombra de
// verdade (uma cópia deslocada fica solta e parece outro objeto).
// A malha é o quadro do sprite aumentado (folga) para caber o arrasto em
// qualquer giro; o deslocamento em UV sai das derivadas da tela, então vale
// para qualquer giro e escala de instância (MultiMesh).

uniform sampler2D textura : filter_linear_mipmap;
uniform vec2 arrasto = vec2(4.0, -2.0); // metros no mundo (x, z)
uniform vec2 folga = vec2(1.0);         // tamanho da malha / tamanho do sprite
uniform float alfa = 0.45;
// 0: arrastada desde a base; 1: só a silhueta no fim do arrasto (objeto suspenso).
uniform float inicio = 0.0;
uniform vec4 cor : source_color = vec4(0.02, 0.03, 0.05, 1.0);

varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv = (UV - 0.5) * folga + 0.5;
	// Jacobiano UV/mundo: quanto o UV anda por metro no mundo.
	mat2 w = mat2(dFdx(mundo), dFdy(mundo));
	mat2 u = mat2(dFdx(uv), dFdy(uv));
	vec2 passo_uv = u * inverse(w) * arrasto;
	float a = 0.0;
	const int N = 14;
	for (int i = 0; i <= N; i++) {
		// A sombra do ponto p vem do objeto em p - arrasto * t.
		vec2 q = uv - passo_uv * mix(inicio, 1.0, float(i) / float(N));
		if (q.x >= 0.0 && q.x <= 1.0 && q.y >= 0.0 && q.y <= 1.0) {
			a = max(a, textureLod(textura, q, 1.5).a);
		}
	}
	ALBEDO = cor.rgb;
	ALPHA = a * alfa;
}
