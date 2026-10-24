shader_type canvas_item;
// Contorno de desenho em volta da silhueta (fotos dos cartões, Estudio): o
// pixel transparente com vizinho opaco a até `raio` px vira a cor do traço.
uniform vec4 cor : source_color = vec4(0.06, 0.05, 0.05, 1.0);
uniform float raio = 3.0;

void fragment() {
	vec4 px = texture(TEXTURE, UV);
	float perto = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398;
		vec2 d = vec2(cos(ang), sin(ang)) * raio * TEXTURE_PIXEL_SIZE;
		perto = max(perto, texture(TEXTURE, UV + d).a);
		perto = max(perto, texture(TEXTURE, UV + d * 0.5).a);
	}
	float traco = smoothstep(0.3, 0.6, perto) * (1.0 - smoothstep(0.3, 0.6, px.a));
	COLOR = mix(px, cor, traco);
	COLOR.a = max(px.a, traco * cor.a);
}
