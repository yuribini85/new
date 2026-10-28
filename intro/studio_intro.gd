extends Control
## Intro do estúdio "BF": o B se forma como nuvem e o F sai de trás dela como um relâmpago.
## Coloque esta cena como cena principal (ou instancie antes dos jogos).
## Arquivos ao lado deste script: logo_b.png, b_halo.png, f_bolt.png, f_glow.png, txt_title.png,
## txt_sub.png e intro_bf.wav (opcional).
## Importe os PNGs com Mipmaps > Generate ligado (evita serrilhado em telas pequenas).

signal finished

## Cena a abrir no fim (deixe vazio para só emitir `finished`).
@export_file("*.tscn") var next_scene: String = ""
@export var background_color: Color = Color("141210")
## Altura do conjunto (marca + textos) em relação à tela.
@export_range(0.2, 0.95) var block_height_landscape: float = 0.64
@export_range(0.2, 0.95) var block_height_portrait: float = 0.48
@export var skippable: bool = true
@export var play_sound: bool = true
## Versão curta (sem a pausa longa) a partir da segunda abertura do jogo.
@export var short_after_first: bool = true
## Força a versão completa sempre (útil para testar).
@export var force_full: bool = false
## Pontos de onde a nuvem nasce, em coordenadas do logo (0,0 = canto superior esquerdo; 1,1 = inferior direito).
@export var origin_a: Vector2 = Vector2(0.0, 1.0)
@export var origin_b: Vector2 = Vector2(1.0, 0.0)
## Atraso (s) do segundo lado em relação ao primeiro.
@export_range(0.0, 1.0) var origin_b_delay: float = 0.08

const FORM_START := 0.15
const FORM_SPREAD := 0.75
const FORM_JIT := 0.10
const FORM_DUR := 0.45
const LIT_DELAY := 0.08
const LIT_JIT := 0.06
const LIT_DUR := 0.40
const COMPLETE_A := 1.45
const COMPLETE_B := 1.75
const HOLD_END := 6.0       # logo pronta e parada por ~4 s; depois corta direto para o jogo (sem sumir)
const FADE_DUR := 0.5
const SKIP_FADE := 0.25
const SHORT_HOLD_END := 2.4   # versão curta: logo pronta por ~0.5 s
const AUDIO_TAIL := 0.4       # o som termina suave nos últimos 0,4 s
const SEEN_FILE := "user://bf_intro_seen.cfg"

# relâmpago
const FLICKERS := [Vector2(1.06, 0.55), Vector2(1.16, 0.85)]  # (tempo, intensidade) dos clarões dentro da nuvem
const T_DRAW := 1.24       # o raio começa a sair
const T_HIT := 1.33        # o raio chega na ponta (impacto)
const SHAKE_PX := 9.0
# posição do F em pixels do logo_b.png
const F_OFFSET := Vector2(309, -117)
const F_SCALE := 1.0
const F_SIZE := Vector2(846, 967)
const F_CONTENT := Rect2(170, 170, 505, 626)
const F_SRC := Vector2(0.2530, 0.4953)      # ponto (UV do f_bolt.png) de onde o raio sai de trás da nuvem
const F_MAXD := 559.5
const HALO_MARGIN := 100.0
const HALO_SIZE := Vector2(880, 899)
const B_SIDE := Vector2(0, 0)         # espessura extra do papel da nuvem (desligada: a arte já tem volume)
const FLASH_CENTER := Vector2(523, 362)   # centro do clarão do impacto (px do logo)
const FLASH_RADIUS := 800.0
# textos (imagens da referência), posição em px do logo_b.png
const TITLE_POS := Vector2(44, 650)
const TITLE_SIZE_PX := Vector2(892, 215)
const SUB_POS := Vector2(93, 827)
const SUB_SIZE_PX := Vector2(797, 85)
const REST_GLOW := 0.28     # brilho de fundo que fica na marca parada (como na referência)
const T_TITLE := 1.55       # textos entram com fade simples depois do clarão
const T_SUB := 1.80

## x, y, raio, tom — em pixels do logo_b.png
var _circles := PackedFloat32Array([
	382.0, 445.0, 90.0, 0, 302.0, 185.0, 90.0, 0, 228.0, 549.0, 90.0, 0, 541.0, 480.0, 74.0, 0, 489.0, 233.0, 68.9, 0, 372.0, 595.0, 61.0, 0,
	326.0, 319.0, 89.9, 0, 162.0, 186.0, 50.1, 0, 461.0, 339.0, 58.2, 0, 475.0, 600.0, 42.8, 0, 98.0, 565.0, 40.5, 0, 256.0, 425.0, 41.4, 0,
	424.0, 149.0, 38.3, 0, 440.0, 544.0, 64.1, 0, 330.0, 534.0, 90.0, 0, 408.0, 202.0, 67.6, 0, 483.0, 411.0, 69.2, 0, 296.0, 67.0, 28.0, 0,
	466.0, 481.0, 90.0, 0, 354.0, 80.0, 27.0, 0, 215.0, 351.0, 25.6, 0, 290.0, 451.0, 84.1, 0, 222.0, 108.0, 20.4, 0, 185.0, 446.0, 20.4, 0,
	583.0, 565.0, 19.4, 0, 570.0, 266.0, 19.0, 0, 220.0, 257.0, 18.6, 0, 137.0, 609.0, 19.0, 0, 255.0, 88.0, 18.6, 0, 139.0, 570.0, 57.7, 0,
	567.0, 392.0, 16.6, 0, 529.0, 308.0, 15.6, 0, 380.0, 113.0, 16.0, 0, 288.0, 95.0, 50.0, 0, 212.0, 199.0, 49.1, 0, 155.0, 464.0, 14.2, 0,
	621.0, 519.0, 14.2, 0, 349.0, 107.0, 47.0, 0, 548.0, 288.0, 18.6, 0, 212.0, 138.0, 21.0, 0, 203.0, 460.0, 41.7, 0, 292.0, 631.0, 13.2, 0,
	169.0, 634.0, 13.8, 0, 269.0, 644.0, 12.4, 0, 604.0, 540.0, 13.2, 0, 243.0, 371.0, 23.0, 0, 570.0, 235.0, 12.6, 0, 103.0, 208.0, 12.4, 0,
	627.0, 492.0, 12.0, 0, 511.0, 302.0, 33.6, 0, 241.0, 117.0, 38.2, 0, 245.0, 265.0, 22.0, 0, 551.0, 264.0, 36.6, 0, 554.0, 405.0, 34.4, 0,
	238.0, 338.0, 33.6, 0, 433.0, 633.0, 11.0, 0, 433.0, 610.0, 32.8, 0, 419.0, 285.0, 11.8, 0, 479.0, 155.0, 10.0, 0, 527.0, 596.0, 10.0, 0,
	83.0, 485.0, 9.8, 0, 130.0, 465.0, 9.0, 0, 605.0, 522.0, 26.2, 0, 314.0, 635.0, 9.6, 0, 581.0, 544.0, 28.0, 0, 190.0, 641.0, 9.0, 0,
	290.0, 616.0, 27.4, 0, 171.0, 620.0, 26.8, 0, 103.0, 187.0, 9.2, 0, 623.0, 472.0, 8.6, 0, 140.0, 504.0, 8.6, 0, 117.0, 223.0, 9.2, 0,
	249.0, 645.0, 8.6, 0, 97.0, 474.0, 7.6, 0, 415.0, 299.0, 20.6, 0, 573.0, 590.0, 7.4, 0, 112.0, 468.0, 7.2, 0, 595.0, 419.0, 7.6, 0,
	468.0, 164.0, 17.0, 0, 167.0, 243.0, 7.0, 0, 112.0, 198.0, 22.0, 0, 259.0, 635.0, 21.8, 0, 496.0, 158.0, 7.0, 0, 616.0, 485.0, 20.8, 0,
	544.0, 365.0, 7.2, 0, 522.0, 614.0, 7.2, 0, 520.0, 580.0, 7.0, 0, 317.0, 625.0, 19.8, 0, 70.0, 495.0, 5.8, 0, 417.0, 645.0, 5.8, 0,
	163.0, 481.0, 10.2, 0, 518.0, 603.0, 16.4, 0, 487.0, 164.0, 16.4, 0, 603.0, 430.0, 6.2, 0, 408.0, 274.0, 9.6, 0, 127.0, 508.0, 5.6, 0,
	98.0, 617.0, 5.6, 0, 154.0, 241.0, 5.4, 0, 47.0, 523.0, 5.0, 0, 176.0, 238.0, 10.2, 0, 108.0, 624.0, 5.0, 0, 204.0, 641.0, 5.8, 0,
	135.0, 512.0, 13.2, 0, 561.0, 221.0, 5.0, 0, 587.0, 420.0, 12.8, 0, 617.0, 460.0, 5.0, 0, 198.0, 116.0, 4.4, 0, 328.0, 59.0, 4.2, 0,
	330.0, 646.0, 4.2, 0, 199.0, 636.0, 12.0, 0, 161.0, 237.0, 11.8, 0, 416.0, 639.0, 11.8, 0, 557.0, 367.0, 4.2, 0, 91.0, 609.0, 4.0, 0,
	515.0, 624.0, 4.0, 0, 394.0, 124.0, 11.4, 0, 558.0, 227.0, 11.4, 0, 628.0, 505.0, 11.0, 0, 149.0, 503.0, 10.8, 0, 512.0, 572.0, 4.0, 0,
	116.0, 627.0, 4.0, 0, 453.0, 641.0, 4.0, 0, 585.0, 242.0, 3.6, 0, 160.0, 446.0, 3.6, 0, 105.0, 617.0, 9.8, 0, 140.0, 463.0, 9.6, 0,
	551.0, 370.0, 9.4, 0, 512.0, 578.0, 9.4, 0, 109.0, 174.0, 4.2, 0, 235.0, 642.0, 4.2, 0, 584.0, 588.0, 3.6, 0, 175.0, 134.0, 4.0, 0,
	146.0, 237.0, 4.2, 0, 104.0, 224.0, 3.2, 0, 232.0, 287.0, 3.2, 0, 534.0, 360.0, 4.0, 0, 460.0, 643.0, 4.0, 0, 580.0, 585.0, 8.4, 0,
	336.0, 57.0, 3.6, 0, 406.0, 650.0, 3.6, 0, 165.0, 133.0, 3.0, 0, 79.0, 497.0, 3.0, 0, 468.0, 645.0, 3.0, 0, 96.0, 610.0, 8.0, 0,
	162.0, 450.0, 7.8, 0, 210.0, 416.0, 3.2, 0, 213.0, 641.0, 3.2, 0, 337.0, 649.0, 3.2, 0, 76.0, 493.0, 7.6, 0, 128.0, 226.0, 5.0, 0,
	587.0, 248.0, 3.0, 0, 605.0, 438.0, 5.0, 0, 56.0, 576.0, 3.0, 0, 120.0, 466.0, 7.4, 0, 205.0, 323.0, 2.8, 0, 564.0, 369.0, 2.8, 0,
	118.0, 513.0, 2.8, 0, 58.0, 582.0, 2.8, 0, 61.0, 588.0, 2.8, 0, 284.0, 646.0, 2.8, 0, 107.0, 221.0, 7.2, 0, 200.0, 110.0, 4.2, 0,
	334.0, 61.0, 6.6, 0, 104.0, 470.0, 6.6, 0, 335.0, 645.0, 6.6, 0, 282.0, 643.0, 6.4, 0, 403.0, 114.0, 3.2, 0, 65.0, 592.0, 3.2, 0,
	441.0, 283.0, 6.0, 0, 548.0, 194.0, 3.0, 0, 123.0, 628.0, 3.0, 0, 182.0, 137.0, 2.8, 0, 531.0, 176.0, 2.8, 0, 535.0, 179.0, 2.8, 0,
	539.0, 183.0, 2.8, 0, 521.0, 336.0, 3.2, 0, 529.0, 584.0, 3.2, 0, 206.0, 326.0, 5.6, 0, 89.0, 476.0, 5.6, 0, 121.0, 514.0, 5.6, 0,
	158.0, 134.0, 3.0, 0, 588.0, 254.0, 3.0, 0, 56.0, 563.0, 3.0, 0, 56.0, 569.0, 3.0, 0, 477.0, 644.0, 3.0, 0, 180.0, 647.0, 3.0, 0,
	400.0, 652.0, 3.0, 0, 465.0, 642.0, 5.4, 0, 323.0, 53.0, 2.8, 0, 544.0, 189.0, 2.8, 0, 236.0, 303.0, 2.8, 0, 613.0, 454.0, 2.8, 0,
	94.0, 483.0, 2.8, 0, 155.0, 492.0, 2.8, 0, 554.0, 556.0, 2.8, 0,
])

const SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D mask_tex : filter_linear;
uniform float complete = 0.0;
uniform float fade = 1.0;
uniform vec3 shade = vec3(0.42, 0.39, 0.36);
uniform float backlight = 0.0;
uniform vec2 px = vec2(0.001, 0.001);       // 1 pixel do logo em UV
uniform vec2 side_off = vec2(-14.0, 22.0);  // espessura do papel, em pixels
float lit_at(vec2 uv) {
	float g = texture(mask_tex, uv).g * 0.36;
	g += texture(mask_tex, uv + vec2(6.0, 0.0) * px).g * 0.16;
	g += texture(mask_tex, uv - vec2(6.0, 0.0) * px).g * 0.16;
	g += texture(mask_tex, uv + vec2(0.0, 6.0) * px).g * 0.16;
	g += texture(mask_tex, uv - vec2(0.0, 6.0) * px).g * 0.16;
	return g;
}
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float form = max(clamp(texture(mask_tex, UV).r, 0.0, 1.0), complete);
	float lit = max(clamp(lit_at(UV), 0.0, 1.0), complete);
	vec3 col = mix(base.rgb * shade * 1.25, base.rgb, lit);
	// luz do raio contornando a nuvem pelo lado direito
	float rim = clamp(base.a - texture(TEXTURE, UV + vec2(8.0, -3.0) * px).a, 0.0, 1.0);
	rim += 0.5 * clamp(base.a - texture(TEXTURE, UV + vec2(16.0, -6.0) * px).a, 0.0, 1.0);
	col += vec3(1.0, 0.96, 0.88) * rim * backlight * 1.1 + col * backlight * 0.04;
	float a_front = base.a * form;
	// lateral do papel (espessura), igual ao raio
	vec2 suv = UV - side_off * px;
	vec4 sb = texture(TEXTURE, suv);
	float sform = max(clamp(texture(mask_tex, suv).r, 0.0, 1.0), complete);
	float a_side = sb.a * sform * (1.0 - a_front);
	vec3 side_col = sb.rgb * vec3(0.30, 0.27, 0.235);
	float a_out = a_front + a_side;
	vec3 rgb = (col * a_front + side_col * a_side) / max(a_out, 0.0001);
	COLOR = vec4(rgb, a_out * fade);
}
"""

const BOLT_SHADER := """
shader_type canvas_item;
uniform float prog = 0.0;
uniform float hot = 0.0;
uniform float fade = 1.0;
uniform vec2 src = vec2(0.28, 0.53);
uniform vec2 tex_size = vec2(1140.0, 1630.0);
uniform float max_dist = 950.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float along = length((UV - src) * tex_size) / max_dist;
	float j = h(floor(UV * vec2(28.0, 60.0))) * 0.05;
	float vis = 1.0 - smoothstep(-0.01, 0.01, along + j - prog * 1.06);
	vec3 col = mix(base.rgb, vec3(1.0, 0.99, 0.95), hot);
	COLOR = vec4(col, base.a * vis * fade);
}
"""

const GLOW_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform float prog = 0.0;
uniform float amount = 0.0;
uniform float fade = 1.0;
uniform vec2 src = vec2(0.28, 0.53);
uniform vec2 tex_size = vec2(1140.0, 1630.0);
uniform float max_dist = 950.0;
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float along = length((UV - src) * tex_size) / max_dist;
	float vis = 1.0 - smoothstep(-0.08, 0.08, along - prog * 1.1);
	COLOR = vec4(base.rgb * amount, base.a * vis * fade);
}
"""

class MaskDrawer extends Node2D:
	var pos: PackedVector2Array
	var rad: PackedFloat32Array
	var tf: PackedFloat32Array
	var tl: PackedFloat32Array
	var t := 0.0
	var form_dur := 0.55
	var lit_dur := 0.7

	static func ease_out_back(x: float) -> float:
		var c1 := 1.70158 * 0.9
		var c3 := c1 + 1.0
		return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)

	static func ease_out_cubic(x: float) -> float:
		return 1.0 - pow(1.0 - x, 3.0)

	func _draw() -> void:
		for i in pos.size():
			var pf := clampf((t - tf[i]) / form_dur, 0.0, 1.0)
			if pf > 0.0:
				draw_circle(pos[i], maxf(rad[i] * ease_out_back(pf), 0.0), Color(1, 0, 0, 1), true, -1.0, true)
			var pl := clampf((t - tl[i]) / lit_dur, 0.0, 1.0)
			if pl > 0.0:
				draw_circle(pos[i], maxf(rad[i] * ease_out_back(pl), 0.0), Color(0, 1, 0, 1), true, -1.0, true)

var _t := 0.0
var _done := false
var _skip_at := -1.0
var _tex: Texture2D
var _vp: SubViewport
var _drawer: MaskDrawer
var _logo: TextureRect
var _mat: ShaderMaterial
var _halo: TextureRect
var _f_glow: TextureRect
var _f_bolt: TextureRect
var _glow_mat: ShaderMaterial
var _bolt_mat: ShaderMaterial
var _screen_flash: TextureRect
var _audio_t0 := -1.0
var _hold_end := HOLD_END
var _shake := Vector2.ZERO
var _bg: ColorRect
var _title: TextureRect
var _sub: TextureRect
var _audio: AudioStreamPlayer


func _ready() -> void:
	# primeira abertura: versão completa; depois, versão curta
	if short_after_first and not force_full and FileAccess.file_exists(SEEN_FILE):
		_hold_end = SHORT_HOLD_END
	else:
		var f := FileAccess.open(SEEN_FILE, FileAccess.WRITE)
		if f:
			f.store_string("seen")
			f.close()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dir: String = get_script().resource_path.get_base_dir()
	_tex = load(dir + "/logo_b.png")

	_bg = ColorRect.new()
	_bg.color = background_color
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_vp = SubViewport.new()
	_vp.size = Vector2i(_tex.get_width(), _tex.get_height())
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	_drawer = MaskDrawer.new()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_drawer.material = add_mat
	_build_timing()
	_vp.add_child(_drawer)

	# luz atrás da nuvem: halo com a forma da própria nuvem (só aparece nas bordas)
	_halo = _make_rect(load(dir + "/b_halo.png"))
	var halo_mat := CanvasItemMaterial.new()
	halo_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo.material = halo_mat
	_halo.modulate.a = 0.002
	add_child(_halo)

	# F: brilho e raio (atrás da nuvem)
	_f_glow = _make_rect(load(dir + "/f_glow.png"))
	var gsh := Shader.new()
	gsh.code = GLOW_SHADER
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = gsh
	_glow_mat.set_shader_parameter("src", F_SRC)
	_glow_mat.set_shader_parameter("tex_size", F_SIZE)
	_glow_mat.set_shader_parameter("max_dist", F_MAXD)
	_f_glow.material = _glow_mat
	add_child(_f_glow)

	_f_bolt = _make_rect(load(dir + "/f_bolt.png"))
	var bsh := Shader.new()
	bsh.code = BOLT_SHADER
	_bolt_mat = ShaderMaterial.new()
	_bolt_mat.shader = bsh
	_bolt_mat.set_shader_parameter("src", F_SRC)
	_bolt_mat.set_shader_parameter("tex_size", F_SIZE)
	_bolt_mat.set_shader_parameter("max_dist", F_MAXD)
	_f_bolt.material = _bolt_mat
	add_child(_f_bolt)

	_logo = _make_rect(_tex)
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("mask_tex", _vp.get_texture())
	_mat.set_shader_parameter("px", Vector2(1.0 / _tex.get_width(), 1.0 / _tex.get_height()))
	_mat.set_shader_parameter("side_off", B_SIDE)
	_logo.material = _mat
	add_child(_logo)

	# clarão do impacto: luz radial centrada no encontro da nuvem com o raio (não a tela inteira)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	grad.colors = PackedColorArray([Color(1, 0.97, 0.9, 1), Color(1, 0.95, 0.86, 0.35), Color(1, 0.95, 0.86, 0)])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256
	_screen_flash = _make_rect(gtex)
	var sf_mat := CanvasItemMaterial.new()
	sf_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_screen_flash.material = sf_mat
	_screen_flash.modulate.a = 0.002
	add_child(_screen_flash)

	_title = _make_rect(load(dir + "/txt_title.png"))
	_title.modulate.a = 0.0
	add_child(_title)
	_sub = _make_rect(load(dir + "/txt_sub.png"))
	_sub.modulate.a = 0.0
	add_child(_sub)

	if play_sound and ResourceLoader.exists(dir + "/intro_bf.wav"):
		_audio = AudioStreamPlayer.new()
		_audio.stream = load(dir + "/intro_bf.wav")
		add_child(_audio)
		_audio.play()

	_layout()


func _build_timing() -> void:
	var n := int(_circles.size() / 4.0)
	var size_px := Vector2(_tex.get_width(), _tex.get_height())
	var oa := origin_a * size_px
	var ob := origin_b * size_px
	var rmax := 0.0
	var dist := PackedFloat32Array()
	var side_delay := PackedFloat32Array()
	dist.resize(n)
	side_delay.resize(n)
	var dmax := 0.0
	var das := PackedFloat32Array()
	var dbs := PackedFloat32Array()
	das.resize(n)
	dbs.resize(n)
	var amin := INF
	var bmin := INF
	for i in n:
		var c := Vector2(_circles[i * 4], _circles[i * 4 + 1])
		var r := _circles[i * 4 + 2]
		rmax = maxf(rmax, r)
		das[i] = c.distance_to(oa) - r * 0.5
		dbs[i] = c.distance_to(ob) - r * 0.5
		amin = minf(amin, das[i])
		bmin = minf(bmin, dbs[i])
	for i in n:
		# cada frente começa no círculo mais próximo do seu ponto de origem
		var da := das[i] - amin
		var db := dbs[i] - bmin
		dist[i] = minf(da, db)
		side_delay[i] = 0.0 if da <= db else origin_b_delay
		dmax = maxf(dmax, dist[i])
	var pos := PackedVector2Array()
	var rad := PackedFloat32Array()
	var tfs := PackedFloat32Array()
	var tls := PackedFloat32Array()
	pos.resize(n)
	rad.resize(n)
	tfs.resize(n)
	tls.resize(n)
	for i in n:
		var x := _circles[i * 4]
		var y := _circles[i * 4 + 1]
		var r := _circles[i * 4 + 2]
		var dn := dist[i] / maxf(dmax, 1.0)
		var t_form := FORM_START + side_delay[i] + FORM_SPREAD * pow(dn, 0.9) + FORM_JIT * _hash01(i, 1) - 0.08 * (r / rmax)
		t_form = maxf(t_form, 0.15)
		pos[i] = Vector2(x, y)
		rad[i] = r
		tfs[i] = t_form
		# puffs pequenos acendem um pouco depois (evita pontinhos claros soltos no começo)
		tls[i] = t_form + LIT_DELAY + LIT_JIT * _hash01(i, 2) + 0.08 * (1.0 - r / rmax)
	_drawer.pos = pos
	_drawer.rad = rad
	_drawer.tf = tfs
	_drawer.tl = tls
	_drawer.form_dur = FORM_DUR
	_drawer.lit_dur = LIT_DUR


func _make_rect(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return r


static func _hash01(i: int, salt: int) -> float:
	var v := sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return v - floor(v)


func _layout() -> void:
	var vs := get_viewport_rect().size
	var tw := float(_tex.get_width())
	var th := float(_tex.get_height())
	# conjunto inteiro (nuvem + raio + textos) em pixels do logo_b.png
	var f_rect := Rect2(F_OFFSET + F_CONTENT.position * F_SCALE, F_CONTENT.size * F_SCALE)
	var bounds := Rect2(0, 0, tw, th).merge(f_rect).merge(Rect2(TITLE_POS, TITLE_SIZE_PX)).merge(Rect2(SUB_POS, SUB_SIZE_PX))
	var ratio := block_height_portrait if vs.y > vs.x else block_height_landscape
	var s0 := minf(vs.y * ratio / bounds.size.y, vs.x * 0.72 / bounds.size.x)

	var k := clampf(_t / COMPLETE_B, 0.0, 1.0)
	var ease_k := 1.0 - pow(1.0 - k, 3.0)
	var s := s0 * (0.94 + 0.06 * ease_k)
	var origin := vs * 0.5 - bounds.get_center() * s + Vector2(0, 14.0 * (1.0 - ease_k)) + _shake
	# respiração da marca parada: a nuvem flutua 1-2 px
	_logo.position = origin
	_logo.size = Vector2(tw, th) * s
	_f_bolt.position = origin + F_OFFSET * s
	_f_bolt.size = F_SIZE * F_SCALE * s
	_f_glow.position = _f_bolt.position
	_f_glow.size = _f_bolt.size
	_halo.position = _logo.position - Vector2.ONE * HALO_MARGIN * s
	_halo.size = HALO_SIZE * s
	_screen_flash.size = Vector2.ONE * FLASH_RADIUS * 2.0 * s
	_screen_flash.position = origin + FLASH_CENTER * s - _screen_flash.size * 0.5
	# textos: posição fixa da referência (sem o tremor do impacto)
	var text_origin := origin - _shake
	_title.position = text_origin + TITLE_POS * s
	_title.size = TITLE_SIZE_PX * s
	_sub.position = text_origin + SUB_POS * s
	_sub.size = SUB_SIZE_PX * s


static func _ease_in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _pulse(t: float, t0: float, decay: float) -> float:
	return exp(-(t - t0) / decay) if t >= t0 else 0.0


func _process(delta: float) -> void:
	if _done:
		return
	# o relógio segue o áudio (se o aparelho engasgar, imagem e som continuam juntos)
	# (o relógio próprio sempre anda: no navegador o som só começa depois do 1º toque, e a intro não pode
	# ficar parada esperando por ele)
	_t += delta
	if _audio and _audio.playing:
		var at := _audio.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		_t = maxf(_t, at)
	_drawer.t = _t
	if _t < COMPLETE_B + 0.1:
		_drawer.queue_redraw()
	elif _vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var complete := smoothstep(COMPLETE_A, COMPLETE_B, _t)
	var fade := 1.0   # a marca não some: no fim a cena troca direto
	# relâmpago
	var pre := 0.0
	for f in FLICKERS:
		pre += f.y * _pulse(_t, f.x, 0.05)
	var hit := _pulse(_t, T_HIT, 0.2)
	var hit_fast := _pulse(_t, T_HIT, 0.07)
	var prog := clampf((_t - T_DRAW) / (T_HIT - T_DRAW), 0.0, 1.0)
	prog = prog * prog
	var drawing := 1.0 if (_t >= T_DRAW and _t < T_HIT) else 0.0
	var hot := maxf(drawing, hit)
	_bolt_mat.set_shader_parameter("prog", prog)
	_bolt_mat.set_shader_parameter("hot", hot)
	_bolt_mat.set_shader_parameter("fade", fade)
	_glow_mat.set_shader_parameter("prog", prog)
	# brilho do F pulsa devagar enquanto a marca está parada
	var breathe := 0.14 * sin(_t * TAU / 2.4) * smoothstep(T_HIT + 0.6, T_HIT + 1.6, _t)
	_glow_mat.set_shader_parameter("amount", (1.0 + 1.0 * hot + breathe) if prog > 0.0 else 0.0)
	_glow_mat.set_shader_parameter("fade", fade)
	_mat.set_shader_parameter("backlight", pre + 0.8 * drawing + 1.0 * hit)
	_halo.modulate.a = maxf(clampf(0.7 * pre + 0.8 * drawing + 1.0 * hit + REST_GLOW * smoothstep(T_HIT, T_HIT + 0.8, _t), 0.0, 1.0) * fade, 0.002)
	_screen_flash.modulate.a = maxf(clampf(0.25 * hit_fast, 0.0, 1.0) * fade, 0.002)
	var sk := SHAKE_PX * _pulse(_t, T_HIT, 1.0 / 12.0)
	_shake = Vector2(sin(_t * 95.0), cos(_t * 120.0)) * sk

	_mat.set_shader_parameter("complete", complete)
	_mat.set_shader_parameter("fade", fade)
	_title.modulate.a = _ease_in_out(clampf((_t - T_TITLE) / 0.5, 0.0, 1.0)) * fade
	_sub.modulate.a = _ease_in_out(clampf((_t - T_SUB) / 0.5, 0.0, 1.0)) * fade
	if _audio and _hold_end < HOLD_END:
		_audio.volume_db = linear_to_db(maxf(1.0 - smoothstep(_hold_end - AUDIO_TAIL, _hold_end, _t), 0.0001))
	_layout()

	if _skip_at >= 0.0 or _t >= _hold_end:
		_finish()


func _gui_input(event: InputEvent) -> void:
	if _try_skip(event):
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _try_skip(event):
		get_viewport().set_input_as_handled()


func _try_skip(event: InputEvent) -> bool:
	if not skippable or _skip_at >= 0.0 or _t < 0.3:
		return false
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		_skip_at = _t
	return pressed


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
