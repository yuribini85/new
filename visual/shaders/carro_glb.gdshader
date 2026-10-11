shader_type spatial;
// Carro em modelo 3D (GLB) com atlas de cores chapadas: a lataria vem quase
// branca no atlas e recebe a pintura; o resto (pneus, vidros, lanternas,
// grades) fica como está.

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec4 pintura : source_color = vec4(1.0);

void fragment() {
	vec3 c = texture(atlas, UV).rgb;
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	float lataria = smoothstep(0.6, 0.8, c.r) * (1.0 - smoothstep(0.05, 0.12, sat));
	ALBEDO = mix(c, c * pintura.rgb * 1.1, lataria);
	ROUGHNESS = mix(0.9, 0.55, lataria);
	SPECULAR = mix(0.2, 0.35, lataria);
}
