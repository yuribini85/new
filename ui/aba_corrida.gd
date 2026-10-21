extends Aba
## Corrida ao vivo: mostra a corrida em andamento da fila no tempo real.
## O resultado já está decidido pela simulação; a tela só o reproduz.
## A vista 3D e o HUD (com a classificação) são fixos; só o painel de baixo
## (resultado da última corrida e "O que ajuda?") é reconstruído.

## Pede para encerrar a corrida em andamento agora (só no playtest "clareza").
signal pular

## A tela segue a hierarquia: a corrida domina; o estado da corrida (HUD e
## eventos) vem em segundo; os controles de câmera em terceiro; meta-jogo e
## navegação ficam no fundo (apagados pela tela principal durante a corrida).
## Ritmo: nada aparece ou some de uma vez (fades curtos).

## Seletor de câmera: some (perde contraste) depois deste tempo sem toque.
const SELETOR_OCIOSO_S := 4.0
const SELETOR_APAGADO := 0.3
## Depois da chegada: os carros seguem freando e a tela escurece antes do
## resultado (a tela principal espera o mesmo antes de abrir o painel).
const SILENCIO_S := 3.6
## Começo e duração do escurecimento dentro do silêncio.
const ESCURECER_EM_S := 1.0
## Eventos: aproximação vale quando a diferença cai abaixo disto (s), e o
## mesmo rival não gera outro aviso antes de EVENTO_RIVAL_S.
const APROXIMA_S := 0.6
const EVENTO_RIVAL_S := 20.0
## Disputa (s): a tela "respira" (secundários apagam) com alguém a menos disto.
const RESPIRA_S := 0.45

## Câmeras: nome (só na dica do mouse) e modo; o ícone é arte/ui/cameras/<modo>.png
## (branco, tingido pelo estado). Sem texto no botão: o jogador descobre tocando.
const CAMERAS := [["Automática", "auto", "AUTO"], ["Seu carro", "jogador", "SEU CARRO"], ["Líder", "lider", "LÍDER"],
		["À frente", "frente", "À FRENTE"], ["Pista inteira", "geral", "PISTA"], ["Dados", "dados", "DADOS"]]

## Minimapa (pista inteira) e fonte das posições da vista 3D.
var _visual: CorridaVisual
var _visual3d: Corrida3D
var _vista: VistaDados  # câmera DADOS: a corrida em números, sem 3D
var _tatica: Array = []  # curvas da pista para o carro inscrito (Tatica.curvas)
var _minimapa: Control
var _area: Control
var _info: Label
var _relogio: Label
var _painel_hud: HudCorrida
var _atributos_hud := {}  # atributos do carro inscrito (marcha e giro no HUD)
var _cameras: Control
var _cameras_botoes: Array = []
var _ocioso := 0.0
## Momentos de decisão (decisão 117): o cartão, o resultado mostrado (onde o
## momento é procurado), quantos já vieram e quando foi o último.
var _cartao: CartaoMomento
var _resultado: Dictionary = {}
var _versao_mostrada := -1
var _momentos := 0
var _t_momento := -INF
## O próximo momento, achado ANTECEDENCIA_S antes enquanto a fila refaz a
## corrida com cada escolha (Fila.prever); só aparece se alguma muda o duelo
## (MomentosCorrida.avaliar). {t, m, ordens, avaliacao?} ou {}.
var _proximo := {}
var _varrido := 0.0  # até onde a corrida mostrada já foi procurada (s de corrida)
## A escolha feita, em curso: {id, m, ordem, vence, t, outra, mostrado} ou {}.
var _em_curso := {}
## Técnicos: antecedência (deixa a fila refazer a corrida duas vezes aos poucos
## em aparelho fraco), quanto de corrida procurar por quadro e o salto depois
## de um momento descartado (10 s: medido, os mesmos cartões com um terço das
## corridas refeitas que 3 s).
const ANTECEDENCIA_S := 10.0
const VARRE_S := 2.0
const PASSO_S := 10.0
## Clarão da tela no toque e na comemoração (só visual).
var _clarao: ColorRect
var _t_clarao := 0.0
const CLARAO_S := 0.45
## Segundos de corrida até a dica da câmera.
const DICA_CAMERA_S := 6.0
var _dica_camera_pedida := false
var _semente_mostrada := 0
## Corrida cuja largada (3-2-1 ou espera no grid) já foi tratada: remontar a
## vista (atualizar) não recomeça a contagem.
var _semente_largada := 0
## Tempo mostrado suavizado (_tempo_suave): valor, alvo do quadro anterior e
## taxa medida (s de corrida por s de quadro).
var _t_suave := -1.0
const SALTO_TEMPO_S := 0.5
var _nomes := {}  # id do participante -> nome do carro
var _nomes_curtos := {}  # id -> nome na classificação do HUD
var _equipes := {}  # id -> nome da equipe (vazio: sem equipe)
var _pista: Pista
var _voltas := 1
var _posicao_antes := 0
var _volta_antes := 0
var _melhor_volta := -1.0
var _avisado := {}  # rival -> tempo do último aviso de aproximação
var _painel: VBoxContainer
var _analisando := false
var _em_andamento := false
var _vazio_topo: Control
var _nome_prova: Label
const ALTURA_MIN_AREA := 720.0
## Quadros com a capa depois de montar a pista (o primeiro desenho e o
## aquecimento dos efeitos acontecem por trás dela).
const CARGA_QUADROS := 4
var _carga: Control
var _carga_texto: Label
var _carga_espera := 0
var _carga_semente := 0  # a corrida para a qual a capa já apareceu
var _carga_sair := -1
var _sons: Sons
var _s_jogador := 0.0
var _chegou := false
var _t_chegada := 0.0
var _segurar := 0.0  # segundos parados na última imagem depois do fim
var _diretor := DiretorCamera.new()
var _foco_auto := "jogador"
## Conversa antes da largada: a corrida fica no grid até a fila de conversas
## acabar (principal.gd segura e libera); depois, o 3-2-1.
var segurar_largada := false
## Há conversa na tela? (a principal liga ao diálogo; sem ela, nunca)
var dialogo_aberto := func() -> bool: return false


## Velocidade máxima do carro inscrito (km/h): o HUD doura o número perto dela.
var _kmh_max := 0.0
## Largada: 3-2-1 com o grid parado (s que faltam; < 0 = sem contagem).
const CONTAGEM_S := 3.0
var _contagem := -1.0
## Chegada: a imagem para PAUSA_CHEGADA_S quando você cruza e depois alcança
## o relógio de novo (_atraso volta a zero). Só apresentação.
const PAUSA_CHEGADA_S := 0.3
const ALCANCE := 0.25  # s de atraso recuperados por segundo
var _atraso := 0.0
var _pausa := 0.0
## Pilotagem por toques (decisão 127, Pilotagem): a régua (FREIE / SEGURE), o
## botão de ataque, o dedo na tela e o que já foi feito em cada curva.
var _pil: Dictionary = {}
var _pedal: PedalPilotagem
var _botao_ataque: Button
var _segurando := false
var _feitas := {}  # curva (distância de entrada na corrida, m) -> nota
## A frenagem esperando o toque: {chave, t_frenagem, fim} ou {}.
var _frenagem := {}
## A curva em que o carro está (para a saída): {chave, fim, com_frenagem} ou {}.
var _na_curva := {}
## A saída em curso: {de, ate, soltou} ou {}.
var _saida := {}
var _s_antes_pil := 0.0
var _ultimo_ataque := -INF
## A corrida refeita por um toque, emendada na tela enquanto termina (Fila.parcial).
var _versao_parcial := 0
var _emenda_desde := -1.0
var _emenda_i := 0

func _init(d: Node, j: Node) -> void:
	super(d, j, "Corrida")
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER  # a corrida cabe na tela: sem rolagem
	_info = rotulo("", 30)
	_relogio = rotulo("", FONTE_PEQUENA, COR_SECUNDARIA)
	# A corrida ocupa a tela: começa no topo absoluto (por trás do cabeçalho),
	# vai de borda a borda e desce até o seletor de câmeras (_ajustar_area). O
	# HUD e a vista DADOS começam abaixo do cabeçalho (topo_livre).
	var area := Control.new()
	_area = area
	area.custom_minimum_size = Vector2(0, ALTURA_MIN_AREA)
	conteudo.add_child(area)
	_visual3d = Corrida3D.new()
	_visual3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual3d.offset_left = -MARGEM_LATERAL
	_visual3d.offset_right = MARGEM_LATERAL
	area.add_child(_visual3d)
	# Minimapa direto sobre a pista, sem caixa (o traçado tem sombra própria),
	# no canto de baixo à direita: os cantos de cima são da posição e da volta.
	_minimapa = Control.new()
	_minimapa.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	# Afastado das bordas: o traçado não encosta embaixo nem do lado.
	_minimapa.offset_left = -190
	_minimapa.offset_right = -16
	_minimapa.offset_top = -170
	_minimapa.offset_bottom = -16
	_minimapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(_minimapa)
	_carga = ColorRect.new()
	(_carga as ColorRect).color = COR_FUNDO
	_carga.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_carga.offset_left = -MARGEM_LATERAL
	_carga.offset_right = MARGEM_LATERAL
	_carga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carga.visible = true  # começa coberta: a área só aparece com a pista pronta
	area.add_child(_carga)
	_carga_texto = Label.new()
	_carga_texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_carga_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_carga_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_carga_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Tipografia.rotulo(_carga_texto, "semibold", 34)
	_carga_texto.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	_carga.add_child(_carga_texto)
	_visual = CorridaVisual.new()
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.escala_carro = 2.2
	_visual.largura_min_px = 5.0
	_visual.com_rotulos = false
	_visual.girar = false
	_visual.sombra = true
	_minimapa.add_child(_visual)
	_vista = VistaDados.new()
	_vista.visible = false
	area.add_child(_vista)
	_painel_hud = HudCorrida.new()
	_painel_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_painel_hud.escolhido.connect(_camera)
	area.add_child(_painel_hud)
	_cartao = CartaoMomento.new()
	_cartao.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_cartao.offset_left = -300
	_cartao.offset_right = 300
	_cartao.offset_top = -420
	_cartao.offset_bottom = -190
	_cartao.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cartao.escolhido.connect(_ordenar)
	_cartao.expirou.connect(_descartar_proximo)
	_clarao = ColorRect.new()
	_clarao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clarao.color = Color(1, 1, 1, 0)
	area.add_child(_clarao)
	area.add_child(_cartao)
	_pil = Pilotagem.params(dados)
	_pedal = PedalPilotagem.new()
	# No alto, entre a posição e a volta: o carro fica no meio da tela e a
	# classificação embaixo.
	_pedal.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_pedal.offset_left = -230
	_pedal.offset_right = 230
	_pedal.offset_top = 330
	_pedal.offset_bottom = 400
	_pedal.visible = false
	area.add_child(_pedal)
	_botao_ataque = Button.new()
	_botao_ataque.focus_mode = Control.FOCUS_NONE
	Tipografia.acao_primaria(_botao_ataque, "ATACAR")
	# À direita, acima do minimapa (a classificação fica à esquerda).
	_botao_ataque.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_botao_ataque.offset_left = -236
	_botao_ataque.offset_right = -16
	_botao_ataque.offset_top = -290
	_botao_ataque.offset_bottom = -196
	_botao_ataque.visible = false
	_botao_ataque.pressed.connect(_atacar)
	area.add_child(_botao_ataque)
	# Nome da prova e da pista no pé da corrida, logo acima das câmeras.
	_nome_prova = rotulo("", FONTE_PEQUENA, COR_SECUNDARIA)
	_nome_prova.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome_prova.autowrap_mode = TextServer.AUTOWRAP_OFF
	_nome_prova.clip_text = true
	_nome_prova.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_cameras = _seletor_cameras()
	conteudo.add_child(_cameras)
	_painel = VBoxContainer.new()
	_painel.add_theme_constant_override("separation", 14)
	conteudo.add_child(_painel)
	Preferencias.carregar()
	_camera_modo = "dados" if Preferencias.vista_corrida == "dados" else "auto"
	_sons = Sons.new()
	add_child(_sons)
	resized.connect(_ajustar_area)


## Seletor único e compacto, ícones com o nome curto embaixo: automática, seu
## carro, líder, à frente, pista inteira e dados. São filtros de acompanhamento, não ações:
## baixos, num fundo só, o escolhido em âmbar (ícone escuro).
func _seletor_cameras() -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COR_CARTAO, 0.7)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(3)
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	p.add_child(h)
	var vazio := StyleBoxEmpty.new()
	var marcado := StyleBoxFlat.new()
	marcado.bg_color = COR_DESTAQUE
	marcado.set_corner_radius_all(8)
	for c in CAMERAS:
		var b := Button.new()
		b.tooltip_text = c[0]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, Tipografia.ALTURA_SECUNDARIA)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ic := TextureRect.new()
		ic.texture = arte("cameras/" + String(c[1]))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.modulate = COR_SECUNDARIA
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		ic.offset_left = -23
		ic.offset_right = 23
		ic.offset_top = -33
		ic.offset_bottom = 13
		b.add_child(ic)
		# O nome curto: o ícone sozinho não dizia o que cada câmera mostra.
		var nome := Label.new()
		nome.text = String(c[2])
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome.clip_text = true
		Tipografia.rotulo(nome, "semibold", 15)
		nome.add_theme_color_override("font_color", COR_SECUNDARIA)
		nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nome.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		nome.offset_top = -26
		nome.offset_bottom = -6
		b.add_child(nome)
		for estado in ["normal", "hover", "focus", "disabled"]:
			b.add_theme_stylebox_override(estado, vazio)
		for estado in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(estado, marcado)
		b.pressed.connect(_camera.bind(c[1]))
		h.add_child(b)
		if c[1] == "auto":
			ancora("CAMERA_AUTO", b)
		_cameras_botoes.append(b)
	return p


var _camera_modo := "auto":
	set(v):
		_camera_modo = v
		for i in _cameras_botoes.size():
			var marcado: bool = CAMERAS[i][1] == v
			_cameras_botoes[i].button_pressed = marcado
			(_cameras_botoes[i].get_child(0) as TextureRect).modulate = Color(0.1, 0.1, 0.1) if marcado else COR_SECUNDARIA
			(_cameras_botoes[i].get_child(1) as Label).add_theme_color_override("font_color",
					Color(0.1, 0.1, 0.1) if marcado else COR_SECUNDARIA)


## "auto", "jogador", "lider", "frente", "geral" ou o id de um participante
## (toque na classificação).
func _camera(modo: String) -> void:
	var antes := _visual3d.foco
	_camera_modo = modo
	_acordar()
	# DADOS: a vista tática no lugar do 3D (que para de desenhar); a escolha
	# fica para as próximas corridas.
	var dados_on := modo == "dados"
	_vista.visible = dados_on
	_visual3d.visible = not dados_on
	_minimapa.visible = not dados_on
	_painel_hud.so_eventos = dados_on
	_painel_hud.queue_redraw()
	_ajustar_area()
	if Preferencias.vista_corrida != ("dados" if dados_on else ""):
		Preferencias.vista_corrida = "dados" if dados_on else ""
		Preferencias.salvar()
	if dados_on:
		return
	_visual3d.visao_geral = modo == "geral"
	_visual3d.enquadrar_com = ""
	if modo == "auto":
		_diretor.reiniciar()
	elif modo != "geral":
		_visual3d.foco = _alvo_camera()
	if _visual3d.foco == "jogador" and antes != "jogador" and modo != "geral":
		_visual3d.destacar_jogador()


func _alvo_camera() -> String:
	var ordem := _visual.ordem()
	match _camera_modo:
		"jogador", "geral", "dados":
			return "jogador"
		"auto":
			return _foco_auto
		"lider":
			return ordem[0] if not ordem.is_empty() else "jogador"
		"frente":
			var i := ordem.find("jogador")
			return ordem[i - 1] if i > 0 else "jogador"
	return _camera_modo


## Parada na última imagem depois da chegada (a tela principal mantém o
## meta-jogo escondido até o resultado).
func em_silencio() -> bool:
	return _segurar > 0.0 and _segurar < SILENCIO_S


## Toque na tela: o seletor volta a aparecer.
func _acordar() -> void:
	_ocioso = 0.0


func _input(e: InputEvent) -> void:
	if is_visible_in_tree() and ((e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed)
			or e is InputEventScreenDrag):
		_acordar()
	_pedal_toque(e)


## O dedo na área da corrida é o pedal da pilotagem: apertar na marca é a
## freada; manter apertado na saída da curva é a aceleração. (O toque também
## chega como clique do mouse: o segundo aviso de apertar é ignorado.)
func _pedal_toque(e: InputEvent) -> void:
	if _pil.is_empty() or not _pil.get("ativa", false):
		return
	var apertou: bool
	var pos: Vector2
	if e is InputEventScreenTouch and e.index == 0:
		apertou = e.pressed
		pos = e.position
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		apertou = e.pressed
		pos = e.position
	else:
		return
	if not apertou:
		_segurando = false
		return
	if _segurando or not is_visible_in_tree() or not _area.visible or not _area.get_global_rect().has_point(pos):
		return
	if _botao_ataque.visible and _botao_ataque.get_global_rect().has_point(pos):
		return
	_segurando = true
	_frear()


func atualizar() -> void:
	# A corrida mostrada acabou agora: mantém a imagem para o silêncio da
	# chegada (_process); senão, remonta a vista.
	var f: Dictionary = jogador.fila
	if not (_semente_mostrada != 0 and (f.is_empty() or f["semente"] != _semente_mostrada)):
		_semente_mostrada = 0
	_construir_painel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_semente_mostrada = 0
		_segurar = 0.0


## Painel de baixo: ações durante a corrida e o relatório da última.
func _construir_painel() -> void:
	for c in _painel.get_children():
		c.queue_free()
	_em_andamento = not jogador.fila.is_empty()
	_cameras.visible = _em_andamento
	if _em_andamento and Preferencias.permite_pular():
		# Só no teste: pular para o resultado (link discreto).
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		_painel.add_child(h)
		botao_texto("Ver resultado (teste)", func(): pular.emit(), h)
	# O resultado de cada corrida aparece na janela do resultado (principal);
	# aqui, sem corrida, só o próximo passo.
	if not _em_andamento and not _area.visible:
		proximo_passo("Nenhuma corrida agora.", "Escolher prova", EVENTOS, _painel)


## Luta da arena por cima (decisão 116): a pista 3D sai da memória enquanto ela
## passa (duas cenas 3D juntas fechavam o navegador do celular) e é remontada
## ao voltar, com a capa "Preparando a pista".
var pausada := false:
	set(v):
		pausada = v
		if v:
			_visual.limpar()
			_visual3d.limpar()
			_semente_mostrada = 0
			_carga_semente = 0


func _process(delta: float) -> void:
	if pausada or not is_visible_in_tree() or jogador.fila_ctrl == null:
		if _sons != null:
			_sons.motor(false)
			_sons.torcida(0.0)
		return
	_atualizar_seletor(delta)
	_tirar_carga()
	_dica_camera()
	var f: Dictionary = jogador.fila
	# Fim da corrida mostrada (fila vazia ou a próxima já começou): fica parado
	# na última imagem por SILENCIO_S antes de seguir.
	var acabou: bool = _semente_mostrada != 0 and (f.is_empty() or f["semente"] != _semente_mostrada)
	if acabou and _segurar < SILENCIO_S:
		_segurar += delta
		_sons.motor(false)
		_painel_hud.secundario = 0.0
		_visual3d.chegada = minf(_visual3d.chegada + delta / 3.0, 1.0)
		# O tempo segue além do fim: quem cruzou a linha continua freando.
		_visual.tempo += delta
		if _visual3d.visible:
			_visual3d.atualizar(delta)
		return
	if f.is_empty() != not _em_andamento:
		_construir_painel()
	if f.is_empty():
		_visual.limpar()
		_visual3d.limpar()
		if _area.visible:
			_area.visible = false
			_ajustar_area()
			_construir_painel()  # agora sim o próximo passo (na chegada, a imagem parada)
		_semente_mostrada = 0
		_segurar = 0.0
		_sons.motor(false)
		_sons.torcida(0.0)
		_info.text = "Nenhuma corrida em andamento."
		_relogio.text = ""
		return
	var agora := Aceleracao.agora(jogador)
	if float(f["inicio"]) > agora + 0.5:
		# Fila esperando combustível (decisão 120): a próxima larga sozinha.
		if _area.visible:
			_area.visible = false
			_ajustar_area()
		_info.text = "Sequência: esperando combustível. A próxima corrida larga em %s." % _mmss(float(f["inicio"]) - agora)
		return
	if _contagem >= 0.0:
		_contar(delta)
	if segurar_largada or _contagem > 0.0:
		f["inicio"] = agora  # parada no grid: o relógio da corrida não anda
	if f["semente"] != _semente_mostrada:
		# Capa de carregamento antes de montar a pista (a montagem e o primeiro
		# desenho levam alguns segundos e a tela ficava verde, parada): aparece
		# um quadro antes, cobre a montagem e sai depois do aquecimento.
		if _carga_semente != int(f["semente"]) or _carga_espera > 0:
			_mostrar_carga(f)
			f["inicio"] = agora  # o relógio da corrida espera a pista
			return
		if not jogador.fila_ctrl.pronta():
			# Sendo resolvida aos poucos (decisão 90; a principal avança a cada
			# quadro). Recém-inscrita, espera no grid: o relógio não anda e a
			# largada (3-2-1) fica para quando a corrida aparecer.
			if agora - float(f["inicio"]) < 0.5:
				f["inicio"] = agora
			_info.text = "Preparando a corrida..."
			return
		var c: Dictionary = jogador.fila_ctrl.corrida_atual(agora)
		if c.is_empty():
			return
		_mostrar_corrida(f, c, agora)
		_visual3d.aquecer()
		_carga_sair = CARGA_QUADROS
	if _pausa > 0.0:
		_pausa -= delta
		_atraso += delta
	else:
		_atraso = move_toward(_atraso, 0.0, delta * ALCANCE)
	# Velocidade do relógio da corrida, conhecida (não medida): parada na
	# contagem e na pausa da chegada; 1× ou o fator da aceleração.
	var taxa := 0.0 if (_pausa > 0.0 or _contagem > 0.0 or segurar_largada) \
			else (float(jogador.aceleracao.get("fator", 1.0)) if Aceleracao.ativa(jogador) else 1.0)
	_visual.tempo = clampf(_tempo_suave(clampf(agora - float(f["inicio"]) - _atraso, 0.0, _visual.duracao()), delta, taxa),
			0.0, _visual.duracao())
	_recarregar_ordem(f, agora)
	_procurar_momento(taxa)
	_acompanhar_ordem(delta)
	_pilotar(taxa)
	var ordem := _visual.ordem()
	_dirigir(ordem)
	if _visual3d.visible:  # na vista DADOS o 3D não anda (bateria)
		_visual3d.taxa = taxa
		_visual3d.atualizar(delta)
	var s_agora := _visual.distancia("jogador")
	var meta := _pista.comprimento * _voltas if _pista != null else INF
	if s_agora >= meta and not _chegou:
		_chegou = true
		_sons.chegada()
		if not Preferencias.reduzir_animacoes:
			_pausa = PAUSA_CHEGADA_S
		_painel_hud.bandeirada()
		var pos := ordem.find("jogador") + 1
		_painel_hud.evento("CHEGADA", "%dº" % pos, COR_DESTAQUE if pos <= 3 else Color.WHITE, 10, -1.0, true)
	if _chegou:
		_t_chegada += delta
		_visual3d.chegada = minf(_t_chegada / 3.0, 1.0)
	# Velocidade no relógio da corrida (em 2× o motor não sobe de giro).
	_sons.motor(not _chegou, (s_agora - _s_jogador) / maxf(delta * maxf(taxa, 1.0), 1e-3) if delta > 0.0 else 0.0)
	_s_jogador = s_agora
	_atualizar_hud(ordem)
	_eventos(ordem)


## Tempo da corrida mostrada sem engasgo: o relógio do sistema tem resolução
## grossa (1 ms no navegador) e não anda junto com o quadro, então o tempo lido
## dele direto oscila alguns % a cada quadro (o carro acelera e reduz na reta).
## Aqui o tempo avança pelo delta do quadro na velocidade conhecida do relógio
## (`taxa`: 0 parado, 1×, ou o fator da aceleração) e só corrige a diferença
## devagar; salto grande (corrida nova, volta do segundo plano) vai direto.
## Antes a velocidade era medida e "aprendia" zero na contagem 3-2-1: a largada
## saía em câmera lenta, o atraso crescia e o tempo pulava (a travada).
func _tempo_suave(alvo: float, delta: float, taxa := 1.0) -> float:
	if _t_suave < 0.0 or delta <= 0.0 or absf(alvo - _t_suave) > SALTO_TEMPO_S:
		_t_suave = alvo
		return alvo
	_t_suave += delta * taxa
	_t_suave += (alvo - _t_suave) * (1.0 - exp(-delta * 4.0))
	return _t_suave


## Capa sobre a área da corrida enquanto a pista é montada: o nome da prova e
## da pista. Fica um quadro na tela antes da montagem (que trava a tela).
func _mostrar_carga(f: Dictionary) -> void:
	if _carga_semente != int(f["semente"]):
		_carga_semente = int(f["semente"])
		_area.move_child(_carga, _area.get_child_count() - 1)  # por cima da pista e do HUD
		var ev: Dictionary = dados.evento(f["evento_id"])
		_carga_texto.text = "PREPARANDO A PISTA\n\n%s\n%s" % [String(ev["nome"]), Aba.nome_pista(String(ev["pista"]))]
		_carga.modulate.a = 1.0
		_carga.visible = true
		_area.visible = true
		_carga_espera = 2
		_carga_sair = -1
	else:
		_carga_espera -= 1


func _tirar_carga() -> void:
	if _carga_sair < 0:
		return
	_carga_sair -= 1
	if _carga_sair > 0:
		return
	_carga_sair = -1
	var tw := _carga.create_tween()
	tw.tween_property(_carga, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): _carga.visible = false)


## Nova corrida na tela: minimapa, 3D, nomes, cabeçalho e diretor do zero.
func _mostrar_corrida(f: Dictionary, c: Dictionary, agora: float) -> void:
	var ev: Dictionary = dados.evento(f["evento_id"])
	_pista = dados.pista(ev["pista"])
	_voltas = int(ev["voltas"])
	var meu: Carro = jogador.garagem.carro(f["uid"])
	_visual.mostrar(_pista, c["resultado"], {"jogador": CarroBloco.cor_do_carro(meu)})
	var categorias := {"jogador": meu.base}
	var pinturas := {"jogador": CarroBloco.cor_do_carro(meu)}
	var faixas_rivais := {}
	for i in ev["adversarios"].size():
		var adv_id: String = ev["adversarios"][i]["carro"]
		var chave := "adv%d_%s" % [i, adv_id]
		categorias[chave] = dados.carro(adv_id)
		# Rival nas cores da equipe dele (decisão 60), com um desenho de faixa
		# sorteado por prova e vaga; sem equipe, uma das cores do modelo.
		var eq_r: Dictionary = jogador.carreira.equipe_de(ev["id"], chave, int(f.get("semente", -1)))
		if eq_r.has("cores"):
			pinturas[chave] = Color(String(eq_r["cores"]["carro"]))
			faixas_rivais[chave] = PinturaCarro.da_equipe(eq_r, "%s|%d|%d" % [ev["id"], int(f.get("semente", -1)), i],
					jogador.carreira.vaga_de(ev["id"], chave, int(f.get("semente", -1))))
		else:
			pinturas[chave] = Cores.sortear(adv_id, "%s|%d" % [ev["id"], i])
	var comp_carro: Carro = jogador.fila_ctrl.companheiro_inscrito(f)
	if comp_carro != null:
		categorias[EquipeJogador.ID] = comp_carro.base
		pinturas[EquipeJogador.ID] = CarroBloco.cor_do_carro(comp_carro)
	_visual.tempo = clampf(agora - float(f["inicio"]), 0.0, _visual.duracao())
	_t_suave = -1.0
	_visual3d.chegada = 0.0
	_visual3d.faixas_pintura = faixas_rivais
	_visual3d.faixas_pintura["jogador"] = meu.faixas
	if comp_carro != null:
		_visual3d.faixas_pintura[EquipeJogador.ID] = comp_carro.faixas
	_visual3d.mostrar(_pista, _visual, categorias, pinturas)
	_area.visible = true
	_ajustar_area()
	_semente_mostrada = f["semente"]
	_resultado = c["resultado"]
	_versao_mostrada = jogador.fila_ctrl.versao
	_momentos = 0
	_t_momento = -INF
	_varrido = 0.0
	_em_curso = {}
	_descartar_proximo()
	_cartao.fechar()
	_feitas = {}
	_frenagem = {}
	_na_curva = {}
	_saida = {}
	_ultimo_ataque = -INF
	_s_antes_pil = 0.0
	_versao_parcial = jogador.fila_ctrl.versao_parcial
	_emenda_desde = -1.0
	_pedal.esconder()
	_botao_ataque.visible = false
	_segurar = 0.0
	_painel_hud.limpar_evento()
	_painel_hud.secundario = 1.0
	_posicao_antes = 0
	_volta_antes = 0
	_melhor_volta = -1.0
	_avisado = {}
	var eu := EquipeJogador.nome_jogador(dados, jogador)
	_nomes = {"jogador": "%s · %s" % [eu, meu.nome_mostrado()]}
	_nomes_curtos = {"jogador": eu}
	var minha := EquipeJogador.dados_equipe(dados, jogador)
	_equipes = {"jogador": String(minha.get("nome", "")) if not minha.is_empty() else ""}
	# Motor e câmbio do carro como foi inscrito (para marcha e giro no HUD).
	var inscrito: Carro = meu.com_configuracao(f["config"], dados.peca, dados.pneu) if f.get("config") is Dictionary else meu
	_atributos_hud = inscrito.atributos_efetivos(ev.get("condicao", "seco"))
	_tatica = Tatica.curvas(_pista, _atributos_hud, dados.simulacao(), dados.curvas(_pista.id))
	_kmh_max = Simulacao.velocidade_maxima_kmh(_atributos_hud, dados.simulacao())
	for i in ev["adversarios"].size():
		var adv: Dictionary = ev["adversarios"][i]
		var pid := "adv%d_%s" % [i, adv["carro"]]
		var piloto: String = jogador.carreira.nome_piloto(ev["id"], pid, int(f.get("semente", -1)))
		var equipe: Dictionary = jogador.carreira.equipe_de(ev["id"], pid, int(f.get("semente", -1)))
		_nomes[pid] = "%s · %s" % [piloto, equipe["nome"]] if not equipe.is_empty() \
				else "%s (%s)" % [piloto, Aba.nome_curto(dados.carro(adv["carro"])["nome"])]
		_nomes_curtos[pid] = piloto
		_equipes[pid] = String(equipe.get("nome", ""))
	# Segundo piloto da equipe (fase 9), com o carro e a cor dele.
	var comp: Carro = jogador.fila_ctrl.companheiro_inscrito(f)
	if comp != null:
		var nome2 := EquipeJogador.nome_segundo(dados, jogador)
		_nomes[EquipeJogador.ID] = "%s · %s" % [nome2, comp.base["nome"]]
		_nomes_curtos[EquipeJogador.ID] = nome2
		_equipes[EquipeJogador.ID] = _equipes["jogador"]
	_visual3d.nomes = _nomes_curtos
	# Cabeçalho enxuto: campeonato · etapa; embaixo, pista · volta (ao vivo).
	_info.text = nome_evento(ev).replace(" — Etapa ", " · Etapa ")
	_nome_prova.text = "%s · %s" % [_info.text, nome_pista(_pista.id)]
	_diretor.reiniciar()
	_foco_auto = "jogador"
	_camera(_camera_modo)
	_chegou = false
	_t_chegada = 0.0
	_s_jogador = _visual.distancia("jogador")
	_atraso = 0.0
	_pausa = 0.0
	if f["semente"] == _semente_largada and _visual.tempo < 0.5:
		return  # a mesma corrida remontada ainda no grid: a contagem segue
	_semente_largada = f["semente"]
	if _visual.tempo < 0.5 and not segurar_largada and dialogo_aberto.call():
		segurar()  # a corrida nova não larga debaixo de uma conversa
	if _visual.tempo < 0.5 and not segurar_largada:
		# Corrida começando agora com a tela aberta: 3-2-1 no grid.
		_contagem = CONTAGEM_S
		_painel_hud.contagem = _contagem
		_sons.largada(false)
	elif _visual.tempo < 2.0:
		_sons.largada(true)
		_painel_hud.evento("LARGADA", "", COR_DESTAQUE, 3)
	else:
		_painel_hud.evento("CORRIDA EM ANDAMENTO", "", Color.WHITE, 3)


## A corrida não reconstrói o conteúdo: o espaço do cabeçalho entra uma vez.
func reservar_topo(altura: float) -> void:
	super(altura)
	var vazio := Control.new()
	# Também abaixo das abas penduradas do cabeçalho (ACELERAR), como em
	# Aba._espaco_topo: o "Nenhuma corrida em andamento." não fica colado nelas.
	vazio.custom_minimum_size = Vector2(0, altura - 14.0 + Cabecalho.ALTURA_MARCADOR + 4.0)
	vazio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteudo.add_child(vazio)
	conteudo.move_child(vazio, 0)
	_vazio_topo = vazio
	_ajustar_area()


## Com corrida na tela: a área começa no topo da aba (sem o espaço do
## cabeçalho nem as linhas de texto, que vão para o HUD) e desce até o seletor
## de câmeras. Sem corrida: o espaço e o texto de sempre.
func _ajustar_area() -> void:
	var correndo := _area.visible
	if _vazio_topo != null:
		_vazio_topo.visible = not correndo
	_info.visible = not correndo
	_relogio.visible = not correndo
	_nome_prova.visible = correndo
	# Abaixo do cabeçalho (o HUD 3D desvia do marcador da aceleração à direita;
	# a vista DADOS, de cima a baixo na largura toda, começa abaixo dele).
	var topo := topo_livre + (Cabecalho.ALTURA_MARCADOR + 6.0 if _camera_modo == "dados" else 0.0)
	_painel_hud.offset_top = topo
	_vista.offset_top = topo
	if correndo:
		var livre := size.y - _cameras.get_combined_minimum_size().y - _nome_prova.get_combined_minimum_size().y \
				- 2.0 * 14.0 - 10.0
		_area.custom_minimum_size.y = maxf(ALTURA_MIN_AREA, livre)


## Contagem da largada: um bipe por número; no zero, a largada (se nenhuma
## cena estiver segurando o grid).
func _contar(delta: float) -> void:
	var antes := ceili(_contagem)
	_contagem = maxf(_contagem - delta, 0.0)
	_painel_hud.contagem = _contagem
	if ceili(_contagem) < antes and _contagem > 0.0:
		_sons.largada(false)
	if _contagem <= 0.0:
		_contagem = -1.0
		_painel_hud.contagem = -1.0
		if not segurar_largada:
			if not jogador.fila.is_empty():
				jogador.fila["inicio"] = Aceleracao.agora(jogador)
			_diretor.reiniciar()
			_sons.largada(true)
			_painel_hud.evento("LARGADA", "", COR_DESTAQUE, 3)


## A corrida ainda não largou (inscrita agora, no 3-2-1 ou parada no grid).
func antes_da_largada() -> bool:
	if jogador.fila.is_empty():
		return false
	return segurar_largada or _contagem > 0.0 \
			or Aceleracao.agora(jogador) - float(jogador.fila.get("inicio", 0.0)) < 0.5


## Para no grid (uma conversa abriu): a contagem some até a conversa acabar.
func segurar() -> void:
	segurar_largada = true
	_contagem = -1.0
	if _painel_hud != null:
		_painel_hud.contagem = -1.0


## Fim das conversas: o 3-2-1 no grid e a largada.
func liberar_largada() -> void:
	if not segurar_largada:
		return
	segurar_largada = false
	if jogador.fila.is_empty():
		return
	jogador.fila["inicio"] = Aceleracao.agora(jogador)
	_diretor.reiniciar()
	_contagem = CONTAGEM_S
	_painel_hud.contagem = _contagem
	_sons.largada(false)


## Câmera AUTO: o diretor escolhe o plano; nas outras, o alvo da escolha.
func _dirigir(ordem: Array) -> void:
	# Largada (contagem, cena segurando o grid ou a abertura do diretor): de
	# cima, enquadrando o grid inteiro.
	_visual3d.enquadrar_grid = _contagem > 0.0 or segurar_largada
	if _camera_modo == "auto":
		var plano := _diretor.atualizar(_visual, _pista.comprimento * _voltas, _pista.comprimento, _voltas)
		_visual3d.enquadrar_grid = _visual3d.enquadrar_grid or plano["motivo"] == "abertura"
		var antes := _foco_auto
		_foco_auto = plano["foco"]
		_visual3d.visao_geral = plano["geral"]
		_visual3d.foco = _foco_auto
		_visual3d.enquadrar_com = plano["com"]
		if _foco_auto == "jogador" and (antes != "jogador" or _visual3d.visao_geral) and not plano["geral"]:
			_visual3d.destacar_jogador()
	elif _camera_modo in ["lider", "frente"]:
		_visual3d.foco = _alvo_camera()
	# O carro da frente é o alvo (anel e traço só na disputa de perto).
	var i := ordem.find("jogador")
	_visual3d.alvo = ordem[i - 1] if i > 0 and not _chegou else ""


## Diferença em segundos de `id` para o líder (quanto tempo atrás dele passou
## no mesmo ponto); -1 para o líder ou sem dado.
func _gap_lider(ordem: Array, id: String) -> float:
	if ordem.is_empty() or ordem[0] == id:
		return -1.0
	var t := _visual.tempo_em(ordem[0], _visual.distancia(id))
	return maxf(_visual.tempo - t, 0.0) if t >= 0.0 else -1.0


## Diferença em segundos entre `a` (à frente) e `b` (atrás): quanto tempo
## depois de a o b passa no ponto onde b está.
func _gap(a: String, b: String) -> float:
	var t := _visual.tempo_em(a, _visual.distancia(b))
	return maxf(_visual.tempo - t, 0.0) if t >= 0.0 else -1.0


func _atualizar_hud(ordem: Array) -> void:
	var i := ordem.find("jogador")
	if i < 0 or _pista == null:
		return
	var s := _visual.distancia("jogador")
	var volta := clampi(floori(maxf(s, 0.0) / _pista.comprimento) + 1, 1, _voltas)
	_relogio.text = "%s · Volta %d/%d" % [nome_pista(_pista.id), volta, _voltas]
	# Tempos de volta: quando o carro cruzou o começo de cada volta.
	var inicio_volta := _visual.tempo_em("jogador", (volta - 1) * _pista.comprimento) if volta > 1 else 0.0
	var melhor := -1.0
	var k_melhor := 0
	for k in range(1, volta):
		var a := _visual.tempo_em("jogador", (k - 1) * _pista.comprimento) if k > 1 else 0.0
		var b := _visual.tempo_em("jogador", k * _pista.comprimento)
		if a >= 0.0 and b > a and (melhor < 0.0 or b - a < melhor):
			melhor = b - a
			k_melhor = k
	# Diferença para a melhor volta no mesmo ponto da pista (s; negativo =
	# adiantado). Sem volta completa ainda, não há referência.
	var delta := 0.0
	var tem_delta := false
	if k_melhor > 0:
		var no_trecho := s - (volta - 1) * _pista.comprimento
		var ini_m := _visual.tempo_em("jogador", (k_melhor - 1) * _pista.comprimento) if k_melhor > 1 else 0.0
		var t_m := _visual.tempo_em("jogador", (k_melhor - 1) * _pista.comprimento + no_trecho)
		if ini_m >= 0.0 and t_m >= 0.0:
			delta = (_visual.tempo - maxf(inicio_volta, 0.0)) - (t_m - ini_m)
			tem_delta = true
	# Velocidade pela distância andada no último meio segundo (o resultado da
	# simulação), sem os saltos de quadro.
	var v := maxf(_visual.distancia_em("jogador", _visual.tempo) - _visual.distancia_em("jogador", maxf(_visual.tempo - 0.5, 0.0)), 0.0) \
			/ minf(0.5, maxf(_visual.tempo, 0.05))
	var mg := Simulacao.marcha_e_giro(_atributos_hud, v) if not _atributos_hud.is_empty() else [0, 0.0]
	_som_da_corrida(mg, i, ordem, s, volta)
	# Quem está atacando você: o carro logo atrás, a menos de APROXIMA_S.
	var atacante := ""
	if i + 1 < ordem.size() and not _chegou:
		var g := _gap("jogador", ordem[i + 1])
		if g >= 0.0 and g < APROXIMA_S:
			atacante = ordem[i + 1]
	var lista := []
	for id in ordem:
		lista.append({"id": id, "nome": _nomes_curtos.get(id, id), "equipe": _equipes.get(id, ""),
			"cor": _visual.cor_de(id), "voce": id == "jogador",
			"camera": id == _visual3d.foco and not _visual3d.visao_geral, "gap": _gap_lider(ordem, id),
			"ataque": id == atacante})
	_painel_hud.definir({"posicao": i + 1, "total": ordem.size(), "volta": volta, "voltas": _voltas,
		"tempo_volta": _visual.tempo - maxf(inicio_volta, 0.0), "melhor": melhor, "kmh": v * 3.6,
		"delta": delta if tem_delta and not _chegou else INF,
		"marcha": mg[0], "giro": mg[1], "corte": float(_atributos_hud.get("corte", 0.0)), "kmh_max": _kmh_max,
		"giro_max": ceilf((float(_atributos_hud.get("corte", 0.0)) + 600.0) / 1000.0) * 1000.0 if _atributos_hud.has("corte") else 0.0,
		"lista": lista, "ultima": volta == _voltas and not _chegou})
	if _vista.visible:
		_atualizar_vista(ordem, i, s, volta, melhor, delta if tem_delta and not _chegou else INF, v, mg)
	# A tela respira: disputa de perto (à frente ou atrás) ou chegada apagam o
	# que é secundário.
	var perto := atacante != ""
	if i > 0 and not _chegou:
		var g := _gap(ordem[i - 1], "jogador")
		perto = perto or (g >= 0.0 and g < RESPIRA_S)
	_painel_hud.secundario = 0.0 if _chegou else (0.35 if perto else 1.0)
	_minimapa.modulate.a = move_toward(_minimapa.modulate.a, 0.0 if _chegou else (0.55 if perto else 1.0),
			get_process_delta_time() / 0.6)


## Som que acompanha o seu carro: motor pelo giro, pneu e
## zebra pelo 3D, o pelotão quando há rival colado, torcida na reta final da
## última volta com disputa de perto (e na chegada).
const PELOTAO_GAP_S := 2.0  # acima dessa diferença o rival não se ouve

func _som_da_corrida(mg: Array, i: int, ordem: Array, s: float, volta: int) -> void:
	if _chegou:
		_sons.torcida(1.0 - smoothstep(1.5, 4.0, _t_chegada))
		return
	var corte := float(_atributos_hud.get("corte", 0.0))
	if corte > 0.0:
		var escala := ceilf((corte + 600.0) / 1000.0) * 1000.0
		_sons.motor_giro(float(mg[1]) / escala)
	_sons.pneu(_visual3d.cantando("jogador"), _visual3d.na_zebra("jogador"))
	# Pelotão: os rivais colados (à frente ou atrás) se ouvem.
	var gap_min := INF
	if i > 0:
		var ga := _gap(ordem[i - 1], "jogador")
		if ga >= 0.0:
			gap_min = ga
	if i + 1 < ordem.size():
		var gb := _gap("jogador", ordem[i + 1])
		if gb >= 0.0:
			gap_min = minf(gap_min, gb)
	_sons.pelotao(1.0 - smoothstep(0.3, PELOTAO_GAP_S, gap_min) if gap_min < INF else 0.0)
	var torcida := 0.0
	if volta == _voltas:
		var resto := 1.0 - fposmod(s, _pista.comprimento) / _pista.comprimento
		var perto := false
		if i > 0:
			var g := _gap(ordem[i - 1], "jogador")
			perto = g >= 0.0 and g < RESPIRA_S
		if i + 1 < ordem.size():
			var g := _gap("jogador", ordem[i + 1])
			perto = perto or (g >= 0.0 and g < RESPIRA_S)
		torcida = (1.0 - smoothstep(0.1, 0.3, resto)) * (1.0 if perto else 0.45)
	_sons.torcida(torcida)


## Vista DADOS: os mesmos números do HUD, mais a próxima curva (Tatica), quem
## está à frente e atrás e o progresso da volta de todos.
func _atualizar_vista(ordem: Array, i: int, s: float, volta: int, melhor: float, delta: float, v: float, mg: Array) -> void:
	var s_volta := fposmod(maxf(s, 0.0), _pista.comprimento)
	var prox := {}
	var p := Tatica.proxima(_tatica, s_volta, _pista.comprimento)
	if not p.is_empty() and not _chegou:
		prox = {"nome": p["curva"]["nome"], "estado": p["estado"], "distancia": p["distancia"],
			"v_kmh": p["curva"]["v_kmh"], "sentido": p["curva"]["sentido"]}
	var vizinhos := []
	if i > 0:
		var g := _gap(ordem[i - 1], "jogador")
		vizinhos.append({"pos": i, "nome": _nomes_curtos.get(ordem[i - 1], ordem[i - 1]),
			"sub": _sub(ordem[i - 1], "à frente · %.1f s" % g if g >= 0.0 else "à frente")})
	vizinhos.append({"pos": i + 1, "nome": _nomes_curtos["jogador"], "voce": true,
		"sub": _sub("jogador", "líder" if i == 0 else "%dº de %d" % [i + 1, ordem.size()])})
	if i + 1 < ordem.size():
		var g := _gap("jogador", ordem[i + 1])
		vizinhos.append({"pos": i + 2, "nome": _nomes_curtos.get(ordem[i + 1], ordem[i + 1]),
			"sub": _sub(ordem[i + 1], "atrás · %.1f s" % g if g >= 0.0 else "atrás")})
	var progresso := []
	for id in ordem:
		progresso.append({"frac": fposmod(maxf(_visual.distancia(id), 0.0), _pista.comprimento) / _pista.comprimento,
			"cor": _visual.cor_de(id), "voce": id == "jogador"})
	_vista.definir({"pista_nome": nome_pista(_pista.id), "kmh": v * 3.6, "marcha": mg[0], "giro": mg[1],
		"corte": float(_atributos_hud.get("corte", 0.0)),
		"giro_max": ceilf((float(_atributos_hud.get("corte", 0.0)) + 600.0) / 1000.0) * 1000.0 if _atributos_hud.has("corte") else 0.0,
		"tempo_volta": _visual.tempo - maxf(_visual.tempo_em("jogador", (volta - 1) * _pista.comprimento) if volta > 1 else 0.0, 0.0),
		"melhor": melhor, "delta": delta, "volta": volta, "voltas": _voltas, "proxima": prox,
		"vizinhos": vizinhos, "progresso": progresso})


## Linha de baixo na vista DADOS: a equipe (quando há) e a situação.
func _sub(id: String, situacao: String) -> String:
	var eq: String = _equipes.get(id, "")
	return situacao if eq == "" else "%s · %s" % [eq, situacao]


## Acontecimentos da corrida, poucos e com peso: ultrapassagem, perdeu a
## posição, líder, rival se aproximando, última volta, melhor volta, chegada.
func _eventos(ordem: Array) -> void:
	var pos := ordem.find("jogador") + 1
	if pos <= 0 or _chegou:
		_posicao_antes = pos
		return
	var s := _visual.distancia("jogador")
	var volta := clampi(floori(maxf(s, 0.0) / _pista.comprimento) + 1, 1, _voltas)
	if _posicao_antes > 0 and pos != _posicao_antes and _visual.tempo > 1.0:
		var ganhou := pos < _posicao_antes
		var outro: String = (ordem[pos] if pos < ordem.size() else "") if ganhou else (ordem[pos - 2] if pos >= 2 else "")
		var nome: String = String(_nomes_curtos.get(outro, "")).to_upper()
		if ganhou and pos == 1:
			_painel_hud.evento("LÍDER", "passou %s" % nome, COR_DESTAQUE, 6)
		elif ganhou:
			_painel_hud.evento("ULTRAPASSAGEM", "passou %s · %dº" % [nome, pos], COR_DESTAQUE, 5)
		else:
			_painel_hud.evento("PERDEU A POSIÇÃO", "%s passou · %dº" % [nome, pos], COR_RUIM.lightened(0.2), 5)
		_sons.ultrapassagem(ganhou)
	_posicao_antes = pos
	# Volta nova: última volta; ou melhor volta; ou, liderando, a vantagem.
	if _volta_antes > 0 and volta > _volta_antes:
		var t0 := _visual.tempo_em("jogador", (volta - 2) * _pista.comprimento) if volta > 2 else 0.0
		var t1 := _visual.tempo_em("jogador", (volta - 1) * _pista.comprimento)
		var tv := t1 - t0 if t0 >= 0.0 and t1 > t0 else -1.0
		var melhorou := tv > 0.0 and _melhor_volta > 0.0 and tv < _melhor_volta
		if tv > 0.0:
			_melhor_volta = tv if _melhor_volta < 0.0 else minf(_melhor_volta, tv)
		var dif := _texto_dif(ordem, pos)
		if volta == _voltas:
			_painel_hud.evento("ÚLTIMA VOLTA", "%dº%s" % [pos, " · " + dif if dif != "" else ""], COR_DESTAQUE, 4,
					HudCorrida.EVENTO_FICA_S + 0.8, false, true)
			_sons.ultima_volta()
		elif melhorou:
			_painel_hud.evento("MELHOR VOLTA", HudCorrida._tempo(tv), Color.WHITE, 3)
		elif pos == 1 and dif != "":
			_painel_hud.evento("LIDERANDO", dif, Color.WHITE, 2)
	_volta_antes = volta
	# Rival se aproximando por trás (uma vez por aproximação).
	if pos < ordem.size():
		var atras: String = ordem[pos]
		var g := _gap("jogador", atras)
		if g >= 0.0 and g < APROXIMA_S and _visual.tempo - float(_avisado.get(atras, -INF)) > EVENTO_RIVAL_S:
			_avisado[atras] = _visual.tempo
			_painel_hud.evento("%s SE APROXIMA" % String(_nomes_curtos.get(atras, "")).to_upper(), "−%.1f s" % g,
					Color.WHITE, 2)


## "+0.8 s" (vantagem, liderando) ou "−0.4 s" (para o carro da frente).
func _texto_dif(ordem: Array, pos: int) -> String:
	if pos == 1 and ordem.size() > 1:
		var g := _gap("jogador", ordem[1])
		return "+%.1f s" % g if g >= 0.0 else ""
	if pos > 1:
		var g := _gap(ordem[pos - 2], "jogador")
		return "−%.1f s" % g if g >= 0.0 else ""
	return ""


## Uma escolha refez a corrida (Fila.ordenar): as amostras novas entram no
## lugar das antigas, iguais até a ordem valer, e o tempo segue de onde estava.
func _recarregar_ordem(f: Dictionary, agora: float) -> void:
	if jogador.fila_ctrl.versao == _versao_mostrada or f["semente"] != _semente_mostrada:
		return
	var c: Dictionary = jogador.fila_ctrl.corrida_atual(agora)
	if c.is_empty() or c["resultado"] == _resultado:
		_versao_mostrada = jogador.fila_ctrl.versao
		return
	var t := _visual.tempo
	_visual.trocar_resultado(c["resultado"])
	_visual.tempo = t
	_resultado = c["resultado"]
	_versao_mostrada = jogador.fila_ctrl.versao


## Momentos de decisão (decisão 117). Procura ANTECEDENCIA_S à frente no
## resultado mostrado; achado, a fila refaz a corrida com cada escolha e o
## cartão só abre, no instante do momento, se alguma delas muda o duelo (sem
## isso o toque não mudava nada na tela). No máximo max_por_corrida, com
## intervalo_s entre eles; nunca com conversa aberta, na chegada ou parado.
func _procurar_momento(taxa: float) -> void:
	var p: Dictionary = dados.simulacao().get("momentos", {})
	# Com a pilotagem, o ATACAR na tela faz o papel dos cartões.
	if p.is_empty() or _resultado.is_empty() or _chegou or _pil.get("ativa", false):
		return
	var agora := _visual.tempo
	if _proximo.is_empty():
		if _momentos >= int(p["max_por_corrida"]) or _cartao.aberto() or not _em_curso.is_empty():
			return
		var de := maxf(maxf(_varrido, agora + 1.0), _t_momento + float(p["intervalo_s"]))
		var ate := minf(agora + ANTECEDENCIA_S, float(_resultado["duracao"]))
		var t := de
		while t < ate and t < de + VARRE_S:
			var m := MomentosCorrida.detectar(_resultado, t, p)
			if not m.is_empty():
				var ordens := {}
				for e in MomentosCorrida.escolhas(m["tipo"], p):
					ordens[e[0]] = MomentosCorrida.ordem(e[0], t, p)
				jogador.fila_ctrl.prever(ordens)
				_proximo = {"t": t, "m": m, "ordens": ordens}
				_varrido = t + PASSO_S
				return
			t += 0.5
		_varrido = maxf(_varrido, t)
		return
	if not _proximo.has("avaliacao"):
		var refeitas := {}
		for id in _proximo["ordens"]:
			var r: Dictionary = jogador.fila_ctrl.previsao(id)
			if not r.is_empty():
				refeitas[id] = r
		if refeitas.size() < _proximo["ordens"].size():
			if agora > float(_proximo["t"]):  # não deu tempo de prever
				_descartar_proximo()
			return
		var av := MomentosCorrida.avaliar(_resultado, _proximo["m"], _proximo["ordens"], refeitas)
		if not MomentosCorrida.importa(av):
			_descartar_proximo()
			return
		_proximo["avaliacao"] = av
		_proximo["dica"] = MomentosCorrida.dica(av, p, int(jogador.fila.get("semente", 0)), float(_proximo["t"]))
	if _cartao.aberto() or agora < float(_proximo["t"]):
		return
	if agora > float(_proximo["t"]) + 1.0 or taxa <= 0.0 or dialogo_aberto.call():
		_descartar_proximo()  # passou o instante (pausa, conversa)
		return
	_momentos += 1
	_t_momento = float(_proximo["t"])
	var m: Dictionary = _proximo["m"]
	_cartao.abrir(m, MomentosCorrida.escolhas(m["tipo"], p), String(_nomes_curtos.get(m["rival"], "O rival")),
			float(p["janela_s"]), _proximo["dica"], _nome_radio(), int(float(_proximo["t"]) * 2.0))
	_sons.largada(false)  # bipe: o cartão pede atenção


## Quem fala no rádio dos momentos (data/personagens.json, "mara"): o primeiro nome.
func _nome_radio() -> String:
	var pers: Dictionary = dados.item("personagens", "mara") if dados.existe("personagens", "mara") else {}
	return String(pers.get("nome", "Mara")).get_slice(" ", 0)


func _descartar_proximo() -> void:
	_proximo = {}
	jogador.fila_ctrl.cancelar_previsoes()


## A escolha vale na hora (a corrida já foi refeita com ela): toque com peso
## (clarão, câmera no duelo, rastro na cor de destaque) e, quando ela muda o
## duelo, a comemoração no instante da ultrapassagem.
func _ordenar(id: String) -> void:
	if _proximo.is_empty() or not _proximo.has("avaliacao") or not _proximo["ordens"].has(id):
		return
	var av: Dictionary = _proximo["avaliacao"]
	var outra := ""
	for o in av:
		if o != id and av[o]["vence"]:
			outra = o
	_em_curso = {"id": id, "m": _proximo["m"], "ordem": _proximo["ordens"][id], "vence": av[id]["vence"],
			"t": float(av[id]["t"]), "como": String(av[id]["como"]), "outra": outra, "mostrado": false,
			"ouviu": id == String(_proximo.get("dica", ""))}
	_proximo = {}
	jogador.fila_ctrl.ordenar(_em_curso["ordem"])
	var nome := String(_nomes_curtos.get(_em_curso["m"]["rival"], "o rival"))
	var acao: Array = CartaoMomento.ACAO.get(id, [id.to_upper(), ""])
	_painel_hud.limpar_evento()
	_painel_hud.evento((acao[1] % nome if "%s" in acao[1] else acao[1]).to_upper(), acao[0], COR_DESTAQUE, 7, 1.6, true)
	_clarear(COR_DESTAQUE, 0.28)
	_visual3d.acionar()
	Sons.tocar_ui(self, "passagem", -4.0, 1.15)


## A ordem em curso: rastro e câmera no duelo enquanto ela vale; a comemoração
## quando o jogador passa (ataque) ou o rival desiste (defesa); no fim, se não
## deu, a jogada que daria.
func _acompanhar_ordem(delta: float) -> void:
	_t_clarao = maxf(_t_clarao - delta, 0.0)
	_clarao.color.a = float(_clarao.get_meta("forca", 0.0)) * pow(_t_clarao / CLARAO_S, 2.0)
	if _em_curso.is_empty():
		_visual3d.impulso = move_toward(_visual3d.impulso, 0.0, delta * 2.0)
		return
	var o: Dictionary = _em_curso["ordem"]
	var t := _visual.tempo
	# Rastro e lanternas acesos enquanto a ordem vale (esperar a reta: depois da espera).
	var valendo := t >= float(o["de"]) - 0.5 and t <= float(o["ate"])
	_visual3d.impulso = move_toward(_visual3d.impulso, 1.0 if valendo else 0.0, delta * 2.0)
	var rival: String = _em_curso["m"]["rival"]
	if _camera_modo == "auto" and not _visual3d.visao_geral:
		_visual3d.foco = "jogador"
		_visual3d.enquadrar_com = rival
	var nome := String(_nomes_curtos.get(rival, "o rival")).to_upper()
	if _em_curso["vence"] and not _em_curso["mostrado"] and t >= float(_em_curso["t"]):
		_em_curso["mostrado"] = true
		_painel_hud.limpar_evento()
		var quem := "OUVIU O RÁDIO" if _em_curso["ouviu"] else "JOGADA SUA"
		if _em_curso["como"] == "passou":
			_painel_hud.evento("%s · PASSOU %s" % [quem, nome], "ULTRAPASSOU!", COR_DESTAQUE, 8, 2.6, true, true)
		else:
			_painel_hud.evento("%s · %s FICOU PARA TRÁS" % [quem, nome], "SEGUROU!", COR_DESTAQUE, 8, 2.6, true, true)
		_clarear(Color(1.0, 0.86, 0.45), 0.42)
		_visual3d.comemorar(Color(1.0, 0.8, 0.3))
		_sons.ultrapassagem(true)
		Sons.tocar_ui(self, "comemoracao", -12.0)
	if t > float(o["ate"]) + MomentosCorrida.CONFERE_S and (not _em_curso["vence"] or _em_curso["mostrado"]):
		if not _em_curso["vence"]:
			var outra: String = _em_curso["outra"]
			var linha := "%s RESISTIU" % nome
			if outra != "" and not _em_curso["ouviu"]:
				linha = "%s AVISOU: %s" % [_nome_radio().to_upper(), CartaoMomento.ROTULOS[outra][0]]
			elif outra != "":
				linha = "NEM %s ACERTOU DESTA VEZ" % ("A " + _nome_radio().to_upper())
			_painel_hud.evento(linha, "QUASE!", Color.WHITE, 6, 2.4, true)
		_em_curso = {}


## Pilotagem por toques, a cada quadro: leva a corrida ao vivo até o instante
## mostrado, emenda a corrida refeita pelo último toque e acompanha a curva à
## frente (a régua FREIE), a saída (SEGURE) e o ATACAR.
func _pilotar(taxa: float) -> void:
	if not _pil.get("ativa", false) or _pista == null or _resultado.is_empty():
		return
	var t := _visual.tempo
	jogador.fila_ctrl.acompanhar(t)
	_emendar()
	if _chegou or taxa <= 0.0 or _contagem > 0.0:
		_pedal.esconder()
		_botao_ataque.visible = false
		return
	var comp := _pista.comprimento
	var s := _visual.distancia("jogador")
	var s_volta := fposmod(s, comp)
	# Saída da curva: começa ao cruzar o fim dela com o dedo na tela.
	if not _na_curva.is_empty() and _s_antes_pil < float(_na_curva["fim"]) and s >= float(_na_curva["fim"]):
		if _segurando and _na_curva["com_frenagem"] and _saida.is_empty():
			var ate := t + Pilotagem.dura_saida(_pil)
			if not _dar(Pilotagem.ordem_saida(Pilotagem.LIMPA, t, ate, _pil)).is_empty():
				_saida = {"de": t, "ate": ate, "soltou": false}
		_na_curva = {}
	_s_antes_pil = s
	var mostrou := false
	if not _saida.is_empty():
		if not _segurando and not _saida["soltou"]:
			_saida["soltou"] = true
			_dar(Pilotagem.ordem_saida(Pilotagem.SOLTOU, t, float(_saida["ate"]), _pil))
			_nota(Pilotagem.SOLTOU)
		var fr := (t - float(_saida["de"])) / maxf(float(_saida["ate"]) - float(_saida["de"]), 0.01)
		if fr >= 1.0:
			if not _saida["soltou"]:
				_nota(Pilotagem.LIMPA)
			_saida = {}
		else:
			_pedal.saida(fr, _segurando)
			mostrou = true
	# A curva à frente: a régua da frenagem até o carro entrar nela.
	_frenagem = {}
	var prox := Tatica.proxima(_tatica, s_volta, comp)
	if not prox.is_empty():
		var c: Dictionary = prox["curva"]
		var inicio_abs := s + fposmod(float(c["inicio"]) - s_volta, comp)
		if prox["estado"] == "na_curva":
			inicio_abs = s - fposmod(s_volta - float(c["inicio"]), comp)
		var chave := roundi(inicio_abs)
		var com_frenagem := Pilotagem.tem_frenagem(c, comp, _pil)
		var fim_abs := inicio_abs + fposmod(float(c["fim"]) - float(c["inicio"]), comp)
		if prox["estado"] == "na_curva":
			_feitas[chave] = _feitas.get(chave, "")
			_na_curva = {"chave": chave, "fim": fim_abs, "com_frenagem": com_frenagem}
		elif com_frenagem and not _feitas.has(chave):
			var fren_abs := inicio_abs - fposmod(float(c["inicio"]) - float(c["frenagem"]), comp)
			var t_fren := _visual.tempo_em("jogador", fren_abs)
			var f: Dictionary = _pil["frenagem"]
			if t_fren >= 0.0 and t_fren - t <= float(f["janela_s"]):
				_frenagem = {"chave": chave, "t_frenagem": t_fren, "fim": fim_abs}
				if not mostrou:
					_pedal.frenagem(t_fren - t, float(f["janela_s"]), float(f["perfeita_s"]), float(f["boa_s"]))
					mostrou = true
				_dica_pilotagem()
	if not mostrou:
		_pedal.esconder()
	# ATACAR: colado no carro da frente, com o ataque recarregado.
	var ordem := _visual.ordem()
	var i := ordem.find("jogador")
	var d_frente := INF if i <= 0 else _visual.distancia(ordem[i - 1]) - s
	_botao_ataque.visible = Pilotagem.pode_atacar(d_frente, t, _ultimo_ataque, _pil)


## O toque na régua FREIE: a nota pelo atraso em relação ao ponto de frenagem.
func _frear() -> void:
	if _frenagem.is_empty():
		return
	var t := _visual.tempo
	var nota := Pilotagem.nota_frenagem(t - float(_frenagem["t_frenagem"]), _pil)
	var t_saida := _visual.tempo_em("jogador", float(_frenagem["fim"]))
	if t_saida < 0.0:
		t_saida = t + 5.0
	if _dar(Pilotagem.ordem_frenagem(nota, t, t_saida, _pil)).is_empty():
		return
	_feitas[_frenagem["chave"]] = nota
	_frenagem = {}
	_pedal.esconder()
	_nota(nota)


func _atacar() -> void:
	var t := _visual.tempo
	if _dar(Pilotagem.ordem_ataque(t, _pil)).is_empty():
		return
	_ultimo_ataque = t
	_botao_ataque.visible = false
	_painel_hud.evento("ATAQUE!", "", COR_DESTAQUE, 7, 1.4, true)
	_clarear(COR_DESTAQUE, 0.22)
	_visual3d.acionar()
	Sons.tocar_ui(self, "passagem", -6.0, 1.2)


## A ordem vai para a corrida (Fila.pilotar); {} se a corrida ao vivo ainda não
## chegou ao instante da tela (o toque não conta).
func _dar(ordem: Dictionary) -> Dictionary:
	return jogador.fila_ctrl.pilotar(ordem, _visual.tempo)


func _nota(nota: String) -> void:
	var boa := nota in [Pilotagem.PERFEITA, Pilotagem.LIMPA]
	var ruim := nota in [Pilotagem.CEDO, Pilotagem.TARDE, Pilotagem.SOLTOU]
	var cor := COR_DESTAQUE if boa else (Color(1.0, 0.45, 0.4) if ruim else Color.WHITE)
	_painel_hud.evento(Pilotagem.TEXTOS[nota], "", cor, 6, 1.1, false, boa)
	if boa:
		_clarear(COR_DESTAQUE, 0.15)


## A corrida refeita pelo último toque entra na tela a partir do toque, à
## medida que a fila a resolve (igual à anterior até ali).
func _emendar() -> void:
	var vp: int = jogador.fila_ctrl.versao_parcial
	if vp != _versao_parcial:
		_versao_parcial = vp
		_emenda_desde = -1.0
		_emenda_i = 0
	var r: Dictionary = jogador.fila_ctrl.parcial()
	if r.is_empty():
		return
	if _emenda_desde < 0.0:
		_emenda_desde = float(r["desde"])
	var t := _visual.tempo
	_emenda_i = _visual.emendar(r, _emenda_desde, _emenda_i)
	_emenda_desde = _visual.duracao() + 1e-6
	_visual.tempo = t


## Nas primeiras corridas, a primeira régua da corrida vem com a explicação.
func _dica_pilotagem() -> void:
	var n := int(jogador.flags.get("PILOTAGEM_DICA", 0))
	if n >= 3 or bool(_frenagem.get("dica", false)) or _feitas.size() > 1:
		return
	if jogador.flags.get("PILOTAGEM_DICA_SEMENTE", 0) == _semente_mostrada:
		return
	jogador.flags["PILOTAGEM_DICA_SEMENTE"] = _semente_mostrada
	jogador.flags["PILOTAGEM_DICA"] = n + 1
	_painel_hud.evento("TOQUE NA TELA NO FREIE", "E SEGURE ATÉ A SAÍDA DA CURVA", Color.WHITE, 9, 3.5, true)


func _clarear(cor: Color, forca: float) -> void:
	if Preferencias.reduzir_animacoes:
		return
	_clarao.color = Color(cor, 0.0)
	_clarao.set_meta("forca", forca)
	_t_clarao = CLARAO_S


## Com a corrida já andando (DICA_CAMERA_S depois da largada), a história conta
## que a câmera muda (CW_P05C, só na primeira vez).
func _dica_camera() -> void:
	if _dica_camera_pedida or jogador.fila.is_empty() or antes_da_largada() or _visual.tempo < DICA_CAMERA_S:
		return
	_dica_camera_pedida = true
	historia("CORRIDA_EM_CURSO")


## Seletor de câmera: perde contraste sem toque; volta ao tocar (e fica aceso
## com uma conversa aberta, que pode estar apontando para ele).
func _atualizar_seletor(delta: float) -> void:
	_ocioso = 0.0 if dialogo_aberto.call() else _ocioso + delta
	var alvo := SELETOR_APAGADO if _ocioso > SELETOR_OCIOSO_S and not Preferencias.reduzir_animacoes else 1.0
	_cameras.modulate.a = move_toward(_cameras.modulate.a, alvo, delta / (0.8 if alvo < 1.0 else 0.25))


static func _mmss(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


static func _mmss_dec(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
