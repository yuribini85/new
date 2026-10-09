extends Aba

signal correr_iniciado

var _repeticoes := 1
## Preparação para a inscrição: -1 = a atual do carro; senão índice em
## Carro.configuracoes. A fila guarda uma cópia dela.
var _config := -1
var _config_uid := -1
## Estimativas simuladas sob demanda: chave (prova + carro + peças) -> faixa,
## ou "..." enquanto calcula.
var _estimativas := {}
## Categoria aberta (mantida ao voltar): "voce", "", "marca" ou o id da licença.
var _filtro := "voce"
## Cartões mostrados de uma vez (cada um custa ~10 ms para montar; a lista toda
## travava a troca de tela). "Mostrar mais" acrescenta outro lote.
const LOTE := 12
var _limite := LOTE

const GRUPOS := [["voce", "Para você"], ["", "Sem licença"], ["marca", "Marcas"], ["CLUB", "Club"], ["SPORT", "Sport"],
	["NATIONAL", "National"], ["INTERNATIONAL", "International"], ["PRO", "Pro"], ["ELITE", "Elite"]]
const NIVEIS_LICENCA := ["CLUB", "SPORT", "NATIONAL", "INTERNATIONAL", "PRO", "ELITE"]
## Cor de fundo da imagem da pista (o tema dela na corrida).
const FUNDO_PISTA := {"anel_do_vale": Color(0.16, 0.3, 0.18), "parque_das_docas": Color(0.22, 0.24, 0.28),
		"serra_alta": Color(0.26, 0.25, 0.17), "pista_de_testes": Color(0.36, 0.3, 0.22),
		"circuito_misto": Color(0.3, 0.28, 0.16)}


func _init(d: Node, j: Node) -> void:
	super(d, j, "Correr")


func construir() -> void:
	cabecalho("Correr", "Vença para ganhar giros", "fundo_competicoes")
	var garagem := carro_ativo()
	if garagem == null:
		proximo_passo("Você precisa de um carro para correr.", "Ir para o Mercado", LOJA)
		return
	if _config_uid != garagem.uid or _config >= garagem.configuracoes.size():
		_config = -1
		_config_uid = garagem.uid
	# Daqui em diante, o carro com a preparação escolhida para a inscrição.
	var c := garagem if _config < 0 else garagem.com_configuracao(garagem.configuracoes[_config], dados.peca)
	_carro_em_uso(garagem, c)
	if not jogador.fila.is_empty():
		_fila()
	elif not jogador.vitorias.is_empty():
		_repeticoes_ui()  # só faz sentido depois da primeira vitória
	# Filtros numa linha só, que rola de lado (em várias linhas ocupavam meia tela).
	var faixa := ScrollContainer.new()
	faixa.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	faixa.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	faixa.scroll_deadzone = 100000  # o arrasto é o da aba (Aba._input)
	faixa.custom_minimum_size = Vector2(0, 64)
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 8)
	faixa.add_child(abas)
	for g in GRUPOS:
		var travada: bool = g[0] in NIVEIS_LICENCA and not g[0] in jogador.licencas
		var b := Button.new()
		b.text = g[1]
		b.toggle_mode = true
		b.button_pressed = _filtro == g[0]
		b.custom_minimum_size = Vector2(0, 60)
		b.add_theme_font_size_override("font_size", 25)
		if travada:
			b.add_theme_color_override("font_color", COR_SECUNDARIA)
		b.pressed.connect(func():
			_filtro = g[0]
			_limite = LOTE
			mudou.emit())
		abas.add_child(b)
		if g[0] in NIVEIS_LICENCA:
			ancora("LICENCA_" + g[0], b)
	conteudo.add_child(faixa)
	var lista := []
	for ev in dados.lista("eventos"):
		var motivos := Elegibilidade.motivos(c, ev["restricoes"], jogador.licencas)
		if _filtro == "voce":
			if motivos.is_empty() and not ev["premios"].is_empty():
				lista.append([ev, motivos])
		elif _grupo_evento(ev) == _filtro:
			lista.append([ev, motivos])
	if _filtro == "voce":
		# Ainda não vencidas primeiro, da de prêmio menor (rivais mais fracos).
		lista.sort_custom(func(a, b):
			var va: bool = jogador.vitorias.has(a[0]["id"])
			var vb: bool = jogador.vitorias.has(b[0]["id"])
			if va != vb:
				return not va
			return a[0]["premios"][0] < b[0]["premios"][0])
	else:
		lista.sort_custom(func(a, b):
			if a[1].is_empty() != b[1].is_empty():
				return a[1].is_empty()
			return a[0]["nome"] < b[0]["nome"])
	if _filtro in NIVEIS_LICENCA and not _filtro in jogador.licencas:
		var v := cartao(COR_INFO)
		nota("icone_cadeado", "Precisa da licença %s" % _filtro, "Os testes da licença ficam em Carreira.", v, Color.WHITE)
		botao("Ver licenças", func(): ir_para.emit(LICENCAS), true, false, v)
	if lista.is_empty():
		nota("icone_alerta", "Nenhuma aceita o %s" % nome_curto(c.base["nome"]),
				"Veja as outras categorias ou troque de carro na Garagem.")
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


## Carro em uso numa linha: foto, nome e números; trocar leva à Garagem.
func _carro_em_uso(garagem: Carro, c: Carro) -> void:
	var h := fileira()
	var img := icone_carro(c.base, false, CarroBloco.cor_do_carro(garagem))
	img.custom_minimum_size = Vector2(130, 72)
	h.add_child(img)
	var a := c.atributos_efetivos("seco")
	var l := rotulo("%s\n%d cv · %d kg · %s" % [c.base["nome"], a["potencia"], a["peso"],
			NOMES_TRACAO_CURTO.get(c.base["tracao"], c.base["tracao"])],
			FONTE_PEQUENA + 2, Color.WHITE, h)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b := botao_texto("Trocar de carro", func(): ir_para.emit(GARAGEM), h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if garagem.configuracoes.is_empty():
		return
	var hp := fileira()
	rotulo("Montagem", FONTE_PEQUENA + 2, COR_SECUNDARIA, hp).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.custom_minimum_size = Vector2(0, 60)
	o.add_item("Como está agora na Oficina")
	for cfg in garagem.configuracoes:
		o.add_item(cfg["nome"])
	o.select(_config + 1)
	o.item_selected.connect(func(i):
		_config = i - 1
		mudou.emit())
	hp.add_child(o)


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


func _repeticoes_ui() -> void:
	var v := cartao()
	var t := fileira(v)
	nota("icone_de_novo", "Vencidas: correr quantas vezes?", "Nas corridas que você já venceu, escolha quantas "
			+ "vezes seguidas correr. Rende giros, até com o app fechado.", t)
	var h := fileira(v)
	botao("−", func(): _repeticoes = maxi(1, _repeticoes - 1), _repeticoes > 1, false, h).custom_minimum_size = Vector2(80, 60)
	var n := Label.new()
	n.text = "×%d" % _repeticoes
	n.add_theme_font_size_override("font_size", 32)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(n)
	botao("+", func(): _repeticoes = mini(999, _repeticoes + 1), true, false, h).custom_minimum_size = Vector2(80, 60)
	botao("×10", func(): _repeticoes = mini(999, _repeticoes * 10), true, false, h).custom_minimum_size = Vector2(90, 60)


## Cartão da corrida (referência ui_competicoes.webp): banner da pista com o
## nome por cima e o traçado no canto, os prêmios do 1º
## ao 3º com a moeda, a barra "seu carro x rivais" e o botão Correr na largura
## toda.
func _cartao_evento(c: Carro, ev: Dictionary, motivos: Array) -> void:
	var pode := motivos.is_empty()
	var vitorias: int = jogador.vitorias.get(ev["id"], 0)
	var tipo := _tipo(ev)
	var v := cartao(tipo[1])
	ancora("EVENT_CARD", v)
	# A prova do tutorial (etapa 1 do campeonato do prólogo): cartão, etapas,
	# competitividade e o botão, cada um com a sua âncora.
	var tutorial: bool = ev["id"] == _evento_tutorial()
	if tutorial:
		ancora("COPA", v)
	var faixa := fileira(v)
	var t := rotulo(("VENCIDA ×%d" % vitorias) if vitorias > 0 else ("ABERTA" if pode else "BLOQUEADA"), FONTE_PEQUENA,
			COR_BOM if vitorias > 0 else (tipo[1].lightened(0.35) if pode else COR_SECUNDARIA), faixa)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var prog := rotulo(_progresso(ev), FONTE_PEQUENA, COR_SECUNDARIA, faixa)
	prog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if tutorial:
		ancora("ETAPAS", prog)
	# Banner da pista com o nome e o lugar por cima.
	var banner := ilustracao("banner_" + String(Corrida3D.TEMA_DE.get(ev["pista"], ev["pista"])), 190, v, 0.85)
	if not pode:
		banner.modulate = Color(0.6, 0.6, 0.62)
	var sobre := HBoxContainer.new()
	sobre.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sobre.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sobre.offset_left = 12
	sobre.offset_right = -12
	sobre.offset_bottom = -10
	banner.add_child(sobre)
	# Traçado no canto de cima, à direita, sobre a ilustração.
	var tracado := icone_pista(ev["pista"])
	tracado.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tracado.offset_left = -130
	tracado.offset_right = -18
	tracado.offset_top = 18
	tracado.offset_bottom = 96
	tracado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(tracado)
	var nomes := VBoxContainer.new()
	nomes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nomes.add_theme_constant_override("separation", -2)
	sobre.add_child(nomes)
	var nl := rotulo(nome_evento(ev), 30, Color.WHITE, nomes)
	nl.add_theme_constant_override("outline_size", 6)
	nl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	var lp := rotulo("%s · %d volta%s · %s" % [nome_pista(ev["pista"]), ev["voltas"], "" if ev["voltas"] == 1 else "s", tipo[0]],
			FONTE_PEQUENA, Color(0.9, 0.91, 0.94), nomes)
	lp.add_theme_constant_override("outline_size", 5)
	lp.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	# Prêmios do 1º ao 3º, cada um com a moeda (o ícone já diz G).
	var premios := HBoxContainer.new()
	premios.add_theme_constant_override("separation", 10)
	v.add_child(premios)
	for k in mini(3, ev["premios"].size()):
		var cel := HBoxContainer.new()
		cel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cel.alignment = BoxContainer.ALIGNMENT_CENTER
		cel.add_theme_constant_override("separation", 6)
		premios.add_child(cel)
		var lp_pos := rotulo("%dº" % (k + 1), 0, COR_SECUNDARIA, cel)
		Tipografia.rotulo(lp_pos, "medium", 24)
		lp_pos.autowrap_mode = TextServer.AUTOWRAP_OFF
		lp_pos.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# Valor e, depois dele, a moeda (como o saldo no topo); 1º > 2º > 3º.
		var lv := rotulo(dinheiro(int(ev["premios"][k])), 0, COR_DESTAQUE if pode and k == 0 else (Color.WHITE if pode else COR_SECUNDARIA), cel)
		Tipografia.numero(lv, [46, 34, 28][k])
		lv.autowrap_mode = TextServer.AUTOWRAP_OFF
		lv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var moeda := icone("icone_creditos", [38, 30, 24][k], cel)
		moeda.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var etiquetas := []
	for r in _regras(ev["restricoes"]).slice(0, 3):
		etiquetas.append([r, COR_NEUTRA.lightened(0.3)])
	if not etiquetas.is_empty():
		selos(etiquetas, v)
	if pode:
		var barra := _comparacao_rivais(c, ev, v)
		if tutorial and barra != null:
			ancora("COMPETITIVIDADE", barra)
	# Recompensa especial: o carro-prêmio aparece no cartão.
	if ev.get("carro_premio") != null and vitorias == 0:
		var cp: Dictionary = dados.carro(ev["carro_premio"])
		var hp := fileira(v)
		var img := icone_carro(cp)
		img.custom_minimum_size = Vector2(150, 84)
		hp.add_child(img)
		var lpr := rotulo("CARRO DE PRÊMIO\n%s, na 1ª vitória" % cp.get("nome", ""), FONTE_PEQUENA, COR_INFO.lightened(0.3), hp)
		lpr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := fileira(v)
	if pode:
		var hist: Dictionary = jogador.historico.get(ev["id"], {})
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		h.add_child(col)
		if not hist.is_empty():
			var hm := fileira(col)
			icone("icone_cronometro", 34, hm)
			rotulo("Seu melhor: %dº" % hist["melhor_pos"], FONTE_PEQUENA, COR_SECUNDARIA, hm)
		var rotulo_correr := "Disputar"
		if vitorias > 0:
			rotulo_correr = "Disputar de novo" if _repeticoes == 1 else "Disputar de novo ×%d" % _repeticoes
		# Disputar: a roda em chamas grande, fora do retângulo, e o botão com
		# contorno e texto na cor de destaque ao lado. Tocar em qualquer um dos
		# dois inscreve.
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 14)
		v.add_child(linha)
		var livre: bool = jogador.fila.is_empty()
		var inscrever := func():
			_correr(ev["id"])
			mudou.emit()
		var roda := TextureButton.new()
		roda.texture_normal = icone_reduzido("icone_correr", 256)
		roda.ignore_texture_size = true
		roda.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		roda.custom_minimum_size = Vector2(260, 220)
		roda.disabled = not livre
		roda.modulate.a = 1.0 if livre else 0.4
		roda.pressed.connect(inscrever)
		linha.add_child(roda)
		var bc := Button.new()
		bc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bc.custom_minimum_size.y = 96
		bc.disabled = not livre
		bc.text = rotulo_correr.to_upper()
		Tipografia.rotulo(bc, "semibold", 44 if rotulo_correr.length() <= 10 else 34)
		for k_cor in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			bc.add_theme_color_override(k_cor, COR_DESTAQUE)
		bc.add_theme_color_override("font_disabled_color", Color(COR_DESTAQUE, 0.4))
		var base := StyleBoxFlat.new()
		base.bg_color = Color(COR_DESTAQUE, 0.08)
		base.border_color = COR_DESTAQUE
		base.set_border_width_all(2)
		base.set_corner_radius_all(Tipografia.RAIO)
		var apertado := base.duplicate()
		apertado.bg_color = Color(COR_DESTAQUE, 0.25)
		var parado := base.duplicate()
		parado.border_color = Color(COR_DESTAQUE, 0.3)
		parado.bg_color = Color(0, 0, 0, 0)
		for estado in ["normal", "hover", "focus"]:
			bc.add_theme_stylebox_override(estado, base)
		bc.add_theme_stylebox_override("pressed", apertado)
		bc.add_theme_stylebox_override("disabled", parado)
		bc.pressed.connect(inscrever)
		linha.add_child(bc)
		if tutorial:
			ancora("DISPUTAR", bc)
	else:
		nota("icone_cadeado", " · ".join(motivos), "", h, COR_RUIM)
		var pede_licenca: bool = motivos.any(func(m): return String(m).begins_with("licença"))
		var recusar := func() -> void:
			avisar("Inscrição recusada: %s." % ", ".join(motivos), false)
			var ctx := {"evento": ev["id"]}
			if not (pede_licenca and historia("LICENCA_EXIGIDA", ctx)):
				historia("EVENTO_BLOQUEADO", ctx)
		botao_texto("Inscrever", recusar, v)


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
	v.add_theme_constant_override("separation", 6)
	pai.add_child(v)
	var topo := HBoxContainer.new()
	v.add_child(topo)
	var t := rotulo("COMPETITIVIDADE", 0, COR_SECUNDARIA, topo)
	Tipografia.rotulo(t, "medium", 20)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	var n := rotulo(["MAIS FRACO", "PARELHO", "MAIS FORTE"][nivel], 0, tons[nivel].lightened(0.35), topo)
	Tipografia.rotulo(n, "semibold", 22)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var barra_c := Control.new()
	barra_c.custom_minimum_size = Vector2(150, 26)
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
	var base := HBoxContainer.new()
	v.add_child(base)
	for k in 3:
		var l := rotulo(["Inferior", "Equilibrado", "Superior"][k], 0, COR_SECUNDARIA, base)
		Tipografia.rotulo(l, "regular", 20)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][k]
	return v


## Prova do tutorial de eventos: a etapa 1 do campeonato do prólogo (Adrian).
func _evento_tutorial() -> String:
	if jogador.personagem != "adrian":
		return ""
	var etapas := Campeonatos.etapas(dados, String(dados.historia().get("adrian", {}).get("campeonato", "")))
	return String(etapas[0]["id"]) if not etapas.is_empty() else ""


## "Etapa 2 de 3 · campeonato: 18 pts, 2º · vale pontos": onde esta prova fica
## na série e na temporada do campeonato (Campeonatos).
func _progresso(ev: Dictionary) -> String:
	var serie := Campeonatos.serie(ev)
	var etapas := Campeonatos.etapas(dados, serie)
	if etapas.is_empty():
		return ""
	var k := etapas.find(ev)
	var est := Campeonatos.estado(jogador, serie)
	var t := "Etapa %d de %d" % [k + 1, etapas.size()]
	if int(est["etapa"]) > 0:
		var tab := Campeonatos.tabela(est)
		var i: int = tab.map(func(x): return x[0]).find("jogador")
		t += " · campeonato: %d pts, %dº" % [int(est["pontos"].get("jogador", 0)), i + 1]
	t += " · vale pontos" if k == int(est["etapa"]) else " · pontos: corra a etapa %d" % (int(est["etapa"]) + 1)
	return t


## Grupo da lista: copas de marca à parte; o resto pela licença exigida.
static func _grupo_evento(ev: Dictionary) -> String:
	return "marca" if ev["restricoes"].has("carros") else ev["restricoes"].get("licenca", "")


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
	var n := _repeticoes if jogador.vitorias.has(evento_id) else 1
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
