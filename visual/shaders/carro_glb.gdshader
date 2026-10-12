shader_type spatial;
render_mode cull_disabled;
// Carro em modelo 3D (GLB) com atlas de cores chapadas: a lataria vem quase
// branca no atlas e recebe a pintura (e as faixas da Oficina,
// faixas.gdshaderinc); o resto (pneus, vidros, lanternas, grades) fica como está.

#include "res://visual/shaders/faixas.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec4 pintura : source_color = vec4(1.0);

void vertex() {
	p_carro = posicao_no_carro(VERTEX);
}

void fragment() {
	vec3 c = texture(atlas, UV).rgb;
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	float lataria = smoothstep(0.6, 0.8, c.r) * (1.0 - smoothstep(0.05, 0.12, sat));
	vec3 pintado = aplicar_faixas(pintura.rgb, p_carro);
	ALBEDO = mix(c, c * pintado * 1.1, lataria);
	ROUGHNESS = mix(0.9, rugosidade_pintura(), lataria);
	SPECULAR = mix(0.2, especular_pintura(), lataria);
	METALLIC = metalico_pintura() * lataria;
}
