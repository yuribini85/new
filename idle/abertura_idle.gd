class_name AberturaIdle
extends Control
## Abertura do jogo novo (docs/idle/conversao_mafia.md, 2): Nova York, 1948, em
## duas cenas de ~3 s. Cena 1: Don Carmine Bellucci, na porta da firma, aponta
## o sobrinho encostado no carro: "Meu sobrinho vai ser campeão." Cena 2: Frankie
## ajeita o cabelo: "Nasci para correr!". Corte seco para a primeira corrida, que
## larga sozinha (a tela faz isso no `fechou`). As cenas 3 e 4 do briefing
## (o último lugar e o primeiro +1) vêm depois da corrida, pela conversa
## "inicio" da escada. Toque completa a fala e pula a pausa.

signal fechou

## Apresentação, não balanceamento.
const CHAO := 0.7
const CREME := Color("eadfc4")
const VINHO := Color("8e2a26")

var _t := 0.0
var _pular := false
var _chefe: TextureRect
var _sobrinho: TextureRect
var _balao: PanelContainer
var _fala: Label
var _brilho := 0.0  # o brilho do topete quando ele ajeita o cabelo
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_chefe = _corpo("edgar_halloway")
	_sobrinho = _corpo("walt_pruitt")
	_balao = PanelContainer.new()
	_balao.add_theme_stylebox_override("panel", IdleUI.caixa(CREME, 4, 16))
	_balao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balao.visible = false
	add_child(_balao)
	_fala = IdleUI.rotulo("", 28, Color("15120e"), _balao)
	_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fala.custom_minimum_size = Vector2(360, 0)


func _corpo(id: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load("res://arte/personagens/corpo/%s.webp" % id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(400, 660)
	r.modulate.a = 0.0
	add_child(r)
	return r


func _ready() -> void:
	_rodar()


func _rodar() -> void:
	var chao := size.y * CHAO
	var r := 0.0 if Preferencias.reduzir_animacoes else 1.0
	# Cena 1: o chefe na porta da firma aponta o sobrinho.
	_chefe.position = Vector2(-160, chao - 470)
	_sobrinho.position = Vector2(size.x * 0.48, chao - 460)
	var tw := create_tween().set_parallel()
	tw.tween_property(_chefe, "modulate:a", 1.0, 0.25 * r + 0.01)
	tw.tween_property(_chefe, "position:x", -40.0, 0.35 * r + 0.01).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sobrinho, "modulate:a", 1.0, 0.3 * r + 0.01)
	await tw.finished
	await _dizer("Meu sobrinho vai ser campeão.", _chefe, 1.2 * r)
	# Cena 2: Frankie ajeita o cabelo.
	_balao.visible = false
	Sons.tocar_ui(self, "toque", -8.0, 1.6)
	tw = create_tween()
	tw.tween_property(self, "_brilho", 1.0, 0.18 * r + 0.01)
	tw.tween_property(self, "_brilho", 0.0, 0.5 * r + 0.01)
	_sobrinho.pivot_offset = _sobrinho.size * Vector2(0.5, 1.0)
	var pulo := create_tween()
	pulo.tween_property(_sobrinho, "scale", Vector2(1.04, 0.97), 0.1 * r + 0.01)
	pulo.tween_property(_sobrinho, "scale", Vector2.ONE, 0.2 * r + 0.01).set_trans(Tween.TRANS_BACK)
	await _dizer("Nasci para correr!", _sobrinho, 1.0 * r)
	# Corte seco para a corrida.
	Sons.tocar_ui(self, "passagem", -6.0)
	tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2 * r + 0.01)
	await tw.finished
	fechou.emit()
	queue_free()


## Balão acima de quem fala, com a fala digitada e a voz em blips. Anda quadro
## a quadro; um toque completa a fala e pula a pausa.
func _dizer(texto: String, quem: TextureRect, espera: float) -> void:
	_fala.text = texto
	_fala.visible_ratio = 0.0
	_balao.visible = true
	_balao.reset_size()
	var x := clampf(quem.position.x + quem.size.x * 0.5 - 200.0, 16.0, size.x - 420.0)
	_balao.position = Vector2(x, quem.position.y - 20.0)
	_pular = false
	var duracao := 0.0 if espera <= 0.0 else texto.length() / 50.0
	var t := 0.0
	var falou := 0
	while t < duracao and not _pular:
		await get_tree().process_frame
		t += get_process_delta_time()
		_fala.visible_ratio = t / duracao
		var letras := int(_fala.visible_ratio * texto.length())
		if letras >= falou + 3:
			falou = letras
			Sons.tocar_ui(self, "voz", -16.0, (0.6 if quem == _chefe else 1.1) * _rng.randf_range(0.94, 1.06), false)
	_fala.visible_ratio = 1.0
	_pular = false
	t = 0.0
	while t < espera and not _pular:
		await get_tree().process_frame
		t += get_process_delta_time()
	_pular = false


func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
	if toque:
		accept_event()
		_pular = true


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var chao := h * CHAO
	TituloIdle.rua(self, w, h, _t, chao)
	# A porta da firma, à esquerda, com a placa.
	draw_rect(Rect2(20, chao - 300, 210, 300), Color("1d1712"))
	draw_rect(Rect2(36, chao - 280, 178, 280), Color("2c2117"))
	draw_rect(Rect2(36, chao - 280, 178, 6), Color("b08d57"))
	var fonte := Tipografia.fonte("display")
	draw_rect(Rect2(20, chao - 352, 300, 44), Color("15120e"))
	draw_string(fonte, Vector2(32, chao - 318), "BELLUCCI & FILHOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("b08d57"))
	# O carro de época do sobrinho.
	TituloIdle.carro_antigo(self, Vector2(w * 0.42, chao + 96), VINHO, 360.0)
	# O topete brilhando quando ele ajeita o cabelo.
	if _brilho > 0.0:
		var c := _sobrinho.position + Vector2(_sobrinho.size.x * 0.5, 40)
		var r := 26.0 * _brilho
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.25, -r * 0.25), c + Vector2(r, 0),
				c + Vector2(r * 0.25, r * 0.25), c + Vector2(0, r), c + Vector2(-r * 0.25, r * 0.25), c + Vector2(-r, 0),
				c + Vector2(-r * 0.25, -r * 0.25)]), Color(1, 1, 0.9, _brilho))
