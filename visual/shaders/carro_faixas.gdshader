shader_type spatial;
render_mode cull_disabled;
// Lataria (material "Paint") com pintura personalizada: a cor da carroceria e
// as faixas (faixas.gdshaderinc).

#include "res://visual/shaders/faixas.gdshaderinc"

uniform vec4 cor_base : source_color = vec4(1.0);

void vertex() {
	p_carro = posicao_no_carro(VERTEX);
}

void fragment() {
	ALBEDO = aplicar_faixas(cor_base.rgb, p_carro);
	ROUGHNESS = rugosidade_pintura();
	SPECULAR = especular_pintura();
	METALLIC = metalico_pintura();
}
