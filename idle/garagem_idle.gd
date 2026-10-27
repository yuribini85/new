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
## comprado, o Tony fala antes da largada (cena "largada").

signal comprou(id: String)
signal correr(id: String)

## Apresentação, não balanceamento.
const GIRO := 0.4  # rad/s
const LUZ := Color(1.0, 0.84, 0.6)
const CAMERA := Vector3(5.0, 2.1, 6.4)
const ALVO := Vector3(0, 0.7, 0)
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
var _mundo: Node3D
var _vp: SubViewport
var _arrastando := false
var _girou_em := -10.0
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
	return PinturaEpoca.do_jogador(fam)


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
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	# O carro escolhido, em 3D, sobre o chão do galpão.
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cont.custom_minimum_size = Vector2(0, 300)
	cont.mouse_filter = Control.MOUSE_FILTER_STOP
	cont.gui_input.connect(_arrastar)
	v.add_child(cont)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED if Preferencias.efeitos_leves else Viewport.MSAA_4X
	cont.add_child(_vp)
	_palco()
	var ficha := IdleUI.painel(Color(IdleUI.COR_CARTAO, 0.94), 14, 16, v)
	_ficha = ficha
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
	_botao = IdleUI.botao("", IdleUI.COR_OURO, 26, 96, f)
	_botao.pressed.connect(_acao)
	# Abre no carro da divisão na tela.
	_indice = _indice_de(String(estado.carro_da_modalidade().get("id", "")))
	_mostrar()


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
	cam.look_at_from_position(CAMERA, ALVO)
	_giro = Node3D.new()
	_giro.rotation.y = -0.6
	_mundo.add_child(_giro)
	_carro = CarroBloco.new()
	_giro.add_child(_carro)
	# Sombra no chão: um disco escuro que some nas bordas.
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
	_giro.add_child(chao)


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
	# Carro comprido (o sedã de 1951 tem 5,3 m): a câmera se afasta para caber.
	var escala := maxf(1.0, _carro.comprimento / 4.0)
	_camera.look_at_from_position(CAMERA * escala + Vector3(0, 0.7, 0) * (1.0 - escala), ALVO)
	atualizar()


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
			if _abertura:
				# O Tony entrega o carro antes da primeira largada.
				_ficha.modulate.a = 0.0
				var cena := CenaQuadrinho.new("largada")
				cena.fechou.connect(func(): comprou.emit(id))
				add_child(cena)
			else:
				comprou.emit(id)
		return
	correr.emit(id)


## Arrastar gira o carro; solto, ele volta a girar sozinho depois de um tempo.
func _arrastar(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_arrastando = e.pressed
	elif e is InputEventScreenTouch:
		_arrastando = e.pressed
	elif _arrastando and (e is InputEventMouseMotion or e is InputEventScreenDrag):
		_giro.rotation.y += e.relative.x * 0.012
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
	if not _arrastando and Time.get_ticks_msec() / 1000.0 - _girou_em > 2.0 and not Preferencias.reduzir_animacoes:
		_giro.rotation.y += GIRO * delta
