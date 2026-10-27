class_name AberturaIdle
extends Control
## Abertura do jogo novo do Chrome Racing Team (docs/idle/direcao.md, 6): uma
## cena curta, física e com uma piada, no ritmo da abertura do White Foot. O
## carrão do Sal derrapa na porta da oficina; ele oferece o contrato e a cena
## espera um toque. O toque rasga o contrato, o Sal arranca furioso, o portão
## da oficina sobe aos trancos e a Mara chama para a corrida. ~13 s, um toque.

signal fechou

## Apresentação, não balanceamento.
const VERMELHO := Color("e5484d")
const OURO := Color("ffc53d")

var _t := 0.0
var _porta := 0.0
var _carro_x := 0.0  # x do carrão do Sal (esquerda do carro)
var _carro_vis := true
var _velho := 0.0  # o carro velho da equipe aparecendo (0 a 1)
var _contrato := false  # o contrato na mão do Sal, esperando o toque
var _rasgou := false
var _pular := false  # toque fora do contrato: completa a fala / pula a pausa
var _tremor := 0.0
var _papeis: Array = []
var _fumaca: Array = []
var _sal: TextureRect
var _mara: TextureRect
var _balao: PanelContainer
var _fala: Label
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_sal = _corpo("sal_moretti")
	_mara = _corpo("mara_hayes_cruzados")
	_balao = PanelContainer.new()
	_balao.add_theme_stylebox_override("panel", IdleUI.caixa(Color("f4f1ea"), 4, 16))
	_balao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balao.visible = false
	add_child(_balao)
	_fala = IdleUI.rotulo("", 26, Color("15181d"), _balao)
	_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fala.custom_minimum_size = Vector2(380, 0)


func _corpo(id: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load("res://arte/personagens/corpo/%s.webp" % id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(420, 680)
	r.modulate.a = 0.0
	add_child(r)
	return r


const CHAO := 0.7  # o chão mais baixo que no título: a cena ocupa a tela


func _chao() -> float:
	return size.y * CHAO


func _ready() -> void:
	_carro_x = size.x + 340.0
	_rodar()


func _rodar() -> void:
	var chao := _chao()
	var r := 0.0 if Preferencias.reduzir_animacoes else 1.0
	# 1. O carrão do Sal derrapa na porta da oficina.
	Sons.tocar_ui(self, "pneu", -4.0)
	var tw := create_tween()
	tw.tween_property(self, "_carro_x", size.x * 0.5, 0.7 * r + 0.01).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	Sons.tocar_ui(self, "impacto", -6.0)
	_tremor = 1.0
	_soltar_fumaca(Vector2(size.x * 0.5 + 280, chao + 96), 10)
	# O Sal desce do carro e fica de pé na calçada, na frente dele.
	_sal.position = Vector2(size.x * 0.42, chao - 470)
	tw = create_tween().set_parallel()
	tw.tween_property(_sal, "modulate:a", 1.0, 0.25 * r + 0.01)
	tw.tween_property(_sal, "position:x", size.x * 0.3, 0.35 * r + 0.01).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	await _dizer("Assina aqui e essa oficina vira meu estacionamento.", _sal, 1.6 * r)
	# 2. O contrato: a cena espera o toque do jogador.
	_contrato = true
	_balao.visible = false
	while not _rasgou:
		await get_tree().process_frame
	# 3. Rasgou: papel para todo lado, o Sal arranca.
	_contrato = false
	Sons.tocar_ui(self, "raspagem", -2.0, 1.4)
	_tremor = 0.6
	var mao := _ponto_contrato()
	for i in 26:
		var a := _rng.randf() * TAU
		_papeis.append({"p": mao, "v": Vector2(cos(a), sin(a) - 0.6) * _rng.randf_range(160, 520), "t0": _t,
				"rot": _rng.randf() * TAU, "w": _rng.randf_range(-8.0, 8.0), "tam": _rng.randf_range(10, 20)})
	await _dizer("Você vai se arrepender!", _sal, 1.2 * r)
	_balao.visible = false
	tw = create_tween()
	tw.tween_property(_sal, "modulate:a", 0.0, 0.2 * r + 0.01)
	await tw.finished
	Sons.tocar_ui(self, "passagem", -4.0)
	tw = create_tween()
	tw.tween_property(self, "_carro_x", size.x + 420.0, 0.6 * r + 0.01).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_soltar_fumaca(Vector2(size.x * 0.5 + 20, chao + 96), 16)
	await tw.finished
	_carro_vis = false
	# 4. O portão sobe aos trancos; a Mara e o carro velho aparecem.
	Sons.tocar_ui(self, "porta_abre", -4.0)
	tw = create_tween()
	for passo in [0.35, 0.65, 1.0]:
		tw.tween_property(self, "_porta", passo, 0.28 * r + 0.01).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.12 * r)
	tw.tween_property(self, "_velho", 1.0, 0.4 * r + 0.01)
	await tw.finished
	_mara.position = Vector2(-120, chao - 470)
	tw = create_tween().set_parallel()
	tw.tween_property(_mara, "modulate:a", 1.0, 0.25 * r + 0.01)
	tw.tween_property(_mara, "position:x", size.x * 0.28, 0.35 * r + 0.01).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	await _dizer("Então vamos mostrar pra ele. Chefe, é com você.", _mara, 1.8 * r)
	# 5. Corte para a corrida.
	tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3 * r + 0.01)
	await tw.finished
	fechou.emit()
	queue_free()


## Balão acima da cabeça de quem fala, com a fala digitada e a voz em blips.
## Anda quadro a quadro (sem esperar sinal de tween, que no navegador podia
## chegar antes da espera e travar a cena). Um toque completa a fala e pula a
## pausa.
func _dizer(texto: String, quem: TextureRect, espera: float) -> void:
	_fala.text = texto
	_fala.visible_ratio = 0.0
	_balao.visible = true
	_balao.reset_size()
	var x := clampf(quem.position.x + quem.size.x * 0.5 - 210.0, 16.0, size.x - 446.0)
	_balao.position = Vector2(x, quem.position.y - 30.0)
	_pular = false
	var duracao := 0.0 if espera <= 0.0 else texto.length() / 60.0
	var t := 0.0
	var falou := 0
	while t < duracao and not _pular:
		await get_tree().process_frame
		t += get_process_delta_time()
		_fala.visible_ratio = t / duracao
		var letras := int(_fala.visible_ratio * texto.length())
		if letras >= falou + 4:
			falou = letras
			Sons.tocar_ui(self, "voz", -16.0, (0.62 if quem == _sal else 0.85) * _rng.randf_range(0.94, 1.06), false)
	_fala.visible_ratio = 1.0
	_pular = false
	t = 0.0
	while t < espera and not _pular:
		await get_tree().process_frame
		t += get_process_delta_time()
	_pular = false


func _ponto_contrato() -> Vector2:
	return _sal.position + Vector2(90, 220)


func _soltar_fumaca(onde: Vector2, n: int) -> void:
	for i in n:
		_fumaca.append({"p": onde + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-10, 10)), "t0": _t,
				"v": Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-70, -20)), "r": _rng.randf_range(14, 30)})


func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
	if not toque:
		return
	accept_event()
	if _contrato:
		_rasgou = true
	else:
		_pular = true  # completa a fala ou pula a pausa


func _process(delta: float) -> void:
	_t += delta
	_tremor = maxf(_tremor - delta * 3.0, 0.0)
	position = Vector2(sin(_t * 90.0), cos(_t * 77.0)) * 10.0 * _tremor if not Preferencias.reduzir_animacoes else Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var chao := _chao()
	TituloIdle.cena(self, w, h, _t, _porta, false, CHAO)
	# O carro velho da equipe na porta da oficina.
	if _velho > 0.0:
		_carro(Vector2(w * 0.03, chao + 96), Color(OURO, _velho), 250.0)
	# O carrão vermelho do Sal.
	if _carro_vis:
		_carro(Vector2(_carro_x, chao + 100), VERMELHO, 300.0)
	for f in _fumaca:
		var k := (_t - float(f["t0"])) / 1.2
		if k < 1.0:
			draw_circle(f["p"] + f["v"] * (_t - float(f["t0"])), float(f["r"]) * (1.0 + k), Color(0.55, 0.57, 0.6, 0.4 * (1.0 - k)))
	# O contrato na mão do Sal, com o anel de TOQUE pulsando.
	if _contrato:
		var c := _ponto_contrato()
		draw_rect(Rect2(c - Vector2(34, 44), Vector2(68, 88)), Color("f4f1ea"))
		for i in 5:
			draw_line(c + Vector2(-24, -30 + i * 14), c + Vector2(24, -30 + i * 14), Color("9aa0a8"), 2.0)
		var p := 0.5 + 0.5 * sin(_t * TAU / 0.9)
		draw_arc(c, 70.0 + 10.0 * p, 0, TAU, 40, Color(OURO, 0.6 + 0.4 * p), 5.0)
		var fonte := Tipografia.fonte("display")
		draw_string(fonte, c + Vector2(-48, -96), "TOQUE", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, OURO)
	# Pedaços do contrato voando.
	for pa in _papeis:
		var dt := _t - float(pa["t0"])
		if dt > 2.0:
			continue
		var p2: Vector2 = pa["p"] + pa["v"] * dt + Vector2(0, 520) * dt * dt * 0.5
		var a := float(pa["rot"]) + float(pa["w"]) * dt
		var s := float(pa["tam"])
		var ponta := Vector2(cos(a), sin(a)) * s
		var lado := Vector2(-sin(a), cos(a)) * s * 0.6
		draw_colored_polygon(PackedVector2Array([p2 + ponta, p2 + lado, p2 - ponta, p2 - lado]),
				Color(0.96, 0.95, 0.92, clampf(2.0 - dt, 0.0, 1.0)))


## Carro em planos chapados, de perfil, com as rodas e o vidro.
func _carro(pe: Vector2, cor: Color, largura: float) -> void:
	var a := largura
	draw_colored_polygon(PackedVector2Array([pe + Vector2(0, -24), pe + Vector2(a * 0.18, -50), pe + Vector2(a * 0.42, -78),
			pe + Vector2(a * 0.72, -78), pe + Vector2(a * 0.88, -48), pe + Vector2(a, -38), pe + Vector2(a, 0), pe]), cor)
	draw_colored_polygon(PackedVector2Array([pe + Vector2(a * 0.46, -72), pe + Vector2(a * 0.7, -72),
			pe + Vector2(a * 0.82, -50), pe + Vector2(a * 0.36, -50)]), Color(0.1, 0.13, 0.18, cor.a))
	for x in [a * 0.2, a * 0.8]:
		draw_circle(pe + Vector2(x, 0), 24, Color(0.06, 0.06, 0.07, cor.a))
		draw_circle(pe + Vector2(x, 0), 11, Color(0.35, 0.37, 0.4, cor.a))
