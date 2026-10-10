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

## Câmeras: nome (só na dica do mouse), modo e ícone. Sem texto no botão: o
## jogador descobre tocando.
const CAMERAS := [["Automática", "auto", "camera"], ["Seu carro", "jogador", "seta"], ["Líder", "lider", "coroa"],
		["À frente", "frente", "frente"], ["Pista inteira", "geral", "pista"], ["Dados", "dados", "dados"]]

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
var _semente_mostrada := 0
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
var _sons: Sons
var _s_jogador := 0.0
var _chegou := false
var _t_chegada := 0.0
var _segurar := 0.0  # segundos parados na última imagem depois do fim
var _diretor := DiretorCamera.new()
var _foco_auto := "jogador"
## Cena da largada (segura_largada): a corrida fica no grid até ela acabar.
var segurar_largada := false


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


## Seletor único e compacto, só ícones: automática, seu carro, líder, à
## frente, pista inteira e dados. São filtros de acompanhamento, não ações:
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
		b.custom_minimum_size = Vector2(0, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ic := IconeVetor.new(c[2], COR_SECUNDARIA)
		ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		ic.offset_left = -21
		ic.offset_right = 21
		ic.offset_top = -19
		ic.offset_bottom = 19
		b.add_child(ic)
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
			(_cameras_botoes[i].get_child(0) as IconeVetor).cor = Color(0.1, 0.1, 0.1) if marcado else COR_SECUNDARIA


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
		proximo_passo("Nenhuma corrida agora.", "Escolher corrida", EVENTOS, _painel)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or jogador.fila_ctrl == null:
		if _sons != null:
			_sons.motor(false)
			_sons.torcida(0.0)
		return
	_atualizar_seletor(delta)
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
	if _contagem >= 0.0:
		_contar(delta)
	if segurar_largada or _contagem > 0.0:
		f["inicio"] = agora  # parada no grid: o relógio da corrida não anda
	if f["semente"] != _semente_mostrada:
		var c: Dictionary = jogador.fila_ctrl.corrida_atual(agora)
		if c.is_empty():
			return
		_mostrar_corrida(f, c, agora)
	if _pausa > 0.0:
		_pausa -= delta
		_atraso += delta
	else:
		_atraso = move_toward(_atraso, 0.0, delta * ALCANCE)
	_visual.tempo = clampf(agora - float(f["inicio"]) - _atraso, 0.0, _visual.duracao())
	var ordem := _visual.ordem()
	_dirigir(ordem)
	if _visual3d.visible:  # na vista DADOS o 3D não anda (bateria)
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
	_sons.motor(not _chegou, (s_agora - _s_jogador) / maxf(delta, 1e-3) if delta > 0.0 else 0.0)
	_s_jogador = s_agora
	_atualizar_hud(ordem)
	_eventos(ordem)


## Nova corrida na tela: minimapa, 3D, nomes, cabeçalho e diretor do zero.
func _mostrar_corrida(f: Dictionary, c: Dictionary, agora: float) -> void:
	var ev: Dictionary = dados.evento(f["evento_id"])
	_pista = dados.pista(ev["pista"])
	_voltas = int(ev["voltas"])
	var meu: Carro = jogador.garagem.carro(f["uid"])
	_visual.mostrar(_pista, c["resultado"], {"jogador": CarroBloco.cor_do_carro(meu)})
	var categorias := {"jogador": meu.base}
	var pinturas := {"jogador": CarroBloco.cor_do_carro(meu)}
	for i in ev["adversarios"].size():
		var adv_id: String = ev["adversarios"][i]["carro"]
		var chave := "adv%d_%s" % [i, adv_id]
		categorias[chave] = dados.carro(adv_id)
		# Rival numa das cores do modelo, fixa por prova e posição no grid.
		pinturas[chave] = Cores.sortear(adv_id, "%s|%d" % [ev["id"], i])
	var comp_carro: Carro = jogador.fila_ctrl.companheiro_inscrito(f)
	if comp_carro != null:
		categorias[EquipeJogador.ID] = comp_carro.base
		pinturas[EquipeJogador.ID] = CarroBloco.cor_do_carro(comp_carro)
	_visual.tempo = clampf(agora - float(f["inicio"]), 0.0, _visual.duracao())
	_visual3d.chegada = 0.0
	_visual3d.mostrar(_pista, _visual, categorias, pinturas)
	_area.visible = true
	_ajustar_area()
	_semente_mostrada = f["semente"]
	_segurar = 0.0
	_painel_hud.limpar_evento()
	_painel_hud.secundario = 1.0
	_posicao_antes = 0
	_volta_antes = 0
	_melhor_volta = -1.0
	_avisado = {}
	var eu := EquipeJogador.nome_jogador(dados, jogador)
	_nomes = {"jogador": "%s · %s" % [eu, meu.base["nome"]]}
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
	_info.text = String(ev["nome"]).replace(" — etapa ", " · Etapa ")
	_nome_prova.text = "%s · %s" % [_info.text, nome_pista(_pista.id)]
	_diretor.reiniciar()
	_foco_auto = "jogador"
	_camera(_camera_modo)
	_chegou = false
	_t_chegada = 0.0
	_s_jogador = _visual.distancia("jogador")
	_atraso = 0.0
	_pausa = 0.0
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
	vazio.custom_minimum_size = Vector2(0, altura - 14.0)
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


## Fim da cena da largada: a corrida começa agora.
func liberar_largada() -> void:
	if not segurar_largada:
		return
	segurar_largada = false
	if not jogador.fila.is_empty():
		jogador.fila["inicio"] = Aceleracao.agora(jogador)
	_diretor.reiniciar()
	_sons.largada(true)
	_painel_hud.evento("LARGADA", "", COR_DESTAQUE, 3)


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
## zebra pelo 3D, torcida na reta final da última volta com disputa de perto
## (e na chegada).

func _som_da_corrida(mg: Array, i: int, ordem: Array, s: float, volta: int) -> void:
	if _chegou:
		_sons.torcida(1.0 - smoothstep(1.5, 4.0, _t_chegada))
		return
	var corte := float(_atributos_hud.get("corte", 0.0))
	if corte > 0.0:
		var escala := ceilf((corte + 600.0) / 1000.0) * 1000.0
		_sons.motor_giro(float(mg[1]) / escala)
	_sons.pneu(_visual3d.cantando("jogador"), _visual3d.na_zebra("jogador"))
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


## Seletor de câmera: perde contraste sem toque; volta ao tocar.
func _atualizar_seletor(delta: float) -> void:
	_ocioso += delta
	var alvo := SELETOR_APAGADO if _ocioso > SELETOR_OCIOSO_S and not Preferencias.reduzir_animacoes else 1.0
	_cameras.modulate.a = move_toward(_cameras.modulate.a, alvo, delta / (0.8 if alvo < 1.0 else 0.25))


static func _mmss(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


static func _mmss_dec(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
