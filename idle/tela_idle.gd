extends Control
## Chrome Racing Team (docs/idle/plano.md): a tela do jogo idle. Abre direto
## na corrida e já recolhe o que a equipe ganhou com o app fechado. Em cima, a
## placa da liga sobre o banner da pista, o dinheiro, a renda de todas as
## modalidades e a engrenagem (som e visual simples). No meio, uma de três
## telas escolhidas no menu de baixo:
##   - CORRIDA: a corrida 3D do Chrome & Wreckage com o que ela tem de assistir
##     (câmera AUTO, painel da corrida, semáforo, avisos, bandeirada, sons,
##     rivais com piloto e pintura das equipes rivais), as câmeras em ícones e
##     os cartões de melhoria da modalidade;
##   - PISTAS: as cinco modalidades e a escada de ligas de cada uma (PistasIdle);
##   - PILOTOS: contratos, fusão e escalação (PilotosIdle).
## A corrida roda sozinha, uma atrás da outra, também com as outras telas
## abertas (o 3D só desenha na CORRIDA).

const COR_FUNDO := IdleUI.COR_FUNDO
const COR_CARTAO := IdleUI.COR_CARTAO
const COR_DINHEIRO := IdleUI.COR_DINHEIRO
const COR_OURO := IdleUI.COR_OURO
const COR_BOTAO := IdleUI.COR_BOTAO
const COR_RUIM := IdleUI.COR_RUIM
const PAUSA_CHEGADA_S := 2.5
const PAUSA_COM_VIDEO_S := 4.0  # tempo para tocar em "VÍDEO: PRÊMIO 2×"
const SALVAR_A_CADA_S := 5.0
const AVISO_S := 3.5
const COLETA_S := 9.0  # a faixa da renda com o app fechado fica isso na tela
## Apresentação, como no Chrome & Wreckage: contagem da largada, rival colado
## que gera o aviso "SE APROXIMA" e o intervalo mínimo entre dois desses avisos.
const CONTAGEM_S := 3.0
const APROXIMA_S := 0.6
const EVENTO_RIVAL_S := 20.0
## Pintura do seu carro: o dourado da equipe com faixas escuras e o número 1.
const EQUIPE_JOGADOR := {"numero": 1, "cores": {"faixa": "#141518", "filete": "#f2f2ee"}}
const ABAS := [
	{"id": "corrida", "nome": "CORRIDA", "icone": "icone_correr"},
	{"id": "pistas", "nome": "PISTAS", "icone": "icone_pista"},
	{"id": "pilotos", "nome": "PILOTOS", "icone": "icone_piloto"},
]
## Câmeras: "auto" (o diretor do Chrome & Wreckage), "jogador" (atrás do seu
## carro) ou "geral" (a pista inteira), com os ícones do Chrome & Wreckage. Na
## Arena: dinâmica, a sua briga e a arena inteira (Arena3D.modo).
const CAMERAS := [["auto", "camera"], ["jogador", "frente"], ["geral", "pista"]]
const CAMERA_ARENA := {"auto": "dinamica", "jogador": "briga", "geral": "geral"}
## Tempo da luta por segundo de tela na Arena (as lutas de dez carros são longas).
const VELOCIDADE_ARENA := 2.0

var dados: Node
var estado: IdleEstado
var anuncios: IdleAnuncios
var _visual: CorridaVisual
var _visual3d: Corrida3D
var _arena3d: Arena3D  # a vista da modalidade Arena (a arena do Chrome & Wreckage)
var _na_arena := false
var _resultado := {}
var _semente := 1
var _pausa := -1.0  # > 0: parada depois da chegada, antes da próxima corrida
var _fim_jogador := INF
var _salvar_em := 0.0
var _camera_modo := "auto"
var _diretor := DiretorCamera.new()
var _pista: Pista

var _dinheiro: Label
var _renda: Label
var _liga: Label
var _icone_mod: TextureRect
var _banner: TextureRect  # banner da pista da liga atrás do topo
var _hud: HudCorrida
var _sons: Sons
var _nomes := {}  # id -> nome do piloto
var _contagem := -1.0  # s até a largada (< 0: correndo)
var _chegada := false  # seu carro cruzou a linha
var _t_chegada := 0.0
var _pos_antes := 0
var _avisado := {}  # rival -> quando avisou que se aproximava (tempo da corrida)
var _subir: Button
var _dobrar: Button
var _ganho_corrida := 0.0
var _sem_intersticial := false  # quem acabou de ver o vídeo não vê intersticial
var _cameras := {}  # modo -> botão
var _cartoes := {}  # melhoria -> {nivel, efeito, botao}
var _barra: BarraIdle
var _paginas := {}  # aba -> Control
var _pistas: PistasIdle
var _pilotos: PilotosIdle
var _aviso_caixa: PanelContainer
var _aviso_t := 0.0
var _coleta: PanelContainer
var _coleta_t := 0.0
var _config: Control


func _ready() -> void:
	dados = get_node("/root/Dados")
	Preferencias.carregar()
	estado = IdleEstado.carregar()
	anuncios = IdleAnuncios.new()
	anuncios.intersticial_min_s = float(estado.cfg.get("intersticial_min_s", 90.0))
	anuncios.config = estado.cfg.get("admob", {})
	add_child(anuncios)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var agora := Time.get_unix_time_from_system()
	# O primeiro piloto vem com a equipe (o primeiro contrato grátis).
	if estado.pilotos.is_empty():
		estado.usar_contrato_gratis(dados, agora)
	_montar()
	_nova_corrida()
	# Abriu, recolheu: a renda com o app fechado já entra no caixa.
	var ganho := estado.ganho_offline(agora)
	if ganho >= 1.0:
		estado.dinheiro += ganho
		_faixa_coleta(ganho)
	estado.salvar(agora)


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
	var raiz := VBoxContainer.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_theme_constant_override("separation", 0)
	add_child(raiz)
	var margem := MarginContainer.new()
	margem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margem.add_theme_constant_override("margin_left", 16)
	margem.add_theme_constant_override("margin_right", 16)
	margem.add_theme_constant_override("margin_top", int(AreaSegura.topo(720.0)) + 12)
	margem.add_theme_constant_override("margin_bottom", 12)
	raiz.add_child(margem)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margem.add_child(v)
	_topo(v)
	var conteudo := Control.new()
	conteudo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(conteudo)
	_paginas["corrida"] = _pagina_corrida()
	_pistas = PistasIdle.new(self)
	_pistas.correr_em.connect(func(mod: String):
		if estado.trocar_modalidade(mod):
			_nova_corrida()
			_abrir("corrida"))
	_paginas["pistas"] = _pistas
	_pilotos = PilotosIdle.new(self)
	_pilotos.mudou.connect(func(): estado.salvar(Time.get_unix_time_from_system()))
	_paginas["pilotos"] = _pilotos
	for id in _paginas:
		var pg: Control = _paginas[id]
		pg.set_anchors_preset(Control.PRESET_FULL_RECT)
		pg.visible = id == "corrida"
		conteudo.add_child(pg)
	_barra = BarraIdle.new(ABAS)
	_barra.escolheu.connect(_abrir)
	raiz.add_child(_barra)
	_atualizar_cartoes()


## Placa do alto: ícone da modalidade e liga, dinheiro e renda sobre o banner
## da pista; a engrenagem à direita.
func _topo(pai: Control) -> void:
	var placa := PanelContainer.new()
	placa.add_theme_stylebox_override("panel", IdleUI.caixa(COR_CARTAO, 14))
	placa.clip_contents = true
	pai.add_child(placa)
	_banner = TextureRect.new()
	_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_banner.modulate = Color(0.45, 0.45, 0.45)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placa.add_child(_banner)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 12)
	placa.add_child(topo)
	var esq := VBoxContainer.new()
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(esq)
	var linha_liga := HBoxContainer.new()
	linha_liga.add_theme_constant_override("separation", 6)
	esq.add_child(linha_liga)
	_icone_mod = IdleUI.icone("icone_correr", 28, linha_liga)
	_liga = IdleUI.rotulo("", 22, Color(0.93, 0.91, 0.87), linha_liga)
	_dinheiro = IdleUI.rotulo("", 52, Color.WHITE, esq)
	Tipografia.numero(_dinheiro, 52)
	var dir := VBoxContainer.new()
	dir.alignment = BoxContainer.ALIGNMENT_CENTER
	topo.add_child(dir)
	IdleUI.rotulo("RENDA", 18, IdleUI.COR_SECUNDARIA, dir).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_renda = IdleUI.rotulo("", 34, COR_DINHEIRO, dir)
	_renda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var eng := Button.new()
	eng.flat = true
	eng.focus_mode = Control.FOCUS_NONE
	eng.custom_minimum_size = Vector2(72, 72)
	eng.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := IconeVetor.new("engrenagem", Color(0.9, 0.9, 0.88))
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 14
	ic.offset_right = -14
	ic.offset_top = 14
	ic.offset_bottom = -14
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eng.add_child(ic)
	eng.pressed.connect(_abrir_config)
	topo.add_child(eng)


## A tela CORRIDA: a corrida 3D com o painel do Chrome & Wreckage, as câmeras e,
## embaixo, os cartões de melhoria da modalidade.
func _pagina_corrida() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var corrida := Control.new()
	corrida.custom_minimum_size = Vector2(0, 480)
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
	_arena3d = Arena3D.new()
	_arena3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arena3d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena3d.visible = false
	corrida.add_child(_arena3d)
	_hud = HudCorrida.new()
	corrida.add_child(_hud)
	_sons = Sons.new()
	add_child(_sons)
	# Câmeras: três ícones num trilho escuro, a ativa em ocre.
	var trilho := PanelContainer.new()
	trilho.add_theme_stylebox_override("panel", IdleUI.caixa(Color(0, 0, 0, 0.55), 14, 4))
	trilho.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	trilho.offset_left = 10
	trilho.offset_bottom = -10
	trilho.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corrida.add_child(trilho)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	trilho.add_child(h)
	for par in CAMERAS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(64, 56)
		var ic := IconeVetor.new(String(par[1]), Color.WHITE)
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 16
		ic.offset_right = -16
		ic.offset_top = 12
		ic.offset_bottom = -12
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		b.pressed.connect(_trocar_camera.bind(String(par[0])))
		h.add_child(b)
		_cameras[par[0]] = b
	_marcar_camera()
	_subir = Button.new()
	Tipografia.acao_primaria(_subir, "PRÓXIMA LIGA", COR_OURO, Color(0.1, 0.1, 0.1), 28, Tipografia.ALTURA_SECUNDARIA)
	_subir.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subir.offset_left = -200
	_subir.offset_right = 200
	_subir.offset_top = -170
	_subir.offset_bottom = -82
	_subir.pressed.connect(_subir_liga)
	corrida.add_child(_subir)
	_dobrar = Button.new()
	Tipografia.acao_primaria(_dobrar, "VÍDEO: PRÊMIO 2×", COR_DINHEIRO, Color(0.1, 0.1, 0.1), 26, Tipografia.ALTURA_SECUNDARIA)
	_dobrar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dobrar.offset_left = -200
	_dobrar.offset_right = 200
	_dobrar.offset_top = -170
	_dobrar.offset_bottom = -82
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
	return v


func _cartao(m: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", IdleUI.caixa(COR_CARTAO, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var ic := IdleUI.icone(String(m.get("icone", "")), 24, h)
	var nome := IdleUI.rotulo(String(m["nome"]).to_upper(), 17, Color.WHITE, h)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.clip_text = true
	var nivel := IdleUI.rotulo("", 15, IdleUI.COR_SECUNDARIA, h)
	var efeito := IdleUI.rotulo("", 18, COR_DINHEIRO, v)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	Tipografia.acao_primaria(b, "", COR_DINHEIRO.darkened(0.15), Color(0.06, 0.08, 0.06), 24, 56)
	b.pressed.connect(_comprar.bind(String(m["id"])))
	v.add_child(b)
	_cartoes[m["id"]] = {"nivel": nivel, "efeito": efeito, "botao": b, "nome": nome, "icone": ic}
	return p


static func curto(v: float) -> String:
	return IdleUI.curto(v)


## Troca a tela do meio (menu de baixo).
func _abrir(id: String) -> void:
	_barra.escolher(id)
	for k in _paginas:
		_paginas[k].visible = k == id
	if id == "pistas":
		_pistas.atualizar()
	elif id == "pilotos":
		_pilotos.atualizar()


func _efeito_texto(m: Dictionary, nivel: int) -> String:
	var x := float(m["por_nivel"]) * nivel
	if _na_arena and m["efeito"] == "vacuo":
		# Blindagem: o peso a mais do carro na Arena.
		return "+%d%%" % roundi(x * float(estado.dados_modalidade().get("blindagem_por_vacuo", 0.0)) * 100.0)
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
		# Na Arena, a melhoria pode ter outro nome (o Vácuo vira Blindagem).
		var arena: bool = _na_arena and m.has("nome_arena")
		c["nome"].text = String(m["nome_arena"] if arena else m["nome"]).to_upper()
		c["icone"].texture = Aba.icone_reduzido(String(m["icone_arena"] if arena else m.get("icone", "")), 24)
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
	_icone_mod.texture = Aba.icone_reduzido(String(estado.dados_modalidade().get("icone", "icone_correr")), 28)
	_banner.texture = IdleUI.banner_pista(String(estado.dados_liga()["pista"]))
	_subir.visible = estado.pode_subir() and _pausa < 0.0
	_dobrar.visible = _dobrar.visible and _pausa >= 0.0


# --- corrida ------------------------------------------------------------------

func _nova_corrida() -> void:
	_semente += 1
	_resultado = estado.correr(dados, _semente + estado.corridas * 7919)
	_na_arena = estado.e_arena()
	_visual3d.visible = not _na_arena
	_arena3d.visible = _na_arena
	_hud.so_eventos = _na_arena
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
	if _na_arena:
		_arena3d.faixas_pintura = faixas
		_arena3d.mostrar(_resultado, estado.params_arena(dados), categorias, pinturas)
		_arena3d.tempo = 0.0
		var eu: Dictionary = _resultado["carros"]["jogador"]
		# Fim para você: quando o seu carro cai ou a luta acaba.
		_fim_jogador = float(eu["eliminado_em"]) + 1.5 if eu["eliminado"] else _arena3d.duracao()
		_fim_jogador = minf(_fim_jogador, _arena3d.duracao())
	else:
		_pista = estado.pista(dados)
		_visual.mostrar(_pista, _resultado, {"jogador": COR_OURO})
		_visual3d.faixas_pintura = faixas
		_visual3d.nomes = _nomes
		_visual3d.chegada = 0.0
		_visual3d.mostrar(_pista, _visual, categorias, pinturas)
		_visual.tempo = 0.0
		_fim_jogador = float(_resultado["carros"]["jogador"]["tempo_total"])
	_pausa = -1.0
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


func _trocar_camera(modo: String) -> void:
	_camera_modo = modo
	_marcar_camera()
	_diretor.reiniciar()
	_aplicar_camera()


func _marcar_camera() -> void:
	for modo in _cameras:
		var b: Button = _cameras[modo]
		var ativa: bool = modo == _camera_modo
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, IdleUI.caixa(Color(COR_OURO, 0.9) if ativa else Color(1, 1, 1, 0.06), 10, 0))
		b.get_child(0).cor = Color(0.08, 0.07, 0.06) if ativa else Color.WHITE
		b.get_child(0).queue_redraw()


func _aplicar_camera() -> void:
	_arena3d.modo = CAMERA_ARENA[_camera_modo]
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
	_avisos(delta)
	if _na_arena:
		_processo_arena(delta)
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
	var vendo: bool = _paginas["corrida"].visible
	if vendo:  # nas outras telas a corrida segue, sem desenhar o 3D
		_visual3d.atualizar(delta)
		var tela := _visual3d.posicao_tela(_visual3d.foco if _visual3d.foco != "" else "jogador")
		_hud.ancora_carro = _hud.get_global_transform().affine_inverse() * tela if tela.x >= 0.0 else Vector2(-1, -1)
	var ordem := _visual.ordem()
	_atualizar_hud(ordem)
	_eventos(ordem)
	if vendo:
		_som(ordem)
	else:
		_sons.motor(false)
		_sons.torcida(0.0)
	_atualizar_topo()
	if vendo:
		_atualizar_cartoes()
	_salvar_em -= delta
	if _salvar_em <= 0.0:
		_salvar_em = SALVAR_A_CADA_S
		estado.salvar(Time.get_unix_time_from_system())


## A luta da Arena: semáforo, a luta acelerada e, quando o seu carro cai ou a
## luta acaba, o resultado (a ordem de quem ficou de pé).
func _processo_arena(delta: float) -> void:
	var vendo: bool = _paginas["corrida"].visible
	if _contagem > 0.0:
		_contar(delta)
	elif _pausa >= 0.0:
		_pausa -= delta
		_arena3d.tempo = minf(_arena3d.tempo + delta * VELOCIDADE_ARENA, _arena3d.duracao())
		if _pausa < 0.0:
			if not _sem_intersticial:
				anuncios.intersticial()
			_sem_intersticial = false
			_nova_corrida()
	else:
		_arena3d.tempo = minf(_arena3d.tempo + delta * VELOCIDADE_ARENA, _arena3d.duracao())
		_eventos_arena()
		if _arena3d.tempo >= _fim_jogador:
			_chegou()
	if vendo:
		_arena3d.atualizar(delta)
		_sons.motor(_contagem <= 0.0 and not _chegada, 20.0)
	else:
		_sons.motor(false)
	_atualizar_topo()
	if vendo:
		_atualizar_cartoes()
	_salvar_em -= delta
	if _salvar_em <= 0.0:
		_salvar_em = SALVAR_A_CADA_S
		estado.salvar(Time.get_unix_time_from_system())


## Avisos da Arena: quem você tirou da luta e quantos ainda estão de pé.
func _eventos_arena() -> void:
	for e in _resultado["eventos"]:
		if e["tipo"] != "eliminado" or float(e["t"]) > _arena3d.tempo or _avisado.has(e):
			continue
		_avisado[e] = true
		var vivos := 0
		for id in _resultado["carros"]:
			var c: Dictionary = _resultado["carros"][id]
			if not c["eliminado"] or float(c["eliminado_em"]) > _arena3d.tempo:
				vivos += 1
		if String(e.get("por", "")) == "jogador":
			_hud.evento("ELIMINOU", "%s · %d de pé" % [String(_nomes.get(String(e["carro"]), "")).to_upper(), vivos], COR_OURO, 5)
			_sons.ultrapassagem(true)
		elif String(e["carro"]) != "jogador":
			_hud.evento("%d DE PÉ" % vivos, String(_nomes.get(String(e["carro"]), "")) + " saiu", Color.WHITE, 2)


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


## Liga nova: o banner da pista, o nome da liga e o carro novo da equipe; se a
## liga abriu outra modalidade, ela vem junto.
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
	p.add_theme_stylebox_override("panel", IdleUI.caixa(COR_CARTAO, 18))
	centro.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	IdleUI.imagem_cobrindo(IdleUI.banner_pista(String(estado.dados_liga()["pista"])), 220, v)
	var t := IdleUI.rotulo("NOVA LIGA", 24, COR_OURO, v)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var n := IdleUI.rotulo(String(estado.dados_liga()["nome"]).to_upper(), 46, Color.WHITE, v, "display")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var c := IdleUI.rotulo("CARRO NOVO: " + String(estado.carro_base(dados)["nome"]).to_upper(), 24, IdleUI.COR_SECUNDARIA, v)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for m in estado.cfg["modalidades"]:
		var lib: Dictionary = m.get("libera", {})
		if lib.get("modalidade", "") == estado.modalidade and int(lib.get("liga", -1)) == estado.liga:
			var abriu := IdleUI.rotulo("MODALIDADE NOVA: %s" % String(m["nome"]).to_upper(), 28, COR_DINHEIRO, v)
			abriu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_barra.avisar("pistas", true)
	var ok := BotaoInicio.new("Correr", true, COR_BOTAO, 40, 88, 360)
	ok.pressed.connect(fundo.queue_free)
	v.add_child(ok)


# --- avisos ---------------------------------------------------------------------

## Aviso curto no alto (piloto novo, fusão): título, linha de baixo e, se
## houver, a imagem (retrato) à esquerda.
func mostrar_aviso(titulo: String, sub := "", tex: Texture2D = null) -> void:
	if _aviso_caixa != null:
		_aviso_caixa.queue_free()
	_aviso_caixa = PanelContainer.new()
	_aviso_caixa.add_theme_stylebox_override("panel", IdleUI.caixa(Color(0.06, 0.07, 0.09, 0.96), 16, 14, COR_OURO, 2))
	_aviso_caixa.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_aviso_caixa.offset_top = AreaSegura.topo(720.0) + 150
	_aviso_caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_aviso_caixa)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_aviso_caixa.add_child(h)
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(120, 120)
		h.add_child(r)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	IdleUI.rotulo(titulo, 28, COR_OURO, v)
	if sub != "":
		IdleUI.rotulo(sub, 20, Color.WHITE, v)
	_aviso_caixa.pivot_offset = _aviso_caixa.size * 0.5
	_aviso_caixa.scale = Vector2(0.85, 0.85)
	create_tween().tween_property(_aviso_caixa, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	_aviso_t = AVISO_S


## A renda com o app fechado já entrou: uma faixa diz quanto e oferece o vídeo
## que dobra.
func _faixa_coleta(ganho: float) -> void:
	_coleta = PanelContainer.new()
	_coleta.add_theme_stylebox_override("panel", IdleUI.caixa(Color(0.06, 0.07, 0.09, 0.96), 16, 12, COR_DINHEIRO, 2))
	_coleta.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_coleta.offset_top = AreaSegura.topo(720.0) + 330
	_coleta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_coleta)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_coleta.add_child(h)
	var v := VBoxContainer.new()
	h.add_child(v)
	IdleUI.rotulo("ENQUANTO VOCÊ ESTEVE FORA", 18, IdleUI.COR_SECUNDARIA, v)
	IdleUI.rotulo("+$" + curto(ganho), 40, COR_DINHEIRO, v)
	var b := IdleUI.botao("VÍDEO: +$%s" % curto(ganho), COR_BOTAO, 22, 64, h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		_coleta_t = 0.0
		anuncios.premiado(func():
			estado.dinheiro += ganho
			estado.salvar(Time.get_unix_time_from_system())
			mostrar_aviso("RENDA DOBRADA", "+$" + curto(ganho))))
	_coleta_t = COLETA_S


func _avisos(delta: float) -> void:
	if _aviso_t > 0.0:
		_aviso_t -= delta
		if _aviso_t <= 0.0 and _aviso_caixa != null:
			_aviso_caixa.queue_free()
			_aviso_caixa = null
	if _coleta_t > 0.0:
		_coleta_t -= delta
		if _coleta_t <= 0.0 and _coleta != null:
			_coleta.queue_free()
			_coleta = null
	_barra.avisar("pilotos", estado.contrato_gratis_pronto(Time.get_unix_time_from_system())
			or estado.piloto_escalado().is_empty())


# --- configurações --------------------------------------------------------------

## Engrenagem: som e visual simples (efeitos leves do 3D, como no Chrome &
## Wreckage), nas preferências do aparelho.
func _abrir_config() -> void:
	if _config != null:
		return
	_config = ColorRect.new()
	(_config as ColorRect).color = Color(0, 0, 0, 0.7)
	_config.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_config)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_config.add_child(centro)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(560, 0)
	p.add_theme_stylebox_override("panel", IdleUI.caixa(COR_CARTAO, 18, 20))
	centro.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	IdleUI.rotulo("CONFIGURAÇÕES", 32, Color.WHITE, v, "display")
	_linha_chave(v, "som", "SOM", Preferencias.volume > 0.001, func(ligado: bool):
		Preferencias.volume = 0.7 if ligado else 0.0
		Preferencias.salvar())
	_linha_chave(v, "tela", "VISUAL SIMPLES", Preferencias.efeitos_leves, func(ligado: bool):
		Preferencias.efeitos_leves = ligado
		Preferencias.salvar())
	var nota := IdleUI.rotulo("Visual simples tira sombras, fumaça e efeitos: mais leve em celulares fracos.", 17,
			IdleUI.COR_SECUNDARIA, v, "regular")
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ok := IdleUI.botao("FECHAR", COR_BOTAO, 26, 72, v)
	ok.pressed.connect(func():
		_config.queue_free()
		_config = null)


func _linha_chave(pai: Control, icone: String, texto: String, ligada: bool, ao_mudar: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	pai.add_child(h)
	var ic := IconeVetor.new(icone, Color(0.9, 0.9, 0.88))
	ic.custom_minimum_size = Vector2(40, 40)
	h.add_child(ic)
	var l := IdleUI.rotulo(texto, 26, Color.WHITE, h)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chave := ChaveLiga.new(ligada)
	chave.toggled.connect(func(x: bool): ao_mudar.call(x))
	h.add_child(chave)
