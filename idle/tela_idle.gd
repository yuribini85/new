extends Control
## The Fastfather (docs/idle/plano.md): a tela do jogo idle. Abre direto
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
## corrida até o jogador pagar: a largada automática, o camarote (a corrida
## 3D), o analista (previsão nos cartões) e as câmeras.

const COR_FUNDO := IdleUI.COR_FUNDO
const CARTAO_S := 2.4  # o lugar e o ano na tela, antes da abertura (apresentação)
const COR_CARTAO := IdleUI.COR_CARTAO
const COR_DINHEIRO := IdleUI.COR_DINHEIRO
const COR_OURO := IdleUI.COR_OURO
const COR_BOTAO := IdleUI.COR_BOTAO
const COR_RUIM := IdleUI.COR_RUIM
const PAUSA_CHEGADA_S := 1.2  # ciclo sem fim (usuário, 2026-10-28): a próxima larga logo
const BEM_VINDO_MIN_S := 300.0  # menos tempo fora que isso: a renda entra sem a janela
const SALVAR_A_CADA_S := 5.0
const AVISO_S := 3.5
## Apresentação, como no Chrome & Wreckage: contagem da largada, rival colado
## que gera o aviso "SE APROXIMA" e o intervalo mínimo entre dois desses avisos.
const CONTAGEM_S := 3.0
const CONTAGEM_SEGUIDA_S := 1.0  # da segunda corrida em diante, um bipe e já larga
const APROXIMA_S := 0.6
const EVENTO_RIVAL_S := 20.0
## Pintura do seu carro: o dourado da equipe com faixas escuras e o número 1.
const EQUIPE_JOGADOR := {"numero": 1, "cores": {"faixa": "#141518", "filete": "#f2f2ee"}}
const ABAS := [
	{"id": "corrida", "nome": "CORRIDA", "icone": "carro_corrida"},
	{"id": "pistas", "nome": "PISTAS", "icone": "estrada"},
	{"id": "pilotos", "nome": "CAPANGAS", "icone": "chapeu_fedora"},
	{"id": "rinha", "nome": "RINHA", "icone": "escudo"},
	{"id": "metas", "nome": "MISSÕES", "icone": "prancheta"},
	{"id": "garagem", "nome": "GARAGEM", "icone": "garagem"},
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
## "ciclo" (o padrão, pedido do usuário em 2026-10-28) passa sozinho pelas
## outras três, uma a cada CICLO_CAMERA_S.
const CAMERAS := [["ciclo", "ciclo"], ["auto", "camera"], ["jogador", "frente"], ["geral", "pista"], ["dupla", "dupla"]]
## A câmera dupla (pedido do usuário, 2026-10-28): a oficina recolhe e a corrida
## ocupa a página, a transmissão 3D em cima e a pista inteira em 2D embaixo.
const DUPLA_3D := 0.58  # fração da altura da corrida para o 3D
const CAMERA_ARENA := {"auto": "dinamica", "jogador": "briga", "geral": "geral", "dupla": "dinamica"}
const CICLO := ["auto", "jogador", "geral"]
const CICLO_CAMERA_S := 8.0  # apresentação, não balanceamento
## Tempo da luta por segundo de tela na Arena (as lutas de dez carros são longas).
const VELOCIDADE_ARENA := 2.0

var dados: Node
var estado: IdleEstado
var anuncios: IdleAnuncios
var nuvem: NuvemIdle
var loja: LojaIdle
var _visual: CorridaVisual
var _visual3d: Corrida3D
var _arena3d: Arena3D  # a vista da modalidade Arena (a arena do Chrome & Wreckage)
var _na_arena := false
var _resultado := {}
var _semente := 1
var _pausa := -1.0  # > 0: parada depois da chegada, antes da próxima corrida
var _fim_jogador := INF
var _salvar_em := 0.0
var _camera_modo := "ciclo"
var _ciclo_i := 0  # a câmera da vez no "ciclo"
var _ciclo_troca := 0.0  # quando o "ciclo" passa para a próxima
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
var _ganho_corrida := 0.0
var _dinheiro_mostrado := 0.0  # o número do topo, que conta até o dinheiro
var _cameras := {}  # modo -> botão
var _cartoes := {}  # melhoria -> {nivel, efeito, botao}
var _barra: BarraIdle
var _paginas := {}  # aba -> Control
var _pistas: PistasIdle
var _pilotos: PilotosIdle
var _metas: MetasIdle
var _garagem: GaragemIdle  # aba GARAGEM
var _loja_abertura: GaragemIdle  # a compra do primeiro carro, depois da abertura
var _previsao := {}  # "melhoria|n" -> posição média com n níveis a mais; "" -> sem
var _previsao_chave := ""
var _previsao_tarefa := -1
## Sem threads (a versão web): a previsão anda aos poucos, umas simulações por
## quadro, em vez de travar a tela na compra (_passo_previsao).
var _previsao_aos_poucos := {}
const PREVISAO_MS_POR_QUADRO := 4
var previsao_sem_threads := not OS.has_feature("threads")  # ferramentas forçam o caminho da web
var _previsao_resultado := {}
var _previsao_mutex := Mutex.new()
var _aviso_caixa: PanelContainer
var _aviso_t := 0.0
var _coleta: Control  # "BEM-VINDO DE VOLTA!": a renda com o app fechado
var _config: Control
var _renda_caixa: Control  # "RENDA" e o valor, no topo (aparecem com o patrocínio)
var _trilho: Control  # as câmeras
var _pagina_corrida_v: VBoxContainer
var _fundo_2d: ColorRect
var _chuva_tela: Control
var _largar: Button
var _aguardando := false  # carros no grid esperando o LARGAR
var _rinha: RinhaIdle  # aba RINHA (a luta corre sempre, a aba só mostra)
var _quadro_corrida: Control  # o telão da corrida (a foto da vitória sai dele)
var _conversa: Control  # ConversaIdle, ou CenaQuadrinho nas cenas do Tony
var _ofertas: VBoxContainer  # ofertas recusadas, no canto da corrida
var _janela_aberta := false
var _tv := true  # o camarote (a corrida em 3D) já foi comprado
var _guia: GuiaIdle  # tutorial leve depois de cada função nova
var _conversa_em := -1  # corridas no total quando a última conversa abriu (uma por corrida)
var _titulo: TituloIdle  # tela de título, ao abrir o app
var _abertura: CenaQuadrinho  # a cena do chefão, do sobrinho e do Tony, no jogo novo
var _cartao_epoca: Control  # o lugar e o ano, no preto entre o título e a abertura
var _largar_na_compra := false  # depois da bronca do chefe, o 1º +1 larga a corrida
var _complexo: ScrollContainer  # os andares da equipe, abaixo da corrida
var _efeitos: EfeitosIdle  # números que pipocam e faíscas, por cima de tudo
var _renda_acumulada := 0.0  # renda desde o último "+$" que pipocou no topo
var _renda_t := 0.0
var _divisao: Label  # o objetivo da liga e a corrida, embaixo da liga
var _posicao: Label  # "5º LUGAR" na faixa da liga
var _pelotao: Control  # _Pelotao
var _volta: Label
var _premio: Label  # o prêmio da posição atual
var _ladrilhos := {}  # melhoria -> LadrilhoIdle (oficina e trapaças)
var _trapacas_caixa: Control
var _combustivel_texto: Label
var _combustivel_botao: Button
var _fiscal_texto: Label
var _fiscal_botao: Button
var _painel_lista: Control  # MELHORIAS: a lista completa por cima da tela
var _painel_trofeus: Control  # TROFÉUS: a coleção, um por pista
var _grade_trofeus: GridContainer
var _conta_trofeus: Label
var _botao_trofeus: Button
var _jornaleiro: JornaleiroIdle
var _jornaleiro_em := 0.0  # quando ele aparece de novo (relógio do app, s)
var _gorjeta := 0.0
var _multiplo := 1  # ×1, ×10, PRÓX. (-2: até o próximo marco) ou MÁX (-1) nos cartões
const PROXIMO_MARCO := -2
var _seletor := {}  # 1/10/-1 -> botão
## Segurar a corrida acelera (cfg "toque"): a carga gasta enquanto segura e
## volta sozinha.
var _toque_carga := 1.0
var _avisou_vazio := false
## O prêmio pinga durante a corrida (análise de engajamento): a corrida já está
## resolvida na largada, então a parte do prêmio da chegada entra conforme o
## carro anda; na chegada entra só o que falta. O total não muda.
var _pago_corrida := 0.0
## Câmera lenta curta nos momentos fortes (golpes visuais): até quando (s do
## relógio) a corrida anda devagar.
var _lento_ate := 0.0
var _ja_correu := false  # nesta abertura do app: as seguintes largam com um bipe só
const LENTO_S := 0.5
const LENTO_VELOCIDADE := 0.3
var _pingado := 0.0  # pingado desde o último "+$" do caixa
var _segurando := false
var _toque_medidor: Control  # _MedidorToque
var _bandeira: BandeiraIdle
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
	ObjetosArena.epoca = true  # a Rinha com fardos, cavaletes e barris de madeira
	# Fotos das pistas e ícones da época, quando existirem (docs/idle/pedido_arte.md).
	Aba.pastas_antes = ["res://arte/fastfather/pistas/", "res://arte/fastfather/icones/"]
	Sons.barramentos()
	Preferencias.carregar()
	Preferencias.aplicar()
	estado = IdleEstado.carregar()
	anuncios = IdleAnuncios.new()
	anuncios.intersticial_min_s = float(estado.cfg.get("intersticial_min_s", 90.0))
	anuncios.config = estado.cfg.get("admob", {})
	add_child(anuncios)
	nuvem = NuvemIdle.new()
	nuvem.config = estado.cfg.get("play_games", {})
	add_child(nuvem)
	nuvem.achou.connect(_nuvem_achou)
	nuvem.iniciar(estado.progresso())
	loja = LojaIdle.new()
	loja.skus = PackedStringArray([String(estado.cfg.get("fundadora", {}).get("sku", ""))])
	loja.concedido.connect(_comprou)
	add_child(loja)
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
	_titulo = TituloIdle.new()
	add_child(_titulo)
	_titulo.saindo.connect(_saindo_do_titulo)
	_titulo.fechou.connect(_depois_do_titulo)


## Jogo novo: a abertura com o Sal (no lugar das conversas "rival" e "inicio").
func _precisa_abertura() -> bool:
	return estado.corridas == 0 and not "rival" in estado.oferecidos and not estado.desbloqueio("rival").is_empty()


## Jogo novo: o título some para o preto, entra o cartão com o lugar e o ano
## (cenas.json → abertura → "cartao") e a cena do chefão sobe do preto. O
## cartão entra por baixo do título enquanto ele some, e o preto dele fica
## atrás da cena até ela fechar: a corrida atrás nunca aparece na passagem.
func _saindo_do_titulo() -> void:
	if not _precisa_abertura() or _abertura != null:
		return
	_abertura = CenaQuadrinho.new("abertura")
	_abertura.fechou.connect(_fim_da_abertura)
	_cartao_epoca = _cartao_de_epoca()
	add_child(_cartao_epoca)
	if _titulo != null:
		move_child(_cartao_epoca, _titulo.get_index())


func _cartao_de_epoca() -> Control:
	var c := ColorRect.new()
	c.color = Color.BLACK
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.modulate.a = 0.0
	c.add_child(v)
	var dados: Dictionary = CenaQuadrinho.carregar("abertura").get("cartao", {})
	var lugar := IdleUI.rotulo(String(dados.get("lugar", "")).to_upper(), 30, IdleUI.COR_CROMO, v, "deco")
	lugar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var traco := ColorRect.new()
	traco.color = MolduraDeco.LATAO
	traco.custom_minimum_size = Vector2(220, 3)
	traco.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(traco)
	var ano := IdleUI.rotulo(String(dados.get("ano", "")), 96, IdleUI.COR_OURO_CLARO, v, "deco")
	ano.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var r := 0.0 if Preferencias.reduzir_animacoes else 1.0
	var tw := c.create_tween()
	tw.tween_interval(0.5 * r)  # o preto do título, um respiro antes
	tw.tween_property(v, "modulate:a", 1.0, 0.9 * r + 0.01)
	tw.tween_interval(CARTAO_S)
	tw.tween_property(v, "modulate:a", 0.0, 0.7 * r + 0.01)
	tw.tween_interval(0.3 * r)
	tw.tween_callback(_cena_da_abertura)
	# Um toque passa o cartão.
	c.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed and tw.is_valid():
			tw.kill()
			v.modulate.a = 0.0
			_cena_da_abertura())
	return c


## A cidade `n` do prestígio (cenas.json → cidades): {lugar, ano}. Depois da
## última, a última com o ano seguinte.
static func cidade(n: int) -> Dictionary:
	var lista: Array = CenaQuadrinho.carregar("cidades").get("lista", [])
	if lista.is_empty():
		return {"lugar": "", "ano": ""}
	if n < lista.size():
		return lista[n]
	var ultima: Dictionary = lista[-1]
	return {"lugar": ultima["lugar"], "ano": str(int(ultima["ano"]) + n - lista.size() + 1)}


## Muda a família de cidade (prestígio): o cartão de época da cidade nova no
## preto e a corrida recomeça na primeira liga.
func mudar_de_cidade() -> void:
	if not estado.mudar_de_cidade():
		return
	estado.salvar(Time.get_unix_time_from_system())
	Sons.tocar_ui(self, "sino", -4.0, 0.9, false)
	_abrir("corrida")
	_nova_corrida()
	_atualizar_cartoes()
	var dados := cidade(estado.cidade)
	var c := ColorRect.new()
	c.color = Color.BLACK
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.z_index = 20
	add_child(c)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.add_theme_constant_override("separation", 14)
	c.add_child(v)
	var lugar := IdleUI.rotulo(String(dados["lugar"]).to_upper(), 30, IdleUI.COR_CROMO, v, "deco")
	lugar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var traco := ColorRect.new()
	traco.color = MolduraDeco.LATAO
	traco.custom_minimum_size = Vector2(220, 3)
	traco.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(traco)
	var ano := IdleUI.rotulo(String(dados["ano"]), 96, IdleUI.COR_OURO_CLARO, v, "deco")
	ano.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mult := IdleUI.rotulo("LUCRO E PRÊMIOS ×%s" % IdleUI.curto(estado.multiplicador_cidade()), 28, IdleUI.COR_GANHO, v, "display")
	mult.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var r := 0.0 if Preferencias.reduzir_animacoes else 1.0
	var tw := c.create_tween()
	tw.tween_interval(CARTAO_S + 0.6)
	tw.tween_property(c, "modulate:a", 0.0, 0.8 * r + 0.01)
	tw.tween_callback(c.queue_free)


## Depois do cartão: a cena por cima do preto (ela sobe em fade, ver cenas.json).
func _cena_da_abertura() -> void:
	if _abertura == null or _abertura.is_inside_tree():
		return
	_cartao_epoca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_abertura)
	move_child(_abertura, _cartao_epoca.get_index() + 1)
	_abertura.fechou.connect(func():
		if _cartao_epoca != null:
			_cartao_epoca.queue_free()
			_cartao_epoca = null)


func _depois_do_titulo() -> void:
	_titulo = null
	_saindo_do_titulo()


## Fim da abertura: corte seco para a primeira corrida, que larga sozinha
## (briefing: a corrida começa em até 15 s, sem o jogador conduzir).
func _fim_da_abertura() -> void:
	_abertura = null
	# Primeiro a garagem: o carro do sobrinho, comprado com o dinheiro do chefe.
	if not estado.pode_correr():
		_loja_abertura = GaragemIdle.new(estado, COR_OURO, PinturaCarro.da_equipe(EQUIPE_JOGADOR, "crt", 0), true)
		add_child(_loja_abertura)
		_loja_abertura.comprou.connect(func(_id: String):
			_atualizar_dinheiro_garagem()
			var tw := _loja_abertura.create_tween()
			tw.tween_interval(0.0 if Preferencias.reduzir_animacoes else 0.6)
			tw.tween_property(_loja_abertura, "modulate:a", 0.0, 0.0 if Preferencias.reduzir_animacoes else 0.25)
			tw.tween_callback(func():
				_loja_abertura.queue_free()
				_loja_abertura = null
				_fim_da_abertura()))
		return
	if not "rival" in estado.oferecidos:
		estado.oferecer("rival")
	_aplicar_desbloqueios()
	_largar_corrida()
	estado.salvar(Time.get_unix_time_from_system())


## Fecha a tela de título e pula a abertura, sem animação (ferramentas de fotos
## e testes; a abertura conta como vista).
func pular_titulo() -> void:
	if _titulo != null:
		_titulo.queue_free()
		_titulo = null
	if _abertura != null:
		_abertura.queue_free()
		_abertura = null
	if _cartao_epoca != null:
		_cartao_epoca.queue_free()
		_cartao_epoca = null
	if _precisa_abertura():
		_fim_da_abertura()
	if _loja_abertura != null:
		# Ferramentas: o primeiro carro comprado direto.
		estado.comprar_carro(String(estado.carro_da_modalidade()["id"]))
		_loja_abertura.queue_free()
		_loja_abertura = null
		_fim_da_abertura()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if estado != null:
			estado.salvar(Time.get_unix_time_from_system())
			nuvem.enviar(estado, true)
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
			if estado.pode_correr():
				_abrir("corrida")
			else:
				_garagem.mostrar_divisao()
				_abrir("garagem"))
	_paginas["pistas"] = _pistas
	_pilotos = PilotosIdle.new(self)
	_pilotos.mudou.connect(func(): estado.salvar(Time.get_unix_time_from_system()))
	_paginas["pilotos"] = _pilotos
	# A Rinha: luta sozinha ao lado da corrida; a aba só mostra.
	_rinha = RinhaIdle.new(self)
	_rinha.terminou.connect(_rinha_terminou)
	_paginas["rinha"] = _rinha
	_metas = MetasIdle.new(self)
	_metas.mudou.connect(func(): estado.salvar(Time.get_unix_time_from_system()))
	_paginas["metas"] = _metas
	_garagem = GaragemIdle.new(estado, COR_OURO, PinturaCarro.da_equipe(EQUIPE_JOGADOR, "crt", 0))
	_garagem.abrir_trofeus.connect(func(): _trofeus_abertos(true))
	_garagem.comprou.connect(func(_id: String):
		_atualizar_dinheiro_garagem()
		estado.salvar(Time.get_unix_time_from_system())
		# Comprou o carro da divisão na tela: a corrida que esperava larga.
		if estado.pode_correr() and _aguardando and estado.tem("largada_auto"):
			_abrir("corrida")
			_largar_corrida())
	_garagem.correr.connect(func(id: String):
		if estado.trocar_modalidade(String(estado.carro_garagem(id)["modalidade"])):
			_nova_corrida()
			_abrir("corrida"))
	_paginas["garagem"] = _garagem
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


## Faixa do alto (layout do usuário, 2026-10-27): o maço de notas e o CAIXA DA
## FAMÍLIA, o LUCRO POR SEGUNDO em verde e a engrenagem.
func _topo(pai: Control) -> void:
	var placa := PanelContainer.new()
	placa.add_theme_stylebox_override("panel", IdleUI.caixa(IdleUI.COR_CARVAO, 6, 6, IdleUI.COR_BORDA, 1))
	pai.add_child(placa)
	_banner = TextureRect.new()  # o banner da pista fica na faixa da liga (abaixo)
	_banner.visible = false
	placa.add_child(_banner)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 12)
	placa.add_child(topo)
	var notas := TextureRect.new()  # o maço de notas (ícone do HUD)
	notas.texture = IdleUI.icone_hud("notas")
	notas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	notas.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	notas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notas.custom_minimum_size = Vector2(76, 64)
	notas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(notas)
	_maco = notas
	var esq := VBoxContainer.new()
	esq.add_theme_constant_override("separation", 0)
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(esq)
	IdleUI.rotulo("CAIXA DA FAMÍLIA", 17, IdleUI.COR_CROMO, esq)
	# Dinheiro em letreiro art déco (cartaz e nota de banco dos anos 1930).
	_dinheiro = IdleUI.rotulo("", 40, IdleUI.COR_OURO_CLARO, esq, "deco")
	var dir := VBoxContainer.new()
	dir.add_theme_constant_override("separation", 0)
	dir.alignment = BoxContainer.ALIGNMENT_CENTER
	topo.add_child(dir)
	_renda_caixa = dir
	IdleUI.rotulo("LUCRO POR SEGUNDO", 17, IdleUI.COR_CROMO, dir)
	_renda = IdleUI.rotulo("", 34, IdleUI.COR_GANHO, dir, "display")
	var eng := Button.new()
	eng.flat = true
	eng.focus_mode = Control.FOCUS_NONE
	eng.custom_minimum_size = Vector2(64, 64)
	eng.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := TextureRect.new()  # a engrenagem (ícone do HUD)
	ic.texture = IdleUI.icone_hud("engrenagem")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 8
	ic.offset_right = -8
	ic.offset_top = 8
	ic.offset_bottom = -8
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eng.add_child(ic)
	eng.pressed.connect(_abrir_config)
	topo.add_child(eng)


## A tela CORRIDA (layout do usuário, 2026-10-27): a faixa da liga com a
## posição e a volta, a corrida 3D, o prêmio da corrida com o andamento e o
## objetivo, a Oficina do Tony (melhorias do carro e da renda, e o combustível
## adulterado por vídeo) e as Trapaças da família. MELHORIAS abre a lista
## completa (os andares, com +10 e MÁX.).
func _pagina_corrida() -> Control:
	var v := VBoxContainer.new()
	_pagina_corrida_v = v
	v.add_theme_constant_override("separation", 8)
	var corrida := Control.new()
	_quadro_corrida = corrida
	corrida.custom_minimum_size = Vector2(0, 420)
	corrida.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corrida.clip_contents = true
	v.add_child(corrida)
	_fundo_2d = ColorRect.new()  # a "segunda tela" da câmera dupla
	_fundo_2d.color = IdleUI.COR_CARVAO
	_fundo_2d.visible = false
	_fundo_2d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corrida.add_child(_fundo_2d)
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
	_chuva_tela = _Chuva.new()  # a chuva na frente da lente (o 3D chove junto, mais fino)
	_chuva_tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chuva_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chuva_tela.visible = false
	corrida.add_child(_chuva_tela)
	_hud = HudCorrida.new()
	_hud.sem_volta = true
	_hud.sem_banda = true  # a posição e a volta estão na faixa da liga
	_hud.sem_semaforo = true  # a bandeira do fiscal no lugar do semáforo
	_hud.escala_texto = 1.3  # texto legível no celular (docs/idle/interface.md)
	_hud.peso_numero = "deco"
	corrida.add_child(_hud)
	_sons = Sons.new()
	add_child(_sons)
	# Trilha da época: jazz de 1924 em domínio público (arte/sons/LICENCA.md),
	# uma faixa depois da outra.
	_musica = _fundo(MUSICAS[0], "Musica", MUSICA_DB)
	if _musica.stream is AudioStreamOggVorbis:
		(_musica.stream as AudioStreamOggVorbis).loop = false
	_musica.finished.connect(_proxima_musica)
	_ambiente = _fundo("oficina", "Ambiente", -60.0)
	# Câmeras: três ícones num trilho escuro, a ativa em ocre.
	var trilho := PanelContainer.new()
	trilho.add_theme_stylebox_override("panel", IdleUI.caixa(Color(IdleUI.COR_FUNDO, 0.7), 14, 4, IdleUI.COR_BORDA, 1))
	trilho.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	trilho.offset_left = 10
	trilho.offset_bottom = -112  # acima da faixa do prêmio
	trilho.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corrida.add_child(trilho)
	_trilho = trilho
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	trilho.add_child(h)
	for par in CAMERAS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(58, 56)
		# Ícones da arte do usuário (arte/fastfather/icones/cameras), em tom só:
		# a cor vem do modulate (tinta no ativo, ouro na câmera da vez).
		var ic := TextureRect.new()
		var arte := "res://arte/fastfather/icones/cameras/%s.png" % par[0]
		ic.texture = load(arte) if ResourceLoader.exists(arte) else IdleUI.icone_hud("mapa")
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 12
		ic.offset_right = -12
		ic.offset_top = 8
		ic.offset_bottom = -8
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
	_subir.offset_top = -270
	_subir.offset_bottom = -182
	_subir.pressed.connect(_subir_liga)
	corrida.add_child(_subir)
	# LARGAR: até a largada automática, cada corrida começa no toque.
	_largar = BotaoInicio.new("Largar", true, COR_BOTAO, 40, 88, 320)
	_largar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_largar.offset_left = -160
	_largar.offset_right = 160
	_largar.offset_top = -218
	_largar.offset_bottom = -130
	_largar.visible = false
	_largar.pressed.connect(_largar_corrida)
	corrida.add_child(_largar)
	# Ofertas que o jogador deixou para depois, no canto de cima à direita.
	_ofertas = VBoxContainer.new()
	_ofertas.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_ofertas.offset_right = -10
	_ofertas.offset_top = 104  # abaixo da faixa da liga
	_ofertas.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ofertas.add_theme_constant_override("separation", 8)
	corrida.add_child(_ofertas)
	# As faixas da liga e do prêmio por cima da corrida, com fundo translúcido
	# (a corrida vai do cabeçalho até a oficina).
	var em_cima := _faixa_liga(corrida)
	em_cima.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var embaixo := _faixa_premio(corrida)
	embaixo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	embaixo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Segurar a corrida acelera: o velocímetro no canto de baixo, à direita,
	# logo acima da faixa do prêmio (pedido do usuário, 2026-10-28).
	_toque_medidor = _MedidorToque.new()
	_toque_medidor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_toque_medidor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var encaixar := func():
		var lado := _MedidorToque.LADO
		var base := 8.0  # no canto direito da faixa do prêmio (as câmeras foram para o centro)
		_toque_medidor.offset_left = -lado - 14.0
		_toque_medidor.offset_right = -14.0
		_toque_medidor.offset_top = -base - lado
		_toque_medidor.offset_bottom = -base
	embaixo.resized.connect(encaixar)
	encaixar.call()
	corrida.add_child(_toque_medidor)
	corrida.gui_input.connect(_toque_corrida)
	# A bandeira do fiscal: verde na largada, quadriculada na chegada.
	_bandeira = BandeiraIdle.new()
	_bandeira.position = Vector2(20, 150)
	corrida.add_child(_bandeira)
	# Por baixo das faixas e do painel.
	corrida.move_child(_bandeira, _hud.get_index())
	# O menino jornaleiro sobe de trás da faixa do prêmio, à esquerda. O corte
	# dele fica no pé da corrida, escondido pela Oficina (opaca) logo abaixo:
	# pela faixa translúcida ele aparece inteiro, nunca cortado.
	_jornaleiro = JornaleiroIdle.new()
	_jornaleiro.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	corrida.add_child(_jornaleiro)
	corrida.move_child(_jornaleiro, _bandeira.get_index())
	_jornaleiro.tocado.connect(_pagar_jornaleiro)
	var tam_j := _jornaleiro.custom_minimum_size
	_jornaleiro.offset_left = 0.0
	_jornaleiro.offset_right = tam_j.x
	_jornaleiro.offset_bottom = 0.0
	_jornaleiro.offset_top = -tam_j.y
	_oficina(v)
	_trapacas(v)
	_lista_melhorias()
	_tela_trofeus()
	return v


## Liga e divisão à esquerda; a posição com os pontos do pelotão e a volta à
## direita.
func _faixa_liga(pai: Control) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", IdleUI.caixa(Color(IdleUI.COR_CARVAO, 0.62), 0, 8))
	pai.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var esq := VBoxContainer.new()
	esq.add_theme_constant_override("separation", 0)
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esq.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(esq)
	var l1 := HBoxContainer.new()
	l1.add_theme_constant_override("separation", 6)
	esq.add_child(l1)
	_icone_mod = TextureRect.new()  # sem ícone pequeno na faixa (pedido do usuário)
	_icone_mod.visible = false
	l1.add_child(_icone_mod)
	_liga = IdleUI.rotulo("", 24, IdleUI.COR_TEXTO, l1, "display")
	_liga.clip_text = true
	_liga.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_divisao = IdleUI.rotulo("", 18, IdleUI.COR_CROMO, esq)
	_divisao.clip_text = true
	var pos := MarginContainer.new()  # sem placa atrás da posição e da volta
	h.add_child(pos)
	var hp := HBoxContainer.new()
	hp.add_theme_constant_override("separation", 10)
	pos.add_child(hp)
	var vp := VBoxContainer.new()
	vp.add_theme_constant_override("separation", 0)
	hp.add_child(vp)
	_posicao = IdleUI.rotulo("", 30, IdleUI.COR_TEXTO, vp, "display")
	_pelotao = _Pelotao.new()
	_pelotao.custom_minimum_size = Vector2(150, 14)
	vp.add_child(_pelotao)
	var sep := ColorRect.new()
	sep.color = IdleUI.COR_BORDA
	sep.custom_minimum_size = Vector2(2, 0)
	hp.add_child(sep)
	var vv := VBoxContainer.new()
	vv.add_theme_constant_override("separation", 0)
	vv.alignment = BoxContainer.ALIGNMENT_CENTER
	hp.add_child(vv)
	IdleUI.rotulo("VOLTA", 15, IdleUI.COR_CROMO, vv).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_volta = IdleUI.rotulo("", 26, IdleUI.COR_TEXTO, vv, "display")
	_volta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return p


## O prêmio da posição em que o carro está, o andamento da corrida (com o
## objetivo da liga em cima) e a melhor chegada na liga.
func _faixa_premio(pai: Control) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", IdleUI.caixa(Color(IdleUI.COR_CARVAO, 0.62), 0, 8))
	pai.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var esq := VBoxContainer.new()
	esq.add_theme_constant_override("separation", 0)
	h.add_child(esq)
	IdleUI.rotulo("PRÊMIO ATUAL", 16, IdleUI.COR_CROMO, esq)
	_premio = IdleUI.rotulo("", 36, IdleUI.COR_NEON, esq, "deco")
	# As câmeras no centro da faixa (pedido do usuário, 2026-10-28), por cima
	# dela; o velocímetro desce para o canto direito da faixa.
	_trilho.get_parent().remove_child(_trilho)
	pai.add_child(_trilho)
	_trilho.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_trilho.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_trilho.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var centrar := func():
		var alto := _trilho.get_combined_minimum_size().y
		_trilho.offset_bottom = -(p.size.y - alto) * 0.5
		_trilho.offset_top = _trilho.offset_bottom - alto
		_trilho.offset_left = -_trilho.get_combined_minimum_size().x * 0.5
		_trilho.offset_right = -_trilho.offset_left
	p.resized.connect(centrar)
	centrar.call()
	return p


## A Oficina do Tony: o Tony com a fala, MELHORIAS (a lista completa) e os
## cartões das melhorias que não são trapaça, rolando de lado, com o
## combustível adulterado fixo à direita.
func _oficina(pai: Control) -> void:
	var p := PanelContainer.new()
	_painel_oficina = p
	p.add_theme_stylebox_override("panel", IdleUI.caixa(IdleUI.COR_CARVAO, 6, 8, IdleUI.COR_BORDA, 1))
	pai.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 10)
	v.add_child(cab)
	var linha := HBoxContainer.new()
	cab.add_child(linha)
	linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := IdleUI.rotulo("OFICINA DO TONY", 26, IdleUI.COR_TEXTO, linha, "display")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var lista := Button.new()
	lista.focus_mode = Control.FOCUS_NONE
	lista.text = "TROFÉUS"
	_botao_trofeus = lista
	lista.custom_minimum_size = Vector2(150, 48)  # depois, a largura do combustível
	lista.add_theme_font_override("font", Tipografia.fonte("display"))
	lista.add_theme_font_size_override("font_size", 24)
	for e in ["normal", "hover", "focus"]:
		lista.add_theme_stylebox_override(e, IdleUI.caixa(IdleUI.COR_CARTAO, 5, 6, IdleUI.COR_OURO_ESCURO, 1))
	lista.add_theme_stylebox_override("pressed", IdleUI.caixa(IdleUI.COR_PETROLEO, 5, 6, IdleUI.COR_OURO_ESCURO, 1))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		lista.add_theme_color_override(c, IdleUI.COR_OURO)
	lista.pressed.connect(func(): _trofeus_abertos(true))
	# Quanto cada toque compra: ×1, ×10, PRÓX. (até o próximo marco) ou MÁX
	# (como nos idles de referência: x1, x10, Next, Max).
	var sel := HBoxContainer.new()
	sel.add_theme_constant_override("separation", 0)
	linha.add_child(sel)
	for par in [[1, "×1"], [10, "×10"], [PROXIMO_MARCO, "PRÓX."], [-1, "MÁX"]]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = String(par[1])
		b.custom_minimum_size = Vector2(60, 48)
		b.add_theme_font_override("font", Tipografia.fonte("display"))
		b.add_theme_font_size_override("font_size", 24)
		var q: int = par[0]
		b.pressed.connect(func():
			_multiplo = q
			_marcar_seletor()
			_atualizar_cartoes())
		sel.add_child(b)
		_seletor[q] = b
	_marcar_seletor()
	var vao_sel := Control.new()
	vao_sel.custom_minimum_size = Vector2(10, 0)
	linha.add_child(vao_sel)
	linha.add_child(lista)
	var linha_cartoes := HBoxContainer.new()
	linha_cartoes.add_theme_constant_override("separation", 8)
	v.add_child(linha_cartoes)
	var rolo := ScrollContainer.new()
	rolo.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolo.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	rolo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolo.custom_minimum_size = Vector2(0, 152)
	linha_cartoes.add_child(rolo)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL  # cartões da altura da linha (a do combustível)
	rolo.add_child(fila)
	for m in estado.cfg["melhorias"]:
		if m.has("trapaca"):
			continue
		var l := LadrilhoIdle.new(String(m["id"]), String(m.get("icone", "icone_melhorar")), String(m["nome"]))
		l.custom_minimum_size = Vector2(168, 0)
		l.size_flags_horizontal = Control.SIZE_FILL
		var id := String(m["id"])
		l.comprar.connect(func(): _comprar(id, _multiplo))
		fila.add_child(l)
		_ladrilhos[id] = l
	# Três cartões inteiros na faixa (o terceiro não fica cortado rente ao
	# combustível); com mais, a faixa rola.
	var ajustar := func():
		var n := mini(fila.get_children().filter(func(c): return c.visible).size(), 3)
		if n <= 0 or rolo.size.x <= 0.0:
			return
		var w := floorf((rolo.size.x - 8.0 * (n - 1)) / n)
		for c in fila.get_children():
			(c as Control).custom_minimum_size.x = w
	rolo.resized.connect(ajustar)
	for c in fila.get_children():
		c.visibility_changed.connect(ajustar)
	_combustivel_cartao(linha_cartoes)


## Combustível adulterado: um vídeo dá potência a mais por um tempo, com usos
## por dia (idle.json → "combustivel").
func _combustivel_cartao(pai: Control) -> void:
	var r := _cartao_por_video(pai, "COMBUSTÍVEL\nADULTERADO")
	# O TROFÉUS, no alto da oficina, com a largura deste cartão.
	var cartao: Control = r[1].get_parent().get_parent()
	cartao.resized.connect(func():
		if _botao_trofeus != null:
			_botao_trofeus.custom_minimum_size.x = cartao.size.x)
	_combustivel_texto = r[0]
	_combustivel_botao = r[1]
	_combustivel_botao.pressed.connect(_usar_combustivel)


## Cartão de bônus por vídeo (combustível, fiscal): o nome, uma linha de
## situação e o botão USAR no pé. Devolve [situação, botão].
func _cartao_por_video(pai: Control, nome: String, cor_nome := IdleUI.COR_TEXTO) -> Array:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", IdleUI.caixa(LadrilhoIdle.FUNDO, 6, 8, IdleUI.COR_BORDA, 1))
	c.custom_minimum_size = Vector2(150, 0)
	pai.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	c.add_child(v)
	var n := IdleUI.rotulo(nome, 17, cor_nome, v, "display")
	n.add_theme_constant_override("line_spacing", -6)
	var texto := IdleUI.rotulo("", 15, IdleUI.COR_CROMO, v)
	texto.clip_text = true
	var vao := Control.new()  # o botão no pé, alinhado com os das melhorias
	vao.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(vao)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_override("font", Tipografia.fonte("display"))
	b.add_theme_font_size_override("font_size", 24)
	for e in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(e, IdleUI.brilho(IdleUI.caixa(IdleUI.COR_NEON, 5, 4, IdleUI.COR_NEON_ESCURO, 1), IdleUI.COR_NEON))
	b.add_theme_stylebox_override("pressed", IdleUI.caixa(IdleUI.COR_NEON.darkened(0.15), 5, 4, IdleUI.COR_NEON_ESCURO, 1))
	b.add_theme_stylebox_override("disabled", IdleUI.caixa(LadrilhoIdle.DESLIGADO, 5, 4, LadrilhoIdle.DESLIGADO_BORDA, 1))
	for c2 in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c2, IdleUI.COR_TINTA)
	b.add_theme_color_override("font_disabled_color", IdleUI.COR_BLOQUEADO.lightened(0.25))
	v.add_child(b)
	return [texto, b]


func _usar_combustivel() -> void:
	var dia := Time.get_date_string_from_system()
	if estado.combustivel_restantes(dia) <= 0:
		return
	anuncios.premiado(func():
		if estado.usar_combustivel(Time.get_unix_time_from_system(), dia):
			_hud.evento("COMBUSTÍVEL ADULTERADO!", "+%d%% de potência" % roundi(estado.bonus_combustivel() * 100.0),
					COR_OURO, 11, -1.0, true)
			celebrar(2)
			estado.salvar(Time.get_unix_time_from_system()))


## Fiscal comprado: um vídeo e o fiscal fecha os olhos por um tempo (idle.json → "fiscal").
func _usar_fiscal() -> void:
	var dia := Time.get_date_string_from_system()
	if estado.fiscal_restantes(dia) <= 0:
		return
	anuncios.premiado(func():
		if estado.usar_fiscal(Time.get_unix_time_from_system(), dia):
			var f := estado.cfg_fiscal()
			_hud.evento("FISCAL COMPRADO!", MetasIdle.texto_bonus(String(f.get("efeito", "")), float(f.get("bonus", 0.0))).to_lower(),
					IdleUI.COR_VINHO_CLARO, 11, -1.0, true)
			celebrar(2)
			estado.salvar(Time.get_unix_time_from_system()))


func _atualizar_fiscal() -> void:
	if _fiscal_botao == null:
		return
	var agora := Time.get_unix_time_from_system()
	var f := estado.cfg_fiscal()
	var restam := estado.fiscal_restantes(Time.get_date_string_from_system())
	if estado.fiscal_ativo(agora):
		_fiscal_texto.text = "Comprado: %s" % IdleUI.relogio(estado.fiscal_ate - agora)
	else:
		_fiscal_texto.text = "%s·%dmin" % [MetasIdle.texto_bonus(String(f.get("efeito", "")), float(f.get("bonus", 0.0))).split(" ")[-1],
				roundi(float(f.get("duracao_s", 0.0)) / 60.0)]
	_fiscal_botao.text = "USAR %d/%d" % [restam, int(f.get("usos_dia", 0))] if restam > 0 else "AMANHÃ"
	_fiscal_botao.disabled = restam <= 0


## As Trapaças da família: as melhorias marcadas "trapaca" em idle.json (com o
## nome e o que fazem); cada uma só aparece quando abre.
func _trapacas(pai: Control) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pai.add_child(v)
	_trapacas_caixa = v
	IdleUI.rotulo("TRAPAÇAS DA FAMÍLIA", 20, IdleUI.COR_VINHO_CLARO, v, "display")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	for m in estado.cfg["melhorias"]:
		if not m.has("trapaca"):
			continue
		var t: Dictionary = m["trapaca"]
		var id := String(m["id"])
		var l := LadrilhoIdle.new(id, String(t.get("icone", m.get("icone", ""))), String(t["nome"]), true)
		l.comprar.connect(func(): _comprar(id, _multiplo))
		h.add_child(l)
		_ladrilhos[id] = l
	if not estado.cfg_fiscal().is_empty():
		var r := _cartao_por_video(h, String(estado.cfg_fiscal().get("nome", "Fiscal comprado")).to_upper().replace(" ", "\n"),
				IdleUI.COR_VINHO_CLARO)
		_fiscal_texto = r[0]
		_fiscal_botao = r[1]
		_fiscal_botao.pressed.connect(_usar_fiscal)


## A lista completa de melhorias (os andares, com +10 e MÁX.), por cima da
## tela, aberta pelo MELHORIAS da oficina.
func _lista_melhorias() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(IdleUI.COR_CARVAO, 0.97)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.visible = false
	fundo.z_index = 5
	add_child(fundo)
	_painel_lista = fundo
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", int(AreaSegura.topo(720.0)) + 16)
	m.add_theme_constant_override("margin_bottom", int(AreaSegura.base(720.0)) + 16)
	fundo.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	var cab := HBoxContainer.new()
	v.add_child(cab)
	var t := IdleUI.rotulo("MELHORIAS", 34, IdleUI.COR_OURO_CLARO, cab, "deco")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fechar := IdleUI.botao("FECHAR", IdleUI.COR_OURO, 22, 64, cab)
	fechar.custom_minimum_size.x = 160
	fechar.pressed.connect(func(): _lista_aberta(false))
	_complexo = ScrollContainer.new()
	_complexo.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_complexo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	IdleUI.rolagem_fina(_complexo)
	v.add_child(_complexo)
	var andares := VBoxContainer.new()
	andares.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	andares.add_theme_constant_override("separation", 6)
	_complexo.add_child(andares)
	for mm in estado.cfg["melhorias"]:
		andares.add_child(_cartao(mm))


## TROFÉUS (pedido do usuário, 2026-10-28): a coleção, um por pista, ganho na
## primeira vitória nela. Os ainda não ganhos ficam em sombra preta e o bônus só
## aparece depois de ganhar.
func _tela_trofeus() -> void:
	var fundo := ColorRect.new()
	fundo.color = IdleUI.COR_CARVAO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.visible = false
	fundo.z_index = 5
	add_child(fundo)
	_painel_trofeus = fundo
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", int(AreaSegura.topo(720.0)) + 16)
	m.add_theme_constant_override("margin_bottom", int(AreaSegura.base(720.0)) + 16)
	fundo.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	var cab := HBoxContainer.new()
	v.add_child(cab)
	var t := IdleUI.rotulo("TROFÉUS", 34, IdleUI.COR_OURO_CLARO, cab, "deco")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fechar := IdleUI.botao("FECHAR", IdleUI.COR_OURO, 22, 64, cab)
	fechar.custom_minimum_size.x = 160
	fechar.pressed.connect(func(): _trofeus_abertos(false))
	_conta_trofeus = IdleUI.rotulo("", 24, IdleUI.COR_CROMO, v)
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	IdleUI.rolagem_fina(rolagem)
	v.add_child(rolagem)
	_grade_trofeus = GridContainer.new()
	_grade_trofeus.columns = 3
	_grade_trofeus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grade_trofeus.add_theme_constant_override("h_separation", 8)
	_grade_trofeus.add_theme_constant_override("v_separation", 8)
	rolagem.add_child(_grade_trofeus)


func _trofeus_abertos(sim: bool) -> void:
	_painel_trofeus.visible = sim
	if not sim:
		return
	for c in _grade_trofeus.get_children():
		c.queue_free()
	var lista := estado.lista_trofeus()
	var ganhos := 0
	for tr in lista:
		var ganho: bool = String(tr["pista"]) in estado.trofeus
		ganhos += 1 if ganho else 0
		var cartao := _cartao_trofeu(tr, ganho)
		_grade_trofeus.add_child(cartao)
		if ganho and String(tr["pista"]) == _trofeu_recente:
			_girar_trofeu.call_deferred(cartao)
	_conta_trofeus.text = "%d DE %d CONQUISTADOS" % [ganhos, lista.size()]


const LARGURA_TEXTO_TROFEU := 196.0  # três cartões lado a lado em 720 px


func _cartao_trofeu(tr: Dictionary, ganho: bool) -> Control:
	var c := PanelContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_stylebox_override("panel", IdleUI.caixa(IdleUI.COR_CARTAO if ganho else LadrilhoIdle.FUNDO_FECHADO, 6, 8,
			IdleUI.COR_OURO_ESCURO if ganho else LadrilhoIdle.DESLIGADO, 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	c.add_child(v)
	var img := TextureRect.new()
	img.texture = load("res://arte/fastfather/trofeus/trofeu_%02d.png" % int(tr["arte"]))
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
	img.custom_minimum_size = Vector2(0, 150)
	# Ainda não ganho: a sombra preta do troféu.
	img.self_modulate = Color.WHITE if ganho else Color(0, 0, 0, 0.92)
	v.add_child(img)
	var nome := IdleUI.rotulo(_nome_da_pista(String(tr["pista"])).to_upper(), 20,
			IdleUI.COR_TEXTO if ganho else IdleUI.COR_BLOQUEADO, v, "display")
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.custom_minimum_size.x = LARGURA_TEXTO_TROFEU  # largura fixa: quebra sem laço de layout
	var b := IdleUI.rotulo(_texto_bonus(tr) if ganho else "VENÇA EM 1º", 20,
			IdleUI.COR_GANHO if ganho else IdleUI.COR_BLOQUEADO, v)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = LARGURA_TEXTO_TROFEU
	return c


var _trofeu_recente := ""


## O troféu recém-ganho, na coleção: gira uma vez no lugar e brilha.
func _girar_trofeu(cartao: Control) -> void:
	_trofeu_recente = ""
	if Preferencias.reduzir_animacoes or cartao.get_child_count() == 0:
		return
	var img := cartao.get_child(0).get_child(0) as Control
	if img == null:
		return
	img.pivot_offset = img.size * 0.5
	var tw := img.create_tween()
	tw.tween_property(img, "scale:x", -1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(img, "scale:x", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(img, "modulate", Color(1.6, 1.4, 0.9), 0.12)
	tw.tween_property(img, "modulate", Color.WHITE, 0.4)
	_efeitos.faiscas(img.get_global_rect().get_center(), IdleUI.COR_OURO_CLARO, 24)


func _texto_bonus(tr: Dictionary) -> String:
	var pct := "+%d%%" % roundi(float(tr["bonus"]) * 100.0)
	match String(tr["efeito"]):
		"premio":
			return pct + " no prêmio"
		"renda":
			return pct + " no lucro"
		"potencia":
			return pct + " no motor"
		"gorjeta":
			return pct + " na gorjeta"
	return pct


func _nome_da_pista(id: String) -> String:
	for a in dados.arena().get("arenas", []):
		if String(a["id"]) == id:
			return String(a["nome"])
	return IdleUI.nome_pista(id)


## O jornaleiro aparece de vez em quando, só com a corrida na tela e ninguém
## falando (cfg "jornaleiro").
func _passo_jornaleiro() -> void:
	var j := estado.cfg_jornaleiro()
	if j.is_empty() or _jornaleiro == null:
		return
	var agora := Time.get_ticks_msec() / 1000.0
	var intervalo: Array = j.get("intervalo_s", [120, 120])
	if _jornaleiro_em <= 0.0:
		_jornaleiro_em = agora + randf_range(float(intervalo[0]), float(intervalo[1]))
		return
	if agora < _jornaleiro_em or _jornaleiro.ativo():
		return
	var pode: bool = _paginas["corrida"].visible and _conversa == null and not _guia.ativo() \
			and not _aguardando and _toque_medidor.visible and _janela_jornaleiro == null \
			and estado.corridas >= int(j.get("a_partir_corridas", 0))
	if not pode:
		_jornaleiro_em = agora + 5.0  # tenta de novo daqui a pouco
		return
	_jornaleiro.aparecer(float(j.get("fica_s", 10.0)))
	_jornaleiro_em = agora + randf_range(float(intervalo[0]), float(intervalo[1]))


## O toque no jornaleiro abre a janela dele: a gorjeta, o quanto capangas e
## troféus já somam nela, FECHAR (leva a gorjeta) e o anúncio que a multiplica.
func _pagar_jornaleiro() -> void:
	if _janela_jornaleiro != null:
		return
	_gorjeta = estado.gorjeta_jornaleiro()
	Sons.tocar_ui(self, "caixa_registradora", -4.0)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)
	_janela_jornaleiro = fundo
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(600, 0)
	p.add_theme_stylebox_override("panel", IdleUI.caixa(COR_CARTAO, 18, 0, IdleUI.COR_BORDA, 1))
	p.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW  # o fundo nos cantos arredondados
	centro.add_child(p)
	# A esquina da banca (dia ou noite, pela hora) ocupando o cartão inteiro,
	# escala uniforme recortando as sobras; embaixo, um véu escuro sob o texto.
	var rua := TextureRect.new()
	rua.texture = load("res://arte/fastfather/jornaleiro/fundo_%s.webp" % ("noite" if CenarioEpoca.fase() == "noite" else "dia"))
	rua.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rua.stretch_mode = TextureRect.STRETCH_SCALE
	var fundo_rua := Control.new()  # o fundo fora do layout do cartão (posição à mão)
	fundo_rua.clip_contents = true
	p.add_child(fundo_rua)
	fundo_rua.add_child(rua)
	var veu := TextureRect.new()
	var grad := Gradient.new()
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	veu.texture = gt
	veu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veu.stretch_mode = TextureRect.STRETCH_SCALE
	p.add_child(veu)
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 26)
	p.add_child(margem)
	p.add_child(MolduraDeco.new(6.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margem.add_child(v)
	var t := IdleUI.rotulo("JORNALEIRO", 40, IdleUI.COR_OURO_CLARO, v, "deco")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 10)
	t.add_theme_color_override("font_outline_color", Color(IdleUI.COR_CARVAO, 0.9))
	# O menino no meio da calçada, trocando de quadro devagar (um funde no outro).
	var menino := _MeninoLento.new()
	menino.custom_minimum_size = Vector2(0, 300)
	v.add_child(menino)
	# A calçada da arte embaixo dos pés do menino: a imagem na largura do cartão
	# (escala uniforme), descida até o chão dela bater no pé dele; daí para baixo
	# o véu escurece até a cor do cartão, sob o texto e os botões.
	var encaixar := func():
		var w := p.size.x
		var alto := w * rua.texture.get_height() / rua.texture.get_width()
		var pe := 26.0 + menino.position.y + menino.size.y
		fundo_rua.size = p.size
		rua.size = Vector2(w, alto)
		rua.position = Vector2(0, pe - alto * CHAO_DA_RUA)
		var k := clampf(pe / maxf(p.size.y, 1.0), 0.05, 0.9)
		grad.offsets = PackedFloat32Array([0.0, k - 0.03, k + 0.08, clampf((rua.position.y + alto) / p.size.y, k + 0.1, 1.0)])
		grad.colors = PackedColorArray([Color(COR_CARTAO, 0.0), Color(COR_CARTAO, 0.0), Color(COR_CARTAO, 0.86),
				Color(COR_CARTAO, 1.0)])
	p.resized.connect(encaixar)
	menino.resized.connect(encaixar)
	var l := IdleUI.rotulo("Extra! O menino trouxe o jornal e a gorjeta da banca:", 22, IdleUI.COR_TEXTO, v, "regular")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 540
	var valor := IdleUI.rotulo("+$" + curto(_gorjeta), 56, IdleUI.COR_NEON, v, "deco")
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var extra := estado.bonus_gorjeta()
	if extra > 0.0:
		var b := IdleUI.rotulo("Gorjeta +%d%% pelos capangas e troféus" % roundi(extra * 100.0), 20, IdleUI.COR_GANHO, v)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mult := estado.multiplicador_anuncio_gorjeta()
	var a := IdleUI.rotulo("Assista a um anúncio e a gorjeta vale ×%d." % mult, 20, IdleUI.COR_SECUNDARIA, v, "regular")
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var x := IdleUI.botao_premio("GORJETA ×%d · $%s" % [mult, curto(_gorjeta * mult)], 26, 80, v)
	x.pressed.connect(_dobrar_gorjeta)
	var fechar := IdleUI.botao("FECHAR", IdleUI.COR_CROMO, 24, 64, v)  # o anúncio é o destaque
	fechar.pressed.connect(_receber_gorjeta.bind(1))
	if not Preferencias.reduzir_animacoes:
		p.pivot_offset = Vector2(300, 300)
		p.scale = Vector2(0.85, 0.85)
		p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


var _janela_jornaleiro: Control
## Altura do chão da calçada nas artes de fundo do jornaleiro (fração da imagem).
const CHAO_DA_RUA := 0.76


## O menino da janela do jornaleiro: os 12 quadros da arte em vaivém, cada um
## parado um tempo e fundindo no seguinte (lento, sem o aceno rápido da corrida).
class _MeninoLento extends Control:
	const PARADO_S := 0.55
	const FUNDE_S := 0.5
	var _a: TextureRect
	var _b: TextureRect
	var _i := 0
	var _passo := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_a = _camada()
		_b = _camada()
		_a.texture = load(JornaleiroIdle.quadro(0))
		_b.modulate.a = 0.0

	func _camada() -> TextureRect:
		var r := TextureRect.new()
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		return r

	func _ready() -> void:
		if not Preferencias.reduzir_animacoes:
			_proximo()

	func _proximo() -> void:
		if not is_inside_tree():
			return
		if _i + _passo < 0 or _i + _passo >= JornaleiroIdle.QUADROS:
			_passo = -_passo
		_i += _passo
		_b.texture = load(JornaleiroIdle.quadro(_i))
		var tw := create_tween()
		tw.tween_interval(PARADO_S)
		tw.tween_property(_b, "modulate:a", 1.0, FUNDE_S).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func():
			_a.texture = _b.texture
			_b.modulate.a = 0.0
			_proximo())


## Fecha a janela e paga a gorjeta `vezes` vezes.
func _receber_gorjeta(vezes: int) -> void:
	if _janela_jornaleiro == null:
		return
	_janela_jornaleiro.queue_free()
	_janela_jornaleiro = null
	var g := _gorjeta * vezes
	estado.dinheiro += g
	ganho_flutuante(g)
	_efeitos.pipoca(_paginas["corrida"].get_global_rect().get_center() + Vector2(0, -60), "+$" + curto(g),
			IdleUI.COR_NEON, 44, 0.9)
	Sons.cascata(self, 4 if vezes == 1 else 7)
	if vezes > 1:
		_hud.evento("GORJETA ×%d!" % vezes, "+$" + curto(g), IdleUI.COR_NEON, 11, -1.0, true)
	estado.salvar(Time.get_unix_time_from_system())


func _dobrar_gorjeta() -> void:
	var mult := estado.multiplicador_anuncio_gorjeta()
	anuncios.premiado(func(): _receber_gorjeta(mult))


## Troféu novo na chegada: estouro sobre a corrida e o botão pulsa.
func _comemorar_trofeu() -> void:
	if estado.trofeu_novo == "":
		return
	_trofeu_recente = estado.trofeu_novo
	estado.trofeu_novo = ""
	var onde: Vector2 = _paginas["corrida"].get_global_rect().get_center()
	_efeitos.pipoca(onde + Vector2(0, -60), "TROFÉU NOVO!", COR_OURO, 44, 1.4)
	Sons.tocar_ui(self, "flash", -4.0)  # o flash de magnésio da foto do troféu
	_efeitos.faiscas(onde, IdleUI.COR_OURO_CLARO, 50)
	if _botao_trofeus != null:
		IdleUI.pulsar(_botao_trofeus, 1.12)


func _marcar_seletor() -> void:
	for q in _seletor:
		var b: Button = _seletor[q]
		var ativo: bool = q == _multiplo
		var cor := IdleUI.COR_NEON if ativo else IdleUI.COR_CARTAO
		for e in ["normal", "hover", "focus", "pressed"]:
			b.add_theme_stylebox_override(e, IdleUI.caixa(cor, 5, 4, IdleUI.COR_OURO_ESCURO, 1))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, IdleUI.COR_TINTA if ativo else IdleUI.COR_OURO)


func _lista_aberta(sim: bool) -> void:
	_painel_lista.visible = sim
	if sim:
		_atualizar_cartoes()


## Busto: o alto da figura (`proporcao` da largura em altura), sem esticar.
static func _busto(tex: Texture2D, proporcao: float) -> Texture2D:
	if tex == null:
		return null
	var a := AtlasTexture.new()
	a.atlas = tex
	var w := float(tex.get_width())
	a.region = Rect2(w * 0.1, 0, w * 0.8, w * 0.8 * proporcao)
	return a


## Velocímetro do toque (arte do usuário, 2026-10-28: mostrador e ponteiro em
## arte/fastfather/corrida): o ponteiro sobe enquanto segura, a carga em ouro
## num arco por dentro das marcas e, carregado, TOQUE pulsando.
class _MedidorToque extends Control:
	## Velocímetro minimalista (referência do usuário, 2026-10-28): arco fino
	## de 270°, sem marcas nem números de escala, a faixa final em neon, o número grande no meio e a
	## velocidade como um traço branco com a ponta acesa. Por dentro, um
	## segundo arco fino é a carga do acelerador (âmbar cheia, verde acelerando,
	## aço enchendo, vinho vazia com o dedo na tela).
	const LADO := 150.0
	const INICIO := deg_to_rad(135.0)
	const VARRE := deg_to_rad(270.0)
	const MAXIMO := 200.0  # km/h no fim da escala (apresentação)
	const FAIXA := 160.0  # onde começa a faixa final em neon
	const FUNDO := Color(0.055, 0.055, 0.063, 0.86)
	const TRILHO := Color("232327")
	const MARCA := Color("4a4a52")
	const MARCA_MENOR := Color("2c2c31")
	const BRANCO := Color("f2f2f2")
	const CINZA := Color("8a8a93")
	var carga := 1.0
	var acelerando := false
	var segurando := false  # o dedo na corrida (com ou sem carga)
	var kmh := 0.0  # a velocidade do seu carro, que a tela passa
	var _mostrado := 0.0

	func vazio() -> bool:
		return segurando and carga <= 0.0

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_mostrado = lerpf(_mostrado, clampf(kmh, 0.0, MAXIMO), minf(delta * 6.0, 1.0))
		queue_redraw()

	func _angulo(f: float) -> float:
		return INICIO + VARRE * clampf(f, 0.0, 1.0)

	func _texto(t: String, cor: Color, tam: int, y: float, peso := "semibold") -> void:
		var c := size * 0.5
		var fonte := Tipografia.fonte(peso)
		var w := fonte.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		draw_string(fonte, c + Vector2(-w * 0.5, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var cheio := carga >= 0.99 and not acelerando
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU / 0.9)
		var k_rapido := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU / 0.35)
		if Preferencias.reduzir_animacoes:
			k = 1.0
			k_rapido = 1.0
		draw_circle(c, r, FUNDO)
		var raio := r * 0.86
		# O arco da escala e a faixa final.
		draw_arc(c, raio, _angulo(0.0), _angulo(1.0), 64, TRILHO, 2.0, true)
		draw_arc(c, raio, _angulo(FAIXA / MAXIMO), _angulo(1.0), 24, Color(IdleUI.COR_NEON, 0.6), 2.0, true)
		# A velocidade: traço branco (neon na faixa final) e a ponta acesa.
		var fv := _mostrado / MAXIMO
		var cor_v := IdleUI.COR_NEON if _mostrado >= FAIXA else BRANCO
		if fv > 0.002:
			draw_arc(c, raio, _angulo(0.0), _angulo(fv), 48, cor_v, 2.0, true)
			draw_circle(c + Vector2.from_angle(_angulo(fv)) * raio, 4.0, cor_v)
		# A carga do acelerador, num arco fino por dentro.
		var raio_c := raio - 34.0
		draw_arc(c, raio_c, _angulo(0.0), _angulo(1.0), 48,
				Color(IdleUI.COR_VINHO, 0.9) if vazio() else TRILHO, 3.0, true)
		if carga > 0.0:
			var cor_c := IdleUI.COR_NEON_VERDE if acelerando else (IdleUI.COR_NEON if cheio else IdleUI.COR_ACO_CLARO)
			draw_arc(c, raio_c, _angulo(0.0), _angulo(carga), 48, cor_c, 3.0, true)
		if cheio:
			draw_arc(c, r - 1.5, 0.0, TAU, 64, Color(IdleUI.COR_NEON, 0.25 + 0.6 * k), 2.5, true)
		elif vazio():
			draw_arc(c, r - 1.5, 0.0, TAU, 64, Color(IdleUI.COR_VINHO_CLARO, 0.3 + 0.6 * k_rapido), 3.0, true)
		# O número grande e, embaixo, o que o toque faz agora.
		_texto(str(roundi(_mostrado)), cor_v, 44, 14.0, "regular")
		if vazio():
			_texto("VAZIO", IdleUI.COR_VINHO_CLARO.lerp(BRANCO, k_rapido), 20, r * 0.62)
		elif cheio:
			_texto("TOQUE", BRANCO.lerp(IdleUI.COR_NEON, k), 20, r * 0.62)
		elif not acelerando:
			_texto("%d%%" % roundi(carga * 100.0), CINZA, 18, r * 0.62)  # enchendo: só a carga, sem TOQUE


## A chuva na lente: riscos inclinados caindo por cima da corrida, poucos e
## finos (o dia de chuva é sorteado pela data, CenarioEpoca.chuva).
class _Chuva extends Control:
	const GOTAS := 70
	var _gotas: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1937
		for i in GOTAS:
			_gotas.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.0)))

	func _process(_d: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		if Preferencias.reduzir_animacoes:
			t = 0.0
		for g in _gotas:
			var y := fmod(g.y + t * 1.6 * g.z, 1.0) * (size.y + 60.0) - 30.0
			var x := fmod(g.x + t * 0.18 * g.z, 1.0) * size.x
			var p := Vector2(x, y)
			draw_line(p, p + Vector2(-6.0, 26.0) * g.z, Color(0.85, 0.9, 1.0, 0.35 * g.z), 2.0, true)


## Os pontos do pelotão: um por carro, o seu em ouro.
class _Pelotao extends Control:
	var total := 0
	var posicao := 0

	func _draw() -> void:
		if total <= 0:
			return
		var y := size.y * 0.5
		draw_line(Vector2(4, y), Vector2(size.x - 4, y), IdleUI.COR_BORDA, 2.0)
		for k in total:
			var x := 4.0 + (size.x - 8.0) * (float(k) / maxf(total - 1, 1))
			var meu := k == posicao - 1
			draw_circle(Vector2(x, y), 6.0 if meu else 3.5, IdleUI.COR_OURO_CLARO if meu else IdleUI.COR_GANHO.darkened(0.2))


func _cartao(m: Dictionary) -> Control:
	var a := AndarIdle.new(m)
	var id := String(m["id"])
	a.comprar.connect(func(quantos: int): _comprar(id, quantos))
	_cartoes[id] = {"nivel": a.nivel, "efeito": a.efeito, "previsao": a.previsao, "botao": a.botao, "dez": a.dez,
			"maximo": a.maximo, "nome": a.nome, "cartao": a}
	return a


static func curto(v: float) -> String:
	return IdleUI.curto(v)


## Troca a tela do meio (menu de baixo).
const MUSICAS := ["jazz_1", "jazz_2", "jazz_3"]
var _faixa := 0


func _proxima_musica() -> void:
	_faixa = (_faixa + 1) % MUSICAS.size()
	var s := Sons._arquivo(String(MUSICAS[_faixa]), false)
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = false
	_musica.stream = s
	_musica.play()


func _abrir(id: String) -> void:
	if not _paginas[id].visible:
		Sons.tocar_ui(self, "toque", -6.0)
	_barra.escolher(id)
	for k in _paginas:
		_paginas[k].visible = k == id
	# Na garagem do Tony a música vem do rádio AM da bancada.
	Sons.radio_musica(id == "garagem")
	if id == "pistas":
		_pistas.atualizar()
	elif id == "pilotos":
		_pilotos.atualizar()
	elif id == "rinha":
		_rinha.atualizar()
	elif id == "metas":
		_metas.atualizar()
	elif id == "garagem":
		_garagem.atualizar()


func _efeito_texto(m: Dictionary, nivel: int) -> String:
	var x := float(m["por_nivel"]) * nivel * estado.multiplicador_marcos(m, nivel)
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
		var id := String(m["id"])
		var c: Dictionary = _cartoes[id]
		_texto_previsao(c["previsao"], m, base)
		var n := estado.nivel(id)
		# Na Arena, a melhoria pode ter outro nome (o Vácuo vira Blindagem).
		var arena: bool = _na_arena and m.has("nome_arena")
		var nome_melhoria := String(m["nome_arena"] if arena else m["nome"]).to_upper()
		c["nivel"].text = IdleUI.nv(n)
		var a: AndarIdle = c["cartao"]
		var f := AndarIdle.fase_do_nivel(n)
		if f != a.fase:
			if f > a.fase and a.is_visible_in_tree() and _efeitos != null:
				# Marco: a estação muda de fase (mais luz, mais gente).
				_efeitos.pipoca(a.get_global_rect().get_center(), "NOVA FASE!", COR_OURO, 40, 0.9)
				celebrar(2)
			a.fase = f
			a.queue_redraw()
		_atualizar_ladrilho(m, n, c["previsao"].text)
		var b: Button = c["botao"]
		var dez: Button = c["dez"]
		var maximo: Button = c["maximo"]
		if estado.no_maximo(id):
			c["efeito"].text = "%s %s" % [nome_melhoria, _efeito_texto(m, n)]
			b.text = "MÁX."
			for x in [b, dez, maximo]:
				x.disabled = true
			dez.text = "+10"
			maximo.text = "MÁX."
			continue
		c["efeito"].text = "%s %s › %s" % [nome_melhoria, _efeito_texto(m, n), _efeito_texto(m, n + 1)]
		b.text = "+1\n$%s" % curto(estado.custo(id))
		var antes := b.disabled
		b.disabled = not estado.pode_comprar(id)
		# Botão que passa a poder ser tocado pulsa uma vez.
		if antes and not b.disabled and a.is_visible_in_tree():
			IdleUI.pulsar(b, 1.08)
		var c10 := estado.custo_varios(id, 10)
		dez.text = "+10\n$%s" % curto(c10) if is_finite(c10) else "+10"
		dez.disabled = not is_finite(c10) or estado.dinheiro < c10
		var pagaveis := estado.niveis_pagaveis(id)
		maximo.text = "MÁX. +%d\n$%s" % [pagaveis, curto(estado.custo_varios(id, pagaveis))] if pagaveis > 0 else "MÁX."
		maximo.disabled = pagaveis <= 0


## O cartão compacto da melhoria (oficina ou trapaça): nível, efeito com a
## previsão e o preço de +1.
func _atualizar_ladrilho(m: Dictionary, n: int, previsao: String) -> void:
	var l: LadrilhoIdle = _ladrilhos.get(String(m["id"]))
	if l == null or l.esta_fechado():
		return
	var ef := _efeito_texto(m, n)
	if m.has("trapaca"):
		ef = String(m["trapaca"].get("sub", ef))
	elif "›" in previsao:
		ef += " · " + previsao.replace(" ", "")
	var id := String(m["id"])
	var pm := estado.proximo_marco(n)
	l.definir_marco(float(n - pm.x) / float(pm.y - pm.x) if pm.y > 0 else -1.0)
	if estado.no_maximo(id):
		l.definir("NV. %d" % n, ef, "MÁX.", false)
		return
	var q := _quantos(id, _multiplo)
	var custo := estado.custo_varios(id, q)
	if not is_finite(custo):
		l.definir("NV. %d" % n, ef, "MÁX.", false)
		return
	var preco := "$" + curto(custo) if q == 1 else "+%d · $%s" % [q, curto(custo)]
	l.definir("NV. %d" % n, ef, preco, estado.dinheiro >= custo)


func _atualizar_topo(delta := 0.0) -> void:
	if _toque_medidor != null:
		_toque_medidor.visible = not _bandeira.visible  # a bandeira do fiscal tem a vez
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
	# Embaixo da liga, o objetivo dela e a corrida da vez.
	if estado.venceu:
		_divisao.text = "CATEGORIA VENCIDA" if estado.ultima_liga() else "VITÓRIA! SUBA DE LIGA"
	elif estado.melhor_posicao() > 0:
		_divisao.text = "CHEGUE EM 1º · MELHOR: %dº" % estado.melhor_posicao()
	else:
		_divisao.text = "CHEGUE EM 1º PARA SUBIR"
	_atualizar_combustivel()
	_atualizar_fiscal()
	_icone_mod.texture = Aba.icone_reduzido(String(estado.dados_modalidade().get("icone", "icone_correr")), 40)
	_banner.texture = IdleUI.banner_pista(String(estado.dados_liga()["pista"]))
	_subir.visible = estado.pode_subir() and _pausa < 0.0
	if _subir.visible and not "subir" in estado.guias and _conversa == null and not _guia.ativo():
		estado.guias.append("subir")
		_guiar.call_deferred("subir", "Vitória! Toque em SUBIR DE LIGA para correr numa liga nova.")
	# Com o LARGAR na tela, PRÓXIMA LIGA fica logo acima dele.
	_subir.offset_top = -330.0 if _largar.visible else -270.0
	_subir.offset_bottom = -242.0 if _largar.visible else -182.0
	if _subir.visible and not Preferencias.reduzir_animacoes:
		_subir.pivot_offset = _subir.size * 0.5
		var k := 1.0 + 0.035 * sin(Time.get_ticks_msec() / 1000.0 * TAU / 1.1)
		_subir.scale = Vector2(k, k)
		# Letreiro de neon da época: de vez em quando o tubo falha duas vezes.
		var ms := Time.get_ticks_msec() % 7000
		_subir.self_modulate = Color(1, 1, 1, 0.45) if (ms > 6700 and ms < 6760) or (ms > 6830 and ms < 6880) else Color.WHITE


# --- corrida ------------------------------------------------------------------

## A família rival de uma equipe (data/idle/cenas.json → "familias"): o nome
## na plaquinha de posição. Uma por equipe, na ordem da lista de equipes.
var _familias := {}
func _familia(eq: Dictionary) -> String:
	if _familias.is_empty():
		var nomes: Array = CenaQuadrinho.carregar("familias").get("nomes", [])
		var i := 0
		for e in dados.lista("equipes"):
			if not e.get("jogador", false) and not Array(e.get("pilotos", [])).is_empty() and not nomes.is_empty():
				_familias[String(e["nome"])] = String(nomes[i % nomes.size()])
				i += 1
	return String(_familias.get(String(eq.get("nome", "")), eq.get("nome", "")))


func _nova_corrida() -> void:
	_pago_corrida = 0.0
	_pingado = 0.0
	_semente += 1
	_resultado = estado.correr(dados, _semente + estado.corridas * 7919)
	_na_arena = estado.e_arena()
	_visual3d.visible = not _na_arena and _tv
	_visual.visible = not _na_arena and not _tv
	_arena3d.visible = _na_arena
	_aplicar_dupla()
	_hud.so_eventos = _na_arena
	var categorias := {}
	var pinturas := {}
	var faixas := {}
	var escalados := estado.escalacao(dados)
	_nomes = {"jogador": "Você"}
	for p in estado.participantes(dados):
		var id := String(p["id"])
		categorias[id] = dados.carro(p["carro"])
		# Divisão de época: todos correm com o carro do período (só a aparência).
		if estado.dados_modalidade().has("epoca"):
			categorias[id] = categorias[id].duplicate()
			categorias[id]["epoca"] = estado.dados_modalidade()["epoca"]
		elif _na_arena:
			# A Rinha também é da época: os mesmos carros da aba RINHA, nada do Chrome & Wreckage.
			categorias[id] = categorias[id].duplicate()
			categorias[id]["epoca"] = RinhaIdle.MODELO_RAPAZES if id == "jogador" else \
					String(RinhaIdle.MODELOS[posmod(hash(id + str(_semente)), RinhaIdle.MODELOS.size())])
		var k := int(id.trim_prefix("r")) if id != "jogador" else -1
		var fam := PinturaEpoca.familia(estado.modalidade, estado.liga) if estado.dados_modalidade().has("epoca") else ""
		if fam != "":
			# Pintura de época: cor da equipe e número pintado (PinturaEpoca).
			var pe: Array
			if id == "jogador":
				pe = GaragemIdle.pintura(estado, estado.carro_da_modalidade(), fam)
			elif k < escalados.size():
				var eq: Dictionary = escalados[k]["equipe"]
				var num := int(eq["numero"]) * 4 - 3 + int(escalados[k]["vaga"]) if eq.get("numero") != null else -1
				pe = PinturaEpoca.do_rival(fam, String(eq.get("nome", k)), "%d|%d" % [estado.liga, k], num)
				_nomes[id] = _familia(eq)
			else:
				pe = PinturaEpoca.do_rival(fam, id, "%d|%s" % [_semente, id])
			pinturas[id] = pe[0]
			faixas[id] = pe[1]
		elif id == "jogador":
			pinturas[id] = COR_OURO
			faixas[id] = PinturaCarro.da_equipe(EQUIPE_JOGADOR, "crt", 0)
		elif k < escalados.size():
			# Rival nas cores da equipe dele, como no Chrome & Wreckage.
			var eq: Dictionary = escalados[k]["equipe"]
			pinturas[id] = Color(String(eq["cores"]["carro"]))
			faixas[id] = PinturaCarro.da_equipe(eq, "%d|%d" % [estado.liga, k], int(escalados[k]["vaga"]))
			_nomes[id] = _familia(eq)
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
		_visual3d.epoca = String(estado.dados_modalidade().get("epoca", ""))
		CenarioEpoca.cidade = estado.cidade
		var fortes := estado.pilotos.duplicate()
		fortes.sort_custom(func(a, b): return int(a["nivel"]) > int(b["nivel"]))
		CenarioEpoca.capangas_arte = fortes.slice(0, 3).map(func(p): return PilotosIdle.arte_rapaz(p))
		CenarioEpoca.letreiros = CenaQuadrinho.carregar("letreiros").get("lista", [])
		# Chuva em cerca de um dia a cada sete, pela data (o dia inteiro igual).
		CenarioEpoca.chuva = absi(hash("chuva|" + MetaDia.dia(estado.relogio()))) % 7 == 0 \
				if CenarioEpoca.chuva_forcada < 0 else CenarioEpoca.chuva_forcada == 1
		_chuva_tela.visible = CenarioEpoca.chuva
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
	_contagem = CONTAGEM_SEGUIDA_S if _ja_correu else CONTAGEM_S
	# Sem o carro da divisão a corrida espera no grid (LARGAR leva à garagem).
	_aguardando = not estado.tem("largada_auto") or not estado.pode_correr()
	_largar.visible = _aguardando
	_hud.contagem = -1.0 if _aguardando else _contagem
	_visual3d.bandeira_fiscal(false)
	if not _aguardando:
		_sons.largada(false)
		_largada_fiscal()
		_trava_projetor()
	_bandeira.esconder()
	_diretor.reiniciar()
	_aplicar_camera()
	_visual3d.destacar_jogador()  # o anel no seu carro (o dourado) na largada


## A largada é do fiscal na beira da pista (3D), nada por cima da tela; na vista
## de cima, que não mostra o fiscal, só o aviso curto no fim da contagem.
func _largada_fiscal() -> void:
	_visual3d.largada_fiscal(_contagem)
	if not _tv:
		get_tree().create_timer(_contagem).timeout.connect(func():
			if not _aguardando:
				_hud.evento("LARGADA!", "", IdleUI.COR_NEON_VERDE, 5, 1.0))


func _trocar_camera(modo: String) -> void:
	_camera_modo = modo
	_ciclo_troca = 0.0
	_marcar_camera()
	_diretor.reiniciar()
	_aplicar_camera()


## A câmera em uso: a escolhida ou, no "ciclo", a da vez; sem o trilho, o diretor.
func _camera_efetiva() -> String:
	if not _trilho.visible or _camera_modo == "dupla":
		return "auto"  # na dupla, o 3D fica com o diretor
	return String(CICLO[_ciclo_i]) if _camera_modo == "ciclo" else _camera_modo


## No "ciclo", passa para a próxima câmera de tempo em tempo (no grid, não).
func _passo_ciclo() -> void:
	if _camera_modo != "ciclo" or not _trilho.visible or _contagem > 0.0:
		return
	var agora := Time.get_ticks_msec() / 1000.0
	if _ciclo_troca <= 0.0:
		_ciclo_troca = agora + CICLO_CAMERA_S
	elif agora >= _ciclo_troca:
		_ciclo_troca = agora + CICLO_CAMERA_S
		_ciclo_i = (_ciclo_i + 1) % CICLO.size()
		_marcar_camera()
		_diretor.reiniciar()
		_aplicar_camera()


func _marcar_camera() -> void:
	var efetiva := _camera_efetiva()
	for modo in _cameras:
		var b: Button = _cameras[modo]
		var ativa: bool = modo == _camera_modo
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, IdleUI.caixa(COR_OURO if ativa else Color(1, 1, 1, 0.05), 10, 0))
		# No "ciclo", a câmera da vez acende em ouro.
		var da_vez: bool = _camera_modo == "ciclo" and modo == efetiva
		# A arte é creme: o modulate escurece no ativo e doura a câmera da vez.
		b.get_child(0).self_modulate = Color(0.16, 0.17, 0.17) if ativa else (Color(1.25, 1.05, 0.7) if da_vez else Color(0.85, 0.85, 0.85))


func _aplicar_camera() -> void:
	var efetiva := _camera_efetiva()
	_arena3d.modo = CAMERA_ARENA[efetiva]
	_visual3d.visao_geral = efetiva == "geral"
	_visual3d.perseguicao = efetiva == "jogador"
	_visual3d.foco = "jogador"
	_visual3d.enquadrar_com = ""
	_aplicar_dupla()


func dupla() -> bool:
	return _camera_modo == "dupla" and _trilho.visible and _tv and not _na_arena


## Câmera dupla: some o que fica abaixo da corrida (oficina e trapaças), o 3D
## vai para a parte de cima e a vista 2D da pista inteira ocupa a de baixo.
func _aplicar_dupla() -> void:
	if _pagina_corrida_v == null:
		return
	var d := dupla()
	for c in _pagina_corrida_v.get_children():
		if c != _quadro_corrida:
			(c as Control).visible = not d and (c != _trapacas_caixa or _trapacas_liberadas())
	_visual3d.anchor_bottom = DUPLA_3D if d else 1.0
	_visual3d.offset_bottom = 0.0
	_fundo_2d.visible = d
	_fundo_2d.anchor_left = 0.0
	_fundo_2d.anchor_right = 1.0
	_fundo_2d.anchor_top = DUPLA_3D
	_fundo_2d.anchor_bottom = 1.0
	_fundo_2d.offset_left = 0.0
	_fundo_2d.offset_right = 0.0
	_fundo_2d.offset_top = 0.0
	_fundo_2d.offset_bottom = 0.0
	if d:
		_visual.visible = true
		_visual.pontos = true
		_visual.anchor_top = DUPLA_3D
		_visual.offset_top = 26.0
		_visual.offset_bottom = -110.0  # acima da faixa do prêmio
	else:
		_visual.visible = not _na_arena and not _tv
		_visual.pontos = not _tv
		_visual.anchor_top = 0.0
		_visual.offset_top = 70.0
		_visual.offset_bottom = -20.0


var _euforia := 0.0
var _maco: TextureRect  # o maço de notas do caixa, no alto
var _euforia_t := 0.0


## A torcida reage: fica de pé nas ultrapassagens e na chegada e quando o seu
## carro passa na reta da largada, em frente à arquibancada.
func _passo_torcida() -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	var dt := clampf(agora - _euforia_t, 0.0, 0.1)
	_euforia_t = agora
	var alvo := 0.0
	if _pista != null and not _chegada and _contagem <= 0.0:
		var s := fmod(_visual.distancia_em("jogador", _visual.tempo), _pista.comprimento)
		if s < 70.0 or s > _pista.comprimento - 40.0:
			alvo = 0.6
	_euforia = maxf(alvo, move_toward(_euforia, 0.0, dt * 0.7))
	if CenarioEpoca.material_torcida != null:
		CenarioEpoca.material_torcida.set_shader_parameter("euforia", _euforia)


func _agitar_torcida(forca := 1.0) -> void:
	_euforia = maxf(_euforia, forca)


## Câmera AUTO: o diretor do Chrome & Wreckage escolhe o plano (abertura de
## cima no grid, o seu carro, a disputa da frente, a pista inteira).
func _dirigir() -> void:
	_passo_torcida()
	var ordem := _visual.ordem()
	var i := ordem.find("jogador")
	_visual3d.alvo = ordem[i - 1] if i > 0 and not _chegada else ""
	_passo_ciclo()
	if _camera_efetiva() != "auto":
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
		_passo_ciclo()
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
		_visual.tempo = minf(_visual.tempo + delta * _passo_toque(delta), _visual.duracao())
		_pingar_premio()
		if _visual.tempo >= _fim_jogador:
			_chegou()
	if _chegada:
		_t_chegada += delta
		_visual3d.chegada = minf(_t_chegada / 3.0, 1.0)
	_visual3d.taxa = 0.0 if _contagem > 0.0 else 1.0
	_dirigir()
	_passo_jornaleiro()
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
		nuvem.enviar(estado)


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
		nuvem.enviar(estado)


## O prêmio da chegada entra aos poucos, conforme o carro anda; de tempos em
## tempos um "+$" pipoca sobre o caixa.
func _pingar_premio() -> void:
	if _resultado.is_empty() or not is_finite(_fim_jogador) or _fim_jogador <= 0.0 or _chegada:
		return
	var alvo := estado.premio(IdleEstado.posicao(_resultado)) * clampf(_visual.tempo / _fim_jogador, 0.0, 1.0)
	var dif := alvo - _pago_corrida
	if dif <= 0.0:
		return
	estado.dinheiro += dif
	_pago_corrida = alvo
	_pingado += dif
	if _pingado >= maxf(1.0, estado.premio(1) * 0.05) and _paginas["corrida"].visible and _conversa == null:
		var r := _dinheiro.get_global_rect()
		_efeitos.pipoca(Vector2(r.get_center().x, r.end.y), "+$" + curto(_pingado), COR_DINHEIRO, 22, 0.25)
		IdleUI.saltar(_dinheiro, 1.05)
		_pingado = 0.0


## Segurar a corrida acelera: devolve o quanto o tempo da corrida anda
## neste quadro e gasta (ou recarrega) a carga (cfg "toque").
func _passo_toque(delta: float) -> float:
	var t: Dictionary = estado.cfg.get("toque", {})
	if t.is_empty():
		return 1.0
	var vel := 1.0
	if _segurando and _toque_carga > 0.0 and _paginas["corrida"].visible:
		vel = float(t.get("velocidade", 1.0))
		_toque_carga = maxf(_toque_carga - delta / maxf(float(t.get("carga_s", 1.0)), 0.01), 0.0)
	else:
		_toque_carga = minf(_toque_carga + delta / maxf(float(t.get("recarga_s", 1.0)), 0.01), 1.0)
	_toque_medidor.carga = _toque_carga
	_toque_medidor.acelerando = vel > 1.0
	_toque_medidor.segurando = _segurando and _paginas["corrida"].visible
	# A carga acabou com o dedo ainda na tela: avisa uma vez que parou de acelerar.
	if _toque_medidor.vazio() and not _avisou_vazio:
		_avisou_vazio = true
		_hud.evento("ACELERADOR VAZIO", "solte e espere encher", IdleUI.COR_VINHO_CLARO, 4)
		Sons.tocar_ui(self, "nao", -6.0)
	elif not _segurando:
		_avisou_vazio = false
	_toque_medidor.queue_redraw()
	# Segurando: o 3D mostra o empurrão (borrão de velocidade e rastro).
	_visual3d.impulso = move_toward(_visual3d.impulso, 1.0 if vel > 1.0 else 0.0, delta * 4.0)
	if Time.get_ticks_msec() / 1000.0 < _lento_ate:
		vel *= LENTO_VELOCIDADE
	if not "toque" in estado.guias and estado.corridas >= 1 and _conversa == null and not _guia.ativo() \
			and _paginas["corrida"].visible:
		estado.guias.append("toque")
		_guiar.call_deferred("toque", "Segure a corrida para acelerar.")
	return vel


func _toque_corrida(e: InputEvent) -> void:
	if e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		_segurando = e.pressed


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
		_locutor("locutor_largada")
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
	_virar_placa(_posicao, "%dº LUGAR" % (i + 1))
	_pelotao.total = ordem.size()
	_pelotao.posicao = i + 1
	_pelotao.queue_redraw()
	_volta.text = "%d/%d" % [volta, voltas]
	_premio.text = "$" + curto(estado.premio(i + 1))

	var perto := atacante != ""
	if i > 0 and not _chegada:
		var g := _gap(ordem[i - 1], "jogador")
		perto = perto or (g >= 0.0 and g < 0.45)
	_hud.secundario = 0.0 if _chegada else (0.35 if perto else 1.0)


func _atualizar_combustivel() -> void:
	var agora := Time.get_unix_time_from_system()
	var restam := estado.combustivel_restantes(Time.get_date_string_from_system())
	var total := int(estado.cfg_combustivel().get("usos_dia", 0))
	if estado.combustivel_ativo(agora):
		_combustivel_texto.text = "No tanque: %s" % IdleUI.relogio(estado.combustivel_ate - agora)
	else:
		_combustivel_texto.text = "+%d%%·%dmin" % [roundi(estado.bonus_combustivel() * 100.0),
				roundi(float(estado.cfg_combustivel().get("duracao_s", 0.0)) / 60.0)]
	_combustivel_botao.text = "USAR %d/%d" % [restam, total] if restam > 0 else "AMANHÃ"
	_combustivel_botao.disabled = restam <= 0


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
			_hud.evento("LÍDER!", "passou %s" % nome, IdleUI.COR_NEON, 6)
		elif ganhou:
			_hud.evento("ULTRAPASSAGEM!", "passou %s · %dº" % [nome, pos], IdleUI.COR_NEON_VERDE, 5)
		if ganhou:
			_estourar_posicao(_pos_antes - pos)
			_agitar_torcida()
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


## Câmera lenta de meio segundo, clarão e tremor (ultrapassagem, chegada).
func _momento_forte(forca: float) -> void:
	if Preferencias.reduzir_animacoes or not _tv or not _paginas["corrida"].visible:
		return
	_lento_ate = Time.get_ticks_msec() / 1000.0 + LENTO_S
	_visual3d.clarao(forca * 0.6)
	_visual3d.tremer(0.15 + forca * 0.2)


## Cada posição ganha estoura: "+1 POSIÇÃO" sobre o carro e o PRÊMIO ATUAL
## salta e acende.
func _estourar_posicao(quantas: int) -> void:
	if not _paginas["corrida"].visible:
		return
	_momento_forte(0.45)
	var onde := _quadro_corrida.get_global_rect().get_center()
	if _hud.ancora_carro.x >= 0.0:
		onde = _hud.get_global_transform() * _hud.ancora_carro + Vector2(0, -60)
	_efeitos.pipoca(onde, "+%d POSIÇÃO!" % quantas if quantas == 1 else "+%d POSIÇÕES!" % quantas,
			IdleUI.COR_NEON_VERDE, 52, 1.3)
	_efeitos.faiscas(onde, IdleUI.COR_NEON_VERDE, 26)
	IdleUI.saltar(_premio, 1.2)
	var tw := _premio.create_tween()
	_premio.add_theme_color_override("font_color", IdleUI.COR_NEON_VERDE)
	tw.tween_interval(0.5)
	tw.tween_callback(func(): _premio.add_theme_color_override("font_color", IdleUI.COR_NEON))


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
	_toque_medidor.kmh = v * 3.6
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
	estado.dinheiro -= _pago_corrida  # a parte que já pingou na corrida
	_pago_corrida = 0.0
	_chegada = true
	_sons.chegada()
	_locutor("locutor_vitoria" if pos == 1 else "locutor_chegada")
	if pos == 1:
		Sons.tocar_ui(self, "comemoracao", -8.0)
		_foto_vitoria.call_deferred()
	_bandeira.chegada()
	_trava_projetor()
	_agitar_torcida(1.0 if pos <= 3 else 0.5)
	_visual3d.bandeira_fiscal(true)
	_comemorar_trofeu.call_deferred()
	_momento_forte(0.8 if pos == 1 else 0.5)
	_hud.evento("VITÓRIA!" if pos == 1 else "%dº LUGAR" % pos, "+$" + curto(ganho),
			COR_OURO if pos == 1 else IdleUI.COR_TEXTO, 10, -1.0, true)
	_ganho_corrida = ganho
	ganho_flutuante(ganho)
	# O prêmio em notas voando até o dinheiro do alto (mais na vitória).
	_efeitos.notas(_paginas["corrida"].get_global_rect().get_center() + Vector2(0, -120),
			_dinheiro.get_global_rect().get_center(), 14 if pos == 1 else (8 if pos <= 3 else 4))
	if pos <= 3:
		# Pódio: faíscas do meio da corrida (mais na vitória).
		var meio: Vector2 = _paginas["corrida"].get_global_rect().get_center() + Vector2(0, -160)
		_efeitos.faiscas(meio, COR_OURO, 40 if pos == 1 else 20)
	_ja_correu = true
	_pausa = PAUSA_CHEGADA_S
	estado.salvar(Time.get_unix_time_from_system())


## Quantos níveis o toque compra: MÁX (-1) o que dá para pagar; PRÓX. até o
## próximo marco (ou até o fim, sem mais marcos); ×10 para no máximo da melhoria.
func _quantos(id: String, modo: int) -> int:
	var n := estado.nivel(id)
	var resta := int(estado.melhoria(id)["max"]) - n
	if modo == -1:
		return maxi(estado.niveis_pagaveis(id), 1)
	if modo == PROXIMO_MARCO:
		var alvo := estado.proximo_marco(n).y
		return clampi(alvo - n if alvo > 0 else resta, 1, maxi(resta, 1))
	return clampi(modo, 1, maxi(resta, 1))


func _comprar(id: String, quantos := 1) -> void:
	var n := estado.niveis_pagaveis(id) if quantos == -1 else _quantos(id, quantos)
	var marcos_antes := estado.marcos_alcancados(estado.nivel(id))
	if estado.comprar_varios(id, n) > 0:
		_tony_espia()
		_comemorar_marco(id, marcos_antes)
		if _largar_na_compra and _aguardando:
			# Cena 4 do briefing: o primeiro +1 e a próxima corrida começa.
			_largar_na_compra = false
			_largar_corrida.call_deferred()
		# Combo: cada compra até COMBO_S depois da anterior sobe um semitom.
		var agora := Time.get_ticks_msec()
		_combo = mini(_combo + 1, COMBO_MAX) if agora - _ultima_compra_ms <= COMBO_S * 1000.0 else 0
		_ultima_compra_ms = agora
		Sons.tocar_ui(self, "moeda", -6.0, pow(2.0, _combo / 12.0))
		# A compra tem peso: o botão afunda e salta com clarão, faíscas estouram
		# dele, o nível novo pipoca acima do cartão (maior a cada compra seguida)
		# e o dinheiro do topo afunda.
		var c: Dictionary = _cartoes[id]
		var b: Button = c["botao"] if quantos == 1 else (c["dez"] if quantos == 10 else c["maximo"])
		var cartao: Control = c["cartao"]
		var lad: LadrilhoIdle = _ladrilhos.get(id)
		if lad != null and not _painel_lista.visible:
			b = lad.botao
			cartao = lad
		IdleUI.premiar(b)
		IdleUI.pulsar(cartao, 1.05)
		_efeitos.faiscas(b.get_global_rect().get_center(), IdleUI.COR_OURO_CLARO, 14 + 3 * _combo)
		var texto := IdleUI.nv(estado.nivel(id)) + ("  ×%d" % (_combo + 1) if _combo > 0 else "")
		_efeitos.pipoca(b.get_global_rect().get_center() + Vector2(0, -110), texto, COR_OURO, 32,
				0.5 + 0.12 * _combo + (0.3 if n > 1 else 0.0))
		IdleUI.saltar(_dinheiro, 0.92)
		_atualizar_cartoes()


## Passou de um nível-marco: estoura na tela; nas melhorias que multiplicam,
## o efeito dobra (cfg "marcos").
func _comemorar_marco(id: String, antes: int) -> void:
	var depois := estado.marcos_alcancados(estado.nivel(id))
	if depois <= antes:
		return
	var m := estado.melhoria(id)
	var texto := "MARCO!"
	if estado.marco_multiplica(m):
		texto = "×%s %s!" % [str(float(estado.cfg_marcos().get("multiplicador", 2.0))).trim_suffix(".0"),
				String(m["nome"]).to_upper()]
	var lad: Control = _ladrilhos.get(id)
	var onde := lad.get_global_rect().get_center() if lad != null and lad.is_visible_in_tree() else get_global_rect().get_center()
	_efeitos.pipoca(onde + Vector2(0, -90), texto, COR_OURO, 40, 1.0)
	_efeitos.faiscas(onde, IdleUI.COR_OURO_CLARO, 40)
	Sons.tocar_ui(self, "sino", -8.0)  # o sino de bonde do marco
	celebrar(3)


func _subir_liga() -> void:
	if not estado.subir_liga():
		return
	Sons.tocar_ui(self, "sino", -6.0, 1.0, false)
	estado.salvar(Time.get_unix_time_from_system())
	_nova_corrida()
	_janela_liga()


## O intersticial só aparece aqui, ao fechar a janela da liga nova, e só depois
## das primeiras ligas (intersticial_a_partir_liga); nunca ao abrir o app nem
## no meio da corrida.
func _intersticial_da_liga() -> void:
	if estado.fundadora:
		return  # Família Fundadora: sem anúncio entre as ligas
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
	# A primeira página do jornal do bairro (data/idle/cenas.json → "jornal").
	var j: Dictionary = CenaQuadrinho.carregar("jornal")
	var liga := String(estado.dados_liga()["nome"]).to_upper()
	var manchetes: Array = j.get("manchetes", ["{liga}"])
	var manchete := String(manchetes[estado.liga_total() % manchetes.size()]).format({"liga": liga})
	var notas := []
	var nova_modalidade := false
	for m in estado.cfg["modalidades"]:
		var lib: Dictionary = m.get("libera", {})
		if lib.get("modalidade", "") == estado.modalidade and int(lib.get("liga", -1)) == estado.liga:
			notas.append(String(j.get("divisao", "{divisao}")).format({"divisao": String(m["nome"]).to_upper()}))
			_barra.avisar("pistas", true)
			nova_modalidade = true
	var p := JornalIdle.new(manchete, IdleUI.banner_pista(String(estado.dados_liga()["pista"])),
			String(j.get("legenda", "")).format({"liga": String(estado.dados_liga()["nome"])}), notas)
	p.custom_minimum_size = Vector2(620, 0)
	centro.add_child(p)
	var ok := BotaoInicio.new("Correr", true, COR_BOTAO, 40, 88, 360)
	ok.pressed.connect(func():
		fundo.queue_free()
		_janela_aberta = false
		_chefao_aprova()
		_oferecer_avisos()
		_intersticial_da_liga())
	p.corpo.add_child(ok)
	# Marco: o jornal entra girando, como nas manchetes dos filmes da época, e o
	# aparelho vibra (mais na divisão nova).
	celebrar(4 if nova_modalidade else 3)
	Sons.tocar_ui(self, "passagem", -6.0, 0.8)
	if not Preferencias.reduzir_animacoes:
		p.pivot_offset = Vector2(310, 420)
		p.scale = Vector2(0.15, 0.15)
		p.rotation = -TAU * 2.0
		var tw := p.create_tween().set_parallel()
		tw.tween_property(p, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation", deg_to_rad(-2.5), 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		p.rotation = deg_to_rad(-2.5)


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
	# A página do livro-caixa do chefão: papel pautado, margem vermelha, uma
	# linha por divisão (a parte de cada uma na renda) e o total sublinhado.
	var lv: Dictionary = CenaQuadrinho.carregar("livro")
	var p := LivroCaixa.new()
	p.custom_minimum_size = Vector2(640, 0)
	centro.add_child(p)
	var t := IdleUI.rotulo(String(lv.get("titulo", "LIVRO-CAIXA")), 36, LivroCaixa.TINTA, p.corpo, "deco")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fora := maxf(Time.get_unix_time_from_system() - estado.salvo_em, 0.0)
	var tempo := "%d h %02d min" % [int(fora / 3600.0), int(fmod(fora, 3600.0) / 60.0)] if fora >= 3600.0 \
			else "%d min" % maxi(int(fora / 60.0), 1)
	IdleUI.rotulo(String(lv.get("fora", "{tempo}")).format({"tempo": tempo}), 20, LivroCaixa.TINTA, p.corpo, "fala")
	var total_renda := maxf(estado.renda_s(), 0.0001)
	for id in estado.liberadas():
		var parte := ganho * estado.renda_modalidade(id) / total_renda
		if parte < 1.0:
			continue
		p.linha(String(estado.dados_modalidade(id).get("nome", id)), "$" + curto(parte))
	p.total(String(lv.get("total", "TOTAL")), "$" + curto(ganho))
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 12)
	p.corpo.add_child(botoes)
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
		p.pivot_offset = Vector2(320, 200)
		p.rotation = deg_to_rad(4.0)
		p.scale = Vector2(0.85, 0.85)
		var tw := p.create_tween().set_parallel()
		tw.tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation", deg_to_rad(-1.0), 0.3)


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
	_barra.avisar("metas", estado.metas_prontas(agora) > 0 or estado.presente_pronto(agora) or estado.desafio_pronto())


# --- personagens de passagem ------------------------------------------------------

var _painel_oficina: Control
var _tony_em := -INF
const TONY_INTERVALO_S := 30.0  # apresentação, não balanceamento


## O Tony espia por cima da oficina quando uma melhoria é comprada (no máximo
## uma vez a cada TONY_INTERVALO_S).
func _tony_espia() -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _tony_em < TONY_INTERVALO_S or _painel_oficina == null or Preferencias.reduzir_animacoes \
			or not _painel_oficina.is_visible_in_tree():
		return
	_tony_em = agora
	var t := TextureRect.new()
	t.texture = IdleUI.busto_de("res://arte/fastfather/abertura/tony_1.webp", 1.0)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT  # escala uniforme
	t.size = Vector2(110, 110)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.z_index = 2
	var base := _painel_oficina.global_position + Vector2(_painel_oficina.size.x - 300.0, 0.0)
	t.position = base
	add_child(t)
	var tw := t.create_tween()
	tw.tween_property(t, "position:y", base.y - 96.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)
	tw.tween_property(t, "position:y", base.y, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(t.queue_free)


## Liga nova: o chefão aparece na mesa por um instante, aprovando.
func _chefao_aprova() -> void:
	if Preferencias.reduzir_animacoes:
		return
	var falas: Array = CenaQuadrinho.carregar("chefao_aprova").get("falas", [])
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var img := TextureRect.new()
	img.texture = load("res://arte/fastfather/abertura/chefe_3.webp")
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT  # escala uniforme
	img.size = Vector2(440, 393)  # a proporção da arte (1096 × 978)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var corrida_r: Rect2 = _paginas["corrida"].get_global_rect()
	img.position = Vector2(corrida_r.position.x + 12.0, corrida_r.get_center().y + 60.0)
	c.add_child(img)
	if not falas.is_empty():
		var b := PanelContainer.new()
		b.add_theme_stylebox_override("panel", IdleUI.caixa(IdleUI.COR_MARFIM, 14, 12, IdleUI.COR_CARVAO, 3))
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		IdleUI.rotulo(String(falas[randi() % falas.size()]), 28, IdleUI.COR_CARVAO, b, "fala")
		b.position = img.position + Vector2(300, -10)
		c.add_child(b)
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.6)
	tw.tween_property(c, "modulate:a", 0.0, 0.3)
	tw.tween_callback(c.queue_free)


## Trava de projetor, como nos cinejornais da época: a imagem pula dois quadros
## e escurece um instante (largada e chegada).
func _trava_projetor() -> void:
	if Preferencias.reduzir_animacoes or _quadro_corrida == null or not _quadro_corrida.is_visible_in_tree():
		return
	var alvo := _visual3d
	var y0 := alvo.position.y
	var tw := alvo.create_tween()
	tw.tween_property(alvo, "position:y", y0 - 14.0, 0.03)
	tw.parallel().tween_property(alvo, "modulate", Color(0.7, 0.7, 0.7), 0.03)
	tw.tween_property(alvo, "position:y", y0 + 6.0, 0.04)
	tw.tween_property(alvo, "position:y", y0, 0.05)
	tw.parallel().tween_property(alvo, "modulate", Color.WHITE, 0.08)


# --- Família Fundadora ----------------------------------------------------------

## A compra chegou (ou já era da conta): o pacote entra uma vez.
func _comprou(sku: String) -> void:
	if sku != String(estado.cfg.get("fundadora", {}).get("sku", "")):
		return
	if estado.conceder_fundadora(dados):
		estado.salvar(Time.get_unix_time_from_system())
		_pilotos.atualizar()
		_garagem.mostrar_divisao()
		_hud.evento("FAMÍLIA FUNDADORA!", "bem-vindo à mesa do chefe", COR_OURO, 11, -1.0, true)
		celebrar(3)


## O pacote: o que vem nele e o preço da loja (sem a loja, só a vitrine).
func _abrir_fundadora() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.78)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(600, 0)
	p.add_theme_stylebox_override("panel", IdleUI.caixa(COR_CARTAO, 18, 26, COR_OURO, 2))
	centro.add_child(p)
	p.add_child(MolduraDeco.new(6.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var t := IdleUI.rotulo("FAMÍLIA FUNDADORA", 36, COR_OURO, v, "deco")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var f: Dictionary = estado.cfg.get("fundadora", {})
	for item in ["Sem anúncio entre as ligas", "O carro dourado da família",
			"Um capanga de nível %d" % int(f.get("capanga_nivel", 1)), "Compra única, para sempre"]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		v.add_child(h)
		IdleUI.icone("icone_ok", 32, h, IdleUI.COR_GANHO)
		IdleUI.rotulo(item, 24, IdleUI.COR_TEXTO, h)
	var sku := String(f.get("sku", ""))
	if estado.fundadora:
		var j := IdleUI.rotulo("JÁ É DA FAMÍLIA", 26, IdleUI.COR_GANHO, v, "display")
		j.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif loja.disponivel():
		var b := IdleUI.botao("ENTRAR · " + String(loja.precos.get(sku, "")), COR_OURO, 26, 76, v)
		b.pressed.connect(func():
			loja.comprar(sku)
			fundo.queue_free())
	else:
		var n := IdleUI.rotulo("A compra abre na versão da loja.", 20, IdleUI.COR_SECUNDARIA, v, "regular")
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fechar := IdleUI.botao("FECHAR", COR_BOTAO, 24, 64, v)
	fechar.pressed.connect(fundo.queue_free)


# --- save na nuvem ---------------------------------------------------------------

## A conta Google tem um jogo mais adiantado que o do aparelho: aparelho sem
## progresso (reinstalou, trocou de celular) carrega direto; com progresso,
## pergunta.
func _nuvem_achou(save: Dictionary) -> void:
	if estado.corridas == 0:
		_restaurar(save)
		return
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(580, 0)
	p.add_theme_stylebox_override("panel", IdleUI.caixa(COR_CARTAO, 18, 24))
	centro.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	var t := IdleUI.rotulo("JOGO SALVO NA SUA CONTA", 32, COR_OURO, v, "deco")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c := cidade(int(save.get("cidade", 0)))
	var texto := IdleUI.rotulo("Sua conta Google tem um jogo mais adiantado que o deste celular: %s, %d corridas." % [
			String(c["lugar"]), int(save.get("corridas", 0))], 22, IdleUI.COR_TEXTO, v, "regular")
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x = 532
	var carregar := IdleUI.botao("CARREGAR", COR_OURO, 26, 76, v)
	carregar.pressed.connect(_restaurar.bind(save))
	var ficar := IdleUI.botao("FICAR COM ESTE", COR_BOTAO, 24, 68, v)
	ficar.pressed.connect(fundo.queue_free)


func _restaurar(save: Dictionary) -> void:
	var f := FileAccess.open(IdleEstado.ARQUIVO_SAVE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(save))
	f.close()
	set_process(false)  # o salvamento automático não grava o jogo antigo por cima
	get_tree().reload_current_scene()


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
	IdleUI.rotulo("CONFIGURAÇÕES", 32, Color.WHITE, v, "deco")
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
	if nuvem.disponivel():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		v.add_child(h)
		var l := IdleUI.rotulo("CONTA GOOGLE", 26, IdleUI.COR_TEXTO, h)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if nuvem.conectado:
			IdleUI.rotulo("SALVANDO", 22, IdleUI.COR_GANHO, h)
		else:
			var entrar := IdleUI.botao("ENTRAR", COR_BOTAO, 22, 56, h)
			entrar.pressed.connect(nuvem.entrar)
	var fund := IdleUI.botao("FAMÍLIA FUNDADORA", COR_OURO, 24, 64, v)
	fund.pressed.connect(_abrir_fundadora)
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
## O número troca como placar de estação: a placa fecha na vertical, troca o
## texto e abre (só quando muda).
func _virar_placa(l: Label, texto: String) -> void:
	if l.text == texto:
		return
	if l.text == "" or Preferencias.reduzir_animacoes or not l.is_visible_in_tree():
		l.text = texto
		return
	if l.has_meta("virando"):
		l.set_meta("proximo", texto)
		return
	l.set_meta("virando", true)
	l.pivot_offset = l.size * 0.5
	var tw := l.create_tween()
	tw.tween_property(l, "scale:y", 0.0, 0.08).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		l.text = String(l.get_meta("proximo", texto))
		l.remove_meta("proximo"))
	tw.tween_property(l, "scale:y", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): l.remove_meta("virando"))


func ganho_flutuante(valor: float) -> void:
	if valor < 1.0:
		return
	var origem := _dinheiro.get_global_rect()
	var largura := _dinheiro.get_theme_font("font").get_string_size(_dinheiro.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_dinheiro.get_theme_font_size("font_size")).x
	_efeitos.pipoca(Vector2(origem.position.x + largura + 70.0, origem.get_center().y), "+$" + curto(valor),
			COR_DINHEIRO, 34, 0.7)
	IdleUI.saltar(_dinheiro, 1.15)
	# O maço do caixa engorda e solta uma poeirinha de notas.
	if _maco != null and not Preferencias.reduzir_animacoes:
		_maco.pivot_offset = _maco.size * 0.5
		var tw := _maco.create_tween()
		tw.tween_property(_maco, "scale", Vector2(1.18, 1.12), 0.08)
		tw.tween_property(_maco, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_efeitos.faiscas(_maco.get_global_rect().get_center(), IdleUI.COR_LATAO_CLARO, 8)


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
	_passo_previsao()
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
	if chave == _previsao_chave or _previsao_tarefa >= 0 or not _previsao_aos_poucos.is_empty():
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
	if not previsao_sem_threads:
		_previsao_tarefa = WorkerThreadPool.add_task(_prever.bind(chave, variantes, pista, voltas, params))
	else:
		_previsao_aos_poucos = {"chave": chave, "variantes": variantes, "chaves": variantes.keys(), "i": 0, "s": 0,
				"soma": 0.0, "posicoes": {}, "corrida": null, "pista": pista, "voltas": voltas, "params": params}


## Um pedaço da previsão sem threads: a corrida da vez anda até gastar
## PREVISAO_MS_POR_QUADRO (Simulacao.iniciar/avancar, resultado igual ao de
## correr); no fim de todas, o resultado entra como o da thread.
func _passo_previsao() -> void:
	var j := _previsao_aos_poucos
	if j.is_empty():
		return
	var ate := Time.get_ticks_msec() + PREVISAO_MS_POR_QUADRO
	while Time.get_ticks_msec() < ate:
		var k = j["chaves"][j["i"]]
		if j.get("corrida") == null:
			j["corrida"] = Simulacao.iniciar(j["pista"], j["variantes"][k], j["voltas"], j["params"],
					int(SEMENTES_PREVISAO[j["s"]]), false)
		var corrida: Simulacao.Andamento = j["corrida"]
		if not corrida.avancar(maxf(1.0, ate - Time.get_ticks_msec())):
			return
		j["soma"] += IdleEstado.posicao(corrida.resultado())
		j["corrida"] = null
		j["s"] += 1
		if j["s"] >= SEMENTES_PREVISAO.size():
			j["posicoes"][k] = j["soma"] / SEMENTES_PREVISAO.size()
			j["soma"] = 0.0
			j["s"] = 0
			j["i"] += 1
			if j["i"] >= j["chaves"].size():
				_previsao_aos_poucos = {}
				if String(j["chave"]) == _chave_previsao():
					_previsao = j["posicoes"]
				else:
					_previsao_chave = ""  # mudou enquanto calculava: de novo
				return


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
## ou camarote), câmeras e as ofertas guardadas.
func _aba_aberta(a: Dictionary) -> bool:
	if a["id"] == "garagem":
		return not estado.garagem.is_empty()  # depois do primeiro carro
	if a["id"] == "rinha":
		return estado.rinha_aberta()
	return a["id"] == "corrida" or estado.tem("aba:" + String(a["id"]))


func _trapacas_liberadas() -> bool:
	return estado.cfg["melhorias"].any(func(m): return m.has("trapaca") and estado.tem("melhoria:" + String(m["id"])))


func _aplicar_desbloqueios() -> void:
	for m in estado.cfg["melhorias"]:
		var aberta := estado.tem("melhoria:" + String(m["id"]))
		_cartoes[m["id"]]["cartao"].visible = aberta
		# O que ainda não abriu não aparece; ao abrir, o cartão entra pulsando.
		var l: LadrilhoIdle = _ladrilhos.get(String(m["id"]))
		if l != null:
			if aberta and not l.visible:
				l.visible = true
				if is_inside_tree():
					IdleUI.pulsar.call_deferred(l, 1.08)
			l.visible = aberta
			l.abrir()
	_renda_caixa.visible = estado.tem("renda")
	# As trapaças só aparecem quando a primeira abre (depois da bronca do chefão).
	if _trapacas_caixa != null:
		_trapacas_caixa.visible = _trapacas_liberadas() and not dupla()
	var abas := ABAS.filter(_aba_aberta)
	_barra.definir_abas(abas)
	_barra.visible = abas.size() > 1
	if not abas.any(func(a): return _paginas[a["id"]].visible):
		_abrir("corrida")
	_tv = estado.tem("camera_tv")
	Sons.radio(not _tv)  # antes do camarote, a corrida soa como rádio de box
	_visual.pontos = not _tv
	_visual.com_rotulos = false
	_visual.visible = not _na_arena and not _tv
	_visual3d.visible = not _na_arena and _tv
	_trilho.visible = estado.tem("cameras")
	# Sem olheiros, _camera_efetiva() devolve "auto": a direção escolhe o plano.
	_marcar_camera()
	_aplicar_camera()
	if _aguardando and estado.tem("largada_auto"):
		_largar_corrida()
	_atualizar_ofertas()


func _largar_corrida() -> void:
	if not _aguardando:
		return
	if not estado.pode_correr():
		# Divisão sem o carro dela: a garagem mostra o que falta comprar.
		_garagem.mostrar_divisao()
		_abrir("garagem")
		return
	_aguardando = false
	_largar.visible = false
	_hud.contagem = _contagem
	_largada_fiscal()
	_sons.largada(false)


## A próxima conversa da escada, quando nada mais está na frente e a corrida
## está parada (grid ou depois da chegada).
func _checar_conversa() -> void:
	if _titulo != null or _abertura != null or _loja_abertura != null or _conversa != null or _janela_aberta or _config != null or _coleta != null or _guia.ativo():
		return
	if not (_aguardando or _pausa >= 0.0):
		return
	# Uma conversa por corrida: duas funções novas de uma vez se atropelam.
	# (Na volta da 1ª corrida vêm duas seguidas: a bronca do chefe e o Theo.)
	var d := estado.proxima_conversa()
	if d.is_empty():
		return
	if estado.corridas == _conversa_em and estado.corridas > 1 and not bool(d.get("avulsa", false)):
		return
	_conversa_em = estado.corridas
	estado.oferecer(String(d["id"]))
	estado.salvar(Time.get_unix_time_from_system())
	_abrir_conversa(d)


func _abrir_conversa(d: Dictionary) -> void:
	if not d.has("cena") and String(d.get("fala", "")) == "":
		# Sem fala (a primeira vitória, até o texto do usuário): só o que ela libera.
		_conversa_fechou(d, true)
		return
	if d.has("cena"):
		# Cena em quadrinho (o Tony e o sobrinho, data/idle/cenas.json).
		var q := CenaQuadrinho.new(String(d["cena"]))
		_conversa = q
		q.fechou.connect(func(): _conversa_fechou(d, true))
		add_child(q)
		return
	var c := ConversaIdle.new(d, estado)
	_conversa = c
	add_child(c)
	c.fechou.connect(func(aceitou: bool): _conversa_fechou(d, aceitou))


func _conversa_fechou(d: Dictionary, aceitou: bool) -> void:
	_conversa = null
	var id := String(d["id"])
	if "pintura_nova" in d.get("libera", []) and estado.ferro_velho:
		# Depois da primeira vitória o Tony pinta o carro do ferro-velho, na frente do jogador.
		estado.ferro_velho = false
		var carro := estado.carro_da_modalidade()
		if not carro.is_empty():
			var rp := RepinturaIdle.new(estado, carro)
			_conversa = rp
			rp.fechou.connect(func(): _conversa = null)
			add_child(rp)
		_nova_pintura_jogador()
	if id in ["inicio", "ultrapassagem"]:
		_largar_na_compra = true
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
	estado.salvar(Time.get_unix_time_from_system())


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


## Música mais baixa sob o motor da corrida; o ambiente do box só nas telas sem
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
	# A câmera dupla recolhe a oficina: a dica volta para a câmera padrão.
	if dupla() and alvo != "" and alvo != "cameras":
		_trocar_camera("ciclo")
	if alvo.begins_with("melhoria:") or alvo in ["largar", "subir", "cameras", "previsao"] or alvo.begins_with("oferta:"):
		_abrir("corrida")
	var andar: Dictionary = _cartoes.get(alvo.trim_prefix("melhoria:"), {}) if alvo.begins_with("melhoria:") else \
			(_cartoes.get("motor", {}) if alvo == "previsao" else {})
	var lad: Control = _ladrilhos.get(alvo.trim_prefix("melhoria:")) if alvo.begins_with("melhoria:") else null
	if lad != null and lad.get_parent().get_parent() is ScrollContainer:
		(lad.get_parent().get_parent() as ScrollContainer).ensure_control_visible(lad)
	elif not andar.is_empty() and _painel_lista.visible:
		_complexo.ensure_control_visible(andar["cartao"])
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
		"toque":
			c = _toque_medidor
		"previsao":
			c = _ladrilhos["motor"].efeito if _ladrilhos.has("motor") else _cartoes["motor"]["previsao"]
	if alvo.begins_with("melhoria:"):
		var lad: LadrilhoIdle = _ladrilhos.get(alvo.trim_prefix("melhoria:"))
		c = lad.botao if lad != null else _cartoes.get(alvo.trim_prefix("melhoria:"), {}).get("botao")
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


## Dinheiro do topo depois de comprar um carro (cai na hora).
func _atualizar_dinheiro_garagem() -> void:
	_dinheiro_mostrado = estado.dinheiro
	_garagem.atualizar()


## O carro pintado (fim do ferro-velho): a garagem mostra na hora; a corrida,
## a partir da próxima largada.
func _nova_pintura_jogador() -> void:
	if _garagem != null:
		_garagem.mostrar_divisao()


## Vitória: o flash do fotógrafo e a foto da chegada em sépia, num papel de
## jornal com a legenda, que fica um instante no canto do telão e some.
func _foto_vitoria() -> void:
	if Preferencias.reduzir_animacoes or _quadro_corrida == null or not _quadro_corrida.is_visible_in_tree():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var r := get_viewport().get_final_transform() * _quadro_corrida.get_global_rect()
	r = r.intersection(Rect2(Vector2.ZERO, img.get_size()))
	if r.size.x < 8.0 or r.size.y < 8.0:
		return
	var foto := ImageTexture.create_from_image(img.get_region(Rect2i(r)))
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 0.95, 0.95)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quadro_corrida.add_child(flash)
	Sons.tocar_ui(self, "flash", -3.0)  # o flash de magnésio
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.35)
	tw.tween_callback(flash.queue_free)
	var papel := PanelContainer.new()
	papel.add_theme_stylebox_override("panel", IdleUI.caixa(JornalIdle.PAPEL, 2, 10, Color("8a7a5a"), 1))
	papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	papel.add_child(v)
	var cab := IdleUI.rotulo(JornalIdle.NOME + " · EXTRA!", 15, JornalIdle.TINTA, v, "deco")
	cab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tr := TextureRect.new()
	tr.texture = foto
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # escala uniforme, recorta
	tr.custom_minimum_size = Vector2(300, 190)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://idle/sepia.gdshader")
	sm.set_shader_parameter("passo", 3.0)
	tr.material = sm
	v.add_child(tr)
	var leg := IdleUI.rotulo("VITÓRIA · " + String(estado.dados_liga()["nome"]).to_upper(), 16, JornalIdle.TINTA, v, "display")
	leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quadro_corrida.add_child(papel)
	papel.position = Vector2(_quadro_corrida.size.x - 340, 70)
	papel.pivot_offset = Vector2(160, 120)
	papel.rotation = deg_to_rad(8.0)
	papel.scale = Vector2(1.6, 1.6)
	papel.modulate.a = 0.0
	var t2 := papel.create_tween()
	t2.tween_interval(0.25)
	t2.set_parallel()
	t2.tween_property(papel, "modulate:a", 1.0, 0.2)
	t2.tween_property(papel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(papel, "rotation", deg_to_rad(-4.0), 0.35)
	t2.set_parallel(false)
	t2.tween_interval(2.6)
	t2.tween_property(papel, "modulate:a", 0.0, 0.4)
	t2.tween_callback(papel.queue_free)


## O locutor de rádio (arte/sons/locutor_*.ogg, quando gravados): a voz passa
## pelo filtro de rádio do barramento da corrida. Sem o arquivo, nada toca.
func _locutor(nome: String) -> void:
	if ResourceLoader.exists(Sons.PASTA + nome + ".ogg"):
		Sons.tocar_ui(self, nome, -2.0, 1.0, false)


## Fim de uma luta da Rinha: o prêmio sobe para o dinheiro; a vitória dos
## rapazes avisa mesmo com o jogador em outra aba.
func _rinha_terminou(pos: int, premio: float) -> void:
	_dinheiro_mostrado = minf(_dinheiro_mostrado, estado.dinheiro)
	if premio >= 1.0:
		ganho_flutuante(premio)
	if pos == 1 and not _rinha.is_visible_in_tree() and _conversa == null:
		mostrar_aviso("RINHA: OS CAPANGAS VENCERAM", "+$" + curto(premio))
	estado.salvar(Time.get_unix_time_from_system())
