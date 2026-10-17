shader_type spatial;
render_mode unshaded, cull_disabled;
// Volumes do estilo chapado (MontadorChapado): cada face uma cor só, clara
// para o lado da luz do tema e escura do outro. A normal sai das derivadas da
// posição (face plana), então a malha não precisa de normais próprias.

uniform vec4 cor : source_color = vec4(1.0);
uniform vec4 tinta : source_color = vec4(1.0);
uniform vec3 luz = vec3(-1.6, 2.0, -0.9);
uniform float sombra = 0.45;
uniform float brilho = 1.15;

varying vec3 mundo;
varying vec4 instancia;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	instancia = COLOR;
}

void fragment() {
	vec3 n = normalize(cross(dFdx(mundo), dFdy(mundo)));
	if (n.y < 0.0) {
		n = -n;
	}
	float l = clamp(dot(n, normalize(luz)), 0.0, 1.0);
	ALBEDO = cor.rgb * instancia.rgb * mix(sombra, brilho, l) * tinta.rgb;
}
