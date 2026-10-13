class_name Dialogo
extends Control
## Diálogo da história (decisão 32), em cena: a tela escurece, o cenário da cena
## aparece ao fundo (data/historia.json → cenarios, com um zoom lento), o
## personagem que fala entra deslizando de lado em corpo inteiro (Assets,
## variante "corpo"), ocupando quase toda a tela, e na sequência a caixa com nome
## e fala aparece no centro, por cima dele, com o texto sendo digitado. Quando
## outro personagem fala, o anterior sai e o novo entra. Sem a arte (ou falas do
## sistema), só a caixa. Tocar completa o texto, depois avança (ou, no meio da
## entrada, completa a animação). Ações de tutorial no meio da cena saem pelo
## sinal `acao` quando a fala chega nelas; quando a cena abre uma tela ou destaca
## algo, o cenário sai e o personagem fica translúcido para o jogo aparecer.
## Cenas pedidas durante outra entram na fila. O primeiro momento de cada
## capítulo abre com um cartão (historia.json → capitulos).
## Ações próprias do diálogo: [ESCURO] (a tela fica preta até [CLARO] ou o fim da
## sequência), [PAUSA] (um silêncio sem caixa), [TREMOR] (a tela treme),
## [CENARIO:id] (troca o fundo) e [ILUSTRACAO:id] (um quadro de tela cheia do
## momento; as falas seguem embaixo, sem o personagem, até o próximo cenário).
## Sobre uma ilustração com `focos` (historia.json: ponto de cada personagem no
## quadro, 0..1), a câmera chega um pouco mais perto e desliza de leve na direção
## de quem fala. Num destaque, o fundo escuro do diálogo sai (o destaque escurece
## o resto da tela) e a caixa desce.
## Falas aceitam variáveis do jogo ({pista}, {saldo}...: Historia.variaveis) e,
## na primeira vez que alguém fala, o nome vem com o papel (personagens.json →
## papel).

signal acao(nome: String)
## Cena terminada (para a principal encadear a próxima e salvar).
signal terminou(c: Dictionary)

## Apresentação, não balanceamento.
const ENTRADA_S := 0.35
const CAIXA_ATRASO_S := 0.2
const CAIXA_S := 0.22
const ALTURA_CORPO := 0.86  # fração da altura da tela
const PAUSA_S := 1.6
const POSE_S := 0.18  # troca de pose do mesmo personagem
## Fundo acústico do cenário (historia.json → cenarios.<id>.som): volume e
## quanto leva para entrar e sair.
const AMBIENTE_DB := -20.0
const AMBIENTE_MUDO_DB := -60.0
const AMBIENTE_S := 0.8
var _ambiente: AudioStreamPlayer
var _ambiente_som := ""
const LETRAS_POR_S := 55.0
const CENARIO_S := 0.6  # troca de fundo
const FAIXA := 0.07  # faixas de cinema, fração da altura
const CARTAO_S := 2.4  # cartão de capítulo, inteiro
const TOM := {"noite": Color(0.42, 0.48, 0.7), "vazio": Color(0.58, 0.58, 0.6), "frio": Color(0.74, 0.8, 0.92)}
## Ações que o próprio diálogo executa (não vão para a principal).
const LOCAIS := ["ESCURO", "CLARO", "PAUSA", "TREMOR", "IMPACTO"]
## Ritmo da fala: pausas depois da pontuação, no texto digitado.
const PAUSA_VIRGULA_S := 0.08
const PAUSA_PONTO_S := 0.2
## Respiração do personagem parado: sobe e desce poucos pixels, em ciclos
## defasados por personagem.
## Dois em cena: quem escuta recua para o outro lado, menor e mais escuro;
## quem fala fica à frente, um pouco para o seu lado.
const OUVINTE_ESCALA := 0.88
const OUVINTE_LUZ := 0.5
const OUVINTE_DESLOCA := 0.3  # fração da largura da tela
const FALANTE_DESLOCA := 0.1
## Caixa: sobe um pouco ao aparecer; faixa na cor de quem fala.
const CAIXA_SOBE_PX := 8.0
const PULAR_Y := 168.0  # o Pular, fixo: abaixo do cabeçalho e das abas penduradas
const PULAR_VAO := 96.0  # do alto do Pular ao alto da caixa, quando ela sobe
## No tutorial, o busto de quem fala (o corpo recortado na silhueta, sem fundo)
## no canto da caixa: o pé dentro da moldura, a cabeça saindo por cima.
## Medidas da arte em personagens.json → busto: [centro do rosto, queixo,
## altura da cabeça], frações do quadro do corpo.
const BUSTO_CABECA := 104.0  # na tela: do alto da cabeça ao queixo
const BUSTO_LARGURA := 3.0  # largura do recorte, em cabeças (cabelo e ombros)
const BUSTO_ACIMA := 1.6  # quanto do recorte fica acima do queixo, em cabeças
const BUSTO_ABAIXO := 3.0  # e abaixo (até a cintura; a caixa corta antes)
const BUSTO_LARGURA_MAX := 300.0  # na tela: o recorte (transparente nas bordas)
const BUSTO_OCUPA := 0.74  # da largura do recorte, o que empurra o texto
const BUSTO_BORDA := 2.0  # espessura da moldura (o corte fica rente a ela)

var historia: Historia
var _fila: Array = []
var _cena: Dictionary = {}
var _i := 0
var _fundo: ColorRect
var _cenario: TextureRect
var _vinheta: TextureRect
var _cenario_id := ""
var _ilustrando := false
var _corpo: TextureRect
var _quem := ""
var _pose := ""  # pose do corpo mostrado (falas "Nome[pose]: ...")
var _faixas: Array[ColorRect] = []
var _caixa: PanelContainer
var _nome: Label
var _texto: Label
var _cartao: Control
var _cartao_rotulo: Label
var _cartao_titulo: Label
var _tween: Tween
var _tw_texto: Tween
var _tw_cartao: Tween
var _animando := false
var _lado := 1.0  # de que lado o próximo personagem entra (alterna)
var _translucido := false  # depois de um destaque, até o fim da cena
var _ouvinte: TextureRect
var _ouvinte_quem := ""
var _lados := {}  # quem -> lado na tela (-1, 1) quando há dois em cena
var _base_y := 0.0
var _impacto := false
var _barra: ColorRect
var _retrato: Control  # o espaço do busto dentro da caixa
var _busto: TextureRect
var _janela: Control  # corta o busto só na borda de baixo da caixa
var _busto_info := {}
static var _bustos := {}
var _dica: Label
var _tempos := PackedFloat32Array()
var _pular: Button
var _escuro := false  # [ESCURO] vale até [CLARO] ou o fim da sequência de cenas
## Recebe a próxima cena e diz se ela tem de esperar (uma janela do jogo está
## aberta: resultado, carro novo...). A cena começa quando a janela fecha.
var espera := Callable()


func _init(historia_: Historia) -> void:
	historia = historia_
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo = ColorRect.new()
	_fundo.color = Color(0, 0, 0, 0.62)
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundo.gui_input.connect(_toque)
	add_child(_fundo)
	_ambiente = AudioStreamPlayer.new()
	_ambiente.volume_db = AMBIENTE_MUDO_DB
	add_child(_ambiente)
	_cenario = TextureRect.new()
	_cenario.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cenario.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cenario.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cenario.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cenario.visible = false
	add_child(_cenario)
	# Vinheta: escurece o alto e, mais, o pé da tela (onde ficam a caixa e o
	# corpo), para o texto ler bem sobre qualquer fundo.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.28, 0.6, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.2), Color(0, 0, 0, 0.92)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	_vinheta = TextureRect.new()
	_vinheta.texture = gt
	_vinheta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vinheta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	_vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vinheta.visible = false
	add_child(_vinheta)
	_ouvinte = TextureRect.new()
	_ouvinte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ouvinte.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ouvinte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ouvinte.visible = false
	add_child(_ouvinte)
	_corpo = TextureRect.new()
	_corpo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_corpo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_corpo)
	for embaixo in [false, true]:
		var f := ColorRect.new()
		f.color = Color.BLACK
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.anchor_left = 0.0
		f.anchor_right = 1.0
		f.anchor_top = 1.0 if embaixo else 0.0
		f.anchor_bottom = f.anchor_top
		add_child(f)
		_faixas.append(f)
	_caixa = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.93)
	sb.border_color = Aba.COR_DESTAQUE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	_caixa.add_theme_stylebox_override("panel", sb)
	_caixa.gui_input.connect(_toque)
	# No centro (um pouco abaixo do meio), crescendo para cima e para baixo.
	_caixa.anchor_left = 0.0
	_caixa.anchor_right = 1.0
	_caixa.offset_left = 24
	_caixa.offset_right = -24
	_caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	_posicionar_caixa(false)
	add_child(_caixa)
	_janela = Control.new()
	_janela.clip_contents = true
	_janela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_janela.visible = false
	add_child(_janela)
	_busto = TextureRect.new()
	_busto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_busto.stretch_mode = TextureRect.STRETCH_SCALE
	_busto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_janela.add_child(_busto)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 14)
	_caixa.add_child(h)
	_barra = ColorRect.new()
	_barra.custom_minimum_size.x = 6
	_barra.color = Aba.COR_DESTAQUE
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_barra)
	_retrato = Control.new()
	_retrato.custom_minimum_size = Vector2(BUSTO_LARGURA_MAX * BUSTO_OCUPA, 0)
	_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato.visible = false
	h.add_child(_retrato)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	h.add_child(v)
	_nome = Label.new()
	_nome.add_theme_font_size_override("font_size", 26)
	_nome.add_theme_color_override("font_color", Aba.COR_DESTAQUE)
	v.add_child(_nome)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 32)
	v.add_child(_texto)
	_dica = Label.new()
	_dica.text = "toque para continuar ›"
	_dica.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dica.add_theme_font_size_override("font_size", 18)
	_dica.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
	v.add_child(_dica)
	_montar_cartao()
	_montar_pular()
	visible = false


## "Pular" fora da caixa, no canto inferior direito da tela; por cima do
## cartão de capítulo também (pula a cena inteira).
func _montar_pular() -> void:
	_pular = Button.new()
	Tipografia.acao_secundaria(_pular, "Pular ›", Color(0.93, 0.92, 0.88, 0.85), 30, 80)
	_pular.custom_minimum_size.x = 150
	_pular.pressed.connect(pular_cena)
	add_child(_pular)
	_lugar_pular()


## "Pular" sempre no mesmo lugar (pedido do usuário): no alto à direita,
## abaixo do cabeçalho; a caixa nunca sobe até ele (_posicionar_caixa).
func _lugar_pular() -> void:
	if _pular == null:
		return
	_pular.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pular.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_pular.grow_vertical = Control.GROW_DIRECTION_END
	_pular.offset_right = -16
	_pular.offset_top = PULAR_Y


## Cartão de capítulo: tela preta, "Capítulo N" pequeno e o título grande.
func _montar_cartao() -> void:
	_cartao = ColorRect.new()
	(_cartao as ColorRect).color = Color.BLACK
	_cartao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cartao.gui_input.connect(_toque_cartao)
	_cartao.visible = false
	add_child(_cartao)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.add_child(v)
	_cartao_rotulo = Label.new()
	_cartao_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartao_rotulo.add_theme_font_size_override("font_size", 24)
	_cartao_rotulo.add_theme_color_override("font_color", Aba.COR_DESTAQUE)
	v.add_child(_cartao_rotulo)
	var linha := ColorRect.new()
	linha.color = Aba.COR_DESTAQUE
	linha.custom_minimum_size = Vector2(90, 3)
	linha.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(linha)
	_cartao_titulo = Label.new()
	_cartao_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartao_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cartao_titulo.add_theme_font_size_override("font_size", 54)
	v.add_child(_cartao_titulo)


func ocupado() -> bool:
	return not _cena.is_empty() or not _fila.is_empty()


func _deve_esperar() -> bool:
	return not _fila.is_empty() and espera.is_valid() and espera.call(_fila[0])


func enfileirar(c: Dictionary) -> void:
	if c.is_empty() or (_cena.get("id") == c["id"]) or _fila.any(func(x): return x["id"] == c["id"]):
		return
	_fila.append(c)
	if _cena.is_empty():
		_proxima()


func _proxima() -> void:
	if _fila.is_empty() or _deve_esperar():
		_cena = {}
		_quem = ""
		_pose = ""
		_ouvinte_quem = ""
		_ouvinte.visible = false
		_escuro = false
		_trocar_cenario("")
		visible = false
		return
	_cena = _fila.pop_front()
	_i = 0
	_lados = {}
	_ouvinte_quem = ""
	_ouvinte.visible = false
	# Na largada (segura_largada) o grid aparece: sem personagem, fundo leve.
	var na_pista: bool = _cena.get("segura_largada", false)
	_translucido = na_pista
	visible = true
	_fundo.visible = true
	_fundo.color.a = 1.0 if _escuro else (0.3 if na_pista else 0.62)
	_caixa.visible = true
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	_posicionar_caixa(_ilustrando or na_pista)
	_trocar_cenario(String(_cena.get("cenario", "")))
	if not _capitulo_novo():
		_mostrar()


## O primeiro momento de um capítulo abre com o cartão; a cena começa quando ele
## some (ou ao tocar).
func _capitulo_novo() -> bool:
	var cap := String(_cena.get("capitulo", ""))
	var titulos: Dictionary = historia.dados.historia().get("capitulos", {})
	var flag := "CAPITULO_" + cap
	if cap == "" or not titulos.has(cap) or historia.jogador.flags.has(flag):
		return false
	historia.jogador.flags[flag] = true
	var n: int = titulos.keys().find(cap)
	_cartao_rotulo.text = "PRÓLOGO" if n == 0 else "CAPÍTULO %d" % n
	_cartao_titulo.text = String(titulos[cap])
	_caixa.visible = false
	_corpo.visible = false
	_cartao.visible = true
	_cartao.modulate.a = 0.0
	if _tw_cartao != null:
		_tw_cartao.kill()
	_tw_cartao = create_tween()
	_tw_cartao.tween_property(_cartao, "modulate:a", 1.0, CARTAO_S * 0.2)
	_tw_cartao.tween_interval(CARTAO_S * 0.6)
	_tw_cartao.tween_property(_cartao, "modulate:a", 0.0, CARTAO_S * 0.2)
	_tw_cartao.tween_callback(_fim_cartao)
	return true


func _fim_cartao() -> void:
	if not _cartao.visible:
		return
	_cartao.visible = false
	_caixa.visible = true
	_mostrar()


func _toque_cartao(ev: InputEvent) -> void:
	var toque: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
			or (ev is InputEventScreenTouch and ev.pressed)
	if toque:
		accept_event()
		if _tw_cartao != null:
			_tw_cartao.kill()
		_fim_cartao()


## Mostra a fala atual; ações seguidas executam antes de parar na próxima fala.
func _mostrar() -> void:
	if _cena.is_empty():  # animação pendente de uma cena já pulada
		return
	var falas: Array = _cena["falas"]
	while _i < falas.size() and falas[_i].has("acao"):
		var nome_acao := String(falas[_i]["acao"])
		_i += 1
		if nome_acao.begins_with("CENARIO:"):
			_trocar_cenario(nome_acao.get_slice(":", 1))
			continue
		if nome_acao.begins_with("ILUSTRACAO:"):
			_trocar_cenario(nome_acao.get_slice(":", 1), true)
			continue
		match nome_acao:
			"ESCURO":
				# Tela preta (o acidente): segue no escuro até [CLARO].
				_escuro = true
				_corpo.visible = false
				_quem = ""
				_pose = ""
				_trocar_cenario("")
				create_tween().tween_property(_fundo, "color:a", 1.0, 0.8)
				continue
			"CLARO":
				_escuro = false
				create_tween().tween_property(_fundo, "color:a", 0.62, 0.8)
				continue
			"TREMOR":
				_tremer()
				continue
			"IMPACTO":
				_impacto = true  # vale para a próxima fala
				continue
			"PAUSA":
				# Silêncio: nada na tela por um instante, depois segue.
				_caixa.visible = false
				_animando = true
				if _tween != null:
					_tween.kill()
				_tween = create_tween()
				_tween.tween_interval(PAUSA_S)
				_tween.tween_callback(func():
					_caixa.visible = true
					_animando = false
					_mostrar())
				return
		# A cena mostra o jogo (abre uma tela ou destaca algo): o cenário sai e o
		# personagem fica translúcido para o elemento aparecer.
		if nome_acao.begins_with("HIGHLIGHT_") or nome_acao.begins_with("OPEN_"):
			_trocar_cenario("")
		if nome_acao.begins_with("HIGHLIGHT_"):
			_translucido = true
			_corpo.visible = false  # o tutorial mostra o jogo, sem o personagem
			_ouvinte.visible = false
			_ouvinte_quem = ""
			_posicionar_caixa(true)
			create_tween().tween_property(_fundo, "color:a", 0.0, 0.3)
		acao.emit(nome_acao)
	if _i >= falas.size():
		_fim()
		return
	var f: Dictionary = falas[_i]
	var quem := String(f["quem"])
	var p := historia.personagem(quem)
	var sistema := quem == "sistema"
	_nome.text = String(p.get("nome", quem))
	# Primeira vez que fala: nome e papel (quem é essa pessoa).
	var flag := "APRESENTADO_" + quem.to_upper()
	if not sistema and String(p.get("papel", "")) != "" and not historia.jogador.flags.has(flag):
		_nome.text += " · " + String(p["papel"])
		historia.jogador.flags[flag] = true
	_nome.visible = not sistema and _nome.text != ""
	# A caixa na cor de quem fala (faixa e nome); o sistema, no ocre.
	var cor := Aba.COR_DESTAQUE if sistema else _cor_legivel(Color(String(p.get("cor", "#d6a23e"))))
	_barra.color = cor
	_nome.add_theme_color_override("font_color", cor)
	# No tutorial (o jogo à mostra), o retrato pequeno no canto da caixa.
	_busto_info = _busto_de(quem) if _translucido and not sistema else {}
	_janela.visible = not _busto_info.is_empty()
	_retrato.visible = _janela.visible
	if _janela.visible:
		_busto.texture = _busto_info["tex"]
		_busto.size = _busto_info["tela"]
		_retrato.custom_minimum_size.x = _busto_info["tela"].x * BUSTO_OCUPA
	_texto.text = String(f["texto"]).format(historia.variaveis(_cena.get("_ctx", {})))
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if sistema else HORIZONTAL_ALIGNMENT_LEFT
	_layout()
	var atraso := 0.0
	var pose := String(f.get("pose", ""))
	if quem != _quem:
		atraso = _entrar(quem, sistema, pose)
	else:
		if pose != _pose and _corpo.visible:
			_trocar_pose(quem, pose)
		_subir_caixa()
	_quem = quem
	_pose = pose
	if _impacto:
		_impacto = false
		_enfatizar(atraso)
	_digitar(atraso)


## Personagem novo: entra do jeito dele (personagens.json → entrada), depois a
## caixa. Se quem falava antes continua em cena, recua para o outro lado como
## ouvinte; se quem entra era o ouvinte, ele vem para a frente. Devolve quanto
## tempo falta para a caixa aparecer. Sobre uma ilustração ou num tutorial,
## sem corpo.
func _entrar(quem: String, sistema: bool, pose := "") -> float:
	if _tween != null:
		_tween.kill()
	var tex: Texture2D = null if sistema or _ilustrando or _translucido else _textura(quem, pose)
	var tela := get_viewport_rect().size
	var anterior := _quem if _corpo.visible and _corpo.texture != null else ""
	var tex_anterior := _corpo.texture
	var era_ouvinte: bool = quem == _ouvinte_quem and _ouvinte.visible
	_lado = -_lado
	# Personagens parados (pedido do usuário): aparecem no lugar, num esmaecer curto.
	var dur: float = 0.01 if Preferencias.reduzir_animacoes else ENTRADA_S
	_caixa.modulate.a = 0.0
	_animando = true
	_tween = create_tween()
	var atraso := CAIXA_S
	var centro := (tela.x - _corpo.size.x) / 2.0
	if tex == null:
		_corpo.visible = false
		_ouvinte.visible = false
		_ouvinte_quem = ""
	else:
		_corpo.texture = tex
		_corpo.visible = true
		var x_final := centro
		if anterior != "" and anterior != quem:
			# Dois em cena: cada um no seu lado.
			if not _lados.has(quem):
				_lados[quem] = _lado if not _lados.has(anterior) else -int(_lados[anterior])
			_lados[anterior] = -int(_lados[quem])
			x_final = centro + float(_lados[quem]) * FALANTE_DESLOCA * tela.x
			_recuar(anterior, tex_anterior, _corpo.position.x, centro + float(_lados[anterior]) * OUVINTE_DESLOCA * tela.x)
		elif anterior != quem:
			_ouvinte.visible = false
			_ouvinte_quem = ""
		_corpo.scale = Vector2.ONE
		_corpo.modulate = Color.WHITE
		_corpo.position.x = x_final
		if not era_ouvinte:
			_corpo.modulate.a = 0.0
			_tween.tween_property(_corpo, "modulate:a", 1.0, dur)
			atraso += dur
		_tween.tween_interval(CAIXA_ATRASO_S)
		atraso += CAIXA_ATRASO_S
	_tween.tween_callback(_subir_caixa)
	_tween.tween_interval(CAIXA_S)
	_tween.tween_callback(func(): _animando = false)
	return atraso


## Quem falava recua para o lado dele como ouvinte (menor e mais escuro).
func _recuar(quem: String, tex: Texture2D, x_de: float, x_para: float) -> void:
	_ouvinte_quem = quem
	_ouvinte.texture = tex
	_ouvinte.visible = true
	# Vai direto para o lado dele, menor e mais escuro (sem deslizar).
	_ouvinte.position.x = x_para
	_ouvinte.scale = Vector2.ONE * OUVINTE_ESCALA
	_ouvinte.modulate = Color(OUVINTE_LUZ, OUVINTE_LUZ, OUVINTE_LUZ)


## A caixa aparece subindo um pouco.
func _subir_caixa() -> void:
	var tw := create_tween().set_parallel()
	var dur := 0.01 if Preferencias.reduzir_animacoes else CAIXA_S
	_caixa.offset_top = CAIXA_SOBE_PX
	_caixa.offset_bottom = CAIXA_SOBE_PX
	tw.tween_property(_caixa, "modulate:a", 1.0, dur)
	tw.tween_property(_caixa, "offset_top", 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_caixa, "offset_bottom", 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## [IMPACTO]: a caixa dá um tremor leve (o personagem fica parado).
func _enfatizar(atraso: float) -> void:
	if Preferencias.reduzir_animacoes:
		return
	var tw := create_tween()
	tw.tween_interval(atraso)
	for k in 4:
		tw.tween_property(_caixa, "offset_left", 24.0 + (6.0 if k % 2 == 0 else -6.0) * (1.0 - k / 4.0), 0.04)
	tw.tween_property(_caixa, "offset_left", 24.0, 0.04)


## Busto do personagem: o corpo (sem fundo) recortado pelas medidas da arte
## (personagens.json → busto), da cabeça inteira à cintura. Devolve {tex, tela
## (tamanho na tela), queixo (px na tela, do alto do recorte ao queixo)}; {}
## sem arte ou sem medidas. Uma vez por personagem.
func _busto_de(quem: String) -> Dictionary:
	if _bustos.has(quem):
		return _bustos[quem]
	var corpo: Texture2D = Assets.get_asset(quem, "corpo")
	var m: Array = historia.personagem(quem).get("busto", [])
	var r := {}
	if corpo != null and m.size() == 3:
		var w := float(corpo.get_width())
		var h := float(corpo.get_height())
		var cabeca := float(m[2]) * h
		var queixo := float(m[1]) * h
		var y0 := maxf(queixo - cabeca * BUSTO_ACIMA, 0.0)
		var y1 := minf(queixo + cabeca * BUSTO_ABAIXO, h)
		var larg := cabeca * BUSTO_LARGURA
		var x0 := clampf(float(m[0]) * w - larg / 2.0, 0.0, maxf(w - larg, 0.0))
		var at := AtlasTexture.new()
		at.atlas = corpo
		at.region = Rect2(x0, y0, minf(larg, w), y1 - y0)
		var k := minf(BUSTO_CABECA / cabeca, BUSTO_LARGURA_MAX / larg)
		r = {"tex": at, "tela": at.region.size * k, "queixo": (queixo - y0) * k}
	_bustos[quem] = r
	return r


## O busto acompanha a caixa: o queixo na borda de cima da moldura (a cabeça
## inteira para fora, sem corte) e o resto dentro dela, cortado só rente à
## borda de baixo.
func _encaixar_busto() -> void:
	if not _janela.visible or _busto_info.is_empty():
		return
	var c := _caixa.get_global_rect()
	var tela: Vector2 = _busto_info["tela"]
	var x := c.position.x + 14.0 + tela.x * BUSTO_OCUPA / 2.0 - tela.x / 2.0
	_janela.global_position = Vector2(x, 0.0)
	_janela.size = Vector2(tela.x, c.end.y - BUSTO_BORDA)
	_busto.position = Vector2(0.0, c.position.y + BUSTO_BORDA - float(_busto_info["queixo"]))
	_janela.modulate.a = _caixa.modulate.a


## A cor de quem fala, clara o bastante para ler sobre a caixa escura.
static func _cor_legivel(c: Color) -> Color:
	while c.get_luminance() < 0.45:
		c = c.lightened(0.15)
	return c


## O texto aparece letra a letra, com pausas depois da pontuação (o ritmo de
## quem fala); tocar completa.
func _digitar(atraso: float) -> void:
	if _tw_texto != null:
		_tw_texto.kill()
	_tempos = PackedFloat32Array()
	var t := 0.0
	var txt := _texto.text
	for k in txt.length():
		t += 1.0 / LETRAS_POR_S
		_tempos.append(t)
		var ch := txt[k]
		var seguinte := txt[k + 1] if k + 1 < txt.length() else " "
		if seguinte == " " or seguinte == "\n":
			if ch in [",", ";", ":"]:
				t += PAUSA_VIRGULA_S
			elif ch in [".", "!", "?", "…", "—"]:
				t += PAUSA_PONTO_S
	_texto.visible_characters = 0
	_tw_texto = create_tween()
	if atraso > 0.0:
		_tw_texto.tween_interval(atraso)
	_tw_texto.tween_method(_letras_ate, 0.0, maxf(t, 0.05), maxf(t, 0.05))
	_tw_texto.tween_callback(func(): _texto.visible_characters = -1)


func _letras_ate(t: float) -> void:
	_texto.visible_characters = _tempos.bsearch(t + 0.0001)


func _digitando() -> bool:
	return _tw_texto != null and _tw_texto.is_running() and _texto.visible_characters != -1


## Fundo da cena ("" tira). Sem a arte, a provisória com o tom do catálogo.
func _trocar_cenario(id: String, ilustracao := false) -> void:
	var chave := ("i:" if ilustracao else "c:") + id
	if chave == _cenario_id:
		return
	_cenario_id = chave if id != "" else ""
	var saiu_da_ilustracao := _ilustrando and not ilustracao
	_ilustrando = ilustracao and id != ""
	if saiu_da_ilustracao:
		_quem = ""  # quem falava sobre a ilustração entra em cena na próxima fala
		_pose = ""
	if _ilustrando:
		_corpo.visible = false
		_quem = ""
		_pose = ""
	_posicionar_caixa(_ilustrando)
	var tex: Texture2D = null
	var tom := Color.WHITE
	var som := ""
	if id != "":
		var cat: Dictionary = historia.dados.historia().get("ilustracoes" if ilustracao else "cenarios", {}).get(id, {})
		som = String(cat.get("som", ""))
		tex = Assets.get_asset(id, "ilustracao" if ilustracao else "cenario")
		if tex == null and cat.has("provisorio"):
			var prov := String(cat["provisorio"])
			# Provisória: outro cenário já pronto ("cenario:<id>") ou arte da interface.
			tex = Assets.get_asset(prov.trim_prefix("cenario:"), "cenario") if prov.begins_with("cenario:") \
					else Assets.get_asset(prov, "ui")
			tom = TOM.get(String(cat.get("tom", "")), Color.WHITE)
	_som_ambiente(som)
	if tex == null:
		if _cenario.visible:
			var tw := create_tween().set_parallel()
			tw.tween_property(_cenario, "modulate:a", 0.0, CENARIO_S)
			tw.tween_property(_vinheta, "modulate:a", 0.0, CENARIO_S)
			tw.chain().tween_callback(func():
				if _cenario_id == "":
					_cenario.visible = false
					_vinheta.visible = false)
		_faixas_cinema(false)
		return
	_cenario.texture = tex
	_cenario.self_modulate = tom
	_cenario.visible = true
	_vinheta.visible = true
	_cenario.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_cenario, "modulate:a", 1.0, CENARIO_S * (2.0 if ilustracao else 1.0))
	tw.tween_property(_vinheta, "modulate:a", 1.0, CENARIO_S)
	# Imagem parada (pedido do usuário): sem zoom lento nem câmera seguindo quem fala.
	_cenario.position = Vector2.ZERO
	_cenario.scale = Vector2.ONE
	_faixas_cinema(true)


func _faixas_cinema(ligar: bool) -> void:
	var h := get_viewport_rect().size.y * FAIXA if ligar else 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_faixas[0], "offset_bottom", h, CENARIO_S)
	tw.tween_property(_faixas[1], "offset_top", -h, CENARIO_S)


## Sobre uma ilustração, a caixa desce para o quadro aparecer.
func _posicionar_caixa(embaixo: bool) -> void:
	_caixa.anchor_top = 0.8 if embaixo else 0.58
	_caixa.anchor_bottom = _caixa.anchor_top
	_caixa.grow_vertical = Control.GROW_DIRECTION_BOTH


## Destaque em `r` (coordenadas da tela): a caixa vai para onde cobre menos
## dele (embaixo, ou no alto logo abaixo do Pular, crescendo para baixo).
func evitar(r: Rect2) -> void:
	if _cena.is_empty():
		return
	var alt := get_viewport_rect().size.y
	var h := maxf(_caixa.size.y, 200.0)
	var embaixo := Rect2(0, alt * 0.8 - h * 0.5, 1, h)
	var no_alto := Rect2(0, PULAR_Y + PULAR_VAO, 1, h)
	var cobre_baixo := maxf(0.0, minf(r.end.y, embaixo.end.y) - maxf(r.position.y, embaixo.position.y))
	var cobre_alto := maxf(0.0, minf(r.end.y, no_alto.end.y) - maxf(r.position.y, no_alto.position.y))
	if cobre_baixo <= cobre_alto:
		_posicionar_caixa(true)
		return
	_caixa.anchor_top = no_alto.position.y / alt
	_caixa.anchor_bottom = _caixa.anchor_top
	_caixa.grow_vertical = Control.GROW_DIRECTION_END


## Onde a caixa do destaque começa embaixo (para quem rola a tela antes).
func topo_da_caixa() -> float:
	return get_viewport_rect().size.y * 0.8 - maxf(_caixa.size.y, 200.0) * 0.5


func _tremer(forca := 18.0, vezes := 10) -> void:
	if Preferencias.reduzir_animacoes and forca < 18.0:
		return
	var tw := create_tween()
	for k in vezes:
		var amp := forca * (1.0 - float(k) / vezes)
		tw.tween_property(self, "position", Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


## Som de fundo do cenário ("" = silêncio): entra e sai devagar, sem cortes.
func _som_ambiente(som: String) -> void:
	if som == _ambiente_som:
		return
	_ambiente_som = som
	var stream: AudioStream = Sons.ambiente(som) if som != "" else null
	var tw := create_tween()
	if stream == null:
		tw.tween_property(_ambiente, "volume_db", AMBIENTE_MUDO_DB, AMBIENTE_S)
		tw.tween_callback(func():
			if _ambiente_som == "":
				_ambiente.stop())
		return
	if _ambiente.stream != stream or not _ambiente.playing:
		_ambiente.stream = stream
		_ambiente.volume_db = AMBIENTE_MUDO_DB
		_ambiente.play()
	tw.tween_property(_ambiente, "volume_db", AMBIENTE_DB, AMBIENTE_S)


## Corpo do personagem na pose da fala (sem a arte da pose, o corpo base).
func _textura(quem: String, pose := "") -> Texture2D:
	var tex: Texture2D = Assets.get_asset(quem + "@" + pose, "corpo") if pose != "" else null
	return tex if tex != null else Assets.get_asset(quem, "corpo")


## Mesmo personagem, outra pose: troca no lugar, com um piscar curto de brilho.
func _trocar_pose(quem: String, pose: String) -> void:
	var tex := _textura(quem, pose)
	if tex == null or tex == _corpo.texture:
		return
	_corpo.texture = tex
	if not Preferencias.reduzir_animacoes:
		var alfa := 0.25 if _translucido else 1.0  # o alvo, não o atual (trocas seguidas)
		_corpo.modulate.a = alfa * 0.55
		create_tween().tween_property(_corpo, "modulate:a", alfa, POSE_S)


## Corpo embaixo, quase da altura da tela (a caixa vai por âncora); o lado é
## o da entrada (_entrar). Escala pelo pé, para o ouvinte encolher no chão.
func _layout() -> void:
	var tela := get_viewport_rect().size
	var h := tela.y * ALTURA_CORPO
	for c in [_corpo, _ouvinte]:
		c.size = Vector2(h * 2.0 / 3.0, h)
		c.pivot_offset = Vector2(c.size.x / 2.0, h)
	_base_y = tela.y - h


## O corpo parado no lugar e a dica de continuar, que pulsa só quando o texto
## acabou.
func _process(_delta: float) -> void:
	if _cena.is_empty() and not _fila.is_empty() and not _deve_esperar():
		_proxima()  # a janela que segurava a cena fechou
	if not visible:
		return
	var t := Time.get_ticks_msec() / 1000.0
	_corpo.position.y = _base_y
	_ouvinte.position.y = _base_y
	_encaixar_busto()
	var pronto := not _digitando() and not _animando
	_dica.modulate.a = (0.55 + 0.45 * sin(t * 3.0)) if pronto else 0.0


func _toque(ev: InputEvent) -> void:
	var toque: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
			or (ev is InputEventScreenTouch and ev.pressed)
	if toque and not _cena.is_empty():
		accept_event()
		if _animando and _tween != null:
			_tween.custom_step(10.0)  # completa a entrada
			if _digitando():
				_tw_texto.custom_step(1000.0)
			return
		if _digitando():
			_tw_texto.custom_step(1000.0)  # completa o texto
			return
		avancar()


## Pula as falas da cena; ações e flags dela acontecem do mesmo jeito.
func pular_cena() -> void:
	if _cena.is_empty():
		return
	for tw in [_tween, _tw_cartao, _tw_texto]:
		if tw != null:
			tw.kill()
	_cartao.visible = false
	_caixa.visible = true
	_animando = false
	var falas: Array = _cena["falas"]
	_i += 1
	while _i < falas.size():
		if falas[_i].has("acao"):
			var nome := String(falas[_i]["acao"])
			if not nome in LOCAIS and not nome.contains(":"):
				acao.emit(nome)
		_i += 1
	_fim()


func avancar() -> void:
	_i += 1
	_mostrar()


func _fim() -> void:
	var c := _cena
	var proxima := historia.concluir(c)
	terminou.emit(c)
	if not proxima.is_empty():
		_fila.push_front(proxima)
	_quem = ""
	_pose = ""
	_proxima()
