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
var _dialogo: Dialogo
var _destaque: Destaque
## Âncoras fora das abas (topo e navegação) para os destaques do tutorial.
var _ancoras := {}
## Cena com lembrete esperando: {"id", "t"} (segundos desde o fim da cena).
var _lembrete := {}
const LEMBRETE_S := 8.0  # apresentação: quanto esperar antes de lembrar
## Nome de cada aba no trigger da história (ABA:<nome>).
const NOMES_ABA := ["GARAGEM", "LOJA", "OFICINA", "EVENTOS", "CORRIDA", "LICENCAS", "EQUIPE"]
var _ao_vivo: Button
## Destinos da barra de baixo: [rótulo, índice da aba, ícone, ícone provisório?]. Oficina e Corrida são
## telas internas (de Garagem e Correr), abertas pelo caminho do jogo.
const DESTINOS := [["Garagem", 0, "aba_garagem"], ["Mercado", 1, "aba_mercado"], ["Correr", 3, "aba_competicoes"],
	["Carreira", 5, "aba_carreira"], ["Equipe", 6, "aba_equipe", "icone_piloto"]]
## Aba que só aparece quando a história libera (a equipe do jogador).
const ABA_EQUIPE := 6
const PAI := {2: 0, 4: 3}
## Título de cada tela no cabeçalho.
const TITULOS := ["Garagem", "Mercado", "Oficina", "Correr", "Corrida", "Carreira", "Equipe"]
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
	_cabecalho.acelerar.connect(_abrir_aceleracao)
	_cabecalho.marcador.visible = not _regras_aceleracao().is_empty()
	_ancoras["SALDO"] = _cabecalho.painel
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
	var eventos := preload("res://ui/aba_eventos.gd").new(dados, jogador)
	_todas = [
		preload("res://ui/aba_garagem.gd").new(dados, jogador),
		preload("res://ui/aba_loja.gd").new(dados, jogador),
		preload("res://ui/aba_oficina.gd").new(dados, jogador),
		eventos,
		preload("res://ui/aba_corrida.gd").new(dados, jogador),
		preload("res://ui/aba_licencas.gd").new(dados, jogador),
		preload("res://ui/aba_equipe.gd").new(dados, jogador),
	]
	for a in _todas:
		a.reservar_topo(_cabecalho.altura_total())
		_abas.add_child(a)
		a.mudou.connect(atualizar)
		a.ir_para.connect(func(i):
			_sobre.fechar()  # ex.: cenário aberto nas Configurações
			_sujar_todas()
			_ir_para(i))
	eventos.correr_iniciado.connect(func(): _ir_para(4))
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
	if jogador.historia != null:
		# O destaque fica abaixo do diálogo: o resto da tela escurece, a caixa não.
		_destaque = Destaque.new()
		add_child(_destaque)
		_dialogo = Dialogo.new(jogador.historia)
		add_child(_dialogo)
		jogador.historia.cena.connect(_dialogo.enfileirar)
		jogador.historia.cena.connect(_cena_pedida)
		_dialogo.acao.connect(_acao_tutorial)
		_dialogo.terminou.connect(_cena_terminou)
	if jogador.carro_ativo < 0 and not jogador.garagem.lista().is_empty():
		jogador.carro_ativo = jogador.garagem.lista()[0].uid
	atualizar()

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_processar_fila)
	timer.timeout.connect(_atualizar_ao_vivo)
	timer.timeout.connect(_foco_corrida)
	timer.timeout.connect(_registrar_fila)
	timer.timeout.connect(_atualizar_fps)
	timer.timeout.connect(_historia_corrida)
	timer.timeout.connect(_contar_lembrete)
	timer.timeout.connect(_atualizar_aceleracao)
	_atualizar_aceleracao()
	add_child(timer)
	var save_manager := get_node("/root/SaveManager")
	if save_manager.aviso != "":
		_sobre.abrir("Save", func(v): _todas[0].rotulo(save_manager.aviso, 0, Color.WHITE, v))
	_mostrar_relatorio(save_manager.relatorio_offline, "Enquanto você esteve fora")
	_fila_vista = jogador.fila
	RegistroSessao.inicio(jogador)
	RegistroSessao.corridas(save_manager.relatorio_offline, dados)
	if jogador.historia != null:
		historia_acao.connect(_acao_historia)
		_abertura()


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
		b.pressed.connect(_ir_para.bind(d[1]))
		barra.add_child(b)
		_botoes.append(b)
		_ancoras["NAV_" + NOMES_ABA[d[1]]] = b
	_ir_para.call_deferred(0)
	return barra


## A aba Equipe fica oculta até a Second Driver existir (documento, seção 29).
func _atualizar_nav() -> void:
	var cinco := EquipeJogador.criada(jogador)
	for k in _botoes.size():
		if DESTINOS[k][1] == ABA_EQUIPE:
			_botoes[k].visible = cinco
		# Cinco destinos: texto menor para os cinco caberem.
		_botoes[k].add_theme_font_size_override("font_size", 20 if cinco else 23)


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
	if jogador.historia != null:
		jogador.historia.disparar("ABA:" + NOMES_ABA[i])
	RegistroSessao.tela(i)
	var destino: int = PAI.get(i, i)
	for k in _botoes.size():
		_botoes[k].button_pressed = DESTINOS[k][1] == destino
	_cabecalho.definir_titulo(TITULOS[i].to_upper())
	_cabecalho.definir_volta(not _historico.is_empty())
	_atualizar_ao_vivo()
	_foco_corrida()


## Corridas aceleradas (decisão 39): regras de data/monetizacao.json.
func _regras_aceleracao() -> Dictionary:
	return dados.monetizacao().get("aceleracao", {})


func _atualizar_aceleracao() -> void:
	if _cabecalho != null:
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
				% [fator, minutos] + "só o tempo de corrida passa mais depressa. Vale também com o app fechado, "
				+ "e um vídeo novo soma tempo.", Aba.FONTE_PEQUENA, Color.WHITE, c)
		Configuracoes.cartao_sem_anuncios(aba, v, _comprar_sem_anuncios),
		[["Assistir vídeo · +%d min" % minutos, _assistir_video], ["Fechar", func(): pass]])


## Vídeo com recompensa (por enquanto, o de teste): no fim, soma a aceleração.
func _assistir_video() -> void:
	var video := VideoRecompensa.new()
	add_child(video)
	video.terminou.connect(func(assistiu):
		if not assistiu:
			return
		var erro := Aceleracao.ativar(jogador, _regras_aceleracao())
		if erro != "":
			_sobre.avisar("Não deu: %s." % erro, false)
			return
		get_node("/root/SaveManager").salvar()
		_atualizar_aceleracao()
		_sobre.avisar("Corridas %d× por mais %d min (faltam %s)." % [roundi(float(jogador.aceleracao["fator"])),
				roundi(float(_regras_aceleracao()["duracao_s"]) / 60.0),
				Aceleracao.texto_tempo(Aceleracao.restante_s(jogador))]))


## Compra Sem anúncios: o lugar já existe; a compra real entra com a loja do
## aparelho (depois do MVP).
func _comprar_sem_anuncios() -> void:
	_sobre.avisar("A compra Sem anúncios chega com a loja do aparelho, na versão final.", false)


## Engrenagem do cabeçalho.
func _abrir_configuracoes() -> void:
	_sobre.abrir("Configurações", func(v):
		Configuracoes.montar(_todas[5], v, jogador, _abrir_aceleracao, _comprar_sem_anuncios,
				func(vv): _todas[5]._modo_teste(vv)))


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
	_ao_vivo.visible = not f.is_empty() and not _abas.current_tab in [3, 4]
	if not _ao_vivo.visible:
		return
	var dur: float = jogador.fila_ctrl.duracao_atual()
	var falta := maxf(dur - (Aceleracao.agora(jogador) - float(f["inicio"])), 0.0)
	if Aceleracao.ativa(jogador):  # tempo real que falta (o relógio da corrida anda mais rápido)
		falta /= float(jogador.aceleracao["fator"])
	_ao_vivo.text = "●  AO VIVO%s · %s · %d:%02d   Assistir ›" % [" %d×" % int(jogador.aceleracao["fator"]) if Aceleracao.ativa(jogador) else "",
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
	if ok and _abas.current_tab == 4 and (not jogador.fila.is_empty() or _todas[4].em_silencio()):
		return
	_sobre.avisar(texto, ok)


## Estado mudou: a tela visível é refeita já; as outras só ficam marcadas e se
## refazem quando forem abertas (refazer as sete a cada toque levava segundos).
func atualizar() -> void:
	_sujar_todas()
	_reconstruir(_abas.current_tab)


func _reconstruir(i: int) -> void:
	if _sujas.has(i):
		_sujas.erase(i)
		_todas[i].atualizar()


func _sujar_todas() -> void:
	for i in _todas.size():
		_sujas[i] = true
	_cabecalho.definir_giros(Aba.dinheiro(jogador.economia.saldo))
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
	var abas := {"OPEN_GARAGE_TAB": 0, "RETURN_TO_GARAGE": 0, "OPEN_DEALERSHIP": 1, "OPEN_TUNE_SERVICE": 2,
			"OPEN_EVENTS": 3, "OPEN_LICENSE_CENTER": 5, "OPEN_TEAM_FINANCE": ABA_EQUIPE}
	if abas.has(nome):
		_ir_para(abas[nome])
		atualizar()
	elif nome.begins_with("HIGHLIGHT_"):
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
	# Espera o layout para saber onde o elemento ficou.
	await get_tree().process_frame
	await get_tree().process_frame
	var alvo: Control = aba.ancoras.get(nome)
	if not is_instance_valid(alvo):
		return
	# Rola só se o elemento não está inteiro na tela (a corrida não sai do lugar).
	if not aba.get_global_rect().encloses(alvo.get_global_rect()):
		aba.scroll_vertical = maxi(int(alvo.global_position.y - aba.conteudo.global_position.y) - 24, 0)
		await get_tree().process_frame
		if not is_instance_valid(alvo):
			return
	# Reconstruída a aba, o destaque acha o controle novo pela mesma âncora.
	_destaque.mostrar(alvo, func(): return aba.ancoras.get(nome) if aba.is_visible_in_tree() else null)
	_dialogo.evitar(alvo.get_global_rect())


## Uma cena começa: a da largada segura a corrida no grid até acabar.
func _cena_pedida(c: Dictionary) -> void:
	if c.get("segura_largada", false):
		_todas[4].segurar_largada = true


## Cena terminada: salva; o destaque fica só se ela acabou nele (o jogador tem
## de tocar ali); a cena com lembrete começa a contar; a largada é liberada.
func _cena_terminou(c: Dictionary) -> void:
	var falas: Array = c.get("falas", [])
	var ultima := String(falas[-1].get("acao", "")) if not falas.is_empty() else ""
	if not ultima.begins_with("HIGHLIGHT_"):
		_destaque.limpar()
	if c.get("lembrete") != null:
		_lembrete = {"id": c["lembrete"], "t": 0.0}
	if c.get("segura_largada", false):
		_todas[4].liberar_largada()
	atualizar()
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


## Jogo novo com a história: a volta do Adrian sozinho na pista e, no fim
## dela, a primeira cena (GAME_START). Só uma vez (flag VOLTA_ABERTURA).
func _abertura() -> void:
	var h: Historia = jogador.historia
	if jogador.personagem != "adrian" or jogador.flags.has("VOLTA_ABERTURA") or h.cena_para("GAME_START").is_empty():
		h.disparar("GAME_START")
		return
	var volta := VoltaAbertura.new(dados, jogador)
	add_child(volta)
	volta.terminou.connect(func():
		jogador.flags["VOLTA_ABERTURA"] = true
		h.disparar("GAME_START"))


## Prólogo: durante a última corrida do Adrian, o rádio e depois o acidente.
func _historia_corrida() -> void:
	if jogador.historia == null or not Prologo.ultima_corrida_ativa(jogador):
		return
	var dur: float = jogador.fila_ctrl.duracao_atual()
	if dur <= 0.0:
		return
	var feito: float = (Aceleracao.agora(jogador) - float(jogador.fila["inicio"])) / dur
	var cfg: Dictionary = dados.historia()
	if feito >= float(cfg.get("radio_fracao", 0.4)):
		jogador.historia.disparar("RADIO_ULTIMA_CORRIDA")
	if feito >= float(cfg.get("acidente_fracao", 0.6)):
		Prologo.acidente(jogador)
		jogador.historia.disparar("ACIDENTE")
		atualizar()
		get_node("/root/SaveManager").salvar()


func _acao_historia(nome: String) -> void:
	if nome == "SALTO_TEMPORAL":
		Prologo.salto_temporal(dados, jogador)
		atualizar()
		get_node("/root/SaveManager").salvar()
	elif nome == "OPEN_DRIVER_HIRE":
		# Segundo piloto entra na equipe, sem contrato (decisão 38).
		EquipeJogador.liberar_segundo(dados, jogador)
		atualizar()
		_ir_para(ABA_EQUIPE)
	elif nome == "UNLOCK_TEAM_TAB":
		# A Second Driver nasce na cena: nada é resetado, só a aba aparece.
		EquipeJogador.criar(jogador)
		atualizar()
		_ir_para(ABA_EQUIPE)


## Decisão 34: prova inédita ou etapa de campeonato só corre com o app aberto.
func _texto_recomecou(evento_id: String) -> String:
	return "%s recomeçou agora: prova inédita e etapa de campeonato só correm com o app aberto." \
			% dados.evento(evento_id).get("nome", evento_id)


func _processar_fila() -> void:
	if jogador.fila.is_empty():
		return
	var antes_vitorias: Dictionary = jogador.vitorias.duplicate()
	var rel: Dictionary = jogador.fila_ctrl.processar(Aceleracao.agora(jogador))
	RegistroSessao.corridas(rel, dados)
	if rel.has("recomecou"):
		_todas[0].avisar(_texto_recomecou(rel["recomecou"]), true)
	if rel["corridas"].is_empty() and rel["erro"] == "":
		return
	atualizar()
	get_node("/root/SaveManager").salvar()
	# Uma corrida terminando com o app aberto: aviso curto e a tela de Corrida
	# mostra o resultado. Várias (voltou do segundo plano), erro ou carro-prêmio:
	# relatório.
	if rel["corridas"].size() == 1 and rel["erro"] == "":
		# Assistindo: um silêncio depois da chegada antes do resultado (a tela da
		# corrida fica parada na última imagem o mesmo tempo).
		if _abas.current_tab == 4:
			var corrida = _todas[4]
			await get_tree().create_timer(corrida.ESCURECER_EM_S).timeout
			_sobre.escurecer(true, corrida.SILENCIO_S - corrida.ESCURECER_EM_S)
			await get_tree().create_timer(corrida.SILENCIO_S - corrida.ESCURECER_EM_S).timeout
		var c: Dictionary = rel["corridas"][0]
		var primeira: bool = not antes_vitorias.has(c["evento_id"])
		# A conversa da chegada vem antes do resultado, sobre a tela escura.
		if jogador.historia != null and jogador.historia.disparar("CORRIDA_FIM",
				{"posicao": int(c["posicao"]), "evento": c["evento_id"]}):
			_quando_dialogo_acabar(_resultado.bind(c, primeira))
		else:
			_resultado(c, primeira)
		return
	_mostrar_relatorio(rel, "Resultado das corridas")


func _notification(what: int) -> void:
	# Volta do segundo plano: aplica o que correu enquanto isso, na hora.
	if what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN] and _sobre != null:
		RegistroSessao.inicio(jogador)  # antes da fila: as corridas de fora entram na sessão
		RegistroSessao.tela(_abas.current_tab)
		_processar_fila()
		_fila_vista = jogador.fila
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST] \
			and _sobre != null:
		RegistroSessao.fim(jogador)


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
	if jogador.fila.is_empty() or is_same(jogador.fila, _fila_vista):
		return
	_fila_vista = jogador.fila
	RegistroSessao.fila(jogador.fila, jogador.fila_ctrl.duracao_atual(), not jogador.vitorias.has(jogador.fila["evento_id"]))


## Resultado de uma corrida terminada com o app aberto: posição em destaque,
## recompensa e a próxima decisão.
func _resultado(c: Dictionary, primeira: bool) -> void:
	var g: Aba = _todas[0]
	var venceu: bool = c["posicao"] == 1
	var ev: Dictionary = dados.evento(c["evento_id"])
	var continua: bool = not jogador.fila.is_empty()
	var botoes := []
	if continua:
		botoes = [["Assistir a próxima", func(): _ir_para(4), "icone_ao_vivo"], ["Fechar", func(): pass]]
	else:
		botoes = [["Disputar de novo", func():
				var m: String = jogador.fila_ctrl.iniciar(c["evento_id"], c["uid"], 1, Aceleracao.agora(jogador))
				if m != "":
					_sobre.avisar("Não deu para correr: %s." % m, false)
				else:
					_ir_para(4)
				atualizar(), "icone_de_novo"],
			["Oficina", func():
				jogador.carro_ativo = c["uid"]
				_ir_para(2)
				atualizar(), "icone_melhorar"],
			["Escolher outra corrida", func(): _ir_para(3), "aba_competicoes"]]
		var carro_corrida: Carro = jogador.garagem.carro(c["uid"])
		if not venceu and carro_corrida != null:
			# Derrota: comparar preparações antes de gastar outra corrida inteira.
			botoes.insert(1, ["Comparar montagens", func(): g.testar_preparacao(c["evento_id"], carro_corrida), "icone_comparar"])
		# A ação em destaque (primeira) é a que leva ao próximo objetivo.
		var alvo_obj: Array = Objetivos.lista(jogador, dados)
		var i_obj := Objetivos.atual(alvo_obj)
		var aba_obj: int = alvo_obj[i_obj]["aba"] if i_obj < alvo_obj.size() else -1
		var primeiro := 0
		if aba_obj == Aba.OFICINA or (not venceu and aba_obj != Aba.EVENTOS):
			primeiro = 1
		elif aba_obj == Aba.EVENTOS and venceu:
			primeiro = 2
		if primeiro > 0:
			var b = botoes[primeiro]
			botoes.remove_at(primeiro)
			botoes.push_front(b)
	# A conversa da chegada já veio antes do painel; a do título de campeão vem
	# depois que o jogador lê o resultado (qualquer botão do painel).
	for b in botoes:
		b[1] = _depois_do_resultado.bind(c, b[1])
	var meu: Carro = jogador.garagem.carro(c["uid"])
	var tabela: Array = c.get("tabela", [])
	var objetivos := Objetivos.lista(jogador, dados)
	var obj := Objetivos.atual(objetivos)
	_sobre.abrir("VITÓRIA!" if venceu else "Resultado", func(v):
		if meu != null:
			# Palco (arte da interface) com o carro em cima.
			var palco := g.ilustracao("fundo_resultado", 300, v, 0.25)
			var foto := Estudio.imagem(meu.base, CarroBloco.cor_do_carro(meu), Vector2(0, 0))
			foto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			foto.offset_top = 20
			foto.offset_bottom = -20
			palco.add_child(foto)
		var pos := Label.new()
		pos.text = "%dº de %d" % [c["posicao"], c["total"]]
		pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Tipografia.numero(pos, 76)
		pos.add_theme_color_override("font_color", Aba.COR_DESTAQUE if venceu else Color.WHITE)
		v.add_child(pos)
		var nome_ev := g.rotulo(Aba.nome_evento(ev), Aba.FONTE_PEQUENA + 3, Aba.COR_SECUNDARIA, v)
		nome_ev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if float(c.get("tempo_jogador", 0.0)) > 0.0:
			var tempo := g.rotulo("Tempo %s" % HudCorrida._tempo(float(c["tempo_jogador"])), Aba.FONTE_PEQUENA + 3,
					Color.WHITE, v)
			tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if tabela.size() >= 2:
			var t0: float = tabela[0]["tempo"]
			var dif := g.rotulo("%.1f s à frente do 2º" % (tabela[1]["tempo"] - t0) if venceu
					else "%.1f s atrás do vencedor" % (c["tempo_jogador"] - t0), Aba.FONTE_PEQUENA + 3, Color.WHITE, v)
			dif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_podio(v, tabela, c)
		if c["premio"] > 0:
			var hs := HBoxContainer.new()
			hs.alignment = BoxContainer.ALIGNMENT_CENTER
			v.add_child(hs)
			g.icone("icone_creditos", 48, hs)
			var liquido: int = int(c.get("folha", {}).get("patrocinio", 0)) - int(c.get("folha", {}).get("cobrado", 0))
			var saldo := g.rotulo("%s → %s  (+%s)" % [Aba.dinheiro(jogador.economia.saldo - liquido - c["premio"]),
					Aba.dinheiro(jogador.economia.saldo), Aba.dinheiro(c["premio"])], 30, Aba.COR_BOM, hs)
			saldo.autowrap_mode = TextServer.AUTOWRAP_OFF
			saldo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var marcos := []
		if int(c.get("posicao_companheiro", 0)) > 0:
			# Equipe: vale quem chegou na frente (fase 9).
			marcos.append(["%s %dº · %s %dº" % [EquipeJogador.nome_jogador(dados, jogador), c["posicao_propria"], EquipeJogador.nome_segundo(dados, jogador),
					c["posicao_companheiro"]], Aba.COR_INFO])
		var folha: Dictionary = c.get("folha", {})
		if int(folha.get("patrocinio", 0)) > 0 or int(folha.get("cobrado", 0)) > 0:
			marcos.append(["Equipe: patrocínio +%s · folha −%s G" % [Aba.dinheiro(int(folha["patrocinio"])),
					Aba.dinheiro(int(folha["cobrado"]))], Aba.COR_INFO])
		if venceu and primeira:
			marcos.append(["PRIMEIRA VITÓRIA NESTA CORRIDA", Aba.COR_DESTAQUE])
		if c.get("recorde", false) and not c.get("anterior", {}).is_empty():
			marcos.append(["RECORDE PESSOAL", Aba.COR_BOM])
		if not c.get("anterior", {}).is_empty():
			var dp: int = int(c["anterior"]["ultima_pos"]) - int(c["posicao"])
			if dp != 0:
				marcos.append(["%s %d posiç%s desde a última vez" % ["subiu" if dp > 0 else "caiu", absi(dp),
						"ão" if absi(dp) == 1 else "ões"], Aba.COR_BOM if dp > 0 else Aba.COR_RUIM])
		var camp: Dictionary = c.get("campeonato", {})
		if not camp.is_empty():
			if camp.get("final", false):
				marcos.append(["CAMPEÃO: %s" % camp["serie"] if camp["campeao"] else
						"%s: %dº no campeonato" % [camp["serie"], camp["posicao_final"]],
						Aba.COR_DESTAQUE if camp["campeao"] else Aba.COR_INFO])
				if int(camp.get("bonus", 0)) > 0:
					marcos.append(["Bônus de campeão +%s G" % Aba.dinheiro(int(camp["bonus"])), Aba.COR_BOM])
			else:
				marcos.append(["Campeonato: +%d pts · etapa %d de %d" % [camp["pontos"], camp["etapa"], camp["total"]],
						Aba.COR_INFO])
		g.selos(marcos, v)
		if c.get("carro_premio_uid", -1) > 0:
			var cp: Carro = jogador.garagem.carro(c["carro_premio_uid"])
			if cp != null:
				var vc := g.cartao(Aba.COR_DESTAQUE, v)
				g.rotulo("CARRO DE PRÊMIO: %s" % cp.base["nome"], Aba.FONTE_PEQUENA + 2, Aba.COR_DESTAQUE, vc)
				vc.add_child(Estudio.imagem(cp.base, CarroBloco.cor_do_carro(cp), Vector2(0, 170)))
		if obj < objetivos.size():
			var lo := g.rotulo("Objetivo %d/%d: %s" % [obj + 1, objetivos.size(), objetivos[obj]["texto"]], Aba.FONTE_PEQUENA + 2,
					Aba.COR_INFO.lightened(0.3), v)
			lo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not venceu:
			var dica := g.rotulo("Por que perdi? Veja na tela da corrida.", Aba.FONTE_PEQUENA,
					Aba.COR_SECUNDARIA, v)
			dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER, botoes)


func _depois_do_resultado(c: Dictionary, acao: Callable) -> void:
	var g: Aba = _todas[0]
	acao.call()
	if c.get("campeonato", {}).get("campeao", false):
		g.historia("CAMPEONATO_VENCIDO", {"evento": c["evento_id"]})


## Pódio dos três primeiros: degraus de alturas diferentes, o jogador em ouro.
func _podio(v: VBoxContainer, tabela: Array, c: Dictionary) -> void:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	for pos in [2, 1, 3]:
		if pos > tabela.size():
			continue
		var id: String = tabela[pos - 1]["id"]
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_END
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		var nome := Label.new()
		nome.text = EquipeJogador.nome_jogador(dados, jogador) if id == "jogador" else (EquipeJogador.nome_segundo(dados, jogador) if id == EquipeJogador.ID
				else jogador.carreira.nome_piloto(c["evento_id"], id, int(c.get("semente", -1))))
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome.add_theme_font_size_override("font_size", 23)
		nome.add_theme_color_override("font_color", Aba.COR_DESTAQUE if id == "jogador" else Color.WHITE)
		col.add_child(nome)
		var sil := TextureRect.new()
		sil.texture = Aba.arte({1: "piloto_silhueta_3", 2: "piloto_silhueta_1", 3: "piloto_silhueta_2"}[pos])
		sil.custom_minimum_size = Vector2(0, {1: 130, 2: 112, 3: 104}[pos])
		sil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if id == "jogador":
			sil.modulate = Aba.COR_DESTAQUE.lightened(0.3)
		col.add_child(sil)
		var degrau := PanelContainer.new()
		degrau.custom_minimum_size = Vector2(0, {1: 90, 2: 64, 3: 46}[pos])
		var sb := StyleBoxFlat.new()
		sb.bg_color = Aba.COR_DESTAQUE.darkened(0.15) if id == "jogador" else Color(0.26, 0.28, 0.33)
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		degrau.add_theme_stylebox_override("panel", sb)
		var dh := HBoxContainer.new()
		dh.alignment = BoxContainer.ALIGNMENT_CENTER
		dh.add_theme_constant_override("separation", 4)
		degrau.add_child(dh)
		var trofeu := TextureRect.new()
		trofeu.texture = Aba.arte({1: "icone_trofeu_ouro", 2: "icone_trofeu_prata", 3: "icone_trofeu_bronze"}[pos])
		trofeu.custom_minimum_size = Vector2(38, 38)
		trofeu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trofeu.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		trofeu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dh.add_child(trofeu)
		var n := Label.new()
		n.text = "%dº" % pos
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.add_theme_font_size_override("font_size", 30)
		n.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1) if id == "jogador" else Color.WHITE)
		dh.add_child(n)
		col.add_child(degrau)
		h.add_child(col)


func _primeira_vitoria(c: Dictionary) -> void:
	var g: Aba = _todas[0]
	_sobre.abrir("Primeira vitória!", func(v):
		g.rotulo(dados.evento(c["evento_id"]).get("nome", ""), 30, Aba.COR_DESTAQUE, v)
		g.nota("icone_creditos", "Prêmio: +%s" % Aba.dinheiro(c["premio"]), "", v, Color.WHITE)
		g.nota("icone_dica", "Agora: corrida que paga mais, ou Oficina", "", v))


## Relatório de várias corridas (offline ou segundo plano): resumo e, sob
## pedido, a lista de cada corrida.
func _mostrar_relatorio(rel: Dictionary, titulo: String) -> void:
	if rel.is_empty() or (rel["corridas"].is_empty() and rel["erro"] == ""):
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
		g.rotulo("Saldo: %s G" % Aba.dinheiro(jogador.economia.saldo), Aba.FONTE_PEQUENA + 3, Aba.COR_DESTAQUE, vp)
		var obstaculo := Objetivos.proximo_obstaculo(jogador, dados)
		if obstaculo != "":
			g.rotulo(obstaculo, Aba.FONTE_PEQUENA + 2, Color.WHITE, vp)
		for cid in jogador.desejos:
			var p := Usados.proxima(dados.carro(cid), jogador.dias, jogador.usados_vendidos)
			if not p.is_empty() and p["inicio"] <= jogador.dias:
				g.rotulo("♥ %s à venda nos usados por %s G" % [dados.carro(cid)["nome"], Aba.dinheiro(p["preco"])],
						Aba.FONTE_PEQUENA + 2, Aba.COR_DESTAQUE, vp)
		if not corridas.is_empty():
			var vitorias := corridas.filter(func(c): return c["posicao"] == 1).size()
			var melhor: int = corridas.map(func(c): return c["posicao"]).min()
			var resumo := g.cartao(Aba.COR_BOM, v)
			g.rotulo("%d corrida%s · %d vitória%s · melhor %dº" % [corridas.size(), "" if corridas.size() == 1 else "s",
					vitorias, "" if vitorias == 1 else "s", melhor], 0, Color.WHITE, resumo)
			g.rotulo("+%s G em prêmios" % Aba.dinheiro(rel["premio_total"]), 34, Aba.COR_DESTAQUE, resumo)
		for uid in rel["carros_premio"]:
			var cp: Carro = jogador.garagem.carro(uid)
			if cp != null:
				var vc := g.cartao(Aba.COR_DESTAQUE, v)
				g.rotulo("CARRO DE PRÊMIO", Aba.FONTE_PEQUENA, Aba.COR_DESTAQUE, vc)
				var h := g.fileira(vc)
				h.add_child(g.icone_carro(cp.base))
				g.rotulo(cp.base["nome"], 30, Color.WHITE, h)
				g.rotulo("Já está na sua garagem.", Aba.FONTE_PEQUENA, Aba.COR_SECUNDARIA, vc)
		if rel.has("recomecou"):
			var vr := g.cartao(Aba.COR_INFO, v)
			g.rotulo(_texto_recomecou(rel["recomecou"]), Aba.FONTE_PEQUENA + 1, Color.WHITE, vr)
		if rel["erro"] != "":
			var ve := g.cartao(Aba.COR_RUIM, v)
			g.rotulo("A sequência de corridas parou: " + rel["erro"], 0, Aba.COR_RUIM, ve)
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
			b.custom_minimum_size = Vector2(0, 68)
			b.pressed.connect(func():
				detalhes.visible = not detalhes.visible
				b.text = "Esconder" if detalhes.visible else "Ver cada corrida")
			v.add_child(b)
			v.add_child(detalhes)
			for c in corridas:
				g.rotulo("%s · %dº · %s G" % [dados.evento(c["evento_id"]).get("nome", ""), c["posicao"],
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
