extends Aba

signal correr_iniciado

## Preparação para a inscrição: -1 = a atual do carro; senão índice em
## Carro.configuracoes. A fila guarda uma cópia dela.
var _config := -1
var _config_uid := -1
## Estimativas simuladas sob demanda: chave (prova + carro + peças) -> faixa,
## ou "..." enquanto calcula.
var _estimativas := {}
## Filtro aberto (mantido ao voltar): "nao_vencidas" ou "todas".
var _filtro := "nao_vencidas"
## Cartões mostrados de uma vez (cada um custa ~10 ms para montar; a lista toda
## travava a troca de tela). "Mostrar mais" acrescenta outro lote.
const LOTE := 12
## Moeda de giros: a mesma do painel do cabeçalho.
const ICONE_GIROS := "cabecalho/icone_giros"
## Cartão horizontal da corrida: imagem da pista à esquerda e o título.
const LARGURA_IMAGEM_CARTAO := 210.0
const ALTURA_IMAGEM_CARTAO := 200.0
const TITULO_CARTAO := 40
const TITULO_CARTAO_MIN := 26
## Véu sobre a imagem do cartão: à esquerda, no meio e à direita (opacidade).
const VEU_CARTAO := [0.15, 0.7, 0.85]
var _limite := LOTE

const FILTROS := [["nao_vencidas", "NÃO VENCIDAS"], ["todas", "TODAS AS CORRIDAS"]]
## Altura do topo (cenário com o carro atual).
const ALTURA_TOPO_CARRO := 342.0
## Cor de fundo da imagem da pista (o tema dela na corrida).
const FUNDO_PISTA := {"anel_do_vale": Color(0.16, 0.3, 0.18), "parque_das_docas": Color(0.22, 0.24, 0.28),
		"serra_alta": Color(0.26, 0.25, 0.17), "pista_de_testes": Color(0.36, 0.3, 0.22),
		"circuito_misto": Color(0.3, 0.28, 0.16)}


func _init(d: Node, j: Node) -> void:
	super(d, j, "Correr")


func construir() -> void:
	var garagem := carro_ativo()
	if garagem == null:
		cabecalho("Corridas", "", "fundo_competicoes")
		proximo_passo("Você precisa de um carro para correr.", "Ir para as Lojas", LOJA)
		return
	_topo_carro(garagem)
	if _config_uid != garagem.uid or _config >= garagem.configuracoes.size():
		_config = -1
		_config_uid = garagem.uid
	# Daqui em diante, o carro com a preparação escolhida para a inscrição.
	var c := garagem if _config < 0 else garagem.com_configuracao(garagem.configuracoes[_config], dados.peca)
	if not jogador.fila.is_empty():
		_fila()
	# Dois filtros: as ainda não vencidas (padrão) e todas.
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 8)
	conteudo.add_child(abas)
	for g in FILTROS:
		var b := Button.new()
		b.text = g[1]
		b.toggle_mode = true
		b.button_pressed = _filtro == g[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Tipografia.rotulo(b, "semibold", 24)
		b.custom_minimum_size = Vector2(0, 60)
		b.pressed.connect(func():
			_filtro = g[0]
			_limite = LOTE
			mudou.emit())
		abas.add_child(b)
	# Só as corridas com licença liberada (ou sem licença) aparecem.
	var liberadas := []
	for ev in dados.lista("eventos"):
		if ev["premios"].is_empty():
			continue
		var lic := String(ev["restricoes"].get("licenca", ""))
		if lic != "" and not lic in jogador.licencas:
			continue
		liberadas.append(ev)
	var lista := []
	for ev in liberadas:
		if _filtro == "nao_vencidas" and jogador.vitorias.has(ev["id"]):
			continue
		lista.append([ev, Elegibilidade.motivos(c, ev["restricoes"], jogador.licencas)])
	# O carro atual pode correr primeiro; depois, da de prêmio menor (rivais
	# mais fracos); vencidas por último.
	lista.sort_custom(func(a, b):
		if a[1].is_empty() != b[1].is_empty():
			return a[1].is_empty()
		var va: bool = jogador.vitorias.has(a[0]["id"])
		var vb: bool = jogador.vitorias.has(b[0]["id"])
		if va != vb:
			return not va
		return a[0]["premios"][0] < b[0]["premios"][0])
	if lista.is_empty():
		var v := cartao(COR_INFO)
		if _filtro == "nao_vencidas" and not liberadas.is_empty():
			nota("icone_trofeu_ouro", "Você venceu todas as corridas disponíveis", "", v, Color.WHITE)
			rotulo("Desbloqueie uma nova licença para novas corridas.", FONTE_PEQUENA + 2, COR_SECUNDARIA, v)
		else:
			nota("icone_cadeado", "Desbloqueie uma licença para novas corridas", "", v, Color.WHITE)
		botao("Ver licenças", func(): ir_para.emit(LICENCAS), true, true, v)
	for l in lista.slice(0, _limite):
		_cartao_evento(c, l[0], l[1])
	if lista.size() > _limite:
		var resto := lista.size() - _limite
		var mais := Button.new()
		Tipografia.acao_secundaria(mais, "Mostrar mais %d corrida%s" % [mini(resto, LOTE), "" if resto == 1 else "s"],
				COR_INFO.lightened(0.2), 28, 88)
		mais.pressed.connect(func():
			_limite += LOTE
			mudou.emit())
		conteudo.add_child(mais)


## Topo: o cenário das corridas com a miniatura do carro atual e o nome grande.
func _topo_carro(garagem: Carro) -> void:
	var faixa := ilustracao("fundo_competicoes", ALTURA_TOPO_CARRO)
	cenario_topo(faixa)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	h.grow_vertical = Control.GROW_DIRECTION_BEGIN
	h.offset_left = 16
	h.offset_right = -16
	h.offset_bottom = -8
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.add_child(h)
	var img := icone_carro(garagem.base, false, CarroBloco.cor_do_carro(garagem))
	img.custom_minimum_size = Vector2(510, 288)
	h.add_child(img)
	var nome := Label.new()
	nome.text = garagem.base["nome"]
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # ao lado do carro grande: quebra em linhas
	Tipografia.rotulo(nome, "semibold", 34)
	nome.add_theme_constant_override("outline_size", 6)
	nome.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	h.add_child(nome)


func _fila() -> void:
	var f: Dictionary = jogador.fila
	var ev: Dictionary = dados.evento(f["evento_id"])
	var carro: Carro = jogador.garagem.carro(int(f["uid"]))
	var v := cartao(COR_BOM)
	rotulo("CORRENDO AGORA", FONTE_PEQUENA, COR_BOM, v)
	rotulo("%s · faltam %d corrida%s" % [ev["nome"], f["restantes"], "" if f["restantes"] == 1 else "s"], 0, Color.WHITE, v)
	var dur: float = jogador.fila_ctrl.duracao_atual()
	if dur > 0.0:
		var decorrido := clampf(Aceleracao.agora(jogador) - float(f["inicio"]), 0.0, dur)
		var falta := dur * int(f["restantes"]) - decorrido
		nota("icone_cronometro", "%s por corrida · fim em %s" % [_tempo(dur), _tempo(falta)], "", v, Color.WHITE)
	var ganho := _ganho_estimado(ev, f)
	if ganho != "":
		rotulo(ganho, FONTE_PEQUENA + 2, COR_BOM, v)
	if jogador.fila_ctrl.importante(f):
		nota("icone_alerta", "Só com o app aberto", "Prova inédita, etapa de campeonato ou corrida da história: "
				+ "se você fechar o app, ela recomeça quando voltar.", v)
	else:
		nota("icone_app_fechado", "Segue com o app fechado", "A sequência continua com o app fechado, até %s."
				% _tempo(float(dados.carreira().get("teto_offline_s", 0.0))), v)
	var h := acoes(v)
	botao("Assistir", func(): ir_para.emit(CORRIDA), true, true, h, "icone_ao_vivo")
	if int(f["restantes"]) > 1:
		botao("Parar no fim desta", func():
			jogador.fila_ctrl.parar_apos_atual()
			avisar("A sequência para quando esta corrida terminar."), true, false, h)
	botao("Parar agora", func():
		jogador.fila_ctrl.cancelar()
		avisar("Sequência cancelada. A corrida em andamento não conta."), true, false, h)


## Faixa de ganho pelas posições já obtidas nesta fila (ou na última vez nesta
## prova). Estimativa, não promessa.
func _ganho_estimado(ev: Dictionary, f: Dictionary) -> String:
	var pos: Array = f.get("posicoes", [])
	if pos.is_empty() and jogador.historico.has(ev["id"]):
		pos = [jogador.historico[ev["id"]]["ultima_pos"]]
	if pos.is_empty():
		return "Ganho previsto: aparece depois da primeira corrida."
	var premios: Array = ev["premios"]
	var p := func(posicao: int) -> int: return int(premios[posicao - 1]) if posicao >= 1 and posicao <= premios.size() else 0
	var n := int(f["restantes"])
	var melhor: int = p.call(int(pos.min())) * n
	var pior: int = p.call(int(pos.max())) * n
	if melhor == pior:
		return "Ganho previsto até o fim: ≈ %s G" % dinheiro(melhor)
	return "Ganho previsto até o fim: %s a %s G (pelas posições até agora)" % [dinheiro(pior), dinheiro(melhor)]


static func _tempo(s: float) -> String:
	if s >= 3600.0:
		return "%d h %02d min" % [int(s) / 3600, (int(s) % 3600) / 60]
	if s >= 60.0:
		return "%d min %02d s" % [int(s) / 60, int(s) % 60]
	return "%d s" % int(s)


## Cartão da corrida, horizontal (vários por tela): à esquerda a imagem da
## pista com o estado e o traçado; à direita a série (ou o tipo), o título
## grande (a etapa no campeonato; o nome na prova avulsa), pista, voltas e
## regras, os pontos do campeonato, os prêmios, a competitividade e o seu
## melhor; embaixo, Disputar na largura toda.
func _cartao_evento(c: Carro, ev: Dictionary, motivos: Array) -> void:
	var pode := motivos.is_empty()
	var vitorias: int = jogador.vitorias.get(ev["id"], 0)
	var tipo := _tipo(ev)
	var tex := arte("banner_" + String(Corrida3D.TEMA_DE.get(ev["pista"], ev["pista"])))
	var v := _cartao_com_fundo(tex, pode)
	ancora("EVENT_CARD", v)
	# A prova do tutorial (etapa 1 do campeonato do prólogo): cartão, etapas,
	# competitividade e o botão, cada um com a sua âncora.
	var tutorial: bool = ev["id"] == _evento_tutorial()
	if tutorial:
		ancora("COPA", v)
	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 14)
	v.add_child(corpo)
	# Faixa da esquerda: a imagem da pista aparece mais forte (o fundo do cartão
	# é ela inteira); estado no canto de cima e o traçado embaixo dele.
	var banner := Control.new()
	banner.custom_minimum_size = Vector2(LARGURA_IMAGEM_CARTAO, ALTURA_IMAGEM_CARTAO)
	banner.size_flags_vertical = Control.SIZE_FILL
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corpo.add_child(banner)
	var estado := Label.new()
	estado.text = ("VENCIDA ×%d" % vitorias) if vitorias > 0 else ("ABERTA" if pode else "BLOQUEADA")
	Tipografia.rotulo(estado, "semibold", 18)
	estado.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	var sb_estado := StyleBoxFlat.new()
	sb_estado.bg_color = COR_BOM if vitorias > 0 else (COR_DESTAQUE if pode else COR_NEUTRA)
	sb_estado.content_margin_left = 10
	sb_estado.content_margin_right = 10
	sb_estado.content_margin_top = 2
	sb_estado.content_margin_bottom = 2
	estado.add_theme_stylebox_override("normal", sb_estado)
	estado.position = Vector2(0, 0)
	banner.add_child(estado)
	var tracado := icone_pista(ev["pista"])
	# Traçado grande no centro da faixa, abaixo do estado.
	tracado.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tracado.offset_left = 6
	tracado.offset_right = -6
	tracado.offset_top = 44
	tracado.offset_bottom = 0
	tracado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(tracado)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	corpo.add_child(col)
	# Série (ou tipo) e a etapa: no campeonato, o título é a etapa.
	var serie := Campeonatos.serie(ev)
	var etapas := Campeonatos.etapas(dados, serie)
	var k_etapa := etapas.find(ev)
	var sobre := rotulo((serie if not etapas.is_empty() else tipo[0]).to_upper(), 0, COR_SECUNDARIA, col)
	Tipografia.rotulo(sobre, "medium", 18)
	sobre.autowrap_mode = TextServer.AUTOWRAP_OFF
	sobre.clip_text = true
	sobre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var titulo := Label.new()
	titulo.text = ("ETAPA %d/%d" % [k_etapa + 1, etapas.size()]) if not etapas.is_empty() else nome_evento(ev).to_upper()
	titulo.clip_text = true
	titulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Tipografia.rotulo(titulo, "semibold", TITULO_CARTAO)
	titulo.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87) if pode else COR_SECUNDARIA)
	col.add_child(titulo)
	# O título diminui até caber (nome longo de prova avulsa).
	var livre := 720.0 - 2.0 * MARGEM_LATERAL - 32.0 - LARGURA_IMAGEM_CARTAO - 14.0
	var tam := TITULO_CARTAO
	var fonte_titulo := titulo.get_theme_font("font")
	while tam > TITULO_CARTAO_MIN and fonte_titulo.get_string_size(titulo.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > livre:
		tam -= 2
	titulo.add_theme_font_size_override("font_size", tam)
	var linha := [nome_pista(ev["pista"]), "%d volta%s" % [ev["voltas"], "" if ev["voltas"] == 1 else "s"]]
	var lic := String(ev["restricoes"].get("licenca", ""))
	if lic != "":
		linha.append("licença " + lic.capitalize())
	var sem_lic: Dictionary = ev["restricoes"].duplicate()
	sem_lic.erase("licenca")
	linha.append_array(_regras(sem_lic).slice(0, 2))
	var lp := rotulo(" · ".join(linha), FONTE_PEQUENA, Color(0.86, 0.87, 0.9), col)
	lp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if lic != "":
		ancora("LICENCA_" + lic, lp)  # tutorial: "olha a licença exigida"
	if not etapas.is_empty():
		var prog := rotulo(_progresso_curto(ev, etapas, k_etapa), FONTE_PEQUENA - 2, COR_DESTAQUE.lightened(0.2), col)
		prog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if tutorial:
			ancora("ETAPAS", prog)
	# Prêmios do 1º ao 3º, cada um com a moeda (o ícone já diz giros).
	var premios := HBoxContainer.new()
	premios.add_theme_constant_override("separation", 6)
	col.add_child(premios)
	for k in mini(3, ev["premios"].size()):
		var cel := HBoxContainer.new()
		cel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cel.add_theme_constant_override("separation", 6)
		premios.add_child(cel)
		var lp_pos := rotulo("%dº" % (k + 1), 0, COR_SECUNDARIA, cel)
		Tipografia.rotulo(lp_pos, "medium", 18)
		lp_pos.autowrap_mode = TextServer.AUTOWRAP_OFF
		lp_pos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lp_pos.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		# Valor logo depois da posição e a moeda de giros do cabeçalho depois dele.
		var lv := rotulo(dinheiro(int(ev["premios"][k])), 0, COR_DESTAQUE if pode and k == 0 else (Color.WHITE if pode else COR_SECUNDARIA), cel)
		Tipografia.numero(lv, [30, 24, 22][k])
		lv.autowrap_mode = TextServer.AUTOWRAP_OFF
		lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lv.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var moeda := icone(ICONE_GIROS, 24, cel)
		moeda.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if pode:
		var barra := _comparacao_rivais(c, ev, col)
		if tutorial and barra != null:
			ancora("COMPETITIVIDADE", barra)
	var hist: Dictionary = jogador.historico.get(ev["id"], {})
	if not hist.is_empty():
		var melhor := "SEU MELHOR  %dº" % int(hist["melhor_pos"])
		if float(hist.get("melhor_tempo", 0.0)) > 0.0:
			melhor += " · " + _tempo_curto(float(hist["melhor_tempo"]))
		Tipografia.rotulo(rotulo(melhor, 0, COR_SECUNDARIA, col), "medium", 18)
	# Recompensa especial: o carro-prêmio aparece no cartão.
	if ev.get("carro_premio") != null and vitorias == 0:
		var cp: Dictionary = dados.carro(ev["carro_premio"])
		var hp := fileira(v)
		var img := icone_carro(cp)
		img.custom_minimum_size = Vector2(120, 68)
		hp.add_child(img)
		var lpr := rotulo("CARRO DE PRÊMIO\n%s, na 1ª vitória" % cp.get("nome", ""), FONTE_PEQUENA, COR_INFO.lightened(0.3), hp)
		lpr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if pode:
		var rotulo_correr := "Disputar"
		if vitorias > 0:
			rotulo_correr = "Disputar de novo"
		var livre_fila: bool = jogador.fila.is_empty()
		var bc := Button.new()
		bc.disabled = not livre_fila
		Tipografia.acao_primaria(bc, rotulo_correr + "   →", COR_DESTAQUE, Color(0.1, 0.1, 0.1), 34, 72)
		bc.pressed.connect(func():
			_correr(ev["id"])
			mudou.emit())
		v.add_child(bc)
		if tutorial:
			ancora("DISPUTAR", bc)
	else:
		var h := fileira(v)
		nota("icone_cadeado", " · ".join(motivos), "", h, COR_RUIM)
		var pede_licenca: bool = motivos.any(func(m): return String(m).begins_with("licença"))
		var recusar := func() -> void:
			avisar("Inscrição recusada: %s." % ", ".join(motivos), false)
			var ctx := {"evento": ev["id"]}
			if not (pede_licenca and historia("LICENCA_EXIGIDA", ctx)):
				historia("EVENTO_BLOQUEADO", ctx)
		botao_texto("Inscrever", recusar, v)


## Cartão com a imagem da pista atrás dele todo (escala uniforme, recortada):
## mais visível à esquerda, coberta por um véu que escurece para a direita,
## onde ficam os textos. Retorna a coluna do conteúdo (margem de 16).
func _cartao_com_fundo(tex: Texture2D, aceso: bool) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_CARTAO
	sb.set_corner_radius_all(14)
	p.add_theme_stylebox_override("panel", sb)
	p.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW  # cantos arredondados na imagem
	conteudo.add_child(p)
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not aceso:
			t.modulate = Color(0.6, 0.6, 0.62)
		p.add_child(t)
		var veu := TextureRect.new()
		var grad := GradientTexture2D.new()
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 0.45, 1.0])
		g.colors = PackedColorArray([Color(COR_CARTAO, VEU_CARTAO[0]), Color(COR_CARTAO, VEU_CARTAO[0]),
				Color(COR_CARTAO, VEU_CARTAO[1]), Color(COR_CARTAO, VEU_CARTAO[2])])
		grad.gradient = g
		grad.fill_from = Vector2(0, 0)
		grad.fill_to = Vector2(1, 0)
		veu.texture = grad
		veu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		veu.stretch_mode = TextureRect.STRETCH_SCALE  # degradê: esticar é o próprio desenho, não uma imagem
		veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(veu)
	var m := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + lado, 16)
	p.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	return v


## "1º: 10 pts · você: 2º, 18 pts" na etapa que vale; nas outras, qual vale.
func _progresso_curto(ev: Dictionary, etapas: Array, k: int) -> String:
	var est := Campeonatos.estado(jogador, Campeonatos.serie(ev))
	var t := "1º: %d pts" % Campeonatos.pontos(ev, 1)
	if int(est["etapa"]) > 0:
		var tab := Campeonatos.tabela(est)
		var i: int = tab.map(func(x): return x[0]).find("jogador")
		t += " · você: %dº, %d pts" % [i + 1, int(est["pontos"].get("jogador", 0))]
	if k != int(est["etapa"]):
		t += " · pontos: corra a etapa %d" % (int(est["etapa"]) + 1)
	return t


## "1:42,3" (min:s,décimo) ou "42,3 s".
static func _tempo_curto(s: float) -> String:
	var d := roundi(s * 10.0)
	if d >= 600:
		return "%d:%02d,%d" % [d / 600, (d / 10) % 60, d % 10]
	return "%d,%d s" % [d / 10, d % 10]


## Seu carro x rivais (potência por peso, frente à mediana dos rivais): barra
## de três faixas com o marcador e a palavra (mais fraco, parelho, mais forte).
func _comparacao_rivais(c: Carro, ev: Dictionary, pai: Control) -> Control:
	var r := _razao_rivais(c, ev)
	if r < 0.0:
		return null
	var nivel := 0 if r < 0.95 else (1 if r < 1.08 else 2)
	# Tons sóbrios (a faixa do nível fica mais viva; as outras, apagadas).
	var tons := [Color(0.42, 0.33, 0.31), Color(0.66, 0.62, 0.5), Color(0.33, 0.47, 0.4)]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	pai.add_child(v)
	var topo := HBoxContainer.new()
	v.add_child(topo)
	var t := rotulo("SEU CARRO", 0, COR_SECUNDARIA, topo)
	Tipografia.rotulo(t, "medium", 18)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	var n := rotulo(["MAIS FRACO", "PARELHO", "MAIS FORTE"][nivel], 0, tons[nivel].lightened(0.35), topo)
	Tipografia.rotulo(n, "semibold", 20)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var barra_c := Control.new()
	barra_c.custom_minimum_size = Vector2(150, 22)
	barra_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var f := clampf((r - 0.8) / 0.4, 0.0, 1.0)
	barra_c.draw.connect(func():
		var w := barra_c.size.x
		var y := barra_c.size.y * 0.5 - 4
		for k in 3:
			barra_c.draw_rect(Rect2(w * k / 3.0 + (0 if k == 0 else 3), y, w / 3.0 - 3, 8),
					Color(tons[k], 1.0 if k == nivel else 0.55))
		barra_c.draw_rect(Rect2(w * f - 1.5, y - 7, 3, 22), Color.WHITE))
	v.add_child(barra_c)
	return v


## Prova do tutorial de eventos: a etapa 1 do campeonato do prólogo (Adrian).
func _evento_tutorial() -> String:
	if jogador.personagem != "adrian":
		return ""
	var etapas := Campeonatos.etapas(dados, String(dados.historia().get("adrian", {}).get("campeonato", "")))
	return String(etapas[0]["id"]) if not etapas.is_empty() else ""


## Tipo da série pelo que ela exige: [nome, cor de identidade].
func _tipo(ev: Dictionary) -> Array:
	var r: Dictionary = ev["restricoes"]
	if r.has("carros"):
		return ["Copa de marca" + (" · corrida" if r.get("corrida", false) else ""), Color(0.85, 0.45, 0.2)]
	if r.has("tracao"):
		var t: String = r["tracao"][0]
		return [{"FF": "Tração dianteira", "FR": "Tração traseira", "4WD": "Tração 4x4", "MR": "Motor central"}.get(t, "Tração " + t),
				{"FF": Color(0.25, 0.6, 0.9), "FR": Color(0.9, 0.35, 0.3), "4WD": Color(0.85, 0.65, 0.2), "MR": Color(0.7, 0.4, 0.9)}.get(t, COR_INFO)]
	if r.has("ano_max"):
		return ["Clássicos", Color(0.8, 0.55, 0.3)]
	if r.has("potencia_max") and float(r["potencia_max"]) <= 200.0:
		return ["Potência limitada", Color(0.35, 0.75, 0.5)]
	if r.has("potencia_max"):
		return ["Até %d cv" % r["potencia_max"], Color(0.3, 0.7, 0.75)]
	return ["Aberta", Color(0.75, 0.75, 0.8)]


## Potência/peso do carro em uso dividida pela mediana dos rivais da prova
## (atributos efetivos, com peças e pneus); -1 sem rivais. Leitura rápida, não
## dificuldade: pneus, curvas e frenagem também contam, e para isso há "Prever
## minha posição". Limites (+8% / −5%) provisórios.
func _razao_rivais(c: Carro, ev: Dictionary) -> float:
	var meu := c.atributos_efetivos(ev["condicao"])
	var rivais := []
	for i in ev["adversarios"].size():
		var a: Dictionary = jogador.carreira.atributos_participante(ev["id"], "adv%d_%s" % [i, ev["adversarios"][i]["carro"]], c.uid)
		if not a.is_empty():
			rivais.append(a["potencia"] / maxf(a["peso"], 1.0))
	if rivais.is_empty():
		return -1.0
	rivais.sort()
	return (meu["potencia"] / maxf(meu["peso"], 1.0)) / maxf(rivais[rivais.size() / 2], 1e-6)


## Chave da estimativa: muda se o carro, as peças ou os pneus mudarem.
static func _chave(ev: Dictionary, c: Carro) -> String:
	return "%s|%d|%s|%s" % [ev["id"], c.uid, str(c.configuracao()), str(c.pneus.map(func(p): return p["id"]))]


## Simula a prova com o carro em uso (Mecanico.avaliar, mesmas sementes do
## "O que ajuda?") e mostra a faixa típica de posições. Sob demanda: a lista
## abre rápido e só calcula o que o jogador pedir.
func _estimar(ev: Dictionary, c: Carro) -> void:
	var chave := _chave(ev, c)
	_estimativas[chave] = "..."
	await get_tree().process_frame
	await get_tree().process_frame
	var a := Mecanico.avaliar(jogador.carreira, ev["id"], c.uid, c)
	if a.is_empty():
		_estimativas.erase(chave)
	else:
		_estimativas[chave] = a["faixa"]
	mudou.emit()


## Regras da prova em texto curto ("até 150 cv", "tração FF").
func _regras(r: Dictionary) -> Array:
	var t := []
	if r.has("carros"):
		var modelos: Array = r["carros"].map(func(x): return nome_curto(dados.item("carros", x).get("nome", x)))
		t.append(", ".join(modelos.slice(0, 2)) + (" +%d" % (modelos.size() - 2) if modelos.size() > 2 else ""))
	if r.has("corrida"):
		t.append("versão de corrida" if r["corrida"] else "carro de rua")
	if r.has("potencia_max"):
		t.append("até %d cv" % r["potencia_max"])
	if r.has("tracao"):
		t.append(" / ".join(r["tracao"].map(func(x): return NOMES_TRACAO_CURTO.get(x, x))))
	if r.has("categoria"):
		t.append("/".join(r["categoria"].map(func(x): return NOMES_CATEGORIA_CARRO.get(x, x))))
	if r.has("fabricante"):
		t.append("/".join(r["fabricante"].map(func(x): return dados.item("fabricantes", x).get("nome", x))))
	if r.has("ano_min"):
		t.append("carros de %d em diante" % r["ano_min"])
	if r.has("ano_max"):
		t.append("carros até %d" % r["ano_max"])
	if r.has("licenca"):
		t.append("licença " + r["licenca"])
	return t


## Prova vencida: renda automática (repete). Ainda não vencida: desafio,
## uma inscrição. A fila guarda a preparação escolhida.
func _correr(evento_id: String) -> void:
	# História: a primeira inscrição pode virar tutorial (ex.: freio antes da prova).
	var ctx := {"evento": evento_id}
	if historia("EVENTO_SELECIONADO", ctx):
		return
	var ev: Dictionary = dados.evento(evento_id)
	var etapas := Campeonatos.etapas(dados, Campeonatos.serie(ev))
	if not etapas.is_empty() and etapas.find(ev) == int(Campeonatos.estado(jogador, Campeonatos.serie(ev))["etapa"]):
		historia("CAMPEONATO_SELECIONADO", ctx)
	var garagem := carro_ativo()
	var n := 1
	var cfg: Dictionary = {} if _config < 0 or garagem == null else garagem.configuracoes[_config]
	var motivo: String = jogador.fila_ctrl.iniciar(evento_id, jogador.carro_ativo, n, Aceleracao.agora(jogador), cfg)
	if motivo != "":
		avisar("Não deu para correr: %s." % motivo, false)
		return
	correr_iniciado.emit()
	if Prologo.deve_ultima_corrida(dados, jogador):
		historia("ULTIMA_CORRIDA_ADRIAN", ctx)
	historia("CORRIDA_INICIO", ctx)
	if dados.evento(evento_id)["restricoes"].get("licenca", "") == "ELITE":
		historia("CORRIDA_RESISTENCIA")
	for g in jogador.carreira.escalacao(evento_id, int(jogador.fila.get("semente", -1))):
		historia("CORRIDA_CONTRA:" + String(g["piloto"]["id"]))
