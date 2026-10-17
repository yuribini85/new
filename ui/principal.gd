extends Control
## Tela principal (retrato): saldo e dia no topo, abas embaixo. Processa a
## fila a cada segundo para aplicar corridas concluídas com o app aberto.

var dados: Node
var jogador: Node
var _cabecalho: Cabecalho
## Telas visitadas (para o voltar do cabeçalho), a mais recente no fim.
var _historico: Array[int] = []
## Telas que precisam ser refeitas antes de aparecer (atualizar).
var _sujas := {}
const HISTORICO_MAX := 20
var _meta: Array = []  # saldo e moeda: meta-jogo, somem durante a corrida
var _nav: Control
var _modo_corrida := false
var _abas: TabContainer
var _todas: Array = []
var _botoes: Array = []
var _sobre: Sobreposicao
var _capa: TextureRect
var _dialogo: Dialogo
var _destaque: Destaque
## Âncoras fora das abas (topo e navegação) para os destaques do tutorial.
var _ancoras := {}
## Cena com lembrete esperando: {"id", "t"} (segundos desde o fim da cena).
var _lembrete := {}
const LEMBRETE_S := 8.0  # apresentação: quanto esperar antes de lembrar
## Nome de cada aba no trigger da história (ABA:<nome>).
const NOMES_ABA := ["GARAGEM", "LOJA", "OFICINA", "EVENTOS", "CORRIDA", "LICENCAS", "EQUIPE", "ARENA"]
var _ao_vivo: Button
## Destinos da barra de baixo: [rótulo, índice da aba, ícone, ícone provisório?]. Oficina e Corrida são
## telas internas (de Garagem e Correr), abertas pelo caminho do jogo.
const DESTINOS := [["Oficina", 0, "aba_garagem"], ["Lojas", 1, "aba_mercado"], ["Corridas", 3, "aba_competicoes"],
	["Carreira", 5, "aba_carreira"], ["Equipe", 6, "aba_equipe", "icone_piloto"], ["Arena", ABA_ARENA, "aba_arena", "icone_estrela"]]
## Arena (decisão 49): a inscrição; a luta abre por cima de tudo (LutaArena).
const ABA_ARENA := 7
## Aba que só aparece quando a história libera (a equipe do jogador).
const ABA_EQUIPE := 6
const PAI := {2: 0, 4: 3}
## Título de cada tela no cabeçalho.
## Janela do resultado: fecha sozinha depois disso (se o jogador deixar).
const FECHAR_RESULTADO_S := 30.0
var _resultado_aberto := 0
const TITULOS := ["Oficina", "Lojas", "Oficina", "Corridas", "Corrida", "Carreira", "Equipe", "Arena"]
## Objetivo atual da carreira; quando avança, o jogador é avisado.
var _objetivo := -1

## Tamanhos para tela de celular em retrato (viewport 720 de largura).
const FONTE := 30
const FONTE_TITULO := 38
const ALTURA_BOTAO := 124


func _ready() -> void:
	dados = get_node("/root/Dados")
	jogador = get_node("/root/Jogador")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_simbolos()
	Preferencias.carregar()
	theme = _tema()
	var fundo := ColorRect.new()
	fundo.color = Aba.COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	# As telas começam no topo absoluto (o cenário passa por trás do cabeçalho,
	# que flutua por cima); só as laterais e o pé têm margem.
	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	margem.add_theme_constant_override("margin_bottom", 16 + int(AreaSegura.base(get_viewport_rect().size.x)))
	for lado in ["left", "right", "top"]:
		margem.add_theme_constant_override("margin_" + lado, 0)
	add_child(margem)
	var raiz := VBoxContainer.new()
	margem.add_child(raiz)

	if jogador.economia == null or jogador.fila_ctrl == null:
		for lado in ["left", "right", "top"]:
			margem.add_theme_constant_override("margin_" + lado, 16)
		_tela_pendencias(raiz)
		return

	_cabecalho = Cabecalho.new()
	_cabecalho.definir_area_segura(AreaSegura.topo(get_viewport_rect().size.x))
	_cabecalho.voltar.connect(_voltar_tela)
	_cabecalho.configuracoes.connect(_abrir_configuracoes)
	_cabecalho.combustivel.connect(func(): _abrir_combustivel())
	_cabecalho.acelerar.connect(_abrir_aceleracao)
	_cabecalho.garagem.connect(func(): _todas[0].abrir_garagem())
	_cabecalho.pintura.connect(_abrir_cabine)
	_cabecalho.nomes.connect(func():
		_todas[1].mostrar_nomes = not _todas[1].mostrar_nomes
		_cabecalho.definir_nomes(_todas[1].mostrar_nomes))
	_cabecalho.mapa.connect(func(): _todas[1].voltar_ao_mapa())
	_cabecalho.corrida.connect(func():
		if jogador.fila.is_empty():
			_sobre.avisar("Nenhuma corrida em andamento.", false)
		else:
			_ir_para(4))
	_ancoras["SALDO"] = _cabecalho.painel
	_ancoras["ACELERAR"] = _cabecalho.marcador
	_meta = [_cabecalho.painel]
	_abas = TabContainer.new()
	_abas.tabs_visible = false  # navegação pelos botões grandes embaixo
	# Moldura sem layout: o tamanho mínimo das abas não passa para a tela. Se
	# algum conteúdo pedir mais largura que o celular, ele é cortado dentro da
	# aba, mas o topo e a navegação nunca saem da tela.
	var moldura := Control.new()
	moldura.size_flags_vertical = Control.SIZE_EXPAND_FILL
	moldura.clip_contents = true
	raiz.add_child(moldura)
	_abas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	moldura.add_child(_abas)
	# Tutorial do dono: enquanto a tela atual não foi apresentada (o começo do
	# jogo, antes do primeiro toque na barra), a oficina no lugar dela; a tela
	# só abre com o toque no botão que o tutorial destaca.
	_capa = TextureRect.new()
	_capa.texture = Assets.get_asset(CENARIO_NOME, "cenario")
	_capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # escala uniforme
	_capa.modulate = Color(0.55, 0.55, 0.55)
	_capa.mouse_filter = Control.MOUSE_FILTER_STOP
	_capa.visible = false
	moldura.add_child(_capa)
	var eventos := preload("res://ui/aba_eventos.gd").new(dados, jogador)
	_todas = [
		preload("res://ui/aba_garagem.gd").new(dados, jogador),
		preload("res://ui/aba_loja.gd").new(dados, jogador),
		Aba.new(dados, jogador, "Oficina antiga"),  # índice 2 reservado (a Oficina antiga saiu)
		eventos,
		preload("res://ui/aba_corrida.gd").new(dados, jogador),
		preload("res://ui/aba_licencas.gd").new(dados, jogador),
		preload("res://ui/aba_equipe.gd").new(dados, jogador),
		preload("res://ui/aba_arena.gd").new(dados, jogador),
	]
	for a in _todas:
		a.reservar_topo(_cabecalho.altura_total())
		_abas.add_child(a)
		a.mudou.connect(atualizar)
		a.ir_para.connect(func(i):
			_sobre.fechar()  # ex.: cenário aberto nas Configurações
			_sujar_todas()
			_ir_para(i))
	_cabecalho.definir_nomes(_todas[1].mostrar_nomes)
	_todas[4].dialogo_aberto = func() -> bool: return _dialogo != null and _dialogo.ocupado()
	_todas[ABA_ARENA].luta.connect(_abrir_luta)
	_todas[5].vinheta.connect(_abrir_vinheta)
	eventos.correr_iniciado.connect(func():
		# Conversa aberta na inscrição (ex.: a do campeonato): o grid espera.
		if _dialogo != null and _dialogo.ocupado():
			_todas[4].segurar()
			_quando_dialogo_acabar(_todas[4].liberar_largada)
		_ir_para(4))
	_todas[4].pular.connect(func():
		RegistroSessao.pulo()
		jogador.fila_ctrl.adiantar(Aceleracao.agora(jogador))
		_processar_fila())
	_ao_vivo = Button.new()
	_ao_vivo.custom_minimum_size = Vector2(0, 64)
	_ao_vivo.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ao_vivo.clip_text = true
	_ao_vivo.add_theme_font_size_override("font_size", 25)
	var sb_vivo := StyleBoxFlat.new()
	sb_vivo.bg_color = Color(0.1, 0.34, 0.2)
	sb_vivo.set_corner_radius_all(10)
	sb_vivo.set_content_margin_all(10)
	for estado in ["normal", "hover", "pressed", "focus"]:
		_ao_vivo.add_theme_stylebox_override(estado, sb_vivo)
	Tipografia.area_toque(_ao_vivo, 64)  # faixa de 64 px, toque de 88
	_ao_vivo.pressed.connect(func(): _ir_para(4))
	# Faixa ao vivo e navegação com a margem lateral (as telas vão até a beira).
	var pe := MarginContainer.new()
	pe.add_theme_constant_override("margin_left", 16)
	pe.add_theme_constant_override("margin_right", 16)
	raiz.add_child(pe)
	var pe_v := VBoxContainer.new()
	pe.add_child(pe_v)
	pe_v.add_child(_ao_vivo)
	_nav = _navegacao()
	pe_v.add_child(_nav)
	add_child(_cabecalho)  # por cima das telas, abaixo de avisos e diálogos
	_sobre = Sobreposicao.new()
	add_child(_sobre)
	for a in _todas:
		a.aviso.connect(_avisar)
		a.painel.connect(_sobre.abrir)
		a.painel_estilo.connect(_sobre.abrir)
		a.fechar_painel.connect(_sobre.fechar)
		a.sem_combustivel.connect(_abrir_combustivel)
		a.loja_real.connect(_abrir_loja_real)
	if jogador.historia != null:
		# O destaque fica abaixo do diálogo: o resto da tela escurece, a caixa não.
		_destaque = Destaque.new()
		add_child(_destaque)
		_destaque.alvo_mudou.connect(func(r: Rect2): _dialogo.evitar(r))
		_dialogo = Dialogo.new(jogador.historia)
		_dialogo.espera = _cena_espera
		add_child(_dialogo)
		jogador.historia.cena.connect(_dialogo.enfileirar)
		jogador.historia.cena.connect(_cena_pedida)
		_dialogo.acao.connect(_acao_tutorial)
		_dialogo.terminou.connect(_cena_terminou)
	if jogador.carro_ativo < 0 and not jogador.garagem.lista().is_empty():
		jogador.carro_ativo = jogador.garagem.lista()[0].uid
	Escalacao.migrar(jogador)
	EquipeJogador.migrar(dados, jogador)
	atualizar()
	_checar_arena.call_deferred()

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_processar_fila)
	timer.timeout.connect(_checar_licencas)
	timer.timeout.connect(_atualizar_combustivel)
	timer.timeout.connect(_atualizar_ao_vivo)
	timer.timeout.connect(_foco_corrida)
	timer.timeout.connect(_registrar_fila)
	timer.timeout.connect(_atualizar_fps)
	timer.timeout.connect(_contar_lembrete)
	timer.timeout.connect(_atualizar_aceleracao)
	timer.timeout.connect(_patrocinio)
	_atualizar_aceleracao()
	add_child(timer)
	var save_manager := get_node("/root/SaveManager")
	if save_manager.aviso != "":
		_sobre.abrir("Save", func(v): _todas[0].rotulo(save_manager.aviso, 0, Color.WHITE, v))
	_abrir_volta(save_manager.relatorio_offline)
	# Decisão 110: a cobrança do Google Play, quando o plugin está no export.
	if Engine.has_singleton(LojaPlay.SINGLETON):
		var ponte := LojaPlay.new(dados)
		ponte.name = "LojaPlay"
		add_child(ponte)
		LojaReal.ponte = ponte
		ponte.concedido.connect(func(id: String):
			if not LojaReal.comprado(dados, jogador, id):
				compra_confirmada(id))
		ponte.erro.connect(func(t: String): _sobre.avisar("Compra não concluída: %s" % t, false))
	_fila_vista = jogador.fila
	RegistroSessao.inicio(jogador)
	RegistroSessao.corridas(save_manager.relatorio_offline, dados)
	if jogador.historia != null:
		historia_acao.connect(_acao_historia)
		_abertura()
		_conversas_das_corridas(save_manager.relatorio_offline.get("corridas", []), save_manager.vitorias_antes)


func _navegacao() -> HBoxContainer:
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 8)
	for d in DESTINOS:
		var b := Button.new()
		b.text = String(d[0]).to_upper()
		b.add_theme_font_override("font", Tipografia.fonte("medium"))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, ALTURA_BOTAO)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 23)
		b.clip_text = true
		# Selecionado: sem fundo; só um filete ocre em cima e o texto em ocre.
		var vazio := StyleBoxFlat.new()
		vazio.bg_color = Color(0, 0, 0, 0)
		vazio.set_content_margin_all(8)
		var marcado := vazio.duplicate()
		marcado.border_color = Aba.COR_DESTAQUE
		marcado.border_width_top = 3
		marcado.expand_margin_left = -28
		marcado.expand_margin_right = -28
		for estado in ["normal", "hover", "focus", "disabled"]:
			b.add_theme_stylebox_override(estado, vazio)
		for estado in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(estado, marcado)
		b.add_theme_color_override("font_color", Color(0.7, 0.73, 0.78))
		b.add_theme_color_override("font_hover_color", Color(0.7, 0.73, 0.78))
		b.add_theme_color_override("font_pressed_color", Aba.COR_DESTAQUE)
		b.add_theme_color_override("font_hover_pressed_color", Aba.COR_DESTAQUE)
		var ic := Aba.icone_reduzido(d[2], 78)
		if ic == null and d.size() > 3:
			ic = Aba.icone_reduzido(d[3], 78)  # ícone provisório até a arte chegar
		if ic != null:
			b.icon = ic
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			# O ícone diz para onde vai; o texto, menor, só confirma.
		b.pressed.connect(func(): Sons.tocar_ui(self, "toque", -6.0))
		barra.add_child(b)
		_botoes.append(b)
		if d[1] == 1:
			# LOJAS na barra abre sempre o mapa, não a última loja visitada.
			b.pressed.connect(func():
				if not _todas[1].no_mapa():
					_todas[1].voltar_ao_mapa()
				_ir_para(1))
		else:
			b.pressed.connect(_ir_para.bind(d[1]))
		_ancoras["NAV_" + NOMES_ABA[d[1]]] = b
	# Começa na primeira tela que o tutorial já apresentou (a Oficina só depois dele).
	var inicio := 0
	for d in DESTINOS:
		if apresentada(int(d[1])):
			inicio = int(d[1])
			break
	_ir_para.call_deferred(inicio)
	return barra


## A aba Equipe fica oculta até a equipe do jogador existir (documento, seção 29).
func _atualizar_nav() -> void:
	var cinco := EquipeJogador.criada(jogador)
	for k in _botoes.size():
		if DESTINOS[k][1] == ABA_EQUIPE:
			_botoes[k].visible = cinco
		else:
			_botoes[k].visible = apresentada(DESTINOS[k][1])
		# Seis destinos (com a Equipe): texto menor para caberem.
		_botoes[k].add_theme_font_size_override("font_size", 17 if cinco else 20)


## Tutorial do dono (pedido do usuário): o que a Mara ainda não apresentou
## fica oculto. Uma tela aparece quando o tutorial a destaca ou abre
## (APRESENTADA_<ABA>) ou, em saves antigos, pelo passo que já passou.
const APRESENTADA_POR := {0: "GARAGE_TUTORIAL_SEEN", 1: "GRID_INTRO", 3: "PILOT_HIRED", 5: "GRID_INTRO",
		ABA_EQUIPE: "FIRST_CAR", ABA_ARENA: "ARENA_INTRO"}


func apresentada(aba: int) -> bool:
	if jogador.historia == null or jogador.personagem != "dono":
		return true
	aba = PAI.get(aba, aba)
	# As Lojas também com carro na garagem (o jogador já esteve nelas).
	if aba == 1 and jogador.garagem != null and not jogador.garagem.lista().is_empty():
		return true
	return not APRESENTADA_POR.has(aba) or jogador.flags.has(APRESENTADA_POR[aba]) \
			or jogador.flags.has("APRESENTADA_" + NOMES_ABA[aba]) \
			or (aba == ABA_ARENA and jogador.flags.has(EquipeJogador.FLAG_ARENA))


func _apresentar(aba: int) -> void:
	aba = PAI.get(aba, aba)
	if not apresentada(aba):
		jogador.flags["APRESENTADA_" + NOMES_ABA[aba]] = true
		_atualizar_nav()


func _ir_para(i: int, voltando := false) -> void:
	if _destaque != null:
		_destaque.limpar()
	# Histórico real de navegação: a tela de onde se saiu (não ao voltar).
	if not voltando and i != _abas.current_tab and _cabecalho != null:
		_historico.append(_abas.current_tab)
		if _historico.size() > HISTORICO_MAX:
			_historico.pop_front()
	_abas.current_tab = i
	_reconstruir(i)
	_liberar_escondidas()
	if jogador.historia != null:
		jogador.historia.disparar("ABA:" + NOMES_ABA[i])
	RegistroSessao.tela(i)
	var destino: int = PAI.get(i, i)
	for k in _botoes.size():
		_botoes[k].button_pressed = DESTINOS[k][1] == destino
	_cabecalho.definir_titulo(TITULOS[i].to_upper())
	_cabecalho.definir_volta(not _historico.is_empty())
	_cabecalho.mostrar_garagem(i == 0)
	_cabecalho.mostrar_nomes(i == 1 and _todas[1].no_mapa())
	_cabecalho.mostrar_mapa(i == 1 and not _todas[1].no_mapa())
	_cabecalho.mostrar_corrida(i != 4)
	_atualizar_ao_vivo()
	_foco_corrida()
	_atualizar_capa()


## A capa (a oficina) fica sobre a tela atual enquanto ela não foi apresentada.
func _atualizar_capa() -> void:
	if _capa == null:
		return
	_capa.visible = not apresentada(_abas.current_tab)
	if _capa.visible:
		_cabecalho.definir_titulo("WRECKAGE")


## Corridas aceleradas (decisão 39): regras de data/monetizacao.json.
func _regras_aceleracao() -> Dictionary:
	return dados.monetizacao().get("aceleracao", {})


## O marcador ACELERAR entra depois do tutorial: a Mara o apresenta no
## primeiro treino de licença (CW_L03, ação UNLOCK_ACELERAR). Sem história, já
## vem liberado.
const FLAG_ACELERAR := "ACELERAR_LIBERADO"


func acelerar_liberado() -> bool:
	if jogador.historia == null or jogador.personagem != "dono":
		return true
	return jogador.flags.has(FLAG_ACELERAR) or jogador.flags.has("FIRST_TRAINING_STARTED")


## A primeira ativação é por conta da casa; as seguintes, com o vídeo.
func _acelerar_gratis() -> bool:
	return jogador.aceleracao.is_empty()


func _atualizar_aceleracao() -> void:
	if _cabecalho != null:
		_cabecalho.marcador.visible = not _regras_aceleracao().is_empty() and acelerar_liberado()
		_cabecalho.definir_aceleracao(Aceleracao.restante_s(jogador),
				float(jogador.aceleracao.get("fator", _regras_aceleracao().get("fator", 2.0))))


## Tela da aceleração (marcador do cabeçalho): o que faz, quanto falta, o vídeo
## e a compra Sem anúncios.
func _abrir_aceleracao() -> void:
	var r := _regras_aceleracao()
	if r.is_empty():
		return
	var fator := roundi(float(r["fator"]))
	var minutos := roundi(float(r["duracao_s"]) / 60.0)
	_sobre.abrir("Corridas aceleradas", func(v):
		var aba: Aba = _todas[0]
		var c := aba.cartao(Cabecalho.COR_NUMERO, v)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		c.add_child(h)
		var ic := IconeVetor.new("acelerar", Cabecalho.COR_NUMERO)
		ic.custom_minimum_size = Vector2(56, 48)
		h.add_child(ic)
		var n := Label.new()
		n.text = "%d×" % fator
		Tipografia.numero(n, 56)
		n.add_theme_color_override("font_color", Cabecalho.COR_NUMERO)
		h.add_child(n)
		var ativa := Aceleracao.ativa(jogador)
		var st := aba.rotulo("Ativa: faltam %s" % Aceleracao.texto_tempo(Aceleracao.restante_s(jogador)) if ativa
				else "Desligada", Aba.FONTE_PEQUENA + 2, Color.WHITE if ativa else Aba.COR_SECUNDARIA, h)
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		aba.rotulo("Cada vídeo deixa as corridas %d vezes mais rápidas por %d minutos. Os prêmios são os mesmos: "
				% [fator, minutos] + "só o tempo de corrida passa mais depressa. Vale também com o jogo fechado, "
				+ "e um vídeo novo soma tempo." + (" A primeira é grátis." if _acelerar_gratis() else ""),
				Aba.FONTE_PEQUENA, Color.WHITE, c)
		Configuracoes.cartao_sem_anuncios(aba, v, _comprar_sem_anuncios),
		[["Ativar grátis · +%d min" % minutos, _ativar_aceleracao] if _acelerar_gratis()
				else (["Ativar · +%d min" % minutos, _ativar_aceleracao] if LojaReal.comprado(dados, jogador, "sem_anuncios")
				else ["Assistir vídeo · +%d min" % minutos, _assistir_video]), ["Fechar", func(): pass]])


## Vídeo com recompensa (por enquanto, o de teste): no fim, soma a aceleração.
func _assistir_video() -> void:
	var video := VideoRecompensa.new()
	add_child(video)
	video.terminou.connect(func(assistiu):
		if assistiu:
			_ativar_aceleracao())


func _ativar_aceleracao() -> void:
	var erro := Aceleracao.ativar(jogador, _regras_aceleracao())
	if erro != "":
		_sobre.avisar("Não deu: %s." % erro, false)
		return
	get_node("/root/SaveManager").salvar()
	_atualizar_aceleracao()
	_sobre.avisar("Corridas %d× por mais %d min (faltam %s)." % [roundi(float(jogador.aceleracao["fator"])),
			roundi(float(_regras_aceleracao()["duracao_s"]) / 60.0),
			Aceleracao.texto_tempo(Aceleracao.restante_s(jogador))])


## O combustível do cabeçalho (renova sozinho: o relógio de 1 s atualiza).
func _atualizar_combustivel() -> void:
	if _cabecalho == null:
		return
	if not Combustivel.vale(dados, jogador):
		_cabecalho.definir_combustivel(-1, 0)
		return
	_cabecalho.definir_combustivel(Combustivel.quantidade(dados, jogador), Combustivel.tanque(dados))


## Combustível (Combustivel): quanto tem, quando renova e o vídeo que enche o
## tanque. `depois` (a largada que esperava o combustível) roda com o tanque cheio.
func _abrir_combustivel(depois: Callable = Callable()) -> void:
	var cheio := Combustivel.quantidade(dados, jogador) >= Combustivel.tanque(dados)
	_sobre.abrir("Combustível", func(v):
		var aba: Aba = _todas[0]
		var c := aba.cartao(Cabecalho.COR_NUMERO, v)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		c.add_child(h)
		var ic := IconeVetor.new("combustivel", Cabecalho.COR_NUMERO)
		ic.cor_fundo = Color(0.09, 0.09, 0.1)
		ic.custom_minimum_size = Vector2(56, 52)
		h.add_child(ic)
		var n := Label.new()
		n.text = "%d/%d" % [Combustivel.quantidade(dados, jogador), Combustivel.tanque(dados)]
		Tipografia.numero(n, 56)
		n.add_theme_color_override("font_color", Cabecalho.COR_NUMERO)
		h.add_child(n)
		var renova := roundi(float(Combustivel.regras(dados)["renova_s"]) / 60.0)
		var linha := "Cada corrida ou luta da arena gasta 1. O tanque renova sozinho: +1 a cada %d min, " % renova \
				+ "mesmo com o jogo fechado."
		if not cheio:
			linha += " Próximo em %s; cheio em %s." % [Aceleracao.texto_tempo(Combustivel.proxima_s(dados, jogador)),
					Aceleracao.texto_tempo(Combustivel.cheio_em_s(dados, jogador))]
		aba.rotulo(linha, Aba.FONTE_PEQUENA, Color.WHITE, c).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not depois.is_null():
			aba.rotulo("Sem combustível para largar. Assista ao vídeo para encher o tanque.", Aba.FONTE_PEQUENA,
					Aba.COR_RUIM.lightened(0.25), c).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART,
		[["Tanque cheio", func(): pass, null, false] if cheio
				else ["Assistir vídeo · tanque cheio", func(): _video_combustivel(depois)], ["Fechar", func(): pass]])


func _video_combustivel(depois: Callable) -> void:
	var video := VideoRecompensa.new("encher o tanque de combustível", "combustivel")
	add_child(video)
	video.terminou.connect(func(assistiu):
		if not assistiu:
			return
		Combustivel.encher(jogador)
		get_node("/root/SaveManager").salvar()
		_avisar("Tanque cheio.")
		atualizar()
		if not depois.is_null():
			depois.call())


## Compra Sem anúncios (cartão da aceleração): pela loja de dinheiro real.
func _comprar_sem_anuncios() -> void:
	_comprar_real("sem_anuncios")


## Loja de dinheiro real (decisões 101 e 102): tela cheia por cima de tudo,
## aberta das Configurações, da aceleração e da contratação de pilotos.
func _abrir_loja_real() -> void:
	_sobre.fechar()
	var aberta := get_node_or_null("LojaReal")
	if aberta != null and not aberta.is_queued_for_deletion():
		return
	var l := LojaRealTela.new(dados, jogador)
	l.name = "LojaReal"
	add_child(l)
	l.comprar.connect(_comprar_real)
	l.restaurar.connect(_restaurar_compras)
	l.ir.connect(func(aba: int): _ir_para(aba))


func _comprar_real(id: String) -> void:
	var erro := LojaReal.comprar(dados, jogador, id)
	if erro != "":
		_sobre.avisar("Não deu: %s." % erro, false)


func _restaurar_compras() -> void:
	var erro := LojaReal.restaurar(dados, jogador)
	if erro != "":
		_sobre.avisar("Não deu: %s." % erro, false)


## A loja confirmou a compra (plugin da loja do aparelho; modo de teste).
func compra_confirmada(id: String) -> void:
	if LojaReal.conceder(dados, jogador, id) != "":
		return
	get_node("/root/SaveManager").salvar()
	Sons.tocar_ui(self, "moeda", -4.0)
	atualizar()
	var loja := get_node_or_null("LojaReal")
	if loja != null and not loja.is_queued_for_deletion():
		# A loja reabre com o estado novo; o pack ganha a cerimônia.
		loja.name = "LojaReal_saindo"
		loja.queue_free()
		_abrir_loja_real()
		if id == "pack_premium":
			(get_node("LojaReal") as LojaRealTela).cerimonia()
			return
	_avisar("%s: compra concluída." % String(LojaReal.produto(dados, id).get("nome", id)))


## Cabine de pintura do carro ativo: por cima das telas e do cabeçalho, abaixo
## dos avisos e dos diálogos (o tutorial do pintor aparece sobre ela).
func _abrir_cabine() -> void:
	var c: Carro = jogador.garagem.carro(jogador.carro_ativo)
	if c == null:
		return
	var cabine := CabinePintura.new(dados, jogador, c)
	add_child(cabine)
	move_child(cabine, _sobre.get_index())
	cabine.aviso.connect(_avisar)
	cabine.aplicada.connect(func():
		_avisar("Carro pintado.")
		if jogador.historia != null:
			jogador.historia.disparar("PINTURA_APLICADA")
		atualizar())
	if jogador.historia != null:
		jogador.historia.disparar("PINTURA")


## Luta da arena (já resolvida e aplicada): por cima de tudo; no fim, a
## conversa do resultado e a tela atualizada.
func _abrir_luta(dados_luta: Dictionary) -> void:
	var luta := LutaArena.new(dados_luta, dados_luta.get("params", dados.arena()))
	luta.name = "LutaArena"
	add_child(luta)
	luta.acabou.connect(func(f: Dictionary):
		if jogador.historia != null and f.get("demo", false):
			jogador.historia.disparar("ARENA_DEMO_FIM")
		elif jogador.historia != null and not f.get("simulacao", false):
			var t := "ARENA_PERDA" if f["perdeu"] else ("ARENA_VITORIA" if f.get("venceu_equipe", f["posicao"] == 1) else "ARENA_FIM")
			jogador.historia.disparar(t)
			jogador.historia.disparar_grid(f.get("grid", {}), dados)
		_sujar_todas()
		atualizar())


## Decisão 96: a luta de demonstração da primeira sessão (cena CW_AD01). Só
## equipes rivais (pedido do usuário: o jogador é convidado a assistir), seis
## duplas para mostrar o tamanho da coisa. O carro de historia.json →
## carro_mara só serve de referência de potência (entra e sai da garagem); a
## luta é simulada (nada muda no jogo) e, no fim, a Mara explica quando a arena
## abre (ARENA_DEMO_FIM).
const DEMO_EQUIPES := 6


func _luta_demo() -> void:
	var cm: Dictionary = dados.historia().get(String(jogador.personagem), {}).get("carro_mara", {})
	var id := String(cm.get("carro", ""))
	if not dados.existe("carros", id):
		jogador.historia.disparar("ARENA_DEMO_FIM")
		return
	var carro := Carro.new(dados.carro(id))
	carro.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
	var uid: int = jogador.garagem.adicionar(carro)
	var semente := hash("arena_demo:%s" % jogador.nome_admin)
	var montada := ArenaCarreira.montar(dados, jogador, uid, semente, DEMO_EQUIPES, {}, "", true)
	jogador.garagem.remover(uid)
	var resultado := Arena.correr(montada["participantes"], montada["params"], semente, true)
	var vencedora: Dictionary = montada["equipes"].get(String(resultado.get("equipe_vencedora", "")), {})
	var final := {"simulacao": true, "demo": true, "perdeu": false, "carro": "", "posicao": 0,
			"venceu_equipe": false, "pontos": 0, "premio": 0, "vencedora": String(vencedora.get("nome", ""))}
	var pintura: Dictionary = montada["cores"].duplicate()
	_abrir_luta({"resultado": resultado, "modelos": montada["modelos"], "nomes": montada["nomes"],
			"pinturas": pintura, "faixas": montada["faixas"], "final": final, "params": montada["params"],
			"blindagens": montada.get("blindagens", {}),
			"equipes": _todas[ABA_ARENA]._equipe_de_cada(resultado, montada["equipes"])})


## Ficha de uma equipe do Grid por cima de tudo, depois de qualquer diálogo
## em curso. Abrir marca como vista (não reaparece sozinha).
func _abrir_vinheta(id: String, contexto: String) -> void:
	while _dialogo != null and _dialogo.ocupado():
		await _dialogo.terminou
	var aberta := get_node_or_null("VinhetaGrid")
	if aberta != null and not aberta.is_queued_for_deletion():
		return
	if aberta != null:
		aberta.name = "VinhetaGrid_saindo"
	TheGrid.marcar_vista(jogador, id)
	get_node("/root/SaveManager").salvar()
	# Decisão 88: na revelação, a intro da equipe; aberta da lista, a ficha.
	var v: Control
	if contexto in ["proximo", "primeiro"] and id != "fim":
		v = GridRivalIntro.new(dados, jogador, id, contexto, 3, ABA_ARENA)
	else:
		v = VinhetaGrid.new(dados, jogador, id, contexto, 3, ABA_ARENA)
	v.name = "VinhetaGrid"
	add_child(v)
	v.ir.connect(func(aba: int): _ir_para(aba))


## Decisão 69: com 3 carros na garagem abre o tutorial da arena (campanha do
## dono); sem história, a arena abre direto.
func _checar_arena() -> void:
	if jogador.flags.has(EquipeJogador.FLAG_ARENA) or jogador.garagem.lista().size() < 3:
		return
	if not EquipeJogador.exige_piloto(jogador) or jogador.historia == null:
		jogador.flags[EquipeJogador.FLAG_ARENA] = true
		return
	jogador.historia.disparar("GARAGEM_TRES_CARROS")


## Engrenagem do cabeçalho.
func _abrir_configuracoes() -> void:
	_sobre.abrir("CONFIGURAÇÕES", func(v):
		Configuracoes.montar(_todas[5], v, jogador, func(vv): _todas[5]._modo_teste(vv), _abrir_configuracoes,
				_abrir_loja_real if Configuracoes.tem_loja() else Callable()),
		[["Fechar", func(): pass]], {"fora_fecha": true})


## Voltar do cabeçalho: a última tela visitada (o estado dela fica como estava).
func _voltar_tela() -> void:
	if _historico.is_empty():
		return
	_ir_para(_historico.pop_back(), true)


## Assistindo a corrida: saldo some (meta-jogo) e a navegação fica apagada
## (continua tocável). Fade curto, nunca de uma vez.
func _foco_corrida() -> void:
	var assistindo: bool = _abas.current_tab == 4 and (not jogador.fila.is_empty() or _todas[4].em_silencio())
	if assistindo == _modo_corrida:
		return
	_modo_corrida = assistindo
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	for n in _meta:
		t.tween_property(n, "modulate:a", 0.0 if assistindo else 1.0, 0.5)
	t.tween_property(_nav, "modulate:a", 0.4 if assistindo else 1.0, 0.5)


## Faixa "ao vivo" acima da navegação enquanto a fila corre (fora da Corrida).
func _atualizar_ao_vivo() -> void:
	var f: Dictionary = jogador.fila
	_cabecalho.definir_corrida(not f.is_empty())
	_ao_vivo.visible = not f.is_empty() and not _abas.current_tab in [3, 4]
	if not _ao_vivo.visible:
		return
	if not jogador.fila_ctrl.pronta(false):  # sendo resolvida aos poucos: sem o tempo ainda
		_ao_vivo.text = "•  AO VIVO · %s   Assistir ›" % dados.evento(f["evento_id"]).get("nome", "")
		return
	var dur: float = jogador.fila_ctrl.duracao_atual()
	var falta := maxf(dur - (Aceleracao.agora(jogador) - float(f["inicio"])), 0.0)
	if Aceleracao.ativa(jogador):  # tempo real que falta (o relógio da corrida anda mais rápido)
		falta /= float(jogador.aceleracao["fator"])
	_ao_vivo.text = "•  AO VIVO%s · %s · %d:%02d   Assistir ›" % [" %d×" % int(jogador.aceleracao["fator"]) if Aceleracao.ativa(jogador) else "",
			dados.evento(f["evento_id"]).get("nome", ""), int(falta) / 60, int(falta) % 60]


## A fonte padrão do Godot não tem ✓ ✗ ★ → ⚠ ■; no navegador não há fonte do
## sistema para cobrir, e eles viravam quadrados. Reserva com esses glifos.
static func _simbolos() -> void:
	var f := ThemeDB.fallback_font
	var reserva: Font = load("res://ui/fontes/simbolos.ttf")
	if reserva != null and not reserva in f.fallbacks:
		f.fallbacks = f.fallbacks + [reserva]
	# Sem procurar nas fontes do sistema: cada glifo que falta (▸, ✓, ›) fazia
	# a busca a cada texto montado e deixava as telas lentas. Os símbolos vêm da
	# fonte de reserva do jogo.
	for fonte in [f, reserva]:
		if fonte is FontFile:
			fonte.allow_system_fallback = false


func _tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONTE
	# Botões são ações: Barlow, como os da Tipografia (o texto corrido segue na
	# fonte padrão, que lê melhor em parágrafo).
	t.set_font("font", "Button", Tipografia.fonte("medium"))
	t.set_font("font", "OptionButton", Tipografia.fonte("medium"))
	# A Barlow condensada lê menor no mesmo tamanho: um pouco maior nos botões.
	t.set_font_size("font_size", "Button", FONTE + 4)
	t.set_font_size("font_size", "OptionButton", FONTE + 4)
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.18, 0.21)
	normal.border_color = Color(1, 1, 1, 0.08)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(12)
	var apertado := normal.duplicate()
	apertado.bg_color = Aba.COR_DESTAQUE
	apertado.border_color = Aba.COR_DESTAQUE.lightened(0.2)
	var desabilitado := normal.duplicate()
	desabilitado.bg_color = Color(0.11, 0.12, 0.14)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	t.set_stylebox("pressed", "Button", apertado)
	t.set_stylebox("hover_pressed", "Button", apertado)
	t.set_stylebox("disabled", "Button", desabilitado)
	t.set_color("font_pressed_color", "Button", Color(0.1, 0.1, 0.1))
	t.set_color("font_hover_pressed_color", "Button", Color(0.1, 0.1, 0.1))
	t.set_color("font_disabled_color", "Button", Color(0.64, 0.65, 0.7))
	# Barra de rolagem lateral: 3× a padrão, para achar e arrastar com o dedo.
	var trilho := StyleBoxFlat.new()
	trilho.bg_color = Color(1, 1, 1, 0.04)
	trilho.set_corner_radius_all(6)
	trilho.content_margin_left = 6
	trilho.content_margin_right = 6
	var pega := StyleBoxFlat.new()
	pega.bg_color = Color(1, 1, 1, 0.28)
	pega.set_corner_radius_all(6)
	pega.content_margin_left = 6
	pega.content_margin_right = 6
	var pega_ativa := pega.duplicate()
	pega_ativa.bg_color = Color(Aba.COR_DESTAQUE, 0.8)
	t.set_stylebox("scroll", "VScrollBar", trilho)
	t.set_stylebox("grabber", "VScrollBar", pega)
	t.set_stylebox("grabber_highlight", "VScrollBar", pega)
	t.set_stylebox("grabber_pressed", "VScrollBar", pega_ativa)
	return t


## Avisos das telas. Assistindo a corrida, só os de erro: os outros cobririam o
## cabeçalho sem dar tempo de ler (a própria corrida já mostra a largada).
func _avisar(texto: String, ok := true) -> void:
	if not ok:
		Sons.tocar_ui(self, "erro", -8.0)
	if ok and _abas.current_tab == 4 and (not jogador.fila.is_empty() or _todas[4].em_silencio()):
		return
	_sobre.avisar(texto, ok)


## Estado mudou: a tela visível é refeita já; as outras só ficam marcadas e se
## refazem quando forem abertas (refazer as sete a cada toque levava segundos).
func atualizar() -> void:
	jogador.garagem.vagas = VagasGaragem.capacidade(dados, jogador.ampliacoes_garagem)
	_sujar_todas()
	_reconstruir(_abas.current_tab)
	_atualizar_capa()
	_atualizar_aceleracao()


func _reconstruir(i: int) -> void:
	if _sujas.has(i):
		_sujas.erase(i)
		_todas[i].atualizar()
	# NOMES só no mapa das Lojas; dentro de uma loja, a volta ao mapa.
	_cabecalho.mostrar_nomes(i == 1 and _todas[1].no_mapa())
	_cabecalho.mostrar_mapa(i == 1 and not _todas[1].no_mapa())


## Telas que ficam montadas fora de vista: a da corrida (a corrida ao vivo) e
## a anterior (o Voltar do cabeçalho a mostra como estava). As outras soltam o
## conteúdo e se refazem ao abrir (memória de vídeo no celular).
func _liberar_escondidas() -> void:
	var manter := [_abas.current_tab, 4]
	if not _historico.is_empty():
		manter.append(_historico.back())
	for k in _todas.size():
		if not k in manter and not _sujas.has(k) and _todas[k] is Aba:
			_todas[k].liberar()
			_sujas[k] = true


func _sujar_todas() -> void:
	for i in _todas.size():
		_sujas[i] = true
	_cabecalho.definir_pecas(Aba.dinheiro(jogador.economia.credito_pecas))  # antes: o número dos giros cabe no resto
	_cabecalho.definir_giros(Aba.dinheiro(jogador.economia.saldo))
	_atualizar_combustivel()
	_atualizar_ao_vivo()
	_atualizar_nav()
	var objetivos := Objetivos.lista(jogador, dados)
	var atual := Objetivos.atual(objetivos)
	if _objetivo >= 0 and atual > _objetivo and _sobre != null:
		var proximo: String = objetivos[atual]["texto"] if atual < objetivos.size() else "todos cumpridos!"
		_avisar("Objetivo cumprido: %s. Próximo: %s" % [objetivos[atual - 1]["texto"], proximo])
	_objetivo = atual
	# Toda ação do jogador passa por aqui: salvar já. No navegador não há aviso
	# confiável de fechamento, e uma compra não pode se perder.
	get_node("/root/SaveManager").salvar()


## Ações de tutorial das cenas (TutorialAction): abrir a tela certa ou destacar
## um ponto dela (HIGHLIGHT_<âncora>, ver Aba.ancora); as ações do prólogo e da
## equipe vão para `historia_acao`.
signal historia_acao(nome: String)


func _acao_tutorial(nome: String) -> void:
	var abas := {"OPEN_GARAGE_TAB": 0, "RETURN_TO_GARAGE": 0, "OPEN_DEALERSHIP": 1, "OPEN_TUNE_SERVICE": 0,
			"OPEN_EVENTS": 3, "OPEN_LICENSE_CENTER": 5, "OPEN_TEAM_FINANCE": ABA_EQUIPE}
	if abas.has(nome):
		_apresentar(abas[nome])
		_ir_para(abas[nome])
		atualizar()
	elif nome.begins_with("HIGHLIGHT_"):
		var nav := NOMES_ABA.find(nome.trim_prefix("HIGHLIGHT_NAV_"))
		if nome.begins_with("HIGHLIGHT_NAV_") and nav >= 0:
			_apresentar(nav)
		_destacar(nome.trim_prefix("HIGHLIGHT_"))
	else:
		historia_acao.emit(nome)


## Destaque do tutorial: a âncora na aba aberta (ou, sem ela lá, na primeira
## aba que a tem), rolada para o alto da tela, acima da caixa de diálogo. As do
## topo e da navegação (SALDO, NAV_<ABA>) valem em qualquer tela.
func _destacar(nome: String) -> void:
	if _ancoras.has(nome):
		_destaque.mostrar(_ancoras[nome])
		_dialogo.evitar(_ancoras[nome].get_global_rect())
		return
	var aba: Aba = _todas[_abas.current_tab]
	aba.preparar_destaque(nome)
	aba.atualizar()
	if not aba.ancoras.has(nome):
		for i in _todas.size():
			_todas[i].preparar_destaque(nome)
			_todas[i].atualizar()
			if _todas[i].ancoras.has(nome):
				_ir_para(i)
				aba = _todas[i]
				break
	if not aba.ancoras.has(nome):
		return  # tela sem o elemento agora (ex.: garagem vazia): só o diálogo
	# Espera o layout para saber onde o elemento ficou (se a cena acabar no
	# meio, o destaque atrasado não mexe na caixa da cena seguinte).
	var cena_id = _dialogo._cena.get("id")
	await get_tree().process_frame
	await get_tree().process_frame
	var alvo: Control = aba.ancoras.get(nome)
	if not is_instance_valid(alvo):
		return
	# Rola se o elemento não está inteiro na tela ou cai onde a caixa do
	# diálogo fica (a corrida não sai do lugar).
	# A área livre: abaixo do cabeçalho e das abas penduradas, que cobririam o topo.
	var r := alvo.get_global_rect()
	if not aba.area_livre().encloses(r) or (r.end.y > _dialogo.topo_da_caixa() - 16.0 and _abas.current_tab != 4):
		aba.scroll_vertical = maxi(int(alvo.global_position.y - aba.conteudo.global_position.y
				- (aba.area_livre().position.y - aba.get_global_rect().position.y)) - 24, 0)
		await get_tree().process_frame
		if not is_instance_valid(alvo):
			return
	# Reconstruída a aba, o destaque acha o controle novo pela mesma âncora.
	_destaque.mostrar(alvo, func():
		if not aba.is_visible_in_tree():
			return null
		# Janela aberta por cima (ex.: a seleção de pilotos): o destaque espera
		# sem desenhar; a escolha dentro dela é do jogador.
		if _sobre.aberto():
			return true
		return aba.ancoras.get(nome))
	if _dialogo._cena.get("id") == cena_id:
		_dialogo.evitar(alvo.get_global_rect())


## Cenas que mostram algo dentro do painel que as abriu (a janela de peças, a
## garagem) e a da largada; as outras esperam a janela aberta fechar (o
## resultado da corrida, o carro novo) para não disputar a tela.
const CENAS_NO_PAINEL := ["EVOLUCAO", "BLINDAGEM", "GARAGEM_ABERTA", "CORRIDA_INICIO"]


func _cena_espera(c: Dictionary) -> bool:
	return _sobre.ocupando() and not String(c.get("trigger", "")) in CENAS_NO_PAINEL \
			and not c.get("segura_largada", false)


## Uma cena começa: a da largada, ou qualquer uma pedida antes de a corrida
## largar, segura a corrida no grid até a fila de conversas acabar.
func _cena_pedida(c: Dictionary) -> void:
	var corrida = _todas[4]
	if c.get("segura_largada", false) or corrida.antes_da_largada():
		corrida.segurar()


## Cena terminada: salva; o destaque fica só se ela acabou nele (o jogador tem
## de tocar ali); a cena com lembrete começa a contar; a largada é liberada.
func _cena_terminou(c: Dictionary) -> void:
	var falas: Array = c.get("falas", [])
	var ultima := String(falas[-1].get("acao", "")) if not falas.is_empty() else ""
	if not ultima.begins_with("HIGHLIGHT_"):
		_destaque.limpar()
	if c.get("lembrete") != null:
		_lembrete = {"id": c["lembrete"], "t": 0.0}
	if _todas[4].segurar_largada:
		# Depois de o diálogo passar para a próxima da fila (aqui a cena ainda
		# conta como aberta): libera só quando não houver mais nenhuma.
		(func(): _quando_dialogo_acabar(_todas[4].liberar_largada)).call_deferred()
	atualizar()
	# A arena pode ter ficado esperando outra conversa (3 carros antes do patrocínio).
	_checar_arena()
	get_node("/root/SaveManager").salvar()


## Lembrete: o jogador não fez o que a cena pediu em LEMBRETE_S; a cena do
## lembrete aparece se ainda vale (as flags dela dizem quando não precisa mais).
func _contar_lembrete() -> void:
	if _lembrete.is_empty() or _dialogo == null or _dialogo.ocupado():
		return
	_lembrete["t"] += 1.0
	if _lembrete["t"] < LEMBRETE_S:
		return
	var id: String = _lembrete["id"]
	_lembrete = {}
	if dados.existe("dialogos", id) and jogador.historia.vale(dados.item("dialogos", id)):
		_dialogo.enfileirar(dados.item("dialogos", id))


## Espera o diálogo (e as cenas encadeadas) acabar e chama `depois`.
func _quando_dialogo_acabar(depois: Callable) -> void:
	while _dialogo != null and _dialogo.ocupado():
		await _dialogo.terminou
		await get_tree().process_frame
	depois.call()


## Jogo novo com a história: a abertura (a noite em que a Wreckage perdeu os
## carros) e, no fim dela, a primeira cena (GAME_START).
func _abertura() -> void:
	_atualizar_capa()
	var h: Historia = jogador.historia
	var falta := h.recuperar()
	# Campanha do dono: a noite do acidente (AberturaCinema) e então a Mara na
	# oficina (GAME_START). Só uma vez (flag ABERTURA_DONO).
	if jogador.personagem == "dono" and not jogador.flags.has("ABERTURA_DONO") \
			and not h.cena_para("GAME_START").is_empty():
		var cinema := AberturaCinema.new()
		add_child(cinema)
		cinema.terminou.connect(func():
			jogador.flags["ABERTURA_DONO"] = true
			# O preto da abertura fica logo abaixo do diálogo até a ilustração
			# da chegada entrar: a garagem não aparece entre os dois.
			move_child(cinema, _dialogo.get_index() if _dialogo != null else get_child_count() - 1)
			h.disparar("GAME_START")
			cinema.sair(Dialogo.CENARIO_S * 2.0 + Dialogo.ENTRADA_S))
		return
	if h.disparar("GAME_START"):
		return
	# Save fechado no meio da chegada (decisão 90): retoma o passo que faltou.
	match falta:
		"nome":
			_quando_dialogo_acabar(_pedir_nome)
		"nome_definido":
			h.disparar("NOME_DEFINIDO")
		"grid":
			h.abrir("CW_GR00")


func _acao_historia(nome: String) -> void:
	if nome == "OPEN_DRIVER_HIRE":
		# Segundo piloto entra na equipe, sem contrato (decisão 38).
		EquipeJogador.liberar_segundo(dados, jogador)
		atualizar()
		_ir_para(ABA_EQUIPE)
	elif nome == "PEDIR_NOME":
		# Decisão 73: a Mara pergunta o nome; o painel vem com a cena fechada.
		_quando_dialogo_acabar(_pedir_nome)
	elif nome == "ARENA_DEMO":
		_quando_dialogo_acabar(_luta_demo)
	elif nome == "UNLOCK_ARENA_PILOTS":
		# Decisão 69: o tutorial da arena libera os pilotos de arena.
		jogador.flags[EquipeJogador.FLAG_ARENA] = true
		atualizar()
	elif nome == "UNLOCK_ACELERAR":
		jogador.flags[FLAG_ACELERAR] = true
		_atualizar_aceleracao()
	elif nome == "UNLOCK_TEAM_TAB":
		# A equipe nasce na cena: nada é resetado, só a aba aparece.
		EquipeJogador.criar(jogador)
		atualizar()
		# A Equipe abre com o toque do jogador na barra (a cena destaca o botão);
		# a de contratar (ABA:EQUIPE) pede FIRST_CAR, que esta cena grava no fim.


## Fundo do painel do nome: o cenário da cena que pergunta (CW_P01).
const CENARIO_NOME := "oficina_mara"


## Nome do administrador (a cena CW_P01 termina pedindo): sem rosto nem
## passado, só o nome que a Mara usa. Confirmado, segue a história.
func _pedir_nome() -> void:
	if get_node_or_null("NomeAdmin") != null:
		return
	var painel := NomeAdmin.new(jogador.nome_admin, Assets.get_asset(CENARIO_NOME, "cenario"))
	painel.name = "NomeAdmin"
	add_child(painel)
	painel.confirmado.connect(func(nome: String):
		jogador.nome_admin = nome
		get_node("/root/SaveManager").salvar()
		jogador.historia.disparar("NOME_DEFINIDO"))


## Aviso de fim de corrida no navegador (AvisoFim): agendado para o fim da
## corrida em andamento, com a posição; sem corrida, cancelado.
func _agendar_aviso() -> void:
	if not AvisoFim.disponivel():
		return
	if jogador.fila.is_empty() or not jogador.fila_ctrl.pronta(false):
		AvisoFim.cancelar()
		return
	var agora := Aceleracao.agora(jogador)
	var c: Dictionary = jogador.fila_ctrl.corrida_atual(agora)
	if c.is_empty():
		return
	var falta := float(c["duracao"]) - float(c["decorrido"])
	var ev_id := String(jogador.fila.get("evento_id", ""))
	var nome := String(dados.evento(ev_id).get("nome", "Corrida")) if dados.existe("eventos", ev_id) else "Corrida"
	var pos: int = Array(c["resultado"]["classificacao"]).find("jogador") + 1
	AvisoFim.agendar(Aceleracao.real_ate(jogador, falta), "Chrome & Wreckage",
			"%s terminou: %s em %dº." % [nome, EquipeJogador.nome_jogador(dados, jogador), pos])


## A corrida recém-inscrita é resolvida aos poucos, Fila.FATIA_MS por quadro
## (decisão 90): uma resistência leva segundos de uma vez e travava a tela.
var _resolvendo := false


func _process(_delta: float) -> void:
	if jogador.fila_ctrl == null:
		return
	var pronta: bool = jogador.fila_ctrl.avancar_preparo(Fila.FATIA_MS)
	if pronta and _resolvendo:
		# Resolvida: o cartão da prova e a faixa ao vivo ganham o tempo que falta.
		_sujas[Aba.EVENTOS] = true
		if _abas.current_tab == Aba.EVENTOS:
			_reconstruir(Aba.EVENTOS)
		_atualizar_ao_vivo()
	_resolvendo = not pronta


## Treino terminado (também com o jogo fechado): a licença sai sozinha; o
## painel da conquista e, depois, a conversa da licença.
func _checar_licencas() -> void:
	if jogador.historia != null and _dialogo != null and _dialogo.ocupado():
		return
	var novas: Array = Licencas.new(dados, jogador).atualizar(Time.get_unix_time_from_system())
	if novas.is_empty():
		return
	get_node("/root/SaveManager").salvar()
	atualizar()
	for id in novas:
		var lic: Dictionary = dados.item("licencas", id)
		var liberadas: Array = dados.lista("eventos").filter(func(e): return e["restricoes"].get("licenca") == id)
		(func(): _todas[0].historia("LICENCA_CONCEDIDA:" + String(id))).call_deferred()
		_sobre.abrir("%s conquistada!" % lic["nome"], func(v):
			var g: Aba = _todas[0]
			g.rotulo("Treino concluído. Agora você pode correr %d corridas novas:" % liberadas.size(), 0, Color.WHITE, v)
			var series := {}
			for e in liberadas:
				series[String(e["nome"]).split(" — ")[0]] = true
			for nome in series:
				g.rotulo("• " + nome, Aba.FONTE_PEQUENA + 2, Aba.COR_DESTAQUE, v),
			[["Ver corridas", func(): _ir_para(Aba.EVENTOS)], ["Fechar", func(): pass]])


func _processar_fila() -> void:
	_agendar_aviso()
	# Corrida ainda sendo resolvida aos poucos (_process): acabou de começar, o
	# próximo segundo confere.
	if jogador.fila.is_empty() or not jogador.fila_ctrl.pronta(false):
		return
	var antes_vitorias: Dictionary = jogador.vitorias.duplicate()
	var rel: Dictionary = jogador.fila_ctrl.processar(Aceleracao.agora(jogador))
	RegistroSessao.corridas(rel, dados)
	if rel["corridas"].is_empty() and rel["erro"] == "":
		return
	atualizar()
	get_node("/root/SaveManager").salvar()
	# Uma corrida terminando com o app aberto: aviso curto e a tela de Corrida
	# mostra o resultado. Várias (voltou do segundo plano), erro ou carro-prêmio:
	# relatório.
	if rel["corridas"].size() == 1 and rel["erro"] == "":
		await _esperar_tela_livre()
		# Assistindo: um silêncio depois da chegada antes do resultado (a tela da
		# corrida fica parada na última imagem o mesmo tempo).
		if _abas.current_tab == 4:
			var corrida = _todas[4]
			await get_tree().create_timer(corrida.ESCURECER_EM_S).timeout
			_sobre.escurecer(true, corrida.SILENCIO_S - corrida.ESCURECER_EM_S)
			await get_tree().create_timer(corrida.SILENCIO_S - corrida.ESCURECER_EM_S).timeout
		var c: Dictionary = rel["corridas"][0]
		var primeira: bool = not antes_vitorias.has(c["evento_id"])
		# Primeiro o resultado (a vitória); a conversa da chegada espera o
		# painel fechar (Dialogo.espera), sem disputar a tela com ele.
		_resultado(c, primeira)
		if jogador.historia != null:
			jogador.historia.disparar_grid(c.get("grid", {}), dados)
			jogador.historia.disparar_fim(int(c["posicao"]), c["evento_id"], antes_vitorias)
		return
	await _esperar_tela_livre()
	_mostrar_relatorio(rel, "Resultado das corridas")
	_conversas_das_corridas(rel["corridas"], antes_vitorias)


## O resultado nunca substitui um painel aberto (ficha, Garagem,
## Configurações) nem fica escondido atrás da intro do Grid, da luta ou do
## pedido do nome: espera a tela ficar livre.
func _esperar_tela_livre() -> void:
	while is_inside_tree() and (_sobre.aberto() or _cobrindo()):
		await get_tree().create_timer(0.25).timeout


func _cobrindo() -> bool:
	for n in ["VinhetaGrid", "LutaArena", "NomeAdmin"]:
		var x := get_node_or_null(n)
		if x != null and not x.is_queued_for_deletion():
			return true
	return false


## Corridas que terminaram fora da tela (app fechado ou várias de uma vez):
## as conversas que elas pedem, como se tivessem terminado com o app aberto
## (o Grid de cada uma, a chegada da última). Elas esperam o relatório fechar.
func _conversas_das_corridas(corridas: Array, antes: Dictionary) -> void:
	if jogador.historia == null or corridas.is_empty():
		return
	for c in corridas:
		jogador.historia.disparar_grid(c.get("grid", {}), dados)
	var u: Dictionary = corridas[-1]
	jogador.historia.disparar_fim(int(u["posicao"]), String(u["evento_id"]), antes)


func _notification(what: int) -> void:
	# Volta do segundo plano: aplica o que correu enquanto isso, na hora.
	if what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN] and _sobre != null:
		Notificacoes.cancelar()  # de volta: os avisos agendados saem
		_volta_do_segundo_plano()
		RegistroSessao.inicio(jogador)  # antes da fila: as corridas de fora entram na sessão
		RegistroSessao.tela(_abas.current_tab)
		_processar_fila()
		_fila_vista = jogador.fila
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST] \
			and _sobre != null:
		RegistroSessao.fim(jogador)
		Notificacoes.agendar(dados, jogador)
		_saiu_em = Time.get_unix_time_from_system()


## Quadros por segundo no canto, só com o modo de playtest ligado: medir o
## custo da corrida (modo velocidade) no aparelho de verdade.
var _fps: Label


func _atualizar_fps() -> void:
	if Preferencias.modo_teste == "":
		if _fps != null:
			_fps.visible = false
		return
	if _fps == null:
		_fps = Label.new()
		_fps.add_theme_font_size_override("font_size", 20)
		_fps.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		_fps.add_theme_constant_override("outline_size", 6)
		_fps.position = Vector2(8, 4)
		_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_fps)
	_fps.visible = true
	_fps.text = "%d fps" % Engine.get_frames_per_second()
	RegistroSessao.quadros(Engine.get_frames_per_second(), _abas.current_tab == 4)


## Fila nova programada nesta sessão (registro do playtest).
var _fila_vista: Dictionary = {}


func _registrar_fila() -> void:
	if jogador.fila.is_empty() or is_same(jogador.fila, _fila_vista) or not jogador.fila_ctrl.pronta(false):
		return
	_fila_vista = jogador.fila
	RegistroSessao.fila(jogador.fila, jogador.fila_ctrl.duracao_atual(), not jogador.vitorias.has(jogador.fila["evento_id"]))


## Resultado de uma corrida terminada com o app aberto: posição em destaque,
## recompensa e a próxima decisão.
func _resultado(c: Dictionary, primeira: bool) -> void:
	var g: Aba = _todas[0]
	var venceu: bool = c["posicao"] == 1
	var ev: Dictionary = dados.evento(c["evento_id"])
	# Só FECHAR (pedido do usuário): as conversas da chegada e a do título de
	# campeão vêm depois que o jogador lê o resultado.
	var fechar := _depois_do_resultado.bind(c, func(): pass)
	var meu: Carro = jogador.garagem.carro(c["uid"])
	var tabela: Array = c.get("tabela", [])
	var token := Time.get_ticks_usec()
	_resultado_aberto = token
	# Caixa de moldura dourada (arte do usuário), sem rolagem: título, etapa,
	# troféu e posição, a classificação em faixas inclinadas e o FECHAR
	# (dourado na vitória, cinza nas outras posições).
	_sobre.abrir("", func(v):
		v.add_theme_constant_override("separation", 6)
		_titulo_resultado(v, "VITÓRIA!" if venceu else ("%dº LUGAR" % int(c["posicao"]) if int(c["posicao"]) <= 3
				else "RESULTADO"), venceu)
		_cartao_etapa(v, ev)
		_trofeu_resultado(v, c, venceu)
		# Bônus dos patrocinadores cuja condição a corrida cumpriu.
		for b in c.get("patrocinio", []):
			var lb := g.rotulo("+%s giros · %s" % [Aba.dinheiro(int(b["valor"])), b["nome"]], Aba.FONTE_PEQUENA,
					Aba.COR_DESTAQUE, v)
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var marcos := []
		var camp: Dictionary = c.get("campeonato", {})
		if camp.get("final", false) and camp.get("campeao", false):
			marcos.append(["CAMPEÃO: %s" % camp["serie"], Aba.COR_DESTAQUE])
			if int(jogador.titulos.get(String(camp["serie"]), 0)) == 1:  # primeiro título da série
				marcos.append(["+1 H DE RENDA OFFLINE", Aba.COR_BOM])
		if not marcos.is_empty():
			g.selos(marcos, v)
		# Carro de prêmio: ele girando na vitrine, com o nome.
		var premiado: Carro = jogador.garagem.carro(c["carro_premio_uid"]) if c.get("carro_premio_uid", -1) > 0 else null
		if premiado != null:
			var lc := g.rotulo("CARRO DE PRÊMIO: %s" % String(premiado.base["nome"]).to_upper(), 0, Color("ffd34d"), v)
			Tipografia.rotulo(lc, "semibold", 26)
			lc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var vit := VitrineCarro.new(230.0)
			vit.fundo_transparente()
			vit.mostrar_modelo(premiado.base, CarroBloco.cor_do_carro(premiado), premiado.faixas)
			v.add_child(vit)
		_lista_resultado(v, tabela, c)
		_fechamento_automatico(v, token, fechar)
		_botao_fechar(v, fechar, venceu), [], {"caixa": Aba.arte("caixa_resultado" if venceu else "caixa_resultado_cinza"), "tela_cheia": _cabecalho.altura_total() + 8.0})


## "VITÓRIA!" (ou a posição) no alto, centrado.
func _titulo_resultado(v: VBoxContainer, texto: String, venceu: bool) -> void:
	var caixa := Control.new()
	caixa.custom_minimum_size = Vector2(0, 100)
	v.add_child(caixa)
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", Tipografia.fonte("display"))
	l.add_theme_font_size_override("font_size", 88 if texto.length() <= 8 else 74)
	l.add_theme_color_override("font_color", Color("ffd34d") if venceu else Color(0.95, 0.94, 0.9))
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.03))
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 5)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caixa.add_child(l)


## A série e a etapa (ou o nome da prova) numa linha e a pista embaixo,
## centradas sob o título (sem caixa).
func _cartao_etapa(v: VBoxContainer, ev: Dictionary) -> void:
	var g: Aba = _todas[0]
	var serie := Campeonatos.serie(ev)
	var etapas := Campeonatos.etapas(dados, serie)
	var l1 := g.rotulo(("%s · ETAPA %d/%d" % [serie.to_upper(), etapas.find(ev) + 1, etapas.size()])
			if not etapas.is_empty() else Aba.nome_evento(ev).to_upper(), 0, Color(0.95, 0.94, 0.9), v)
	Tipografia.rotulo(l1, "semibold", 32)
	var l2 := g.rotulo(Aba.nome_pista(ev["pista"]), Aba.FONTE_PEQUENA + 2, Color(0.8, 0.82, 0.86), v)
	for l in [l1, l2]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_OFF


## Troféu (com os louros na vitória), a posição grande e o prêmio com a moeda.
func _trofeu_resultado(v: VBoxContainer, c: Dictionary, venceu: bool) -> void:
	var g: Aba = _todas[0]
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 18)
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(linha)
	var trofeu := TextureRect.new()
	trofeu.texture = Aba.arte("resultado_trofeu") if venceu else Aba.arte(
			{2: "icone_trofeu_prata", 3: "icone_trofeu_bronze"}.get(int(c["posicao"]), "icone_podio"))
	trofeu.custom_minimum_size = Vector2(140, 112) if venceu else Vector2(96, 96)
	trofeu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trofeu.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if int(c["posicao"]) > 3:
		trofeu.modulate = Color(1, 1, 1, 0.35)
	linha.add_child(trofeu)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(col)
	var pos := Label.new()
	pos.text = "%dº de %d" % [c["posicao"], c["total"]]
	Tipografia.numero(pos, 58)
	pos.add_theme_color_override("font_color", Color("ffd34d") if venceu else Color.WHITE)
	pos.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	pos.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(pos)
	var traco := ColorRect.new()
	traco.color = Color("ffd34d", 0.8) if venceu else Color(1, 1, 1, 0.35)
	traco.custom_minimum_size = Vector2(0, 4)
	col.add_child(traco)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(pr)
	if int(c["premio"]) > 0:
		var lv := Label.new()
		lv.text = "+" + Aba.dinheiro(int(c["premio"]))
		Tipografia.numero(lv, 36)
		lv.add_theme_color_override("font_color", Color("ffd34d"))
		pr.add_child(lv)
		g.icone(Aba.ICONE_GIROS, 34, pr).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		Sons.tocar_ui(self, "moeda", -2.0)
	else:
		Tipografia.rotulo(g.rotulo("Sem prêmio", 0, Aba.COR_SECUNDARIA, pr), "medium", 26)


## FECHAR na arte do botão: dourado na vitória, cinza nas outras posições.
func _botao_fechar(v: VBoxContainer, ao_fechar: Callable, venceu: bool) -> void:
	var b := Button.new()
	b.text = "FECHAR  →"
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Tipografia.fonte("display"))
	b.add_theme_font_size_override("font_size", 46)
	var cor_texto := Color(0.1, 0.08, 0.04) if venceu else Color(0.95, 0.95, 0.95)
	for cor in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cor, cor_texto)
	var arte := StyleBoxTexture.new()
	arte.texture = Aba.arte("botao_dourado" if venceu else "botao_cinza")
	# As bordas da arte (o contorno e o canto inclinado) não esticam.
	arte.texture_margin_left = 40
	arte.texture_margin_right = 40
	arte.texture_margin_top = 20
	arte.texture_margin_bottom = 20
	var apertado := arte.duplicate()
	apertado.modulate_color = Color(0.85, 0.85, 0.85)
	for estado in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(estado, arte)
	b.add_theme_stylebox_override("pressed", apertado)
	b.custom_minimum_size = Vector2(560, 560.0 * 138.0 / 900.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		_sobre.fechar()
		ao_fechar.call())
	v.add_child(b)


## Competidores na ordem de chegada: posição, emblema da equipe, piloto e tempo
## (diferença para o vencedor); a sua linha em destaque.
func _lista_resultado(v: VBoxContainer, tabela: Array, c: Dictionary) -> void:
	var t0: float = float(tabela[0]["tempo"]) if not tabela.is_empty() else 0.0
	for i in tabela.size():
		var it: Dictionary = tabela[i]
		var id: String = it["id"]
		var voce: bool = id == "jogador" or id == EquipeJogador.ID
		var linha := PanelContainer.new()
		# Faixa inclinada; a sua em dourado.
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("f0b630") if id == "jogador" else Color(0.06, 0.07, 0.1, 0.8)
		sb.border_color = Color("ffd76a") if id == "jogador" else Color(1, 1, 1, 0.1)
		sb.set_border_width_all(1)
		sb.skew = Vector2(0.12, 0.0)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 16
		sb.content_margin_right = 20
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		linha.add_theme_stylebox_override("panel", sb)
		v.add_child(linha)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		linha.add_child(h)
		var cor := Color(0.1, 0.1, 0.1) if id == "jogador" else Color.WHITE
		var n := Label.new()
		n.text = str(i + 1)
		n.custom_minimum_size = Vector2(34, 0)
		Tipografia.numero(n, 26)
		n.add_theme_color_override("font_color", cor)
		h.add_child(n)
		h.add_child(_emblema_equipe(_equipe_no_resultado(id, c), 38, false))
		var nome := Label.new()
		nome.text = EquipeJogador.nome_jogador(dados, jogador) if id == "jogador" else (EquipeJogador.nome_segundo(dados, jogador)
				if id == EquipeJogador.ID else jogador.carreira.nome_piloto(c["evento_id"], id, int(c.get("semente", -1))))
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nome.clip_text = true
		nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nome.add_theme_font_size_override("font_size", 25)
		nome.add_theme_color_override("font_color", cor)
		h.add_child(nome)
		var tempo := Label.new()
		tempo.text = "—" if not it.get("terminou", true) else (HudCorrida._tempo(float(it["tempo"])) if i == 0
				else "+%.1f s" % (float(it["tempo"]) - t0))
		Tipografia.numero(tempo, 24)
		tempo.add_theme_color_override("font_color", cor if voce else Color(cor, 0.8))
		h.add_child(tempo)


func _equipe_no_resultado(id: String, c: Dictionary) -> Dictionary:
	if id == "jogador" or id == EquipeJogador.ID:
		return EquipeJogador.dados_equipe(dados, jogador)
	return jogador.carreira.equipe_de(c["evento_id"], id, int(c.get("semente", -1)))


## Emblema da equipe: a logo, se existir (e `com_logo`); senão um círculo na
## cor da equipe com o número dela. No resultado, sempre o número (pedido do
## usuário: a logo pequena fica ilegível).
func _emblema_equipe(eq: Dictionary, tamanho: int, com_logo := true) -> Control:
	var caminho := String(eq.get("logo", ""))
	if com_logo and caminho != "" and ResourceLoader.exists(caminho):
		var t := TextureRect.new()
		t.texture = load(caminho)
		t.custom_minimum_size = Vector2(tamanho, tamanho)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return t
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(tamanho, tamanho)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.from_hsv(float(posmod(hash(String(eq.get("id", ""))), 360)) / 360.0, 0.45, 0.5) \
			if not eq.is_empty() else Color(0.3, 0.31, 0.34)
	sb.set_corner_radius_all(tamanho / 2)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = str(int(eq["numero"])) if eq.has("numero") else String(eq.get("nome", "?")).left(1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Tipografia.numero(l, int(tamanho * 0.58))
	p.add_child(l)
	return p


## Contagem no texto da caixa ("Fechar sozinha em 12 s"): no zero, fecha a
## janela; a caixa liga e desliga o fechamento automático (fica nas preferências).
func _fechamento_automatico(v: VBoxContainer, token: int, ao_fechar: Callable) -> void:
	var caixa := CheckBox.new()
	caixa.button_pressed = Preferencias.fechar_resultado
	caixa.add_theme_font_size_override("font_size", Aba.FONTE_PEQUENA)
	caixa.custom_minimum_size.y = 56
	caixa.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for estado in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		caixa.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
	for cor in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		caixa.add_theme_color_override(cor, Aba.COR_SECUNDARIA)
	v.add_child(caixa)
	var resta := [int(FECHAR_RESULTADO_S)]
	var mostrar := func():
		caixa.text = "Fechar sozinha em %d s" % resta[0] if Preferencias.fechar_resultado \
				else "Fechar sozinha em %d s" % int(FECHAR_RESULTADO_S)
	mostrar.call()
	var relogio := Timer.new()
	relogio.wait_time = 1.0
	relogio.autostart = true
	caixa.add_child(relogio)
	relogio.timeout.connect(func():
		if not Preferencias.fechar_resultado:
			return
		resta[0] -= 1
		mostrar.call()
		if resta[0] <= 0:
			relogio.stop()
			if _resultado_aberto == token and _sobre.aberto():
				_sobre.fechar()
				ao_fechar.call())
	caixa.toggled.connect(func(ligado):
		Preferencias.fechar_resultado = ligado
		Preferencias.salvar()
		resta[0] = int(FECHAR_RESULTADO_S)
		mostrar.call())


func _depois_do_resultado(c: Dictionary, acao: Callable) -> void:
	var g: Aba = _todas[0]
	acao.call()
	if c.get("campeonato", {}).get("campeao", false):
		g.historia("CAMPEONATO_VENCIDO", {"evento": c["evento_id"]})


func _primeira_vitoria(c: Dictionary) -> void:
	var g: Aba = _todas[0]
	_sobre.abrir("Primeira vitória!", func(v):
		g.rotulo(dados.evento(c["evento_id"]).get("nome", ""), 30, Aba.COR_DESTAQUE, v)
		g.nota("cabecalho/icone_giros", "Prêmio: +%s" % Aba.dinheiro(c["premio"]), "", v, Color.WHITE)
		g.nota("icone_dica", "Agora: corrida que paga mais, ou Oficina", "", v))


## Relatório de várias corridas (offline ou segundo plano): resumo e, sob
## pedido, a lista de cada corrida.
## Patrocínio: a renda por hora entra a cada segundo com o app aberto; um
## contrato que acaba avisa.
func _patrocinio() -> void:
	if GestaoEquipe.concluir_treino(jogador, Time.get_unix_time_from_system()):
		_sobre.avisar("Treino concluído: energia cheia e o ritmo subiu.")
		if jogador.historia != null:
			jogador.historia.disparar("TREINO_CONCLUIDO")
		atualizar()
	var r := GestaoEquipe.acumular(dados, jogador, Time.get_unix_time_from_system())
	for nome in r["encerrados"]:
		_sobre.avisar("Contrato de %s encerrado. Há ofertas novas na Equipe." % nome)
	if not r["encerrados"].is_empty():
		atualizar()


## Volta ao jogo (decisão 108): com renda do patrocínio, a tela própria
## "Enquanto você esteve fora"; sem ela, o relatório das corridas, como antes.
func _abrir_volta(rel: Dictionary) -> void:
	if int(rel.get("patrocinio", 0)) <= 0:
		_mostrar_relatorio(rel, "Enquanto você esteve fora")
		return
	if get_node_or_null("TelaVolta") != null:
		return
	var t := TelaVolta.new(rel, dados)
	t.name = "TelaVolta"
	add_child(t)
	t.dobrar.connect(func(valor: int):
		var video := VideoRecompensa.new("dobrar a renda offline", "coroa")
		add_child(video)
		video.terminou.connect(func(assistiu):
			if not assistiu:
				t.liberar_dobro()
				return
			jogador.economia.creditar(valor)
			get_node("/root/SaveManager").salvar()
			atualizar()
			t.dobrado()))


## Quando o jogo saiu de foco (s Unix) e quanto tempo fora abre a tela de volta.
var _saiu_em := 0.0
const VOLTA_MIN_S := 300.0


## O jogo voltou do segundo plano: a renda do patrocínio do tempo fora entra de
## uma vez e aparece na tela de volta (o relógio de 1 s pagaria em silêncio).
func _volta_do_segundo_plano() -> void:
	var agora := Time.get_unix_time_from_system()
	var rel := {"corridas": [], "erro": "", "carros_premio": [], "premio_total": 0}
	rel["treino_concluido"] = GestaoEquipe.concluir_treino(jogador, agora)
	var pat := GestaoEquipe.acumular(dados, jogador, agora)
	rel["patrocinio"] = pat["ganho"]
	rel["patrocinios_encerrados"] = pat["encerrados"]
	var fora := agora - _saiu_em
	if int(rel["patrocinio"]) <= 0:
		return
	get_node("/root/SaveManager").salvar()
	atualizar()
	# Trocar de aba ou de app por instantes (Web dá foco a cada troca) não abre a tela.
	if _saiu_em > 0.0 and fora >= VOLTA_MIN_S:
		_abrir_volta(rel)


func _mostrar_relatorio(rel: Dictionary, titulo: String) -> void:
	var patrocinio := int(rel.get("patrocinio", 0))
	if rel.is_empty() or (rel["corridas"].is_empty() and rel["erro"] == "" and patrocinio <= 0):
		return
	var g: Aba = _todas[0]
	var objetivos := Objetivos.lista(jogador, dados)
	var i_obj := Objetivos.atual(objetivos)
	var botoes := []
	if i_obj < objetivos.size():
		var aba_obj: int = objetivos[i_obj]["aba"]
		botoes = [[objetivos[i_obj]["botao"], func(): _ir_para(aba_obj)], ["Fechar", func(): pass]]
	_sobre.abrir(titulo, func(v):
		var corridas: Array = rel["corridas"]
		# Primeiro o plano: objetivo, dinheiro e o próximo obstáculo.
		var vp := g.cartao(Aba.COR_INFO, v)
		if i_obj < objetivos.size():
			g.rotulo("OBJETIVO %d/%d" % [i_obj + 1, objetivos.size()], Aba.FONTE_PEQUENA, Aba.COR_INFO, vp)
			g.rotulo(objetivos[i_obj]["texto"], 30, Color.WHITE, vp)
		g.rotulo("Saldo: %s giros" % Aba.dinheiro(jogador.economia.saldo), Aba.FONTE_PEQUENA + 3, Aba.COR_DESTAQUE, vp)
		var obstaculo := Objetivos.proximo_obstaculo(jogador, dados)
		if obstaculo != "":
			g.rotulo(obstaculo, Aba.FONTE_PEQUENA + 2, Color.WHITE, vp)
		if patrocinio > 0:
			var vpat := g.cartao(Aba.COR_DESTAQUE, v)
			g.rotulo("PATROCÍNIO", Aba.FONTE_PEQUENA, Aba.COR_DESTAQUE, vpat)
			g.rotulo("+%s giros enquanto você esteve fora" % Aba.dinheiro(patrocinio), 30, Color.WHITE, vpat)
			if rel.get("treino_concluido", false):
				g.rotulo("Treino concluído: energia cheia e o ritmo subiu.", Aba.FONTE_PEQUENA, Aba.COR_BOM, vpat)
			for nome in rel.get("patrocinios_encerrados", []):
				g.rotulo("Contrato de %s encerrado." % nome, Aba.FONTE_PEQUENA, Aba.COR_SECUNDARIA, vpat)
		if not corridas.is_empty():
			var vitorias := corridas.filter(func(c): return c["posicao"] == 1).size()
			var melhor: int = corridas.map(func(c): return c["posicao"]).min()
			var resumo := g.cartao(Aba.COR_BOM, v)
			g.rotulo("%d corrida%s · %d vitória%s · melhor %dº" % [corridas.size(), "" if corridas.size() == 1 else "s",
					vitorias, "" if vitorias == 1 else "s", melhor], 0, Color.WHITE, resumo)
			g.rotulo("+%s giros em prêmios" % Aba.dinheiro(rel["premio_total"]), 34, Aba.COR_DESTAQUE, resumo)
		for uid in rel["carros_premio"]:
			var cp: Carro = jogador.garagem.carro(uid)
			if cp != null:
				var vc := g.cartao(Aba.COR_DESTAQUE, v)
				g.rotulo("CARRO DE PRÊMIO", Aba.FONTE_PEQUENA, Aba.COR_DESTAQUE, vc)
				var h := g.fileira(vc)
				h.add_child(g.icone_carro(cp.base))
				g.rotulo(cp.base["nome"], 30, Color.WHITE, h)
				g.rotulo("Já está na sua garagem.", Aba.FONTE_PEQUENA, Aba.COR_SECUNDARIA, vc)
		if rel["erro"] != "":
			var ve := g.cartao(Aba.COR_RUIM, v)
			g.rotulo("A corrida parou: " + rel["erro"], 0, Aba.COR_RUIM, ve)
		if rel.get("tempo_perdido_s", 0.0) > 0.0:
			var teto: float = float(dados.carreira().get("teto_offline_s", 0.0))
			var vt := g.cartao(Aba.COR_INFO, v)
			# Dentro de um painel: sem ⓘ (abriria outro painel por cima).
			g.nota("icone_cronometro", "Limite fora do app: %s" % _duracao(teto), "", vt, Color.WHITE)
			g.rotulo("%s além dele não contaram." % _duracao(rel["tempo_perdido_s"]), Aba.FONTE_PEQUENA + 1,
					Aba.COR_SECUNDARIA, vt)
		if corridas.size() > 1:
			var detalhes := VBoxContainer.new()
			detalhes.visible = false
			var b := Button.new()
			b.text = "Ver cada corrida"
			b.custom_minimum_size = Vector2(0, Tipografia.ALTURA_SECUNDARIA)
			b.pressed.connect(func():
				detalhes.visible = not detalhes.visible
				b.text = "Esconder" if detalhes.visible else "Ver cada corrida")
			v.add_child(b)
			v.add_child(detalhes)
			for c in corridas:
				g.rotulo("%s · %dº · %s giros" % [dados.evento(c["evento_id"]).get("nome", ""), c["posicao"],
						Aba.dinheiro(c["premio"])], Aba.FONTE_PEQUENA + 2, Color.WHITE, detalhes), botoes)


static func _duracao(s: float) -> String:
	if s >= 3600.0:
		return "%d h %02d min" % [int(s) / 3600, (int(s) % 3600) / 60]
	return "%d min" % maxi(1, int(s) / 60)


func _tela_pendencias(raiz: VBoxContainer) -> void:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var linhas := ["Balanceamento incompleto — o jogo não pode começar.", ""]
	for e in dados.erros():
		linhas.append("ERRO: " + e)
	for p in dados.pendencias():
		linhas.append("• " + p)
	linhas.append("")
	linhas.append("Para ver as telas com dados de teste: godot -- --dados=res://tests/fixtures/")
	l.text = "\n".join(linhas)
	raiz.add_child(l)
