class_name GaragemIdle
extends Control
## Garagem e loja de carros (pedido do usuário, 2026-10-27; idle.json →
## "garagem"): o carro de época de cada divisão girando numa oficina de tijolo
## e madeira, com nome, ano, a divisão em que corre e o preço em dólares. Um
## carro por divisão: comprado, ele abre a divisão; com mais de um, as setas
## trocam e CORRER COM ESTE leva à divisão dele. Arrastar gira o carro.
## Na abertura do jogo vem em tela cheia, só com a compra do primeiro carro.

signal comprou(id: String)
signal correr(id: String)

## Apresentação, não balanceamento.
const GIRO := 0.4  # rad/s
const PAREDE := Color(0.3, 0.17, 0.12)
const PISO := Color(0.3, 0.21, 0.14)
const LUZ := Color(1.0, 0.84, 0.6)

var estado: IdleEstado
var _abertura := false
var _cor: Color
var _faixas: Dictionary
var _indice := 0
var _carro: CarroBloco
var _mundo: Node3D
var _vp: SubViewport
var _arrastando := false
var _girou_em := -10.0
var _nome: Label
var _divisao: Label
var _preco: Label
var _botao: Button
var _setas: Array = []


func _init(estado_: IdleEstado, cor: Color, faixas: Dictionary, abertura := false) -> void:
	estado = estado_
	_cor = cor
	_faixas = faixas
	_abertura = abertura
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = IdleUI.COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 10)
	if abertura:
		v.offset_top = AreaSegura.topo(720.0) + 24
		v.offset_bottom = -AreaSegura.base(720.0) - 24
		v.offset_left = 16
		v.offset_right = -16
	add_child(v)
	var titulo := IdleUI.rotulo("O CARRO DO SOBRINHO" if abertura else "GARAGEM", 34, IdleUI.COR_OURO, v, "display")
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if abertura:
		var verba := IdleUI.rotulo("O chefe deu $%s para o carro." % IdleUI.curto(estado.dinheiro), 24, IdleUI.COR_TEXTO, v)
		verba.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# O carro na oficina, em 3D.
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cont.custom_minimum_size = Vector2(0, 360)
	cont.mouse_filter = Control.MOUSE_FILTER_STOP
	cont.gui_input.connect(_arrastar)
	v.add_child(cont)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED if Preferencias.efeitos_leves else Viewport.MSAA_4X
	cont.add_child(_vp)
	_oficina()
	# Setas por cima da vitrine (só com mais de um carro).
	for lado in [-1, 1]:
		var s := IdleUI.botao("‹" if lado < 0 else "›", IdleUI.COR_CARTAO_CLARO, 40, 96, cont)
		s.custom_minimum_size = Vector2(72, 96)
		s.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if lado < 0 else Control.PRESET_CENTER_RIGHT)
		s.position.x = 8.0 if lado < 0 else -80.0
		s.pressed.connect(func(): _trocar(lado))
		_setas.append(s)
	var ficha := IdleUI.painel(IdleUI.COR_CARTAO, 14, 16, v)
	var f := VBoxContainer.new()
	f.add_theme_constant_override("separation", 6)
	ficha.add_child(f)
	var linha := HBoxContainer.new()
	f.add_child(linha)
	_nome = IdleUI.rotulo("", 32, IdleUI.COR_TEXTO, linha, "display")
	_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preco = IdleUI.rotulo("", 32, IdleUI.COR_OURO_CLARO, linha, "numero")
	_divisao = IdleUI.rotulo("", 22, IdleUI.COR_SECUNDARIA, f)
	_divisao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_botao = IdleUI.botao("", IdleUI.COR_OURO, 26, 96, f)
	_botao.pressed.connect(_acao)
	# Abre no carro da divisão na tela.
	var atual := estado.carro_da_modalidade()
	var lista := estado.carros_garagem()
	for k in lista.size():
		if not atual.is_empty() and String(lista[k]["id"]) == String(atual["id"]):
			_indice = k
	_mostrar()


## Oficina dos anos 1930: parede de tijolo, piso de tábuas, luminária
## pendurada com luz quente sobre o carro.
func _oficina() -> void:
	_mundo = Node3D.new()
	_vp.add_child(_mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.05, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.38, 0.34)
	CarroBloco.reflexo(env)
	amb.environment = env
	_mundo.add_child(amb)
	var foco := SpotLight3D.new()
	foco.position = Vector3(0, 4.6, 0.6)
	foco.rotation = Vector3(-PI / 2.0 + 0.12, 0, 0)
	foco.spot_angle = 42.0
	foco.spot_range = 10.0
	foco.light_energy = 3.0
	foco.light_color = LUZ
	foco.shadow_enabled = not Preferencias.efeitos_leves
	_mundo.add_child(foco)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.6, 0.8, 0)
	luz.light_energy = 0.45
	luz.light_color = LUZ
	_mundo.add_child(luz)
	# Piso de tábuas.
	for i in range(-16, 17):
		_bloco(Vector3(0.48, 0.04, 16.0), Vector3(i * 0.5, -0.02, 0), PISO.darkened(0.12 * (absi(i * 7) % 3)))
	# Parede de tijolo atrás, em fiadas desencontradas.
	for fiada in 22:
		var y := 0.1 + fiada * 0.2
		var desloc := 0.25 if fiada % 2 == 0 else 0.0
		for k in range(-26, 27):
			var cor := PAREDE.darkened(0.1 * ((k * 3 + fiada * 5) % 4)) if (k + fiada) % 7 != 0 else PAREDE.lightened(0.08)
			_bloco(Vector3(0.48, 0.18, 0.2), Vector3(k * 0.5 + desloc, y, -3.2), cor)
	# Bancada, pneus e a luminária.
	_bloco(Vector3(2.2, 0.1, 0.6), Vector3(-2.4, 0.95, -2.7), Color(0.42, 0.29, 0.18))
	for x in [-3.4, -1.4]:
		_bloco(Vector3(0.1, 0.95, 0.5), Vector3(x, 0.47, -2.7), Color(0.2, 0.15, 0.1))
	for n in 3:
		var pneu := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.38
		cil.bottom_radius = 0.38
		cil.height = 0.12
		cil.radial_segments = 16
		pneu.mesh = cil
		pneu.material_override = CarroBloco._material(Color(0.07, 0.07, 0.07))
		pneu.position = Vector3(2.8, 0.06 + n * 0.13, -2.5)
		_mundo.add_child(pneu)
	var lampada := CarroBloco._material(LUZ)
	lampada.emission_enabled = true
	lampada.emission = LUZ
	_bloco(Vector3(0.02, 1.2, 0.02), Vector3(0, 4.4, 0.6), Color(0.1, 0.1, 0.1))
	var cupula := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.08
	cone.bottom_radius = 0.4
	cone.height = 0.3
	cupula.mesh = cone
	cupula.material_override = CarroBloco._material(Color(0.18, 0.26, 0.2))
	cupula.position = Vector3(0, 3.7, 0.6)
	_mundo.add_child(cupula)
	var bulbo := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.08
	esf.height = 0.16
	bulbo.mesh = esf
	bulbo.material_override = lampada
	bulbo.position = Vector3(0, 3.55, 0.6)
	_mundo.add_child(bulbo)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH  # o carro inteiro na largura, em tela alta ou baixa
	cam.fov = 30.0
	_mundo.add_child(cam)
	cam.look_at_from_position(Vector3(5.0, 2.1, 6.4), Vector3(0, 0.7, 0))
	_carro = CarroBloco.new()
	_carro.rotation.y = -0.6
	_mundo.add_child(_carro)


func _bloco(tam: Vector3, pos: Vector3, cor: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = CarroBloco._material(cor)
	mi.position = pos
	_mundo.add_child(mi)


func _atual() -> Dictionary:
	var lista := estado.carros_garagem()
	return lista[_indice] if _indice < lista.size() else {}


func _trocar(passo: int) -> void:
	var n := estado.carros_garagem().size()
	if n < 2:
		return
	Sons.tocar_ui(self, "toque", -6.0)
	_indice = posmod(_indice + passo, n)
	_mostrar()


func _mostrar() -> void:
	var c := _atual()
	for s in _setas:
		s.visible = estado.carros_garagem().size() > 1 and not _abertura
	if c.is_empty():
		return
	_carro.configurar_modelo({"id": String(c["id"]), "epoca": String(c["modelo"])}, _cor, _faixas)
	_nome.text = String(c["nome"]).to_upper()
	var mod := estado.dados_modalidade(String(c["modalidade"]))
	_divisao.text = "Corre nas %s." % String(mod.get("nome", ""))
	atualizar()


## Preço e botão pelo dinheiro e pelo que já é seu.
func atualizar() -> void:
	var c := _atual()
	if c.is_empty():
		return
	var preco := float(c["preco"])
	var seu := estado.tem_carro(String(c["id"]))
	_preco.text = "SEU" if seu else "$" + IdleUI.curto(preco)
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
			atualizar()
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
		_carro.rotation.y += e.relative.x * 0.012
		_girou_em = Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not _arrastando and Time.get_ticks_msec() / 1000.0 - _girou_em > 2.0 and not Preferencias.reduzir_animacoes:
		_carro.rotation.y += GIRO * delta
