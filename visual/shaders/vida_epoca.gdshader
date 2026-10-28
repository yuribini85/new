shader_type spatial;
// O que se mexe no cenário de época (golpes visuais, 2026-10-28): a torcida
// balançando no lugar (modo 0) e as bandeirolas no vento (modo 1). A cor vem
// do vértice; o alfa dela é a fase de cada peça.

uniform int modo = 0;
uniform bool parado = false;
// 0..1: a torcida de pé, agitando (ultrapassagem, chegada, o seu carro passando).
uniform float euforia = 0.0;
varying vec3 cor;

void vertex() {
	cor = COLOR.rgb;
	if (!parado) {
		float fase = COLOR.a * 6.2832;
		if (modo == 0) {
			// Sentados, mexendo de leve; de vez em quando um se levanta um pouco.
			float pulo = max(sin(TIME * 0.7 + fase * 3.0) - 0.85, 0.0) * 1.6;
			VERTEX.y += sin(TIME * 2.4 + fase) * 0.04 + pulo;
			VERTEX.y += euforia * (0.25 + 0.45 * abs(sin(TIME * 9.0 + fase * 5.0)));
		} else {
			// Vento: ondas ao longo da peça, mais forte embaixo (ponta solta).
			vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
			float onda = sin(TIME * 6.0 + fase + w.x * 1.3 + w.z * 1.3);
			VERTEX.x += onda * 0.12;
			VERTEX.z += cos(TIME * 5.0 + fase + w.x) * 0.08;
		}
	}
}

void fragment() {
	ALBEDO = cor;
	ROUGHNESS = 0.95;
}
