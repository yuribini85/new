class_name CenaQuadrinho
extends Control
## Cena em quadrinho do The Fastfather (data/idle/cenas.json; arte do pacote do
## usuário, arte/fastfather/): como as cenas do inFAMOUS 2, uma ilustração
## parada que a câmera percorre — aproxima de quem fala, com o fundo andando
## menos que as figuras (profundidade) — e balões de quadrinho com a fala
## datilografada. Troca de pose com um pulo curto; quem entra desliza pela
## lateral; a cena abre e fecha com uma passada de tinta. Toque completa a
## fala; outro toque passa (e ela passa sozinha depois de um tempo).
## Sem fundo, a cena vem por cima da tela do jogo (loja, corrida): sem câmera,
## só as figuras e os balões, e a tela escurece um pouco.

signal fechou
signal acao(nome: String)

const CENAS := "res://data/idle/cenas.json"
## Apresentação, não balanceamento.
const LETRAS_POR_S := 42.0
const ESPERA_S := 1.4  # fala inteira na tela: passa sozinha depois disso (+ tempo de leitura)
const LEITURA_S_POR_LETRA := 0.035
const CAMERA_S := 0.6
const ZOOM := 1.14
const PAPEL := Color("f4ecd8")
const TINTA := Color("15110c")
const TARJA := Color("e0b24a")
const VOZ := {"chefe": 0.62, "sobrinho": 1.15, "tony": 0.82}

## Para as fotos (tools/fotos_quadrinho.gd): para na fala de índice parar_em,
## tudo sem animação.
var parar_em := -1

var _cena: Dictionary
var _id := ""
var _com_fundo := false
var _r := 1.0  # 0 sem animação
var _camada_fundo: Control
var _camada_atores: Control
var _fundo: TextureRect
var _atores := {}  # id -> TextureRect
var _ref := {}  # id -> altura de textura da primeira pose (mesma escala em todas)
var _balao: _Balao
var _tinta: _Tinta
var _cam_o := Vector2.ZERO
var _cam_z := 1.0
var _toque := false
var _pulou := false
var _botao_pular: Button
var _t := 0.0
var _rng := RandomNumberGenerator.new()


static func carregar(id: String) -> Dictionary:
	var f := FileAccess.open(CENAS, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d.get(id, {}) if d is Dictionary else {}


func _init(id: String) -> void:
	_id = id
	_cena = carregar(id)
	_com_fundo = String(_cena.get("fundo", "")) != ""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	if not _com_fundo:
		var escuro := ColorRect.new()
		escuro.color = Color(0, 0, 0, 0.3)
		escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
		escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(escuro)
	_camada_fundo = _camada()
	_camada_atores = _camada()
	if _com_fundo:
		_fundo = TextureRect.new()
		_fundo.texture = load("res://arte/fastfather/%s.webp" % String(_cena["fundo"]))
		_fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # escala uniforme, recorta
		_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_camada_fundo.add_child(_fundo)
		# Retícula de impressão nas bordas, como página de quadrinho.
		var ret := ColorRect.new()
		ret.set_anchors_preset(Control.PRESET_FULL_RECT)
		ret.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://idle/reticula.gdshader")
		ret.material = sm
		_camada_fundo.add_child(ret)
	var atores: Dictionary = _cena.get("atores", {})
	for id_ator in atores:
		var a: Dictionary = atores[id_ator]
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE  # o tamanho segue a proporção da textura
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex: Texture2D = load("res://arte/fastfather/%s.webp" % String(a["pose"]))
		_ref[id_ator] = float(tex.get_height())
		tr.texture = tex
		tr.visible = id_ator in _cena.get("inicio", [])
		_camada_atores.add_child(tr)
		_atores[id_ator] = tr
	_balao = _Balao.new()
	_balao.visible = false
	add_child(_balao)
	_tinta = _Tinta.new()
	add_child(_tinta)


func _camada() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _ready() -> void:
	_r = 0.0 if Preferencias.reduzir_animacoes or parar_em >= 0 else 1.0
	_camada_fundo.size = size
	_camada_atores.size = size
	for id_ator in _atores:
		_posar(id_ator, String(_cena["atores"][id_ator]["pose"]))
		_atores[id_ator].position.x = _x_alvo(id_ator)
	_aplicar_camera()
	_rodar()


# --- atores ---------------------------------------------------------------------

func _dado(id_ator: String) -> Dictionary:
	return _cena["atores"][id_ator]


## A pose no tamanho certo: altura da tela × alt na primeira pose, a mesma
## escala nas outras (as artes do mesmo personagem saem do mesmo quadro).
func _posar(id_ator: String, pose: String) -> void:
	var tr: TextureRect = _atores[id_ator]
	var tex: Texture2D = load("res://arte/fastfather/%s.webp" % pose)
	var k := float(_dado(id_ator)["alt"]) * size.y / float(_ref[id_ator])
	var cx := tr.position.x + tr.size.x * 0.5
	tr.texture = tex
	tr.size = Vector2(tex.get_width(), tex.get_height()) * k
	tr.position.y = float(_dado(id_ator)["pe"]) * size.y - tr.size.y
	if tr.visible:
		tr.position.x = cx - tr.size.x * 0.5
	tr.pivot_offset = Vector2(tr.size.x * 0.5, tr.size.y)


func _x_alvo(id_ator: String, x := -1.0) -> float:
	var tr: TextureRect = _atores[id_ator]
	var fx := float(_dado(id_ator)["x"]) if x < 0.0 else x
	return fx * size.x - tr.size.x * 0.5


func _entrar(id_ator: String) -> void:
	var tr: TextureRect = _atores[id_ator]
	if tr.visible:
		return
	var alvo := _x_alvo(id_ator)
	var lado := -1.0 if String(_dado(id_ator).get("entra", "esquerda")) == "esquerda" else 1.0
	tr.visible = true
	tr.position.x = alvo + lado * size.x * 0.5
	tr.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(tr, "position:x", alvo, 0.4 * _r + 0.01).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tr, "modulate:a", 1.0, 0.2 * _r + 0.01)
	Sons.tocar_ui(self, "passagem", -12.0, 1.2)


func _pular(id_ator: String) -> void:
	var tr: TextureRect = _atores[id_ator]
	if _r <= 0.0:
		return
	var tw := create_tween()
	tw.tween_property(tr, "scale", Vector2(1.035, 0.975), 0.07)
	tw.tween_property(tr, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- câmera ---------------------------------------------------------------------

## Janela da câmera: origem o (em coordenadas da cena) e aproximação z; a
## janela nunca sai da cena (sem bordas vazias).
func _janela(foco: Vector2, z: float, altura_foco := 0.36) -> Vector2:
	var o := foco - Vector2(size.x * 0.5, size.y * altura_foco) / z
	return o.clamp(Vector2.ZERO, size - size / z)


func _aplicar_camera() -> void:
	if not _com_fundo:
		return
	_camada_atores.scale = Vector2.ONE * _cam_z
	_camada_atores.position = -_cam_o * _cam_z
	# O fundo anda menos (está mais longe).
	var zf := 1.0 + (_cam_z - 1.0) * 0.55
	var meio := (size - size / _cam_z) * 0.5
	var of := (meio + (_cam_o - meio) * 0.55).clamp(Vector2.ZERO, size - size / zf)
	_camada_fundo.scale = Vector2.ONE * zf
	_camada_fundo.position = -of * zf


func _set_cam_o(v: Vector2) -> void:
	_cam_o = v
	_aplicar_camera()


func _set_cam_z(v: float) -> void:
	_cam_z = v
	_aplicar_camera()


func _cabeca_na_cena(id_ator: String) -> Vector2:
	var tr: TextureRect = _atores[id_ator]
	var x := _x_alvo(id_ator) + tr.size.x * 0.5
	# O chefe está sentado atrás da mesa: a cabeça fica no alto do quadro, à direita do meio.
	if id_ator == "chefe":
		return Vector2(tr.position.x + tr.size.x * 0.62, tr.position.y + tr.size.y * 0.1)
	return Vector2(x, tr.position.y + tr.size.y * 0.09)


func _mirar(id_ator: String, z: float) -> void:
	if not _com_fundo:
		return
	var o := _janela(_cabeca_na_cena(id_ator), z)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_cam_o, _cam_o, o, CAMERA_S * _r + 0.01)
	tw.tween_method(_set_cam_z, _cam_z, z, CAMERA_S * _r + 0.01)
	await tw.finished


func _na_tela(p: Vector2) -> Vector2:
	return _camada_atores.position + p * _camada_atores.scale


# --- roteiro --------------------------------------------------------------------

func _rodar() -> void:
	if _com_fundo:
		_tinta.moldura = true
		await _tinta.abrir(_r)
	else:
		_tinta._set_p(0.0)
		modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.2 * _r + 0.01)
	var falas: Array = _cena.get("falas", [])
	for i in falas.size():
		var f: Dictionary = falas[i]
		var quem := String(f["quem"])
		if _pulou:
			# PULAR: as ações que faltam ainda chegam à tela (a loja precisa do último pulso).
			if f.has("acao"):
				acao.emit(String(f["acao"]))
			continue
		if f.has("acao"):
			acao.emit(String(f["acao"]))
		if i == 1 and parar_em < 0:
			_mostrar_pular()
		for outro in f.get("move", {}):
			var tw := create_tween()
			tw.tween_property(_atores[outro], "position:x", _x_alvo(outro, float(f["move"][outro])), 0.4 * _r + 0.01) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var novo := not (_atores[quem] as TextureRect).visible
		_posar(quem, String(f["pose"]))
		if novo:
			_entrar(quem)
		else:
			_pular(quem)
		_balao.visible = false
		await _mirar(quem, float(f.get("zoom", ZOOM if String(f["fala"]) != "" else 1.04)))
		if String(f["fala"]) == "":
			if i == parar_em:
				return
			await _esperar(0.5 * _r)
			continue
		await _dizer(quem, String(f["fala"]), i == parar_em)
		if i == parar_em:
			return
	_balao.visible = false
	await _tinta.fechar(_r, _com_fundo)
	fechou.emit()
	queue_free()


## PULAR ›: aparece a partir da segunda fala, discreto no canto de cima.
func _mostrar_pular() -> void:
	if _botao_pular != null:
		return
	_botao_pular = Button.new()
	_botao_pular.text = "PULAR ›"
	_botao_pular.flat = true
	_botao_pular.focus_mode = Control.FOCUS_NONE
	Tipografia.rotulo(_botao_pular, "display", IdleUI.legivel(22))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		_botao_pular.add_theme_color_override(c, Color(PAPEL, 0.85))
	_botao_pular.add_theme_constant_override("outline_size", 6)
	_botao_pular.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_botao_pular.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_botao_pular.offset_left = -190
	_botao_pular.offset_right = -24
	_botao_pular.offset_top = AreaSegura.topo(720.0) + 28
	_botao_pular.offset_bottom = _botao_pular.offset_top + 64
	_botao_pular.pressed.connect(func():
		_pulou = true
		_toque = true
		_botao_pular.visible = false)
	add_child(_botao_pular)
	move_child(_botao_pular, _tinta.get_index())


func _esperar(s: float) -> void:
	var t := 0.0
	_toque = false
	while t < s and not _toque and not _pulou:
		await get_tree().process_frame
		t += get_process_delta_time()
	_toque = false


## O balão acima da cabeça de quem fala, a fala sendo datilografada com a voz
## em blips; um toque completa, outro passa.
func _dizer(quem: String, texto: String, parar: bool) -> void:
	_balao.montar(String(_dado(quem).get("nome", "")), texto, size.x)
	var cabeca := _na_tela(_cabeca_na_cena(quem))
	_balao.apontar(cabeca, size, AreaSegura.topo(720.0) + 20.0)
	_balao.visible = true
	_balao.texto.visible_ratio = 0.0
	if _r > 0.0:
		_balao.scale = Vector2(0.85, 0.85)
		var tw := create_tween()
		tw.tween_property(_balao, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var duracao := texto.length() / LETRAS_POR_S * _r
	var t := 0.0
	var falou := 0
	_toque = false
	while t < duracao and not _toque:
		await get_tree().process_frame
		t += get_process_delta_time()
		_balao.texto.visible_ratio = t / duracao
		var letras := int(_balao.texto.visible_ratio * texto.length())
		if letras >= falou + 3:
			falou = letras
			Sons.tocar_ui(self, "voz", -15.0, float(VOZ.get(quem, 1.0)) * _rng.randf_range(0.94, 1.06), false)
	_balao.texto.visible_ratio = 1.0
	if parar:
		return
	await _esperar((ESPERA_S + texto.length() * LEITURA_S_POR_LETRA) * _r)


func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
	if toque:
		accept_event()
		_toque = true


func _process(delta: float) -> void:
	_t += delta
	if _balao.visible:
		_balao.seta = 0.5 + 0.5 * sin(_t * 5.0) if _balao.texto.visible_ratio >= 1.0 else 0.0
		_balao.queue_redraw()


# --- balão e tinta ----------------------------------------------------------------

## Balão de quadrinho no traço da arte (personagens em facetas, low poly):
## um polígono torto de papel creme, em facetas de tons vizinhos, contorno de
## tinta, sombra dura e o rabo em ponta até quem fala; a tarja do nome, torta.
class _Balao extends Control:
	var texto: Label
	var nome: Label
	var _tarja: PanelContainer
	var ponta := Vector2.ZERO  # ponta do rabo, em coordenadas do balão
	var seta := 0.0  # o ▼ de "toque para continuar", piscando
	var _semente := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texto = Label.new()
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.uppercase = true  # letreiro de gibi
		Tipografia.rotulo(texto, "fala", IdleUI.legivel(28))
		texto.add_theme_color_override("font_color", CenaQuadrinho.TINTA)
		add_child(texto)
		_tarja = PanelContainer.new()
		_tarja.add_theme_stylebox_override("panel", IdleUI.caixa(CenaQuadrinho.TARJA, 0, 6, CenaQuadrinho.TINTA, 3))
		_tarja.rotation = deg_to_rad(-4.0)
		add_child(_tarja)
		nome = Label.new()
		Tipografia.rotulo(nome, "display", 24)
		nome.add_theme_color_override("font_color", CenaQuadrinho.TINTA)
		_tarja.add_child(nome)

	func montar(quem: String, fala: String, largura_tela: float) -> void:
		nome.text = quem
		_tarja.visible = quem != ""
		texto.text = fala
		_semente = hash(fala)
		var largura := minf(560.0, largura_tela - 48.0)
		var fonte := texto.get_theme_font("font")
		var tam := texto.get_theme_font_size("font_size")
		var caixa := fala.to_upper()
		var medida := fonte.get_multiline_string_size(caixa, HORIZONTAL_ALIGNMENT_LEFT, largura - 72.0, tam)
		# Fala curta: balão mais estreito.
		largura = clampf(medida.x + 80.0, 240.0, largura)
		medida = fonte.get_multiline_string_size(caixa, HORIZONTAL_ALIGNMENT_LEFT, largura - 72.0, tam)
		size = Vector2(largura, medida.y + 70.0)
		texto.position = Vector2(36, 38)
		texto.size = Vector2(largura - 72.0, medida.y + 4.0)
		_tarja.position = Vector2(22, -20)
		_tarja.reset_size()

	## Bem acima da cabeça (o rabo desce até ela), sem sair da tela.
	func apontar(cabeca: Vector2, tela: Vector2, topo: float) -> void:
		var x := clampf(cabeca.x - size.x * 0.5, 20.0, tela.x - size.x - 20.0)
		var y := cabeca.y - size.y - 150.0
		y = clampf(y, topo + 24.0, tela.y - size.y - 20.0)
		position = Vector2(x, y)
		var alvo := cabeca - position
		var base := Vector2(clampf(alvo.x, 50.0, size.x - 50.0), size.y)
		var d := alvo - base
		ponta = base + d.limit_length(maxf(d.length() - 34.0, 40.0)) if d.y > 0.0 else base + Vector2(0, 46)
		pivot_offset = Vector2(clampf(alvo.x, 0.0, size.x), size.y)

	## O contorno torto: cantos chanfrados e lados quebrados, sempre o mesmo
	## para a mesma fala; o rabo entra no lado de baixo.
	func _forma() -> PackedVector2Array:
		var rng := RandomNumberGenerator.new()
		rng.seed = _semente
		var w := size.x
		var h := size.y
		var j := func(v: float) -> float: return rng.randf_range(-v, v)
		var base_x := clampf(ponta.x, 50.0, w - 50.0)
		var pts := PackedVector2Array([
			Vector2(0, 18 + j.call(6)), Vector2(20 + j.call(6), j.call(5)),
			Vector2(w * 0.45 + j.call(20), -6 + j.call(5)), Vector2(w - 22 + j.call(6), 2 + j.call(5)),
			Vector2(w + 4 + j.call(3), 22 + j.call(6)), Vector2(w - 2 + j.call(4), h * 0.55 + j.call(8)),
			Vector2(w - 14 + j.call(5), h + 2 + j.call(4)),
		])
		pts.append_array([Vector2(base_x + 22, h + j.call(3)), ponta, Vector2(base_x - 24, h + 4 + j.call(3))])
		pts.append_array([Vector2(16 + j.call(6), h - 2 + j.call(4)), Vector2(-4 + j.call(3), h * 0.5 + j.call(8))])
		return pts

	func _draw() -> void:
		var pts := _forma()
		# Sombra dura de tinta, depois o papel em facetas e o contorno.
		var sombra := PackedVector2Array()
		for p in pts:
			sombra.append(p + Vector2(7, 8))
		draw_colored_polygon(sombra, Color(CenaQuadrinho.TINTA, 0.55))
		var meio := size * Vector2(0.42, 0.46)
		var rng := RandomNumberGenerator.new()
		rng.seed = _semente + 7
		for i in pts.size():
			var tom := CenaQuadrinho.PAPEL.darkened(rng.randf_range(0.0, 0.07))
			draw_colored_polygon(PackedVector2Array([meio, pts[i], pts[(i + 1) % pts.size()]]), tom)
		var contorno := pts.duplicate()
		contorno.append(pts[0])
		draw_polyline(contorno, CenaQuadrinho.TINTA, 5.0)
		if seta > 0.0:
			var s := Vector2(size.x - 38, size.y - 22)
			draw_colored_polygon(PackedVector2Array([s + Vector2(-10, -7), s + Vector2(9, -5), s + Vector2(-1, 6)]),
					Color(CenaQuadrinho.TINTA, seta))


## A passada de tinta que abre e fecha a cena (quadro de quadrinho virando).
class _Tinta extends Control:
	var _p := 1.0  # 1 cobre a tela, 0 descoberta
	var _da_esquerda := false
	var moldura := false  # o contorno do quadro

	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _set_p(v: float) -> void:
		_p = v
		queue_redraw()

	func abrir(r: float) -> void:
		_da_esquerda = false
		var tw := create_tween()
		tw.tween_method(_set_p, 1.0, 0.0, 0.45 * r + 0.01).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await tw.finished

	func fechar(r: float, tinta: bool) -> void:
		if not tinta:
			var tw := get_parent().create_tween()
			tw.tween_property(get_parent(), "modulate:a", 0.0, 0.25 * r + 0.01)
			await tw.finished
			return
		_da_esquerda = true
		var tw := create_tween()
		tw.tween_method(_set_p, 0.0, 1.0, 0.4 * r + 0.01).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw.finished

	func _draw() -> void:
		if moldura:
			draw_rect(Rect2(Vector2.ZERO, size), CenaQuadrinho.TINTA, false, 14.0)
		if _p <= 0.0:
			return
		# Faixa inclinada que varre a tela: na abertura sai pela direita, no fecho entra pela esquerda.
		var w := size.x
		var h := size.y
		var incl := w * 0.35
		var borda := (w + incl) * _p - incl if _da_esquerda else w - (w + incl) * _p
		var pts := PackedVector2Array()
		if _da_esquerda:
			pts = [Vector2(-incl, 0), Vector2(borda + incl, 0), Vector2(borda, h), Vector2(-incl, h)]
		else:
			pts = [Vector2(borda + incl, 0), Vector2(w + incl, 0), Vector2(w + incl, h), Vector2(borda, h)]
		draw_colored_polygon(pts, CenaQuadrinho.TINTA)
