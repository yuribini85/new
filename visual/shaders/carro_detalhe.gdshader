shader_type spatial;
render_mode cull_disabled;
// Tudo o que não é pintura no carro gerado (Carroceria, Rodas): frisos, cromo,
// vidro, pneus, aros, faróis e lanternas numa superfície só (uma chamada de
// desenho). Cada vértice traz o próprio material:
//   COLOR.rgb  cor (linear)
//   UV         (metálico, rugosidade)
//   UV2        (emissão relativa à cor, especular)

// Força das luzes do carro (faróis, lanternas, setas): 1 de dia; a corrida
// noturna pode baixar para os faróis não estourarem.
uniform float brilho_luzes = 1.0;

void fragment() {
	ALBEDO = COLOR.rgb;
	METALLIC = UV.x;
	ROUGHNESS = UV.y;
	SPECULAR = UV2.y;
	EMISSION = COLOR.rgb * UV2.x * brilho_luzes;
}
