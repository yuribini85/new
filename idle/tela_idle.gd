extends Control
## Chrome Racing Team (docs/idle/plano.md): a tela única do jogo idle. Em cima
## o dinheiro e a renda por segundo; no meio, ocupando a maior parte da tela, a
## corrida 3D do Chrome & Wreckage com o que ela tem de assistir: a câmera AUTO
## (o diretor alterna entre o seu carro, as disputas de perto e a pista), o
## painel da corrida (posição, quem está à frente e atrás, a classificação num
## toque), o semáforo da largada, os avisos de ultrapassagem, a bandeirada com a
## câmera fechando no seu carro, os sons e os rivais com piloto e pintura das
## equipes rivais; embaixo os cartões de melhoria, três por linha. A corrida
## roda sozinha, uma atrás da outra.
## Identidade visual do Chrome & Wreckage: a abertura com a paisagem em camadas
## e o botão da tela inicial dele, as cores e fontes da interface, os ícones nos
## cartões e o banner da pista atrás do topo.

const COR_FUNDO := Aba.COR_FUNDO
const COR_CARTAO := Aba.COR_CARTAO
const COR_DINHEIRO := Color(0.45, 0.9, 0.5)
const COR_OURO := Aba.COR_DESTAQUE
const LOGO := "res://arte/idle/logo.png"  # tools/gerar_logo_crt.py
const COR_BOTAO := Color("f5b52e")  # o amarelo-ouro do botão da tela inicial do C&W (ui/inicio.gd)
const PAUSA_CHEGADA_S := 2.5
const PAUSA_COM_VIDEO_S := 4.0  # tempo para tocar em "VÍDEO: PRÊMIO 2×"
const SALVAR_A_CADA_S := 5.0
## Apresentação, como no Chrome & Wreckage: contagem da largada, rival colado
## que gera o aviso "SE APROXIMA" e o intervalo mínimo entre dois desses avisos.
const CONTAGEM_S := 3.0
const APROXIMA_S := 0.6
const EVENTO_RIVAL_S := 20.0
const COR_RUIM := Color(1.0, 0.46, 0.4)
## Pintura do seu carro: o dourado da equipe com faixas escuras e o número 1.
const EQUIPE_JOGADOR := {"numero": 1, "cores": {"faixa": "#141518", "filete": "#f2f2ee"}}

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
## Câmera: "auto" (o diretor do Chrome & Wreckage), "jogador" (atrás do seu
## carro) ou "geral" (a pista inteira). O botão CÂMERA passa de uma à outra.
const CAMERAS := ["auto", "jogador", "geral"]
const NOMES_CAMERA := {"auto": "AUTO", "jogador": "SEU CARRO", "geral": "PISTA"}
var _camera_modo := "auto"
var _diretor := DiretorCamera.new()
var _pista: Pista

var _dinheiro: Label
var _renda: Label
var _liga: Label
var _banner: TextureRect  # banner da pista da liga atrás do topo
var _abertura_tela: Control
var _hud: HudCorrida
var _sons: Sons
var _nomes := {}  # id -> nome do piloto
var _contagem := -1.0  # s até a largada (< 0: correndo)
var _chegada := false  # seu carro cruzou a linha
var _t_chegada := 0.0
var _pos_antes := 0
var _avisado := {}  # rival -> quando avisou que se aproximava (tempo da corrida)
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
	_abertura()


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
	# Topo: o nome da liga, o dinheiro e a renda por segundo, sobre o banner da
	# pista (como os cartões de prova do Chrome & Wreckage).
	var placa := PanelContainer.new()
	placa.add_theme_stylebox_override("panel", _caixa(COR_CARTAO, 14))
	placa.clip_contents = true
	v.add_child(placa)
	_banner = TextureRect.new()
	_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_banner.modulate = Color(0.45, 0.45, 0.45)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placa.add_child(_banner)
	var topo := HBoxContainer.new()
	placa.add_child(topo)
	var esq := VBoxContainer.new()
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(esq)
	var linha_liga := HBoxContainer.new()
	esq.add_child(linha_liga)
	var emblema := TextureRect.new()
	emblema.texture = Aba.icone_reduzido("emblema_liga", 30)
	emblema.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	linha_liga.add_child(emblema)
	_liga = _rotulo("", 24, Color(0.93, 0.91, 0.87), linha_liga)
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
	corrida.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corrida.clip_contents = true
	v.add_child(corrida)
	_visual = CorridaVisual.new()
	_visual.visible = false
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corrida.add_child(_visual)
	_visual3d = Corrida3D.new()
	_visual3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual3d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corrida.add_child(_visual3d)
	_hud = HudCorrida.new()
	corrida.add_child(_hud)
	_sons = Sons.new()
	add_child(_sons)
	_camera = Button.new()
	_camera.text = "CÂMERA: AUTO"
	_camera.focus_mode = Control.FOCUS_NONE
	_camera.add_theme_font_size_override("font_size", 20)
	_camera.add_theme_stylebox_override("normal", _caixa(Color(0, 0, 0, 0.5), 10))
	_camera.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_camera.offset_left = 10
	_camera.offset_bottom = -10
	_camera.offset_top = -58
	_camera.offset_right = 190
	_camera.pressed.connect(_trocar_camera)
	corrida.add_child(_camera)
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
	# Os cartões de melhoria, três por linha.
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 10)
	v.add_child(grade)
	for m in estado.cfg["melhorias"]:
		grade.add_child(_cartao(m))
	_atualizar_cartoes()


func _cartao(m: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _caixa(COR_CARTAO, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var tex := Aba.icone_reduzido(String(m.get("icone", "")), 24) if m.has("icone") else null
	if tex != null:
		var ic := TextureRect.new()
		ic.texture = tex
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(ic)
	var nome := _rotulo(String(m["nome"]).to_upper(), 17, Color.WHITE, h)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.clip_text = true
	var nivel := _rotulo("", 15, Color(0.77, 0.79, 0.85), h)
	var efeito := _rotulo("", 18, COR_DINHEIRO, v)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	Tipografia.acao_primaria(b, "", COR_DINHEIRO.darkened(0.15), Color(0.06, 0.08, 0.06), 24, 56)
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
			c["efeito"].text = "%s > %s" % [_efeito_texto(m, n), _efeito_texto(m, n + 1)]
			b.text = "$%s" % curto(estado.custo(m["id"]))
			b.disabled = not estado.pode_comprar(m["id"])


func _atualizar_topo() -> void:
	_dinheiro.text = "$" + curto(estado.dinheiro)
	_renda.text = "$%s/s" % curto(estado.renda_s())
	_liga.text = String(estado.dados_liga()["nome"]).to_upper()
	var pista_id := String(estado.dados_liga()["pista"])
	_banner.texture = Aba.arte("banner_" + String(Corrida3D.TEMA_DE.get(pista_id, pista_id)))
	_subir.visible = estado.pode_subir() and _pausa < 0.0
	_dobrar.visible = _dobrar.visible and _pausa >= 0.0


# --- corrida ------------------------------------------------------------------

func _nova_corrida() -> void:
	_semente += 1
	_resultado = estado.correr(dados, _semente + estado.corridas * 7919)
	var pista := estado.pista(dados)
	_pista = pista
	_visual.mostrar(pista, _resultado, {"jogador": COR_OURO})
	var categorias := {}
	var pinturas := {}
	var faixas := {}
	var escalados := estado.escalacao(dados)
	_nomes = {"jogador": "Você"}
	for p in estado.participantes(dados):
		var id := String(p["id"])
		categorias[id] = dados.carro(p["carro"])
		var k := int(id.trim_prefix("r")) if id != "jogador" else -1
		if id == "jogador":
			pinturas[id] = COR_OURO
			faixas[id] = PinturaCarro.da_equipe(EQUIPE_JOGADOR, "crt", 0)
		elif k < escalados.size():
			# Rival nas cores da equipe dele, como no Chrome & Wreckage.
			var eq: Dictionary = escalados[k]["equipe"]
			pinturas[id] = Color(String(eq["cores"]["carro"]))
			faixas[id] = PinturaCarro.da_equipe(eq, "%d|%d" % [estado.liga, k], int(escalados[k]["vaga"]))
			_nomes[id] = escalados[k]["nome"]
		else:
			pinturas[id] = Cores.sortear(String(p["carro"]), "%d|%s" % [_semente, id])
	_visual3d.faixas_pintura = faixas
	_visual3d.nomes = _nomes
	_visual3d.chegada = 0.0
	_visual3d.mostrar(pista, _visual, categorias, pinturas)
	_visual.tempo = 0.0
	_fim_jogador = float(_resultado["carros"]["jogador"]["tempo_total"])
	_pausa = -1.0
	_aviso.text = ""
	_chegada = false
	_t_chegada = 0.0
	_pos_antes = 0
	_avisado = {}
	_hud.limpar_evento()
	_hud.secundario = 1.0
	_contagem = CONTAGEM_S
	_hud.contagem = _contagem
	_sons.largada(false)
	_diretor.reiniciar()
	_aplicar_camera()
	_visual3d.destacar_jogador()  # o anel no seu carro (o dourado) na largada


func _trocar_camera() -> void:
	_camera_modo = CAMERAS[(CAMERAS.find(_camera_modo) + 1) % CAMERAS.size()]
	_camera.text = "CÂMERA: " + NOMES_CAMERA[_camera_modo]
	_diretor.reiniciar()
	_aplicar_camera()


func _aplicar_camera() -> void:
	_visual3d.visao_geral = _camera_modo == "geral"
	_visual3d.perseguicao = _camera_modo == "jogador"
	_visual3d.foco = "jogador"
	_visual3d.enquadrar_com = ""


## Câmera AUTO: o diretor do Chrome & Wreckage escolhe o plano (abertura de
## cima no grid, o seu carro, a disputa da frente, a pista inteira).
func _dirigir() -> void:
	var ordem := _visual.ordem()
	var i := ordem.find("jogador")
	_visual3d.alvo = ordem[i - 1] if i > 0 and not _chegada else ""
	if _camera_modo != "auto":
		_visual3d.enquadrar_grid = false
		return
	if _contagem > 0.0:
		# No grid, de cima, enquadrando todos (como o Chrome & Wreckage).
		_visual3d.enquadrar_grid = true
		return
	var voltas := int(estado.dados_liga()["voltas"])
	var plano := _diretor.atualizar(_visual, _pista.comprimento * voltas, _pista.comprimento, voltas)
	_visual3d.enquadrar_grid = plano["motivo"] == "abertura"
	_visual3d.visao_geral = plano["geral"]
	_visual3d.foco = plano["foco"]
	_visual3d.enquadrar_com = plano["com"]


func _process(delta: float) -> void:
	estado.dinheiro += estado.renda_s() * delta
	if _pista == null:  # a abertura ainda está na tela
		return
	if _contagem > 0.0:
		_contar(delta)
	elif _pausa >= 0.0:
		_pausa -= delta
		# Depois da linha os carros seguem, freando, e a câmera fecha no seu.
		_visual.tempo += delta
		if _pausa < 0.0:
			if not _sem_intersticial:
				anuncios.intersticial()
			_sem_intersticial = false
			_nova_corrida()
	else:
		_visual.tempo = minf(_visual.tempo + delta, _visual.duracao())
		if _visual.tempo >= _fim_jogador:
			_chegou()
	if _chegada:
		_t_chegada += delta
		_visual3d.chegada = minf(_t_chegada / 3.0, 1.0)
	_visual3d.taxa = 0.0 if _contagem > 0.0 else 1.0
	_dirigir()
	_visual3d.atualizar(delta)
	var tela := _visual3d.posicao_tela(_visual3d.foco if _visual3d.foco != "" else "jogador")
	_hud.ancora_carro = _hud.get_global_transform().affine_inverse() * tela if tela.x >= 0.0 else Vector2(-1, -1)
	var ordem := _visual.ordem()
	_atualizar_hud(ordem)
	_eventos(ordem)
	_som(ordem)
	_atualizar_topo()
	_atualizar_cartoes()
	_salvar_em -= delta
	if _salvar_em <= 0.0:
		_salvar_em = SALVAR_A_CADA_S
		estado.salvar(Time.get_unix_time_from_system())


## 3-2-1 no grid: um bipe por número; no zero, a largada.
func _contar(delta: float) -> void:
	var antes := ceili(_contagem)
	_contagem = maxf(_contagem - delta, 0.0)
	_hud.contagem = _contagem if _contagem > 0.0 else -1.0
	if ceili(_contagem) < antes and _contagem > 0.0:
		_sons.largada(false)
	if _contagem <= 0.0:
		_contagem = -1.0
		_diretor.reiniciar()
		_sons.largada(true)
		_hud.evento("LARGADA", "", COR_OURO, 3)


## Diferença em segundos entre quem vai à frente (`a`) e quem vem atrás (`b`):
## quanto tempo antes `a` passou no ponto onde `b` está (-1 sem dado).
func _gap(a: String, b: String) -> float:
	var t := _visual.tempo_em(a, _visual.distancia(b))
	return maxf(_visual.tempo - t, 0.0) if t >= 0.0 else -1.0


## O painel da corrida do Chrome & Wreckage: posição, vizinhos e classificação.
func _atualizar_hud(ordem: Array) -> void:
	var i := ordem.find("jogador")
	var atacante := ""
	if i + 1 < ordem.size() and not _chegada:
		var g := _gap("jogador", ordem[i + 1])
		if g >= 0.0 and g < APROXIMA_S:
			atacante = ordem[i + 1]
	var lista := []
	for id in ordem:
		lista.append({"id": id, "nome": _nomes.get(id, id), "cor": _visual.cor_de(id), "voce": id == "jogador",
			"camera": id == _visual3d.foco and not _visual3d.visao_geral,
			"gap": _gap(ordem[0], id) if id != ordem[0] else -1.0, "ataque": id == atacante})
	var voltas := int(estado.dados_liga()["voltas"])
	var volta := clampi(floori(maxf(_visual.distancia("jogador"), 0.0) / _pista.comprimento) + 1, 1, voltas)
	_hud.definir({"posicao": i + 1, "total": ordem.size(), "volta": volta, "voltas": voltas, "lista": lista,
		"ultima": false})
	var perto := atacante != ""
	if i > 0 and not _chegada:
		var g := _gap(ordem[i - 1], "jogador")
		perto = perto or (g >= 0.0 and g < 0.45)
	_hud.secundario = 0.0 if _chegada else (0.35 if perto else 1.0)


## Avisos da corrida, como no Chrome & Wreckage: ultrapassagem, líder, perdeu a
## posição e rival se aproximando.
func _eventos(ordem: Array) -> void:
	var pos := ordem.find("jogador") + 1
	if pos <= 0 or _chegada or _contagem > 0.0:
		_pos_antes = pos
		return
	if _pos_antes > 0 and pos != _pos_antes and _visual.tempo > 1.0:
		var ganhou := pos < _pos_antes
		var outro: String = (ordem[pos] if pos < ordem.size() else "") if ganhou else (ordem[pos - 2] if pos >= 2 else "")
		var nome := String(_nomes.get(outro, "")).to_upper()
		if ganhou and pos == 1:
			_hud.evento("LÍDER", "passou %s" % nome, COR_OURO, 6)
		elif ganhou:
			_hud.evento("ULTRAPASSAGEM", "passou %s · %dº" % [nome, pos], COR_OURO, 5)
		else:
			_hud.evento("PERDEU A POSIÇÃO", "%s passou · %dº" % [nome, pos], COR_RUIM, 5)
		_sons.ultrapassagem(ganhou)
	_pos_antes = pos
	if pos < ordem.size():
		var atras: String = ordem[pos]
		var g := _gap("jogador", atras)
		if g >= 0.0 and g < APROXIMA_S and _visual.tempo - float(_avisado.get(atras, -INF)) > EVENTO_RIVAL_S:
			_avisado[atras] = _visual.tempo
			_hud.evento("%s SE APROXIMA" % String(_nomes.get(atras, "")).to_upper(), "−%.1f s" % g, COR_RUIM, 2)


## Som do seu carro: motor pela velocidade, pneu e zebra pelo 3D, o pelotão
## com rival colado e a torcida no fim (e na chegada).
func _som(ordem: Array) -> void:
	if _chegada:
		_sons.motor(false)
		_sons.torcida(1.0 - smoothstep(1.5, 4.0, _t_chegada))
		return
	var v := 0.0
	if _contagem <= 0.0:
		v = maxf(_visual.distancia_em("jogador", _visual.tempo) - _visual.distancia_em("jogador", maxf(_visual.tempo - 0.5, 0.0)), 0.0) \
				/ minf(0.5, maxf(_visual.tempo, 0.05))
	_sons.motor(true, v)
	_sons.pneu(_visual3d.cantando("jogador"), _visual3d.na_zebra("jogador"))
	var i := ordem.find("jogador")
	var gap_min := INF
	if i > 0:
		var ga := _gap(ordem[i - 1], "jogador")
		if ga >= 0.0:
			gap_min = ga
	if i >= 0 and i + 1 < ordem.size():
		var gb := _gap("jogador", ordem[i + 1])
		if gb >= 0.0:
			gap_min = minf(gap_min, gb)
	_sons.pelotao(1.0 - smoothstep(0.3, 2.0, gap_min) if gap_min < INF else 0.0)
	var resto := 1.0 - clampf(_visual.distancia("jogador") / (_pista.comprimento * int(estado.dados_liga()["voltas"])), 0.0, 1.0)
	_sons.torcida((1.0 - smoothstep(0.1, 0.3, resto)) * 0.6)


func _chegou() -> void:
	var pos := IdleEstado.posicao(_resultado)
	var ganho := estado.concluir(pos)
	_chegada = true
	_sons.chegada()
	_hud.bandeirada()
	_hud.evento("VITÓRIA!" if pos == 1 else "%dº LUGAR" % pos, "+$" + curto(ganho),
			COR_OURO if pos == 1 else COR_DINHEIRO, 10, -1.0, true)
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
		_hud.evento("PRÊMIO 2×", "+$" + curto(ganho * 2.0), COR_OURO, 11, -1.0, true)
		_pausa = maxf(_pausa, PAUSA_CHEGADA_S)
		estado.salvar(Time.get_unix_time_from_system()))


func _comprar(id: String) -> void:
	if estado.comprar(id):
		_atualizar_cartoes()


func _subir_liga() -> void:
	if not estado.subir_liga():
		return
	estado.salvar(Time.get_unix_time_from_system())
	_nova_corrida()
	_janela_liga()


## Liga nova: o banner da pista, o nome da liga e o carro novo da equipe.
func _janela_liga() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.75)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(600, 0)
	p.add_theme_stylebox_override("panel", _caixa(COR_CARTAO, 18))
	centro.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var pista_id := String(estado.dados_liga()["pista"])
	var tex := Aba.arte("banner_" + String(Corrida3D.TEMA_DE.get(pista_id, pista_id)))
	if tex != null:
		var b := TextureRect.new()
		b.texture = tex
		b.custom_minimum_size = Vector2(0, 220)
		b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		b.clip_contents = true
		v.add_child(b)
	var t := _rotulo("NOVA LIGA", 24, COR_OURO, v)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var n := _rotulo(String(estado.dados_liga()["nome"]).to_upper(), 46, Color.WHITE, v)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c := _rotulo("CARRO NOVO: " + String(estado.carro_base(dados)["nome"]).to_upper(), 24,
			Color(0.77, 0.79, 0.85), v)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ok := BotaoInicio.new("Correr", true, COR_BOTAO, 40, 88, 360)
	ok.pressed.connect(fundo.queue_free)
	v.add_child(ok)


# --- abertura -------------------------------------------------------------------

## Abertura como a tela inicial do Chrome & Wreckage: a paisagem em camadas, o
## logo e o botão. O toque também libera o som no navegador.
func _abertura() -> void:
	var tela := Control.new()
	tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tela)
	var ceu := ColorRect.new()
	ceu.color = Color("1b222c")
	ceu.set_anchors_preset(Control.PRESET_FULL_RECT)
	tela.add_child(ceu)
	tela.add_child(PaisagemParallax.new())
	var logo := TextureRect.new()
	logo.texture = load(LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.anchor_right = 1.0
	logo.anchor_top = 0.17
	logo.anchor_bottom = 0.17
	logo.offset_left = 48
	logo.offset_right = -48
	logo.offset_top = AreaSegura.topo(720.0)
	logo.offset_bottom = AreaSegura.topo(720.0) + 230.0
	tela.add_child(logo)
	var botao := BotaoInicio.new("Continuar" if estado.corridas > 0 else "Começar", true, COR_BOTAO, 56,
			104, 470)
	botao.anchor_left = 0.5
	botao.anchor_right = 0.5
	botao.anchor_top = 0.47
	botao.anchor_bottom = 0.47
	botao.offset_left = -235
	botao.offset_right = 235
	tela.add_child(botao)
	botao.pressed.connect(comecar)
	_abertura_tela = tela


## Sai da abertura: a primeira corrida e, se rendeu, a renda de quando o app
## esteve fechado.
func comecar() -> void:
	if _abertura_tela == null:
		return
	var tela := _abertura_tela
	_abertura_tela = null
	var tw := create_tween()
	tw.tween_property(tela, "modulate:a", 0.0, 0.3)
	tw.tween_callback(tela.queue_free)
	_nova_corrida()
	var ganho := estado.ganho_offline(Time.get_unix_time_from_system())
	if ganho >= 1.0:
		_janela_offline(ganho)


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
