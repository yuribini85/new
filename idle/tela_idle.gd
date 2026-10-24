extends Control
## Chrome Racing Team (docs/idle/plano.md): a tela única do jogo idle. Em cima
## o dinheiro e a renda por segundo; no meio a corrida 3D (a pista inteira ou a
## câmera atrás do seu carro), com a posição e o tempo; embaixo os cartões de
## melhoria. A corrida roda sozinha, uma atrás da outra.

const COR_FUNDO := Color(0.07, 0.08, 0.1)
const COR_CARTAO := Color(0.13, 0.145, 0.17)
const COR_DINHEIRO := Color(0.45, 0.9, 0.5)
const COR_OURO := Color("d6a23e")
const PAUSA_CHEGADA_S := 2.5
const PAUSA_COM_VIDEO_S := 4.0  # tempo para tocar em "VÍDEO: PRÊMIO 2×"
const SALVAR_A_CADA_S := 5.0

var dados: Node
var estado: IdleEstado
var anuncios: IdleAnuncios
var _visual: CorridaVisual
var _visual3d: Corrida3D
var _resultado := {}
var _semente := 1
var _pausa := -1.0  # > 0: parada depois da chegada, antes da próxima corrida
var _fim_jogador := INF
var _salvar_em := 0.0
var _camera_de_cima := true

var _dinheiro: Label
var _renda: Label
var _liga: Label
var _posicao: Label
var _relogio: Label
var _aviso: Label
var _subir: Button
var _dobrar: Button
var _ganho_corrida := 0.0
var _sem_intersticial := false  # quem acabou de ver o vídeo não vê intersticial
var _camera: Button
var _cartoes := {}  # melhoria -> {nivel, efeito, botao}


func _ready() -> void:
	dados = get_node("/root/Dados")
	estado = IdleEstado.carregar()
	anuncios = IdleAnuncios.new()
	anuncios.intersticial_min_s = float(estado.cfg.get("intersticial_min_s", 90.0))
	anuncios.config = estado.cfg.get("admob", {})
	add_child(anuncios)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_montar()
	var ganho := estado.ganho_offline(Time.get_unix_time_from_system())
	if ganho >= 1.0:
		_janela_offline(ganho)
	_nova_corrida()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if estado != null:
			estado.salvar(Time.get_unix_time_from_system())


# --- montagem -----------------------------------------------------------------

func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = AreaSegura.topo(720.0) + 12.0
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	# Topo: o nome da liga, o dinheiro e a renda por segundo.
	var topo := HBoxContainer.new()
	v.add_child(topo)
	var esq := VBoxContainer.new()
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(esq)
	_liga = _rotulo("", 24, Color(0.77, 0.79, 0.85), esq)
	_dinheiro = _rotulo("", 52, Color.WHITE, esq)
	Tipografia.numero(_dinheiro, 52)
	var dir := VBoxContainer.new()
	dir.alignment = BoxContainer.ALIGNMENT_CENTER
	topo.add_child(dir)
	_rotulo("RENDA", 20, Color(0.77, 0.79, 0.85), dir).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_renda = _rotulo("", 36, COR_DINHEIRO, dir)
	_renda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# A corrida.
	var corrida := Control.new()
	corrida.custom_minimum_size = Vector2(0, 560)
	corrida.clip_contents = true
	v.add_child(corrida)
	_visual = CorridaVisual.new()
	_visual.visible = false
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corrida.add_child(_visual)
	_visual3d = Corrida3D.new()
	_visual3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual3d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual3d.sem_rotulos = true
	corrida.add_child(_visual3d)
	var faixa := PanelContainer.new()
	faixa.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	faixa.add_theme_stylebox_override("panel", _caixa(Color(0, 0, 0, 0.55), 0))
	corrida.add_child(faixa)
	var hf := HBoxContainer.new()
	faixa.add_child(hf)
	_posicao = _rotulo("", 44, COR_OURO, hf)
	Tipografia.numero(_posicao, 44)
	_posicao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_relogio = _rotulo("", 30, Color.WHITE, hf)
	_camera = Button.new()
	_camera.text = "CÂMERA"
	_camera.focus_mode = Control.FOCUS_NONE
	_camera.add_theme_font_size_override("font_size", 20)
	_camera.pressed.connect(_trocar_camera)
	hf.add_child(_camera)
	_aviso = _rotulo("", 40, COR_DINHEIRO, corrida)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_constant_override("outline_size", 10)
	_aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subir = Button.new()
	Tipografia.acao_primaria(_subir, "PRÓXIMA LIGA", COR_OURO, Color(0.1, 0.1, 0.1), 28, Tipografia.ALTURA_SECUNDARIA)
	_subir.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subir.offset_left = -200
	_subir.offset_right = 200
	_subir.offset_top = -100
	_subir.offset_bottom = -12
	_subir.pressed.connect(_subir_liga)
	corrida.add_child(_subir)
	_dobrar = Button.new()
	Tipografia.acao_primaria(_dobrar, "VÍDEO: PRÊMIO 2×", COR_DINHEIRO, Color(0.1, 0.1, 0.1), 26, Tipografia.ALTURA_SECUNDARIA)
	_dobrar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dobrar.offset_left = -200
	_dobrar.offset_right = 200
	_dobrar.offset_top = -100
	_dobrar.offset_bottom = -12
	_dobrar.visible = false
	_dobrar.pressed.connect(_dobrar_premio)
	corrida.add_child(_dobrar)
	# Os cartões de melhoria, dois por linha.
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 12)
	grade.add_theme_constant_override("v_separation", 12)
	grade.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(grade)
	for m in estado.cfg["melhorias"]:
		grade.add_child(_cartao(m))
	_atualizar_cartoes()


func _cartao(m: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _caixa(COR_CARTAO, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var nome := _rotulo(String(m["nome"]).to_upper(), 24, Color.WHITE, h)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nivel := _rotulo("", 20, Color(0.77, 0.79, 0.85), h)
	var efeito := _rotulo("", 22, COR_DINHEIRO, v)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	Tipografia.acao_primaria(b, "", COR_DINHEIRO.darkened(0.15), Color(0.06, 0.08, 0.06), 24, 64)
	b.pressed.connect(_comprar.bind(String(m["id"])))
	v.add_child(b)
	_cartoes[m["id"]] = {"nivel": nivel, "efeito": efeito, "botao": b}
	return p


func _rotulo(texto: String, tamanho: int, cor: Color, pai: Node) -> Label:
	var l := Label.new()
	l.text = texto
	Tipografia.rotulo(l, "semibold", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	return l


func _caixa(cor: Color, raio: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(raio)
	sb.set_content_margin_all(12)
	return sb


# --- números ------------------------------------------------------------------

## 1234 -> "1,2 mil"; 3 400 000 -> "3,4 mi" (o jogador lê rápido).
static func curto(v: float) -> String:
	var sufixos := ["", " mil", " mi", " bi", " tri", " qua"]
	var k := 0
	while absf(v) >= 1000.0 and k < sufixos.size() - 1:
		v /= 1000.0
		k += 1
	if k == 0:
		return ("%.1f" % v).replace(".", ",").trim_suffix(",0") if absf(v) < 10.0 else str(int(v))
	return ("%.1f" % v).replace(".", ",") + sufixos[k]


func _efeito_texto(m: Dictionary, nivel: int) -> String:
	var x := float(m["por_nivel"]) * nivel
	match String(m["efeito"]):
		"renda":
			return "+$%s/s" % curto(x * float(estado.dados_liga()["multiplicador"]))
		"vacuo", "potencia", "aderencia", "agressividade":
			# Efeito de menos de 1% por nível (vácuo) com uma casa: "+0,4%".
			if not is_equal_approx(fmod(float(m["por_nivel"]) * 100.0, 1.0), 0.0):
				return ("+%.1f%%" % (x * 100.0)).replace(".", ",")
			return "+%d%%" % roundi(x * 100.0)
	return str(x)


func _atualizar_cartoes() -> void:
	for m in estado.cfg["melhorias"]:
		var c: Dictionary = _cartoes[m["id"]]
		var n := estado.nivel(m["id"])
		c["nivel"].text = "NV %d" % n
		var b: Button = c["botao"]
		if estado.no_maximo(m["id"]):
			c["efeito"].text = _efeito_texto(m, n)
			b.text = "MÁXIMO"
			b.disabled = true
		else:
			c["efeito"].text = "%s  >  %s" % [_efeito_texto(m, n), _efeito_texto(m, n + 1)]
			b.text = "MELHORAR  $%s" % curto(estado.custo(m["id"]))
			b.disabled = not estado.pode_comprar(m["id"])


func _atualizar_topo() -> void:
	_dinheiro.text = "$" + curto(estado.dinheiro)
	_renda.text = "$%s/s" % curto(estado.renda_s())
	_liga.text = String(estado.dados_liga()["nome"]).to_upper()
	_subir.visible = estado.pode_subir() and _pausa < 0.0
	_dobrar.visible = _dobrar.visible and _pausa >= 0.0


# --- corrida ------------------------------------------------------------------

func _nova_corrida() -> void:
	_semente += 1
	_resultado = estado.correr(dados, _semente + estado.corridas * 7919)
	var pista := estado.pista(dados)
	_visual.mostrar(pista, _resultado, {"jogador": COR_OURO})
	var categorias := {}
	var pinturas := {}
	for p in estado.participantes(dados):
		categorias[p["id"]] = dados.carro(p["carro"])
		pinturas[p["id"]] = COR_OURO if p["id"] == "jogador" else Cores.sortear(String(p["carro"]), "%d|%s" % [_semente, p["id"]])
	_visual3d.mostrar(pista, _visual, categorias, pinturas)
	_visual.tempo = 0.0
	_fim_jogador = float(_resultado["carros"]["jogador"]["tempo_total"])
	_pausa = -1.0
	_aviso.text = ""
	_aplicar_camera()


func _trocar_camera() -> void:
	_camera_de_cima = not _camera_de_cima
	_aplicar_camera()


func _aplicar_camera() -> void:
	_visual3d.visao_geral = _camera_de_cima
	_visual3d.perseguicao = not _camera_de_cima
	_visual3d.foco = "jogador"


func _process(delta: float) -> void:
	estado.dinheiro += estado.renda_s() * delta
	if _pausa >= 0.0:
		_pausa -= delta
		if _pausa < 0.0:
			if not _sem_intersticial:
				anuncios.intersticial()
			_sem_intersticial = false
			_nova_corrida()
	else:
		_visual.tempo = minf(_visual.tempo + delta, _visual.duracao())
		if _visual.tempo >= _fim_jogador:
			_chegou()
	_visual3d.taxa = 1.0 if _pausa < 0.0 else 0.0
	_visual3d.atualizar(delta)
	var ordem := _visual.ordem()
	_posicao.text = "P%d/%d" % [ordem.find("jogador") + 1, ordem.size()]
	_relogio.text = "%d:%02d" % [int(_visual.tempo) / 60, int(_visual.tempo) % 60]
	_atualizar_topo()
	_atualizar_cartoes()
	_salvar_em -= delta
	if _salvar_em <= 0.0:
		_salvar_em = SALVAR_A_CADA_S
		estado.salvar(Time.get_unix_time_from_system())


func _chegou() -> void:
	var pos := IdleEstado.posicao(_resultado)
	var ganho := estado.concluir(pos)
	_aviso.text = ("VITÓRIA!\n" if pos == 1 else "%dº LUGAR\n" % pos) + "+$" + curto(ganho)
	_aviso.add_theme_color_override("font_color", COR_OURO if pos == 1 else COR_DINHEIRO)
	_ganho_corrida = ganho
	_dobrar.visible = anuncios.premiado_disponivel()
	_pausa = PAUSA_COM_VIDEO_S if _dobrar.visible else PAUSA_CHEGADA_S
	estado.salvar(Time.get_unix_time_from_system())


## O vídeo premiado depois da corrida: assistido até o fim, paga o prêmio de
## novo.
func _dobrar_premio() -> void:
	_dobrar.visible = false
	var ganho := _ganho_corrida
	anuncios.premiado(func():
		estado.dinheiro += ganho
		_sem_intersticial = true
		_aviso.text = "PRÊMIO 2×\n+$" + curto(ganho * 2.0)
		_aviso.add_theme_color_override("font_color", COR_OURO)
		_pausa = maxf(_pausa, PAUSA_CHEGADA_S)
		estado.salvar(Time.get_unix_time_from_system()))


func _comprar(id: String) -> void:
	if estado.comprar(id):
		_atualizar_cartoes()


func _subir_liga() -> void:
	if estado.subir_liga():
		_aviso.text = "%s\nCARRO NOVO: %s" % [String(estado.dados_liga()["nome"]).to_upper(),
				String(estado.carro_base(dados)["nome"]).to_upper()]
		_nova_corrida()
		_aviso.text = "%s\nCARRO NOVO: %s" % [String(estado.dados_liga()["nome"]).to_upper(),
				String(estado.carro_base(dados)["nome"]).to_upper()]
		estado.salvar(Time.get_unix_time_from_system())


# --- renda com o app fechado -------------------------------------------------------

func _janela_offline(ganho: float) -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.7)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(560, 0)
	p.add_theme_stylebox_override("panel", _caixa(COR_CARTAO, 18))
	centro.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var t := _rotulo("ENQUANTO VOCÊ ESTEVE FORA", 28, Color.WHITE, v)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var g := _rotulo("+$" + curto(ganho), 56, COR_DINHEIRO, v)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dobro := Button.new()
	Tipografia.acao_primaria(dobro, "VÍDEO: RECEBER 2×", COR_OURO, Color(0.1, 0.1, 0.1), 26, Tipografia.ALTURA_SECUNDARIA)
	v.add_child(dobro)
	var pegar := Button.new()
	Tipografia.acao_neutra(pegar, "RECEBER")
	v.add_child(pegar)
	var fechar := func(fator: float):
		estado.dinheiro += ganho * fator
		estado.salvar(Time.get_unix_time_from_system())
		fundo.queue_free()
	pegar.pressed.connect(fechar.bind(1.0))
	dobro.pressed.connect(func(): anuncios.premiado(fechar.bind(2.0)))
