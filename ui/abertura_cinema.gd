class_name AberturaCinema
extends Control
## Abertura do jogo (campanha do dono): a noite da corrida em que a Wreckage
## perdeu o piloto, em oito quadros (arte/abertura/NN.webp) com movimento lento
## de câmera e fusões; no acidente, corte seco com clarão, tremor e o estrondo;
## depois o outro carro cruza a linha, a tela escurece e o logo entra com o
## golpe final da música (arte/sons/abertura.ogg, tools/gerar_musica_abertura.py).
## Tempos e movimentos: arte/abertura/roteiro.json (o mesmo da música).
## "Pular" encerra; no fim emite `terminou`.

signal terminou

const PASTA := "res://arte/abertura/"
const CLARAO_S := 0.45
const TREMOR_S := 0.7
const TREMOR_PX := 22.0
const LOGO_ENTRA_S := 1.6
const SAIDA_S := 1.2  # o logo e a música somem juntos no fim

var _r: Dictionary
var _planos: Array = []  # [{dados, rect}]
var _t := 0.0
var _clarao: ColorRect
var _logo: TextureRect
var _musica: AudioStreamPlayer
var _bateu := false
var _acabou := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	_r = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "roteiro.json"))
	for p in _r["planos"]:
		var t := TextureRect.new()
		t.texture = load(PASTA + String(p["img"]) + ".webp")
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.modulate.a = 0.0
		add_child(t)
		_planos.append({"dados": p, "rect": t})
	_clarao = ColorRect.new()
	_clarao.color = Color(1, 0.97, 0.92, 0.0)
	_clarao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clarao)
	_logo = TextureRect.new()
	_logo.texture = Aba.arte("logo")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_logo.offset_left = -310
	_logo.offset_right = 310
	_logo.offset_top = -160
	_logo.offset_bottom = 160
	_logo.pivot_offset = Vector2(310, 160)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.modulate.a = 0.0
	add_child(_logo)
	_musica = AudioStreamPlayer.new()
	_musica.stream = load("res://arte/sons/abertura.ogg")
	add_child(_musica)
	var pular := Button.new()
	Tipografia.acao_secundaria(pular, "Pular ›", Color(0.93, 0.92, 0.88, 0.7), 30, 80)
	pular.custom_minimum_size.x = 150
	pular.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	pular.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pular.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pular.offset_right = -16
	pular.offset_bottom = -16
	pular.pressed.connect(_terminar)
	add_child(pular)


func _ready() -> void:
	_musica.play()


func _process(delta: float) -> void:
	if _acabou:
		return
	# O relógio segue a música (sem descompasso entre som e imagem).
	_quadro(_musica.get_playback_position() if _musica.playing else _t + delta)


## Monta a imagem do instante `t` (s).
func _quadro(t_: float) -> void:
	_t = t_
	var fusao := float(_r["fusao"])
	var batida := float(_r["batida"])
	var tremor := Vector2.ZERO
	if _t >= batida and _t < batida + TREMOR_S and not Preferencias.reduzir_animacoes:
		var forca := 1.0 - (_t - batida) / TREMOR_S
		tremor = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * TREMOR_PX * forca
	for pl in _planos:
		var p: Dictionary = pl["dados"]
		var t: TextureRect = pl["rect"]
		var ini := float(p["ini"])
		var dur := float(p["dur"])
		var u := clampf((_t - ini) / dur, 0.0, 1.0)
		# Entra em fusão (ou seco, no corte) e sai em fusão no fim do plano.
		var entra := 1.0 if p.get("corte", false) and _t >= ini else smoothstep(ini, ini + fusao, _t)
		var sai := 1.0 - smoothstep(ini + dur - fusao, ini + dur, _t)
		t.modulate.a = entra * sai
		t.visible = t.modulate.a > 0.0
		if not t.visible:
			continue
		# Movimento lento: zoom e deslocamento do começo ao fim do plano.
		var z := lerpf(float(p["zoom"][0]), float(p["zoom"][1]), u)
		var pan := Vector2(p["pan"][0][0], p["pan"][0][1]).lerp(Vector2(p["pan"][1][0], p["pan"][1][1]), u)
		var tam := size * z
		var trem := Vector2.ZERO
		if p.has("tremor") and not Preferencias.reduzir_animacoes:
			trem = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * size.x * float(p["tremor"])
		t.size = tam
		t.position = (size - tam) * 0.5 + pan * size + trem + tremor
	# O acidente: clarão branco e o estrondo.
	if _t >= batida and not _bateu:
		_bateu = true
		Sons.tocar_ui(self, "batida", 6.0, 0.7)
	_clarao.color.a = 0.0 if _t < batida else (1.0 - smoothstep(0.0, CLARAO_S, _t - batida)) * 0.9
	# O logo: entra crescendo de leve com o golpe e some no fim.
	var logo := float(_r["logo"])
	var fim := float(_r["fim"])
	if _t >= logo:
		var e := smoothstep(logo, logo + LOGO_ENTRA_S, _t)
		_logo.modulate.a = e * (1.0 - smoothstep(fim - SAIDA_S, fim, _t))
		_logo.scale = Vector2.ONE * lerpf(1.08, 1.0, e)
	if _t >= fim:
		_terminar()


func _terminar() -> void:
	if _acabou:
		return
	_acabou = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(_musica, "volume_db", -40.0, 0.5)
	tw.tween_callback(func():
		terminou.emit()
		queue_free())
