class_name GaragemIdle
extends Control
## Garagem e loja de carros (idle.json → "garagem"; arte do pacote do usuário,
## 2. Loja): o galpão do Tony ao fundo, a vitrine com todos os carros no alto —
## os de divisão ainda fechada em silhueta preta, sem nome nem preço — e o
## carro escolhido girando em 3D, com nome, divisão e preço em dólares. Um carro
## por divisão: comprado, ele abre a divisão; com mais de um, CORRER COM ESTE
## leva à divisão dele. Arrastar gira o carro.
## Na abertura (SEQUÊNCIA 2) vem em tela cheia com a conversa do sobrinho e do
## Tony por cima (CenaQuadrinho "loja"): o carro do meio pulsa no "E aquele
## ali?", o ferro-velho pulsa no "Agora compre!" e só então aparece a compra;
## comprada, a corrida começa (as falas da corrida esperam o texto do usuário).

signal comprou(id: String)
signal correr(id: String)
signal abrir_trofeus

## Apresentação, não balanceamento.
const GIRO := 0.4  # rad/s
const LUZ := Color(1.0, 0.84, 0.6)
const CAMERA := Vector3(5.0, 2.1, 6.4)  # repintura (RepinturaIdle)
const ALVO := Vector3(0, 0.7, 0)
## A perspectiva do galpão (arte/fastfather/loja/fundo.webp, 941×1672, em
## pixels da imagem): o horizonte é onde a cidade encontra o chão lá fora,
## pela porta; o ponto de fuga das linhas da parede da esquerda (corrimão e
## mezanino) fica nesse horizonte, à direita, fora do quadro. O carro na
## garagem é visto dali: câmera na altura do horizonte e o carro alinhado
## com o galpão.
const FUNDO_TAM := Vector2(941, 1672)
const FUNDO_HORIZONTE := 918.0
const FUNDO_FUGA_X := 1210.0
const OLHO := Vector2(0.6, 1.6)  # altura da câmera (m), mínima e máxima
const CARRO_LARGURA := 4.6  # o carro ocupa a largura da tela como se tivesse isso (m) de lado a lado
const CARRO_FOLGA := 100.0  # do chão do carro até o fim do espaço dele (px)
## As duas luminárias do galpão: centro da boca e meia largura, em pixels da imagem.
const LUMINARIAS := [Vector3(286, 356, 62), Vector3(859, 376, 34)]
const MINIATURA := Vector2i(240, 140)
const SILHUETA := Color(0.02, 0.02, 0.02)
const PAPEL_SILHUETA := Color("b9a47c")

var estado: IdleEstado
var _abertura := false
var _cor: Color
var _faixas: Dictionary
var _indice := 0
var _carro: CarroBloco
var _giro: Node3D  # o carro e a sombra dele, girando juntos
var _seta: Control  # a seta curva de "arraste para girar"
var _mundo: Node3D
var _vp: SubViewport
var _arrastando := false
var _girou_em := -10.0
var _girou := false  # o jogador já mexeu no carro
var _espaco: Control  # o espaço livre do carro, entre a vitrine e a ficha
var _nome: Label
var _divisao: Label
var _preco: Label
var _preco_cheio: Label  # o preço de tabela riscado (ferro-velho)
var _botao: Button
var _ficha: Control
var _camera: Camera3D
var _cartoes: Array = []  # um por carro: {painel, mini, rotulo, vp, pintado}
var _pulsos := {}  # índice -> Tween
var _pulso_botao: Tween
## Para as fotos (tools/fotos_loja.gd): a conversa da loja para nessa fala.
var parar_cena_em := -1


## A pintura do carro do jogador: o ferro-velho até o Tony pintar (depois da
## primeira vitória), senão a da família da divisão (PinturaEpoca).
static func pintura(e: IdleEstado, c: Dictionary, fam := "") -> Array:
	if not c.is_empty() and c.has("ferro_velho"):
		var seu := e.tem_carro(String(c["id"]))
		if not seu or e.ferro_velho:
			return PinturaEpoca.ferro_velho(seu)
	if fam == "" and not c.is_empty():
		var m := String(c["modalidade"])
		fam = PinturaEpoca.familia(m, e.liga if m == e.modalidade else 0)
	var p := PinturaEpoca.do_jogador(fam)
	if e.fundadora:
		p[0] = Color(String(e.cfg.get("fundadora", {}).get("cor", "c9a24a")))  # o carro dourado da Família Fundadora
	return p


func _init(estado_: IdleEstado, cor: Color, faixas: Dictionary, abertura := false) -> void:
	estado = estado_
	_cor = cor
	_faixas = faixas
	_abertura = abertura
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var fundo := TextureRect.new()
	fundo.texture = load("res://arte/fastfather/loja/fundo.webp")
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # escala uniforme, recorta
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.22)
	sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sombra)
	var luzes := _LuzLuminarias.new()
	luzes.set_anchors_preset(Control.PRESET_FULL_RECT)
	luzes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(luzes)
	# O carro escolhido, em 3D, na tela inteira: a câmera usa a perspectiva do
	# fundo e o carro fica no chão do galpão, no espaço livre entre a vitrine e
	# a ficha.
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	cont.mouse_filter = Control.MOUSE_FILTER_STOP
	cont.gui_input.connect(_arrastar)
	add_child(cont)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED if Preferencias.efeitos_leves else Viewport.MSAA_4X
	cont.add_child(_vp)
	_seta = _SetaGiro.new()
	_seta.size = Vector2(220, 56)
	_seta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_seta)
	_palco()
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE  # o toque fora da vitrine e da ficha gira o carro
	v.add_theme_constant_override("separation", 10)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 12
	v.offset_bottom = -12
	if abertura:
		v.offset_top = AreaSegura.topo(720.0) + 20
		v.offset_bottom = -AreaSegura.base(720.0) - 20
	add_child(v)
	var titulo := IdleUI.rotulo("GARAGEM", 36, IdleUI.COR_OURO_CLARO, v, "deco")
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contorno(titulo)
	if abertura:
		var verba := IdleUI.rotulo("O chefe deu $%s para o carro." % IdleUI.curto(estado.dinheiro), 24, IdleUI.COR_TEXTO, v)
		verba.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_contorno(verba)
	_montar_vitrine(v)
	if not abertura:
		_estante = _Estante.new(estado)
		_estante.tocou.connect(func(): abrir_trofeus.emit())
		v.add_child(_estante)
	_espaco = Control.new()
	_espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_espaco.custom_minimum_size = Vector2(0, 300)
	_espaco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_espaco.resized.connect(_enquadrar)
	v.add_child(_espaco)
	var ficha := IdleUI.painel(Color(IdleUI.COR_CARTAO, 0.94), 14, 16, v)
	_ficha = ficha
	ficha.add_child(MolduraDeco.new(5.0))
	var f := VBoxContainer.new()
	f.add_theme_constant_override("separation", 6)
	ficha.add_child(f)
	var linha := HBoxContainer.new()
	f.add_child(linha)
	_nome = IdleUI.rotulo("", 32, IdleUI.COR_TEXTO, linha, "display")
	_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var precos := VBoxContainer.new()
	precos.add_theme_constant_override("separation", -6)
	linha.add_child(precos)
	_preco_cheio = IdleUI.rotulo("", 20, IdleUI.COR_BLOQUEADO, precos, "deco")
	_preco_cheio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var risco := ColorRect.new()
	risco.color = IdleUI.COR_RUIM
	risco.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	risco.offset_top = -2
	risco.offset_bottom = 2
	risco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preco_cheio.add_child(risco)
	_preco = IdleUI.rotulo("", 32, IdleUI.COR_OURO_CLARO, precos, "deco")
	_preco.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_divisao = IdleUI.rotulo("", 22, IdleUI.COR_SECUNDARIA, f)
	_divisao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_colecao = IdleUI.rotulo("", 22, IdleUI.COR_GANHO, f)
	_botao = IdleUI.botao("", IdleUI.COR_OURO, 26, 96, f)
	_botao.pressed.connect(_acao)
	# Abre no carro da divisão na tela.
	_indice = _indice_de(String(estado.carro_da_modalidade().get("id", "")))
	_mostrar()


var _estante: Control
var _colecao: Label  # o bônus do carro na coleção


## A estante de troféus na parede da garagem (sugestão aprovada, 2026-10-28):
## prateleira de madeira com os troféus ganhos de pé, o mais novo por último; o
## toque abre a coleção. Vazia, mostra só a madeira com os encaixes.
class _Estante extends Control:
	signal tocou
	const ALTURA := 100.0
	const LADO := 84.0  # a arte é quadrada, com o troféu no meio e o pé no fundo
	const PASSO := 42.0  # de um troféu ao outro: 16 cabem na prateleira
	var _e: IdleEstado
	var _vistos := -1
	var _caixa: HBoxContainer

	func _init(e: IdleEstado) -> void:
		_e = e
		custom_minimum_size = Vector2(0, ALTURA)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_caixa = HBoxContainer.new()
		_caixa.alignment = BoxContainer.ALIGNMENT_CENTER
		_caixa.add_theme_constant_override("separation", int(PASSO - LADO))  # as bordas vazias se sobrepõem
		_caixa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_caixa.offset_bottom = -5
		_caixa.offset_left = 10
		_caixa.offset_right = -10
		_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_caixa)

	func _process(_d: float) -> void:
		if _e.trofeus.size() != _vistos:
			_vistos = _e.trofeus.size()
			_montar()

	func _montar() -> void:
		for c in _caixa.get_children():
			c.queue_free()
		for tr in _e.lista_trofeus():
			if not String(tr["pista"]) in _e.trofeus:
				continue
			var t := TextureRect.new()
			t.texture = load("res://arte/fastfather/trofeus/trofeu_%02d.png" % int(tr["arte"]))
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
			t.custom_minimum_size = Vector2(LADO, LADO)
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_caixa.add_child(t)
		queue_redraw()

	func _draw() -> void:
		# A tábua de couro com a borda de latão, a sombra embaixo e os suportes.
		var y := size.y - 16.0
		draw_rect(Rect2(6, y + 12, size.x - 12, 6), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(0, y, size.x, 14), IdleUI.COR_COURO)
		draw_rect(Rect2(0, y, size.x, 3), IdleUI.COR_COURO.lightened(0.25))
		draw_rect(Rect2(0, y + 12, size.x, 2), IdleUI.COR_OURO_ESCURO)
		for x in [size.x * 0.18, size.x * 0.82]:
			draw_colored_polygon(PackedVector2Array([Vector2(x - 8, y + 14), Vector2(x + 8, y + 14), Vector2(x, y + 26)]),
					IdleUI.COR_COURO.darkened(0.3))

	func _gui_input(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.pressed:
			tocou.emit()
			accept_event()


static func _contorno(l: Label) -> void:
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))


func _ready() -> void:
	if not _abertura:
		return
	# A conversa do sobrinho com o Tony antes da compra.
	_ficha.modulate.a = 0.0
	var cena := CenaQuadrinho.new("loja")
	cena.parar_em = parar_cena_em
	# Ligado antes de entrar na árvore: sem animação a cena anda inteira no add_child.
	cena.acao.connect(func(a: String):
		if a.begins_with("pulsar:"):
			_pulsar(_indice_de(a.trim_prefix("pulsar:"))))
	cena.fechou.connect(func():
		var tw := create_tween()
		tw.tween_property(_ficha, "modulate:a", 1.0, 0.0 if Preferencias.reduzir_animacoes else 0.25)
		_pulsar_botao())
	add_child(cena)


func _indice_de(id: String) -> int:
	var lista := estado.carros_garagem()
	for k in lista.size():
		if String(lista[k]["id"]) == id:
			return k
	return 0


## Vitrine: uma miniatura por carro, na ordem das divisões.
func _montar_vitrine(pai: Control) -> void:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	pai.add_child(h)
	var lista := estado.carros_garagem()
	for k in lista.size():
		var painel := PanelContainer.new()
		painel.custom_minimum_size = Vector2(156, 0)
		painel.mouse_filter = Control.MOUSE_FILTER_STOP
		h.add_child(painel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		painel.add_child(col)
		var vp := SubViewport.new()
		vp.size = MINIATURA
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_DISABLED if Preferencias.efeitos_leves else Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		painel.add_child(vp)
		var mini := TextureRect.new()
		mini.texture = vp.get_texture()
		mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
		mini.custom_minimum_size = Vector2(140, 82)
		mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(mini)
		var rot := IdleUI.rotulo("", 20, IdleUI.COR_TEXTO, col, "deco")
		rot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		painel.gui_input.connect(func(e: InputEvent): _tocar_cartao(k, e))
		_cartoes.append({"painel": painel, "mini": mini, "rotulo": rot, "vp": vp, "pintado": ""})
	_atualizar_vitrine()


## A miniatura de um carro (desenhada uma vez, de novo só se a pintura mudar);
## a silhueta é a mesma imagem em preto.
func _miniatura(k: int) -> void:
	var c: Dictionary = estado.carros_garagem()[k]
	var cartao: Dictionary = _cartoes[k]
	var pe := pintura(estado, c)
	var chave := "%s|%s" % [(pe[0] as Color).to_html(), str(pe[1])]
	if cartao["pintado"] == chave:
		return
	cartao["pintado"] = chave
	var vp: SubViewport = cartao["vp"]
	for n in vp.get_children():
		n.queue_free()
	var mundo := Node3D.new()
	vp.add_child(mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.52, 0.48)
	amb.environment = env
	mundo.add_child(amb)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.8, 0.6, 0)
	luz.light_color = LUZ
	mundo.add_child(luz)
	var carro := CarroBloco.new()
	mundo.add_child(carro)
	carro.configurar_modelo({"id": String(c["id"]), "epoca": String(c["modelo"])}, pe[0], pe[1])
	carro.rotation.y = -0.5
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 30.0
	mundo.add_child(cam)
	var escala := maxf(1.0, carro.comprimento / 4.0)
	cam.look_at_from_position(Vector3(5.6, 1.6, 6.2) * escala, Vector3(0, 0.6, 0))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _atualizar_vitrine() -> void:
	var lista := estado.carros_garagem()
	for k in lista.size():
		var c: Dictionary = lista[k]
		var cartao: Dictionary = _cartoes[k]
		_miniatura(k)
		var bloqueado := estado.carro_bloqueado(c)
		var seu := estado.tem_carro(String(c["id"]))
		(cartao["mini"] as TextureRect).self_modulate = SILHUETA if bloqueado else Color.WHITE
		var rot: Label = cartao["rotulo"]
		rot.text = "?" if bloqueado else ("SEU" if seu else "$" + IdleUI.curto(estado.preco_carro(c)))
		rot.add_theme_color_override("font_color", Color("2a2118") if bloqueado else (IdleUI.COR_GANHO if seu else IdleUI.COR_OURO_CLARO))
		var destaque := k == _indice or _pulsos.has(k)
		var borda := IdleUI.COR_OURO_CLARO if _pulsos.has(k) else (IdleUI.COR_OURO if k == _indice else IdleUI.COR_BORDA)
		# Fechado: papel claro atrás, para a silhueta preta aparecer.
		var fundo := Color(PAPEL_SILHUETA, 0.9) if bloqueado else Color(IdleUI.COR_FUNDO, 0.82)
		var caixa := IdleUI.caixa(fundo, 10, 6, borda, 4 if destaque else 2)
		(cartao["painel"] as PanelContainer).add_theme_stylebox_override("panel", caixa)


func _tocar_cartao(k: int, e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
	if not toque:
		return
	var c: Dictionary = estado.carros_garagem()[k]
	var painel: PanelContainer = _cartoes[k]["painel"]
	if estado.carro_bloqueado(c):
		# Fechado: só a silhueta, sem ficha. Um tremor diz "ainda não".
		Sons.tocar_ui(self, "toque", -10.0, 0.7)
		if not Preferencias.reduzir_animacoes:
			painel.pivot_offset = painel.size * 0.5
			var tw := painel.create_tween()
			for d in [3.0, -3.0, 2.0, 0.0]:
				tw.tween_property(painel, "rotation", deg_to_rad(d), 0.05)
		return
	if k == _indice:
		return
	Sons.tocar_ui(self, "toque", -6.0)
	_indice = k
	_mostrar()


func _parar_pulsos() -> void:
	for outro in _pulsos.keys():
		(_pulsos[outro] as Tween).kill()
		(_cartoes[outro]["painel"] as Control).scale = Vector2.ONE
	_pulsos.clear()


## O cartão pulsa como quem diz "este" (a conversa da loja); um de cada vez.
func _pulsar(k: int) -> void:
	_parar_pulsos()
	var painel: Control = _cartoes[k]["painel"]
	painel.pivot_offset = painel.size * 0.5
	var tw := painel.create_tween().set_loops()
	tw.tween_property(painel, "scale", Vector2(1.1, 1.1), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(painel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	if Preferencias.reduzir_animacoes:
		tw.kill()
		painel.scale = Vector2(1.06, 1.06)
	_pulsos[k] = tw
	if not estado.carro_bloqueado(estado.carros_garagem()[k]) and k != _indice:
		_indice = k
		_mostrar()
	else:
		_atualizar_vitrine()


func _pulsar_botao() -> void:
	if Preferencias.reduzir_animacoes:
		return
	_botao.pivot_offset = _botao.size * 0.5
	_pulso_botao = _botao.create_tween().set_loops()
	_pulso_botao.tween_property(_botao, "scale", Vector2(1.05, 1.05), 0.4).set_trans(Tween.TRANS_SINE)
	_pulso_botao.tween_property(_botao, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)


## O carro sobre o chão do galpão (a arte ao fundo): luz quente de cima e a
## sombra no chão, que gira com ele.
func _palco() -> void:
	_mundo = Node3D.new()
	_vp.add_child(_mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	CarroBloco.reflexo(env)
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.42, 0.36)
	amb.environment = env
	_mundo.add_child(amb)
	var foco := SpotLight3D.new()
	foco.position = Vector3(0, 4.6, 0.6)
	foco.rotation = Vector3(-PI / 2.0 + 0.12, 0, 0)
	foco.spot_angle = 42.0
	foco.spot_range = 10.0
	foco.light_energy = 2.6
	foco.light_color = LUZ
	_mundo.add_child(foco)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.6, 0.8, 0)
	luz.light_energy = 0.6
	luz.light_color = LUZ
	_mundo.add_child(luz)
	var cam := Camera3D.new()
	_camera = cam
	cam.keep_aspect = Camera3D.KEEP_WIDTH  # o carro inteiro na largura, em tela alta ou baixa
	cam.fov = 30.0
	_mundo.add_child(cam)
	_giro = Node3D.new()
	_mundo.add_child(_giro)
	_carro = CarroBloco.new()
	_giro.add_child(_carro)
	_giro.add_child(GaragemIdle.sombra_chao())


## Sombra no chão: um disco escuro que some nas bordas (gira com o carro).
static func sombra_chao() -> MeshInstance3D:
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(2.6, 5.4)
	chao.mesh = plano
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.7))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	chao.material_override = mat
	chao.position.y = 0.01
	return chao


## Mostra o carro da divisão na tela (a que pediu a garagem).
func mostrar_divisao() -> void:
	_indice = _indice_de(String(estado.carro_da_modalidade().get("id", "")))
	_mostrar()


func _atual() -> Dictionary:
	var lista := estado.carros_garagem()
	return lista[_indice] if _indice < lista.size() else {}


func _mostrar() -> void:
	var c := _atual()
	if c.is_empty():
		return
	var pe := pintura(estado, c)
	_carro.configurar_modelo({"id": String(c["id"]), "epoca": String(c["modelo"])}, pe[0], pe[1])
	_nome.text = String(c["nome"]).to_upper()
	var mod := estado.dados_modalidade(String(c["modalidade"]))
	_divisao.text = "Divisão: %s" % String(mod.get("nome", ""))
	if c.has("ferro_velho") and not estado.tem_carro(String(c["id"])):
		_divisao.text += " · do ferro-velho"
	_enquadrar()
	atualizar()


## A câmera na perspectiva do fundo: inclinada para o horizonte da arte cair
## onde ele está na tela e longe o bastante para o chão do carro ficar no fim
## do espaço livre. Antes do primeiro toque, o carro fica alinhado com o
## galpão (apontando para o ponto de fuga da parede).
func _enquadrar() -> void:
	if _camera == null or _espaco == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var s := maxf(size.x / FUNDO_TAM.x, size.y / FUNDO_TAM.y)
	var dentro := (size - FUNDO_TAM * s) * 0.5  # STRETCH_KEEP_ASPECT_COVERED: centralizado
	var horizonte := dentro.y + FUNDO_HORIZONTE * s
	var fuga_x := dentro.x + FUNDO_FUGA_X * s
	var foco := size.x * 0.5 / tan(deg_to_rad(_camera.fov * 0.5))  # KEEP_WIDTH
	var fim := _espaco.global_position.y - global_position.y + _espaco.size.y
	# O carro do mesmo tamanho em qualquer tela; a altura do olho é a que põe
	# o chão do carro no fim do espaço livre (tela baixa: câmera rente ao chão).
	var dist := foco * CARRO_LARGURA / size.x
	var olho := clampf(dist * (fim - CARRO_FOLGA - horizonte) / foco, OLHO.x, OLHO.y)
	# Carro comprido (o sedã de 1951 tem 5,3 m): a câmera se afasta para caber,
	# subindo junto para o chão do carro não sair do lugar.
	var escala := maxf(1.0, _carro.comprimento / 4.0)
	_camera.position = Vector3(0, olho, dist) * escala
	_camera.rotation = Vector3(atan((horizonte - size.y * 0.5) / foco), 0, 0)  # horizonte abaixo do meio: olha para cima
	if not _girou:
		_giro.rotation.y = -PI / 2.0 - atan((fuga_x - size.x * 0.5) / foco)  # a frente para quem olha
	_seta.position = Vector2((size.x - _seta.size.x) * 0.5, fim - _seta.size.y + 4.0)


## Preço e botão pelo dinheiro e pelo que já é seu.
func atualizar() -> void:
	_atualizar_vitrine()
	var c := _atual()
	if c.is_empty():
		return
	var preco := estado.preco_carro(c)
	var seu := estado.tem_carro(String(c["id"]))
	_preco.text = "SEU" if seu else "$" + IdleUI.curto(preco)
	_preco_cheio.text = "$" + IdleUI.curto(float(c["preco"])) if not seu and preco < float(c["preco"]) else ""
	_preco_cheio.visible = _preco_cheio.text != ""
	var col: Dictionary = c.get("colecao", {})
	_colecao.visible = not col.is_empty()
	if _colecao.visible:
		var b := MetasIdle.texto_bonus(String(col["efeito"]), float(col["bonus"]))
		_colecao.text = ("Na coleção: %s para sempre" if seu else "Na coleção dá %s para sempre") % b
		_colecao.add_theme_color_override("font_color", IdleUI.COR_GANHO if seu else IdleUI.COR_SECUNDARIA)
	if not seu:
		_botao.text = "COMPRAR · $" + IdleUI.curto(preco)
		_botao.disabled = estado.dinheiro < preco
		if _botao.disabled:
			_botao.text = "FALTAM $" + IdleUI.curto(preco - estado.dinheiro)
	elif String(c["modalidade"]) == estado.modalidade:
		_botao.text = "NA PISTA"
		_botao.disabled = true
	else:
		_botao.text = "CORRER COM ESTE"
		_botao.disabled = not estado.liberada(String(c["modalidade"]))
	IdleUI.desativado_legivel(_botao)


func _acao() -> void:
	var c := _atual()
	if c.is_empty():
		return
	var id := String(c["id"])
	if not estado.tem_carro(id):
		if estado.comprar_carro(id):
			Sons.tocar_ui(self, "moeda", -4.0)
			IdleUI.premiar(_botao)
			if _pulso_botao != null:
				_pulso_botao.kill()
				_botao.scale = Vector2.ONE
			_parar_pulsos()
			_mostrar()
			comprou.emit(id)
		return
	correr.emit(id)


## Arrastar gira o carro (ele não gira sozinho).
func _arrastar(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_arrastando = e.pressed
	elif e is InputEventScreenTouch:
		_arrastando = e.pressed
	elif _arrastando and (e is InputEventMouseMotion or e is InputEventScreenDrag):
		_giro.rotation.y += e.relative.x * 0.012
		_girou = true
		_girou_em = Time.get_ticks_msec() / 1000.0


var _relogio := 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	# O dinheiro entra enquanto a garagem está aberta: o FALTAM acompanha.
	_relogio += delta
	if _relogio >= 0.5:
		_relogio = 0.0
		atualizar()
	# O carro só gira no dedo do jogador; a seta curva embaixo pisca devagar.
	if _seta != null:
		_seta.modulate.a = 0.35 + 0.5 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU / 3.0))


## Luz das luminárias do galpão (a arte ao fundo): um cone de facetas, como
## a arte low poly, saindo da boca de cada uma e abrindo até o chão, com a
## mancha de luz no piso; somada à imagem e respirando bem devagar.
class _LuzLuminarias extends Control:
	const COR := Color(1.0, 0.82, 0.5)

	func _init() -> void:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m

	func _process(_delta: float) -> void:
		if not Preferencias.reduzir_animacoes:
			queue_redraw()

	func _draw() -> void:
		var s := maxf(size.x / FUNDO_TAM.x, size.y / FUNDO_TAM.y)
		var dentro := (size - FUNDO_TAM * s) * 0.5
		var chao_y := dentro.y + 1040.0 * s
		var t := Time.get_ticks_msec() / 1000.0
		for i in LUMINARIAS.size():
			var l: Vector3 = LUMINARIAS[i]
			var boca := dentro + Vector2(l.x, l.y) * s
			var meia := l.z * s
			var forca := (0.85 + 0.15 * sin(t * TAU / 7.0 + i * 2.1)) * (1.0 if i == 0 else 0.7)
			var abre := meia * 3.2
			# Três faixas do cone, da de fora (larga e fraca) à de dentro (forte).
			for k in 3:
				var f := 1.0 - k * 0.3
				var topo := meia * f
				var base := abre * f
				var cima := Color(COR, (0.07 + 0.05 * k) * forca)
				var baixo := Color(COR, 0.0)
				var torto := (k - 1) * meia * 0.25  # faceta fora de esquadro
				draw_polygon(PackedVector2Array([boca + Vector2(-topo, 0), boca + Vector2(topo, 0),
						Vector2(boca.x + base + torto, chao_y), Vector2(boca.x - base + torto, chao_y)]),
						PackedColorArray([cima, cima, baixo, baixo]))
			# A mancha no chão: um losango achatado de facetas.
			var c := Vector2(boca.x, chao_y)
			var r := Vector2(abre * 1.1, abre * 0.22)
			var meio := Color(COR, 0.16 * forca)
			var borda := Color(COR, 0.0)
			var pts := [c + Vector2(-r.x, 0), c + Vector2(-r.x * 0.35, -r.y), c + Vector2(r.x * 0.45, -r.y * 0.9),
					c + Vector2(r.x, r.y * 0.1), c + Vector2(r.x * 0.3, r.y), c + Vector2(-r.x * 0.5, r.y * 0.85)]
			for j in pts.size():
				draw_polygon(PackedVector2Array([c, pts[j], pts[(j + 1) % pts.size()]]),
						PackedColorArray([meio, borda, borda]))


## Seta curva de "arraste para girar": um arco achatado de ponta a ponta, com
## as duas pontas de seta, em latão.
class _SetaGiro extends Control:
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.2)
		var r := Vector2(size.x * 0.45, size.y * 0.6)
		var pts := PackedVector2Array()
		for k in 25:
			var a := PI * (0.12 + 0.76 * k / 24.0)
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		var cor := MolduraDeco.LATAO
		draw_polyline(pts, Color(0, 0, 0, 0.6), 9.0)
		draw_polyline(pts, cor, 5.0)
		for ponta in [[pts[0], pts[1]], [pts[pts.size() - 1], pts[pts.size() - 2]]]:
			var p: Vector2 = ponta[0]
			var d := (p - (ponta[1] as Vector2)).normalized()
			var n := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([p + d * 14.0, p + n * 10.0, p - n * 10.0]), cor)
