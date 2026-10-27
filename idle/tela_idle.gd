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
##   - PILOTOS: contratos, fusão e escalação (PilotosIdle);
##   - MISSÕES: as missões do dia (MetasIdle).
## A corrida roda sozinha, uma atrás da outra, também com as outras telas
## abertas (o 3D só desenha na CORRIDA).
##
## O jogo cresce com o jogador (idle.json → desbloqueios, IdleEstado.tem): no
## começo, a vista de cima com os carros em pontos, só o cartão do Motor, sem
## menu de baixo e a largada no toque (LARGAR). Cada passo chega com a conversa
## de um personagem (ConversaIdle); os que custam ficam como oferta no canto da
## corrida até o jogador pagar: a largada automática, a transmissão (a corrida
## 3D), o analista (previsão nos cartões) e as câmeras.

const COR_FUNDO := IdleUI.COR_FUNDO
const COR_CARTAO := IdleUI.COR_CARTAO
const COR_DINHEIRO := IdleUI.COR_DINHEIRO
const COR_OURO := IdleUI.COR_OURO
const COR_BOTAO := IdleUI.COR_BOTAO
const COR_RUIM := IdleUI.COR_RUIM
const PAUSA_CHEGADA_S := 2.5
const BEM_VINDO_MIN_S := 300.0  # menos tempo fora que isso: a renda entra sem a janela
const PAUSA_COM_VIDEO_S := 4.0  # tempo para tocar em "▶ PRÊMIO x2"
const SALVAR_A_CADA_S := 5.0
const AVISO_S := 3.5
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
	{"id": "metas", "nome": "MISSÕES", "icone": "icone_objetivo"},
]
## Previsão nos cartões de melhoria: corridas simuladas (sementes fixas) com e
## sem níveis a mais (NIVEIS_PREVISAO), numa thread, para mostrar a posição que
## a compra traz.
const SEMENTES_PREVISAO := [101, 202, 303, 404]
const EFEITOS_PREVISAO := ["potencia", "aderencia", "agressividade", "vacuo"]
const NIVEIS_PREVISAO := [1, 3]
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
var _dinheiro_mostrado := 0.0  # o número do topo, que conta até o dinheiro
var _cameras := {}  # modo -> botão
var _cartoes := {}  # melhoria -> {nivel, efeito, botao}
var _barra: BarraIdle
var _paginas := {}  # aba -> Control
var _pistas: PistasIdle
var _pilotos: PilotosIdle
var _metas: MetasIdle
var _previsao := {}  # "melhoria|n" -> posição média com n níveis a mais; "" -> sem
var _previsao_chave := ""
var _previsao_tarefa := -1
var _previsao_resultado := {}
var _previsao_mutex := Mutex.new()
var _aviso_caixa: PanelContainer
var _aviso_t := 0.0
var _coleta: Control  # "BEM-VINDO DE VOLTA!": a renda com o app fechado
var _config: Control
var _renda_caixa: Control  # "RENDA" e o valor, no topo (aparecem com o patrocínio)
var _trilho: Control  # as câmeras
var _largar: Button
var _aguardando := false  # carros no grid esperando o LARGAR
var _conversa: ConversaIdle
var _ofertas: VBoxContainer  # ofertas recusadas, no canto da corrida
var _janela_aberta := false
var _tv := true  # a transmissão (corrida 3D) já foi comprada
var _guia: GuiaIdle  # tutorial leve depois de cada função nova
var _conversa_em := -1  # corridas no total quando a última conversa abriu (uma por corrida)
var _efeitos: EfeitosIdle  # números que pipocam e faíscas, por cima de tudo
var _renda_acumulada := 0.0  # renda desde o último "+$" que pipocou no topo
var _renda_t := 0.0
var _objetivo: Label  # o alvo da liga, entre a corrida e os cartões
var _melhor: Label
## Som (docs/idle/sonorizacao.md): música de fundo, ambiente do box nas telas sem
## corrida e o combo de compras seguidas.
const MUSICA_DB := -16.0
const MUSICA_SOB_MOTOR_DB := -26.0
const AMBIENTE_DB := -24.0
const COMBO_S := 1.2
const COMBO_MAX := 7
var _musica: AudioStreamPlayer
var _ambiente: AudioStreamPlayer
var _combo := 0
var _ultima_compra_ms := -100000


func _ready() -> void:
	dados = get_node("/root/Dados")
	Sons.barramentos()
	Preferencias.carregar()
	Preferencias.aplicar()
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
	_dinheiro_mostrado = estado.dinheiro
	_montar()
	_nova_corrida()
	# Abriu, recolheu: a renda com o app fechado já entra no caixa (fica salva
	# mesmo se o app fechar de novo); o "BEM-VINDO DE VOLTA!" a mostra e o
	# COLETAR faz o número do topo subir.
	var ganho := estado.ganho_offline(agora)
	if ganho >= 1.0:
		estado.dinheiro += ganho
		if agora - estado.salvo_em >= BEM_VINDO_MIN_S:
			_bem_vindo(ganho)
	estado.salvar(agora)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if estado != null:
			estado.salvar(Time.get_unix_time_from_system())
			IdleAvisos.agendar(estado)
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		IdleAvisos.cancelar()


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
	_metas = MetasIdle.new(self)
	_metas.mudou.connect(func(): estado.salvar(Time.get_unix_time_from_system()))
	_paginas["metas"] = _metas
	for id in _paginas:
		var pg: Control = _paginas[id]
		pg.set_anchors_preset(Control.PRESET_FULL_RECT)
		pg.visible = id == "corrida"
		conteudo.add_child(pg)
	_barra = BarraIdle.new(ABAS)
	_barra.escolheu.connect(_abrir)
	raiz.add_child(_barra)
	_guia = GuiaIdle.new()
	add_child(_guia)
	_efeitos = EfeitosIdle.new()
	add_child(_efeitos)
	_aplicar_desbloqueios()
	_atualizar_cartoes()


## Placa do alto: ícone da modalidade e liga, dinheiro e renda sobre o banner
## da pista; a engrenagem à direita.
func _topo(pai: Control) -> void:
	var placa := PanelContainer.new()
	placa.add_theme_stylebox_override("panel", IdleUI.caixa(COR_CARTAO, 14, 12, IdleUI.COR_BORDA, 1))
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
	_icone_mod = IdleUI.icone("icone_correr", 40, linha_liga)
	_liga = IdleUI.rotulo("", 22, IdleUI.COR_CROMO, linha_liga)
	_dinheiro = IdleUI.rotulo("", 52, IdleUI.COR_TEXTO, esq)
	Tipografia.numero(_dinheiro, 52)
	var dir := VBoxContainer.new()
	dir.alignment = BoxContainer.ALIGNMENT_CENTER
	topo.add_child(dir)
	_renda_caixa = dir
	IdleUI.rotulo("POR SEGUNDO", 16, IdleUI.COR_SECUNDARIA, dir).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_renda = IdleUI.rotulo("", 34, COR_DINHEIRO, dir)
	_renda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var vao := Control.new()
	vao.custom_minimum_size = Vector2(4, 0)
	topo.add_child(vao)
	var eng := Button.new()
	eng.flat = true
	eng.focus_mode = Control.FOCUS_NONE
	eng.custom_minimum_size = Vector2(72, 72)
	eng.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := IconeVetor.new("engrenagem", IdleUI.COR_CROMO)
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
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual.offset_top = 70  # abaixo da posição do painel
	_visual.offset_bottom = -20
	_visual.sombra = true
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
	_hud.sem_volta = true
	_hud.escala_texto = 1.3  # texto legível no celular (docs/idle/interface.md)
	corrida.add_child(_hud)
	_sons = Sons.new()
	add_child(_sons)
	_musica = _fundo("musica_box", "Musica", MUSICA_DB)
	_ambiente = _fundo("oficina", "Ambiente", -60.0)
	# Câmeras: três ícones num trilho escuro, a ativa em ocre.
	var trilho := PanelContainer.new()
	trilho.add_theme_stylebox_override("panel", IdleUI.caixa(Color(IdleUI.COR_FUNDO, 0.7), 14, 4, IdleUI.COR_BORDA, 1))
	trilho.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	trilho.offset_left = 10
	trilho.offset_bottom = -10
	trilho.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corrida.add_child(trilho)
	_trilho = trilho
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
	Tipografia.acao_primaria(_subir, "SUBIR DE LIGA", COR_OURO, IdleUI.COR_TINTA, IdleUI.legivel(28), IdleUI.ALTURA_MIN)
	IdleUI.estilo_ouro(_subir)
	_subir.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subir.offset_left = -200
	_subir.offset_right = 200
	_subir.offset_top = -170
	_subir.offset_bottom = -82
	_subir.pressed.connect(_subir_liga)
	corrida.add_child(_subir)
	_dobrar = IdleUI.botao_premio("PRÊMIO x2", 28, Tipografia.ALTURA_SECUNDARIA)
	_dobrar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dobrar.offset_left = -200
	_dobrar.offset_right = 200
	_dobrar.offset_top = -170
	_dobrar.offset_bottom = -82
	_dobrar.visible = false
	_dobrar.pressed.connect(_dobrar_premio)
	corrida.add_child(_dobrar)
	# LARGAR: até a largada automática, cada corrida começa no toque.
	_largar = BotaoInicio.new("Largar", true, COR_BOTAO, 40, 88, 320)
	_largar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_largar.offset_left = -160
	_largar.offset_right = 160
	_largar.offset_top = -118
	_largar.offset_bottom = -30
	_largar.visible = false
	_largar.pressed.connect(_largar_corrida)
	corrida.add_child(_largar)
	# Ofertas que o jogador deixou para depois, no canto de cima à direita.
	_ofertas = VBoxContainer.new()
	_ofertas.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_ofertas.offset_right = -10
	_ofertas.offset_top = 10
	_ofertas.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ofertas.add_theme_constant_override("separation", 8)
	corrida.add_child(_ofertas)
	# O objetivo sempre à vista: o que sobe de liga e a melhor chegada nela.
	var alvo := PanelContainer.new()
	alvo.add_theme_stylebox_override("panel", IdleUI.caixa(COR_CARTAO, 12, 10, IdleUI.COR_BORDA, 1))
	v.add_child(alvo)
	var linha_alvo := HBoxContainer.new()
	alvo.add_child(linha_alvo)
	_objetivo = IdleUI.rotulo("", 22, COR_OURO, linha_alvo)
	_objetivo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_melhor = IdleUI.rotulo("", 22, IdleUI.COR_TEXTO, linha_alvo)
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
	p.add_theme_stylebox_override("panel", IdleUI.caixa(COR_CARTAO, 14, 12, IdleUI.COR_BORDA, 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var nome := IdleUI.rotulo(String(m["nome"]).to_upper(), 17, IdleUI.COR_TEXTO, h)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.clip_text = true
	var efeito := IdleUI.rotulo("", 18, IdleUI.COR_GANHO, v)
	efeito.clip_text = true
	var linha := HBoxContainer.new()
	v.add_child(linha)
	var previsao := IdleUI.rotulo("", 15, IdleUI.COR_SECUNDARIA, linha)
	previsao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	previsao.clip_text = true
	var nivel := IdleUI.rotulo("", 15, IdleUI.COR_SECUNDARIA, linha)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	Tipografia.acao_primaria(b, "", COR_OURO, IdleUI.COR_TINTA, IdleUI.legivel(24), 72)
	IdleUI.estilo_ouro(b)
	IdleUI.desativado_legivel(b)
	b.pressed.connect(_comprar.bind(String(m["id"])))
	v.add_child(b)
	_cartoes[m["id"]] = {"nivel": nivel, "efeito": efeito, "previsao": previsao, "botao": b, "nome": nome,
			"cartao": p}
	return p


static func curto(v: float) -> String:
	return IdleUI.curto(v)


## Troca a tela do meio (menu de baixo).
func _abrir(id: String) -> void:
	if not _paginas[id].visible:
		Sons.tocar_ui(self, "toque", -6.0)
	_barra.escolher(id)
	for k in _paginas:
		_paginas[k].visible = k == id
	if id == "pistas":
		_pistas.atualizar()
	elif id == "pilotos":
		_pilotos.atualizar()
	elif id == "metas":
		_metas.atualizar()


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
	_atualizar_previsao()
	var base := float(_previsao.get("", 0.0))
	for m in estado.cfg["melhorias"]:
		var c: Dictionary = _cartoes[m["id"]]
		_texto_previsao(c["previsao"], m, base)
		var n := estado.nivel(m["id"])
		# Na Arena, a melhoria pode ter outro nome (o Vácuo vira Blindagem).
		var arena: bool = _na_arena and m.has("nome_arena")
		c["nome"].text = String(m["nome_arena"] if arena else m["nome"]).to_upper()
		c["nivel"].text = IdleUI.nv(n)
		var b: Button = c["botao"]
		if estado.no_maximo(m["id"]):
			c["efeito"].text = _efeito_texto(m, n)
			b.text = "MÁX."
			b.disabled = true
		else:
			c["efeito"].text = "%s › %s" % [_efeito_texto(m, n), _efeito_texto(m, n + 1)]
			b.text = "$%s" % curto(estado.custo(m["id"]))
			var antes := b.disabled
			b.disabled = not estado.pode_comprar(m["id"])
			# Botão que passa a poder ser tocado pulsa uma vez.
			if antes and not b.disabled and c["cartao"].is_visible_in_tree():
				IdleUI.pulsar(b, 1.08)


func _atualizar_topo(delta := 0.0) -> void:
	# O número conta até o dinheiro quando entra muito de uma vez (prêmio,
	# renda com o app fechado, meta); gasto e renda corrente vão direto.
	if estado.dinheiro < _dinheiro_mostrado or estado.dinheiro - _dinheiro_mostrado < estado.renda_s() * 0.5 \
			or Preferencias.reduzir_animacoes:
		_dinheiro_mostrado = estado.dinheiro
	else:
		_dinheiro_mostrado = lerpf(_dinheiro_mostrado, estado.dinheiro, 1.0 - exp(-5.0 * delta))
	_dinheiro.text = "$" + curto(_dinheiro_mostrado)
	_renda.text = "+$%s/s" % curto(estado.renda_s())
	_liga.text = String(estado.dados_liga()["nome"]).to_upper()
	if estado.venceu:
		_objetivo.text = "CATEGORIA VENCIDA" if estado.ultima_liga() else "VITÓRIA! SUBA DE LIGA"
	else:
		_objetivo.text = "VENÇA PARA SUBIR DE LIGA"
	_melhor.text = "MELHOR: %dº" % estado.melhor_posicao() if estado.melhor_posicao() > 0 else ""
	_icone_mod.texture = Aba.icone_reduzido(String(estado.dados_modalidade().get("icone", "icone_correr")), 40)
	_banner.texture = IdleUI.banner_pista(String(estado.dados_liga()["pista"]))
	_subir.visible = estado.pode_subir() and _pausa < 0.0
	if _subir.visible and not "subir" in estado.guias and _conversa == null and not _guia.ativo():
		estado.guias.append("subir")
		_guiar.call_deferred("subir", "Vitória! Toque em SUBIR DE LIGA para correr numa liga nova.")
	# Com o LARGAR na tela, PRÓXIMA LIGA fica logo acima dele.
	_subir.offset_top = -230.0 if _largar.visible else -170.0
	_subir.offset_bottom = -142.0 if _largar.visible else -82.0
	if _subir.visible and not Preferencias.reduzir_animacoes:
		_subir.pivot_offset = _subir.size * 0.5
		var k := 1.0 + 0.035 * sin(Time.get_ticks_msec() / 1000.0 * TAU / 1.1)
		_subir.scale = Vector2(k, k)
	_dobrar.visible = _dobrar.visible and _pausa >= 0.0


# --- corrida ------------------------------------------------------------------

func _nova_corrida() -> void:
	_semente += 1
	_resultado = estado.correr(dados, _semente + estado.corridas * 7919)
	_na_arena = estado.e_arena()
	_visual3d.visible = not _na_arena and _tv
	_visual.visible = not _na_arena and not _tv
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
	_aguardando = not estado.tem("largada_auto")
	_largar.visible = _aguardando
	_hud.contagem = -1.0 if _aguardando else _contagem
	if not _aguardando:
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
			b.add_theme_stylebox_override(st, IdleUI.caixa(COR_OURO if ativa else Color(1, 1, 1, 0.05), 10, 0))
		b.get_child(0).cor = IdleUI.COR_TINTA if ativa else IdleUI.COR_CROMO
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
	_misturar(delta)
	_pipocar_renda(delta)
	_checar_conversa()
	if _aguardando or _conversa != null or _coleta != null:
		# Carros no grid (esperando o LARGAR) ou alguém falando: a corrida para.
		_atualizar_topo(delta)
		if _paginas["corrida"].visible:
			_atualizar_cartoes()
			if _tv and not _na_arena:
				_visual3d.atualizar(delta)
		return
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
	if vendo and _tv:  # nas outras telas a corrida segue, sem desenhar o 3D
		_visual3d.atualizar(delta)
		var tela := _visual3d.posicao_tela(_visual3d.foco if _visual3d.foco != "" else "jogador")
		_hud.ancora_carro = _hud.get_global_transform().affine_inverse() * tela if tela.x >= 0.0 else Vector2(-1, -1)
	elif vendo:
		_hud.ancora_carro = Vector2(-1, -1)
	var ordem := _visual.ordem()
	_atualizar_hud(ordem)
	_eventos(ordem)
	if vendo:
		_som(ordem)
	else:
		_sons.motor(false)
		_sons.torcida(0.0)
	_atualizar_topo(delta)
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
	_atualizar_topo(delta)
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
	# A torcida da reta final cresce com a Arquibancada.
	var arquibancada := clampf(estado.nivel("arquibancada") / 20.0, 0.0, 1.0)
	_sons.torcida((1.0 - smoothstep(0.1, 0.3, resto)) * (0.5 + 0.5 * arquibancada))


func _chegou() -> void:
	var pos := IdleEstado.posicao(_resultado)
	var ganho := estado.concluir(pos)
	_chegada = true
	_sons.chegada()
	if pos == 1:
		Sons.tocar_ui(self, "comemoracao", -8.0)
	_hud.bandeirada()
	_hud.evento("VITÓRIA!" if pos == 1 else "%dº LUGAR" % pos, "+$" + curto(ganho),
			COR_OURO if pos == 1 else IdleUI.COR_TEXTO, 10, -1.0, true)
	_ganho_corrida = ganho
	ganho_flutuante(ganho)
	if pos <= 3:
		# Pódio: faíscas do meio da corrida (mais na vitória).
		var meio: Vector2 = _paginas["corrida"].get_global_rect().get_center() + Vector2(0, -160)
		_efeitos.faiscas(meio, COR_OURO, 40 if pos == 1 else 20)
	_dobrar.visible = true
	_pausa = PAUSA_COM_VIDEO_S
	estado.salvar(Time.get_unix_time_from_system())


## O vídeo premiado depois da corrida: assistido até o fim, paga o prêmio de
## novo.
func _dobrar_premio() -> void:
	_dobrar.visible = false
	var ganho := _ganho_corrida
	anuncios.premiado(func():
		estado.dinheiro += ganho
		ganho_flutuante(ganho)
		_hud.evento("PRÊMIO x2!", "+$" + curto(ganho * 2.0), COR_OURO, 11, -1.0, true)
		_pausa = maxf(_pausa, PAUSA_CHEGADA_S)
		estado.salvar(Time.get_unix_time_from_system()))


func _comprar(id: String) -> void:
	if estado.comprar(id):
		# Combo: cada compra até COMBO_S depois da anterior sobe um semitom.
		var agora := Time.get_ticks_msec()
		_combo = mini(_combo + 1, COMBO_MAX) if agora - _ultima_compra_ms <= COMBO_S * 1000.0 else 0
		_ultima_compra_ms = agora
		Sons.tocar_ui(self, "moeda", -6.0, pow(2.0, _combo / 12.0))
		# A compra tem peso: o botão afunda e salta com clarão, faíscas estouram
		# dele, o nível novo pipoca acima do cartão (maior a cada compra seguida)
		# e o dinheiro do topo afunda.
		var c: Dictionary = _cartoes[id]
		var b: Button = c["botao"]
		IdleUI.premiar(b)
		IdleUI.pulsar(c["cartao"], 1.05)
		_efeitos.faiscas(b.get_global_rect().get_center(), IdleUI.COR_OURO_CLARO, 14 + 3 * _combo)
		var texto := IdleUI.nv(estado.nivel(id)) + ("  ×%d" % (_combo + 1) if _combo > 0 else "")
		_efeitos.pipoca(c["cartao"].get_global_rect().get_center() + Vector2(0, -40), texto, COR_OURO, 32, 0.5 + 0.12 * _combo)
		IdleUI.saltar(_dinheiro, 0.92)
		_atualizar_cartoes()


func _subir_liga() -> void:
	if not estado.subir_liga():
		return
	estado.salvar(Time.get_unix_time_from_system())
	_nova_corrida()
	_janela_liga()


## O intersticial só aparece aqui, ao fechar a janela da liga nova, e só depois
## das primeiras ligas (intersticial_a_partir_liga); nunca ao abrir o app nem
## no meio da corrida.
func _intersticial_da_liga() -> void:
	var maior := 0
	for id in estado.liberadas():
		maior = maxi(maior, int(estado._m(id)["liga"]))
	if maior >= int(estado.cfg.get("intersticial_a_partir_liga", 0)):
		anuncios.intersticial()


## Liga nova: o banner da pista, o nome da liga e o carro novo da equipe; se a
## liga abriu outra modalidade, ela vem junto.
func _janela_liga() -> void:
	_janela_aberta = true
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
	var c := IdleUI.rotulo("SEU CARRO NOVO: " + String(estado.carro_base(dados)["nome"]).to_upper(), 24, IdleUI.COR_SECUNDARIA, v)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var nova_modalidade := false
	for m in estado.cfg["modalidades"]:
		var lib: Dictionary = m.get("libera", {})
		if lib.get("modalidade", "") == estado.modalidade and int(lib.get("liga", -1)) == estado.liga:
			var abriu := IdleUI.rotulo("NOVA MODALIDADE: %s" % String(m["nome"]).to_upper(), 28, IdleUI.COR_GANHO, v)
			abriu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_barra.avisar("pistas", true)
			nova_modalidade = true
	var ok := BotaoInicio.new("Correr", true, COR_BOTAO, 40, 88, 360)
	ok.pressed.connect(func():
		fundo.queue_free()
		_janela_aberta = false
		_oferecer_avisos()
		_intersticial_da_liga())
	v.add_child(ok)
	# Marco: a janela entra crescendo com um brilho dourado na borda, e o
	# aparelho vibra (mais na modalidade nova).
	celebrar(4 if nova_modalidade else 3)
	if not Preferencias.reduzir_animacoes:
		var sb := IdleUI.caixa(COR_CARTAO, 18, 12, COR_OURO, 3)
		sb.shadow_color = Color(COR_OURO, 0.55)
		sb.shadow_size = 28
		p.add_theme_stylebox_override("panel", sb)
		p.pivot_offset = Vector2(300, 300)
		p.scale = Vector2(0.8, 0.8)
		p.modulate.a = 0.0
		var tw := p.create_tween().set_parallel()
		tw.tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 1.0, 0.2)
		var brilho := p.create_tween().set_loops()
		brilho.tween_property(sb, "shadow_size", 12, 0.9).set_trans(Tween.TRANS_SINE)
		brilho.tween_property(sb, "shadow_size", 28, 0.9).set_trans(Tween.TRANS_SINE)


## Na primeira liga nova, os avisos com o app fechado ligam (o aparelho pede a
## permissão); a chave fica nas Configurações.
func _oferecer_avisos() -> void:
	if estado.avisos_oferecidos or not Engine.has_singleton(IdleAvisos.PLUGIN):
		return
	estado.avisos_oferecidos = true
	Preferencias.notificacoes = true
	Preferencias.salvar()
	IdleAvisos.pedir_permissao()
	estado.salvar(Time.get_unix_time_from_system())


# --- avisos ---------------------------------------------------------------------

## Aviso curto no alto (piloto novo, fusão): título, linha de baixo e, se
## houver, a imagem (retrato) à esquerda.
func mostrar_aviso(titulo: String, sub := "", tex: Texture2D = null) -> void:
	if _aviso_caixa != null:
		_aviso_caixa.queue_free()
	_aviso_caixa = PanelContainer.new()
	_aviso_caixa.add_theme_stylebox_override("panel", IdleUI.caixa(Color(IdleUI.COR_CARTAO, 0.97), 16, 14, COR_OURO, 2))
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


## "BEM-VINDO DE VOLTA!": quanto a equipe faturou com o app fechado, como nos
## idles do gênero. COLETAR faz o topo contar até o novo saldo (o dinheiro já
## entrou); ▶ x2 paga de novo com o anúncio premiado.
func _bem_vindo(ganho: float) -> void:
	_dinheiro_mostrado = estado.dinheiro - ganho  # o topo só conta depois do COLETAR
	_coleta = ColorRect.new()
	(_coleta as ColorRect).color = Color(0, 0, 0, 0.72)
	_coleta.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_coleta)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coleta.add_child(centro)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(560, 0)
	p.add_theme_stylebox_override("panel", IdleUI.caixa(COR_CARTAO, 20, 24, COR_OURO, 3))
	centro.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var t := IdleUI.rotulo("BEM-VINDO DE VOLTA!", 34, Color.WHITE, v, "display")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := IdleUI.rotulo("Sua equipe faturou enquanto você estava fora", 20, IdleUI.COR_SECUNDARIA, v, "regular")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 12)
	v.add_child(linha)
	IdleUI.icone("icone_creditos", 64, linha)
	var valor := IdleUI.rotulo("$" + curto(ganho), 64, COR_DINHEIRO, linha, "display")
	valor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 12)
	v.add_child(botoes)
	var coletar := IdleUI.botao("COLETAR", COR_OURO, 26, 76, botoes)
	coletar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dobro := IdleUI.botao_premio("COLETAR x2", 26, 76, botoes)
	dobro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coletar.pressed.connect(_fechar_bem_vindo.bind(ganho))
	dobro.pressed.connect(func():
		anuncios.premiado(func():
			estado.dinheiro += ganho
			estado.salvar(Time.get_unix_time_from_system())
			_fechar_bem_vindo(ganho * 2.0)))
	Sons.tocar_ui(self, "moeda", -4.0)
	if not Preferencias.reduzir_animacoes:
		p.pivot_offset = Vector2(280, 160)
		p.scale = Vector2(0.85, 0.85)
		p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fechar_bem_vindo(total: float) -> void:
	if _coleta == null:
		return
	_coleta.queue_free()
	_coleta = null
	# Cascata: mais moedas quanto mais minutos de renda o valor vale.
	var minutos := total / maxf(estado.renda_s() * 60.0, 1.0)
	Sons.cascata(self, clampi(3 + int(log(maxf(minutos, 1.0)) / log(2.0)), 3, 12))
	celebrar(1)
	ganho_flutuante(total)


func _avisos(delta: float) -> void:
	if _aviso_t > 0.0:
		_aviso_t -= delta
		if _aviso_t <= 0.0 and _aviso_caixa != null:
			_aviso_caixa.queue_free()
			_aviso_caixa = null
	var agora := Time.get_unix_time_from_system()
	_barra.avisar("pilotos", estado.contrato_gratis_pronto(agora) or estado.piloto_escalado().is_empty())
	_barra.avisar("metas", estado.metas_prontas(agora) > 0)


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
	_linha_chave(v, "som", "MÚSICA", Preferencias.musica, func(ligado: bool):
		Preferencias.musica = ligado
		Preferencias.salvar()
		Preferencias.aplicar())
	_linha_chave(v, "som", "EFEITOS", Preferencias.volume > 0.001, func(ligado: bool):
		Preferencias.volume = 0.7 if ligado else 0.0
		Preferencias.salvar()
		Preferencias.aplicar())
	_linha_chave(v, "tela", "GRÁFICOS LEVES", Preferencias.efeitos_leves, func(ligado: bool):
		Preferencias.efeitos_leves = ligado
		Preferencias.salvar())
	if Engine.has_singleton(IdleAvisos.PLUGIN):
		_linha_chave(v, "bandeira", "AVISOS", Preferencias.notificacoes, func(ligado: bool):
			Preferencias.notificacoes = ligado
			Preferencias.salvar()
			if ligado:
				IdleAvisos.pedir_permissao())
	var nota := IdleUI.rotulo("Gráficos leves tiram sombras, fumaça e efeitos: o jogo roda melhor em celulares simples.", 17,
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
	var ic := IconeVetor.new(icone, IdleUI.COR_CROMO)
	ic.custom_minimum_size = Vector2(40, 40)
	h.add_child(ic)
	var l := IdleUI.rotulo(texto, 26, IdleUI.COR_TEXTO, h)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chave := ChaveLiga.new(ligada)
	chave.toggled.connect(func(x: bool): ao_mudar.call(x))
	h.add_child(chave)


# --- marcos e números -------------------------------------------------------------

## Comemoração de um marco, em quatro tamanhos (docs/idle/sonorizacao.md, 3.2):
## 1 coleta, 2 piloto novo/evolução/desbloqueio, 3 compra de oferta/liga nova,
## 4 modalidade nova. O som da família de recompensa, um clarão dourado e o
## aparelho vibrando, tudo do mesmo tamanho.
func celebrar(tamanho: int) -> void:
	Sons.recompensa(self, tamanho)
	var grande := tamanho >= 3
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(120 if grande else 40)
	if Preferencias.reduzir_animacoes:
		return
	var flash := ColorRect.new()
	flash.color = Color(COR_OURO, 0.35 if grande else 0.18)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.6 if grande else 0.4)
	tw.tween_callback(flash.queue_free)


## "+$X" que pipoca ao lado do dinheiro do topo (prêmio, vídeo, meta) e o
## número do topo salta.
func ganho_flutuante(valor: float) -> void:
	if valor < 1.0:
		return
	var origem := _dinheiro.get_global_rect()
	var largura := _dinheiro.get_theme_font("font").get_string_size(_dinheiro.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_dinheiro.get_theme_font_size("font_size")).x
	_efeitos.pipoca(Vector2(origem.position.x + largura + 70.0, origem.get_center().y), "+$" + curto(valor),
			COR_DINHEIRO, 34, 0.7)
	IdleUI.saltar(_dinheiro, 1.15)


## A renda por segundo pipoca de leve no topo a cada RENDA_POP_S: "+$X" sobe
## do POR SEGUNDO e o número salta (o dinheiro anda junto, sem esperar a corrida).
const RENDA_POP_S := 2.5
func _pipocar_renda(delta: float) -> void:
	if not _renda_caixa.visible or estado.renda_s() <= 0.0:
		return
	_renda_acumulada += estado.renda_s() * delta
	_renda_t += delta
	if _renda_t < RENDA_POP_S or _renda_acumulada < 1.0 or _conversa != null:
		return
	var r := _renda.get_global_rect()
	_efeitos.pipoca(Vector2(r.get_center().x, r.position.y - 6.0), "+$" + curto(_renda_acumulada),
			COR_DINHEIRO, 22, 0.25)
	IdleUI.saltar(_renda, 1.08)
	_renda_acumulada = 0.0
	_renda_t = 0.0


# --- previsão nos cartões -------------------------------------------------------------

## Chave do que muda a previsão: modalidade, liga, níveis, piloto escalado.
func _chave_previsao() -> String:
	var p := estado.piloto_escalado()
	return "%s|%d|%s|%s%s|%s" % [estado.modalidade, estado.liga, str(estado.niveis), str(p.get("nivel", 0)),
			String(p.get("id", "")), str(estado.tem("previsao"))]


## Recalcula numa thread quando a chave muda. A chegada com um nível a mais é de
## graça desde o começo; a com três níveis vem com o Analista (previsao). Na
## Arena não há previsão: a luta simulada é longa demais para isso.
func _atualizar_previsao() -> void:
	if _previsao_tarefa >= 0 and WorkerThreadPool.is_task_completed(_previsao_tarefa):
		WorkerThreadPool.wait_for_task_completion(_previsao_tarefa)
		_previsao_tarefa = -1
		_previsao_mutex.lock()
		var r := _previsao_resultado.duplicate()
		_previsao_mutex.unlock()
		if String(r.get("chave", "")) == _chave_previsao():
			_previsao = r.get("posicoes", {})
		else:
			_previsao_chave = ""  # mudou enquanto calculava: de novo
	if _na_arena:
		_previsao = {}
		_previsao_chave = _chave_previsao()
		return
	var chave := _chave_previsao()
	if chave == _previsao_chave or _previsao_tarefa >= 0:
		return
	_previsao_chave = chave
	_previsao = {}
	# Os participantes de cada variante saem aqui (lêem o estado); só a
	# simulação, que não lê nada fora dos argumentos, vai para a thread.
	var variantes := {"": estado.participantes(dados)}
	for m in estado.cfg["melhorias"]:
		var id := String(m["id"])
		if String(m["efeito"]) in EFEITOS_PREVISAO and not estado.no_maximo(id):
			for n in NIVEIS_PREVISAO:
				if n > 1 and not estado.tem("previsao"):
					continue
				var extra := mini(int(n), int(m["max"]) - estado.nivel(id))
				variantes["%s|%d" % [id, n]] = estado.participantes(dados, {id: extra})
	var pista := estado.pista(dados)
	var voltas := int(estado.dados_liga()["voltas"])
	var params: Dictionary = dados.simulacao().duplicate(true)
	_previsao_tarefa = WorkerThreadPool.add_task(_prever.bind(chave, variantes, pista, voltas, params))


func _prever(chave: String, variantes: Dictionary, pista: Pista, voltas: int, params: Dictionary) -> void:
	var posicoes := {}
	for k in variantes:
		var soma := 0.0
		for sem in SEMENTES_PREVISAO:
			soma += IdleEstado.posicao(Simulacao.correr(pista, variantes[k], voltas, params, int(sem), false))
		posicoes[k] = soma / SEMENTES_PREVISAO.size()
	_previsao_mutex.lock()
	_previsao_resultado = {"chave": chave, "posicoes": posicoes}
	_previsao_mutex.unlock()


## "5º › 4º" no cartão quando um nível a mais melhora a chegada; "+3 NÍVEIS: 4º"
## quando só três melhoram; "CHEGA EM 5º" quando nem isso muda; nada nas
## melhorias de renda e enquanto calcula.
func _texto_previsao(l: Label, m: Dictionary, base: float) -> void:
	var id := String(m["id"])
	if not _previsao.has("%s|1" % id) or not _previsao.has(""):
		l.text = ""
		return
	var antes := roundi(base)
	var com_um := roundi(float(_previsao["%s|1" % id]))
	var com_tres := roundi(float(_previsao.get("%s|3" % id, base)))
	if com_um < antes:
		l.text = "%dº › %dº" % [antes, com_um]
		l.add_theme_color_override("font_color", COR_OURO)
	elif com_tres < antes and estado.tem("previsao"):
		l.text = "+3 NÍVEIS: %dº" % com_tres
		l.add_theme_color_override("font_color", IdleUI.COR_OURO_CLARO)
	else:
		l.text = "CHEGA EM %dº" % antes
		l.add_theme_color_override("font_color", IdleUI.COR_SECUNDARIA)


func _exit_tree() -> void:
	if _previsao_tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_previsao_tarefa)


# --- o jogo que cresce com o jogador ------------------------------------------------

## Mostra só o que a equipe já tem: cartões, renda, menu de baixo, vista (pontos
## ou TV), câmeras e as ofertas guardadas.
func _aplicar_desbloqueios() -> void:
	for m in estado.cfg["melhorias"]:
		_cartoes[m["id"]]["cartao"].visible = estado.tem("melhoria:" + String(m["id"]))
	_renda_caixa.visible = estado.tem("renda")
	var abas := ABAS.filter(func(a): return a["id"] == "corrida" or estado.tem("aba:" + String(a["id"])))
	_barra.definir_abas(abas)
	_barra.visible = abas.size() > 1
	if not abas.any(func(a): return _paginas[a["id"]].visible):
		_abrir("corrida")
	_tv = estado.tem("camera_tv")
	Sons.radio(not _tv)  # antes da TV, a corrida soa como rádio de box
	_visual.pontos = not _tv
	_visual.com_rotulos = false
	_visual.visible = not _na_arena and not _tv
	_visual3d.visible = not _na_arena and _tv
	_trilho.visible = estado.tem("cameras")
	if not _trilho.visible and _camera_modo != "auto":
		_camera_modo = "auto"  # a TV: a direção escolhe o plano
		_marcar_camera()
		_diretor.reiniciar()
	_aplicar_camera()
	if _aguardando and estado.tem("largada_auto"):
		_largar_corrida()
	_atualizar_ofertas()


func _largar_corrida() -> void:
	if not _aguardando:
		return
	_aguardando = false
	_largar.visible = false
	_hud.contagem = _contagem
	_sons.largada(false)


## A próxima conversa da escada, quando nada mais está na frente e a corrida
## está parada (grid ou depois da chegada).
func _checar_conversa() -> void:
	if _conversa != null or _janela_aberta or _config != null or _coleta != null or _guia.ativo():
		return
	if not (_aguardando or _pausa >= 0.0):
		return
	# Uma conversa por corrida: duas funções novas de uma vez se atropelam.
	if estado.corridas == _conversa_em:
		return
	var d := estado.proxima_conversa()
	if d.is_empty():
		return
	_conversa_em = estado.corridas
	estado.oferecer(String(d["id"]))
	estado.salvar(Time.get_unix_time_from_system())
	_abrir_conversa(d)


func _abrir_conversa(d: Dictionary) -> void:
	_conversa = ConversaIdle.new(d, estado)
	add_child(_conversa)
	_conversa.fechou.connect(func(aceitou: bool):
		_conversa = null
		var id := String(d["id"])
		var custo := float(d.get("custo", 0.0))
		if custo > 0.0 and aceitou and estado.comprar_desbloqueio(id):
			Sons.tocar_ui(self, "moeda", -4.0)
			celebrar(3)
		elif custo <= 0.0 and not d.get("libera", []).is_empty():
			celebrar(2)
		for coisa in d.get("libera", []):
			if String(coisa).begins_with("aba:"):
				_barra.avisar(String(coisa).trim_prefix("aba:"), true)
		_aplicar_desbloqueios()
		# Tutorial leve: a dica de onde tocar (a oferta guardada, se ficou para depois).
		if estado.desbloqueio(id).is_empty() or id in estado.desbloqueados:
			var g: Dictionary = d.get("guia", {})
			if not g.is_empty():
				_guiar.call_deferred(String(g.get("alvo", "")), String(g.get("texto", "")))
		elif not "oferta" in estado.guias:
			estado.guias.append("oferta")
			_guiar.call_deferred("oferta:" + id, "A oferta fica guardada aqui. Toque quando quiser comprar.")
		estado.salvar(Time.get_unix_time_from_system()))


## As ofertas guardadas (AGORA NÃO): um botão por oferta, com o ícone, o nome e o
## preço; tocar abre a conversa de novo.
func _atualizar_ofertas() -> void:
	for c in _ofertas.get_children():
		c.queue_free()
	for d in estado.ofertas_abertas():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%s  $%s" % [String(d.get("oferta", "")), curto(float(d.get("custo", 0.0)))]
		Tipografia.rotulo(b, "semibold", IdleUI.legivel(18))
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, IdleUI.caixa(Color(IdleUI.COR_FUNDO, 0.85), 12, 8, COR_OURO, 2))
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, COR_OURO)
		b.set_meta("id", String(d["id"]))
		b.pressed.connect(func():
			if _conversa == null:
				_abrir_conversa(d))
		_ofertas.add_child(b)
		if not Preferencias.reduzir_animacoes:
			var tw := b.create_tween().set_loops()
			tw.tween_property(b, "modulate", Color(1.25, 1.25, 1.25), 0.8).set_trans(Tween.TRANS_SINE)
			tw.tween_property(b, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)


# --- som de fundo -----------------------------------------------------------------

func _fundo(nome: String, bus: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = Sons._arquivo(nome, true)
	p.bus = bus
	p.volume_db = db
	add_child(p)
	if p.stream != null:
		p.play()
	return p


## Música mais baixa sob o motor da TV; o ambiente do box só nas telas sem
## corrida. Os volumes andam devagar (sem cortes).
func _misturar(delta: float) -> void:
	var na_corrida: bool = _paginas.has("corrida") and _paginas["corrida"].visible
	var correndo := na_corrida and _tv and not _aguardando and _conversa == null
	_musica.volume_db = move_toward(_musica.volume_db, MUSICA_SOB_MOTOR_DB if correndo else MUSICA_DB, delta * 12.0)
	_ambiente.volume_db = move_toward(_ambiente.volume_db, -60.0 if na_corrida else AMBIENTE_DB, delta * 30.0)


# --- tutorial leve ------------------------------------------------------------------

## Mostra a dica do tutorial leve: o alvo destacado e a frase de onde tocar.
## Alvos: largar, subir, cameras, previsao, melhoria:<id>, aba:<id>,
## oferta:<id> ou vazio (só a frase).
func _guiar(alvo: String, texto: String) -> void:
	if alvo.begins_with("melhoria:") or alvo in ["largar", "subir", "cameras", "previsao"] or alvo.begins_with("oferta:"):
		_abrir("corrida")
	_guia.mostrar(texto, _retangulo_do_alvo.bind(alvo) if alvo != "" else Callable())


func _retangulo_do_alvo(alvo: String) -> Rect2:
	var c: Control = null
	match alvo:
		"largar":
			c = _largar
		"subir":
			c = _subir
		"cameras":
			c = _trilho
		"previsao":
			c = _cartoes["motor"]["previsao"]
	if alvo.begins_with("melhoria:"):
		c = _cartoes.get(alvo.trim_prefix("melhoria:"), {}).get("botao")
	elif alvo.begins_with("aba:"):
		return _barra.retangulo_aba(alvo.trim_prefix("aba:"))
	elif alvo.begins_with("oferta:"):
		for b in _ofertas.get_children():
			if String(b.get_meta("id", "")) == alvo.trim_prefix("oferta:"):
				c = b
	return c.get_global_rect() if c != null and c.is_visible_in_tree() else Rect2()


## Qualquer toque fecha a dica (sem segurar: o toque segue para o botão).
func _input(e: InputEvent) -> void:
	if _guia != null and _guia.ativo() and _guia.modulate.a >= 0.9:
		var toque: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
		if toque:
			_guia.limpar.call_deferred()
