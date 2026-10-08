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
	cabecalho("Correr", "Vença para ganhar créditos", "fundo_competicoes")
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
	else:
		_repeticoes_ui()
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
			mudou.emit())
		abas.add_child(b)
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
	for l in lista:
		_cartao_evento(c, l[0], l[1])


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
		var decorrido := clampf(Time.get_unix_time_from_system() - float(f["inicio"]), 0.0, dur)
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
		return "Ganho previsto até o fim: ≈ %s Cr" % dinheiro(melhor)
	return "Ganho previsto até o fim: %s a %s Cr (pelas posições até agora)" % [dinheiro(pior), dinheiro(melhor)]


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
			+ "vezes seguidas correr. Rende créditos, até com o app fechado.", t)
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
## nome por cima, emblema do campeonato, traçado, prêmio com troféu, a barra
## "seu carro x rivais" e a ação.
func _cartao_evento(c: Carro, ev: Dictionary, motivos: Array) -> void:
	var pode := motivos.is_empty()
	var vitorias: int = jogador.vitorias.get(ev["id"], 0)
	var tipo := _tipo(ev)
	var v := cartao(tipo[1])
	ancora("EVENT_CARD", v)
	var faixa := fileira(v)
	var t := rotulo(("VENCIDA ×%d" % vitorias) if vitorias > 0 else ("ABERTA" if pode else "BLOQUEADA"), FONTE_PEQUENA,
			COR_BOM if vitorias > 0 else (tipo[1].lightened(0.35) if pode else COR_SECUNDARIA), faixa)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var prog := rotulo(_progresso(ev), FONTE_PEQUENA, COR_SECUNDARIA, faixa)
	prog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	var emb := _emblema(ev)
	if emb != "":
		icone(emb, 74, sobre)
	var nomes := VBoxContainer.new()
	nomes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nomes.add_theme_constant_override("separation", -2)
	sobre.add_child(nomes)
	var nl := rotulo(ev["nome"], 30, Color.WHITE, nomes)
	nl.add_theme_constant_override("outline_size", 6)
	nl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	var lp := rotulo("%s · %d volta%s · %s" % [nome_pista(ev["pista"]), ev["voltas"], "" if ev["voltas"] == 1 else "s", tipo[0]],
			FONTE_PEQUENA, Color(0.9, 0.91, 0.94), nomes)
	lp.add_theme_constant_override("outline_size", 5)
	lp.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	# Traçado e prêmio.
	var topo := fileira(v)
	var fundo := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.25)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)
	fundo.add_theme_stylebox_override("panel", sb)
	var ic := icone_pista(ev["pista"])
	ic.custom_minimum_size = Vector2(120, 80)
	fundo.add_child(ic)
	fundo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(fundo)
	var premio: int = int(ev["premios"][0]) if not ev["premios"].is_empty() else 0
	var caixa_premio := HBoxContainer.new()
	caixa_premio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa_premio.alignment = BoxContainer.ALIGNMENT_END
	topo.add_child(caixa_premio)
	icone("icone_trofeu_ouro", 56, caixa_premio)
	var vp := VBoxContainer.new()
	vp.add_theme_constant_override("separation", -4)
	caixa_premio.add_child(vp)
	var l1 := rotulo("1º lugar", FONTE_PEQUENA, COR_SECUNDARIA, vp)
	l1.autowrap_mode = TextServer.AUTOWRAP_OFF
	var l2 := rotulo("%s Cr" % dinheiro(premio), 34, COR_DESTAQUE if pode else COR_SECUNDARIA, vp)
	l2.autowrap_mode = TextServer.AUTOWRAP_OFF
	var etiquetas := []
	for r in _regras(ev["restricoes"]).slice(0, 3):
		etiquetas.append([r, COR_NEUTRA.lightened(0.3)])
	if not etiquetas.is_empty():
		selos(etiquetas, v)
	if pode:
		_comparacao_rivais(c, ev, v)
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
		var est = _estimativas.get(_chave(ev, c))
		if est == null:
			botao_texto("Prever minha posição", _estimar.bind(ev, c), col)
		elif est is String:
			rotulo("Prevendo…", FONTE_PEQUENA, COR_INFO, col)
		else:
			nota("icone_prever", "Previsão: %s" % Mecanico.texto_faixa(est), "%d corridas simuladas com a montagem atual."
					% Mecanico.amostras_para(ev), col, COR_INFO)
		var rotulo_correr := "Correr"
		if vitorias > 0:
			rotulo_correr = "Correr de novo" if _repeticoes == 1 else "Correr de novo ×%d" % _repeticoes
		var bc := botao(rotulo_correr, _correr.bind(ev["id"]), jogador.fila.is_empty(), true, h, "icone_correr")
		bc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		botao_texto("Comparar montagens", func(): testar_preparacao(ev["id"], carro_ativo()), v)
	else:
		nota("icone_cadeado", " · ".join(motivos), "", h, COR_RUIM)
		var pede_licenca: bool = motivos.any(func(m): return String(m).begins_with("licença"))
		var recusar := func() -> void:
			avisar("Inscrição recusada: %s." % ", ".join(motivos), false)
			if not (pede_licenca and historia("LICENCA_EXIGIDA")):
				historia("EVENTO_BLOQUEADO")
		botao_texto("Inscrever", recusar, v)


## Emblema do campeonato pela família do nome (o nome vai escrito ao lado).
static func _emblema(ev: Dictionary) -> String:
	var n := String(ev["nome"])
	for par in [["Copa", "emblema_copa"], ["Desafio", "emblema_desafio"], ["Liga", "emblema_liga"],
			["Série", "emblema_serie"], ["Troféu", "emblema_trofeu"]]:
		if n.begins_with(par[0]):
			return par[1]
	return ""


## Seu carro x rivais (potência por peso, frente à mediana dos rivais): barra
## de três faixas com o marcador e a palavra (mais fraco, parelho, mais forte).
func _comparacao_rivais(c: Carro, ev: Dictionary, pai: Control) -> void:
	var r := _razao_rivais(c, ev)
	if r < 0.0:
		return
	var nivel := 0 if r < 0.95 else (1 if r < 1.08 else 2)
	var cor: Color = [COR_RUIM, COR_INFO, COR_BOM][nivel]
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(cor, 0.12)
	sb.border_color = Color(cor, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	pai.add_child(p)
	var h := HBoxContainer.new()
	p.add_child(h)
	var l := rotulo("Seu carro x rivais", FONTE_PEQUENA, cor.lightened(0.3), h)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var barra_c := Control.new()
	barra_c.custom_minimum_size = Vector2(150, 30)
	barra_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var f := clampf((r - 0.8) / 0.4, 0.0, 1.0)
	barra_c.draw.connect(func():
		var w := barra_c.size.x
		var y := barra_c.size.y * 0.5 - 6
		for k in 3:
			barra_c.draw_rect(Rect2(w * k / 3.0 + 2, y, w / 3.0 - 4, 12), Color([COR_RUIM, COR_INFO, COR_BOM][k], 0.25 if k != nivel else 0.9))
		barra_c.draw_rect(Rect2(w * f - 2, y - 6, 4, 24), Color.WHITE))
	h.add_child(barra_c)
	var n := rotulo(["Mais fraco", "Parelho", "Mais forte"][nivel], FONTE_PEQUENA, cor.lightened(0.3), h)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.size_flags_horizontal = Control.SIZE_SHRINK_END


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
	if historia("EVENTO_SELECIONADO"):
		return
	var ev: Dictionary = dados.evento(evento_id)
	var etapas := Campeonatos.etapas(dados, Campeonatos.serie(ev))
	if not etapas.is_empty() and etapas.find(ev) == int(Campeonatos.estado(jogador, Campeonatos.serie(ev))["etapa"]):
		historia("CAMPEONATO_SELECIONADO")
	var garagem := carro_ativo()
	var n := _repeticoes if jogador.vitorias.has(evento_id) else 1
	var cfg: Dictionary = {} if _config < 0 or garagem == null else garagem.configuracoes[_config]
	var motivo: String = jogador.fila_ctrl.iniciar(evento_id, jogador.carro_ativo, n, Time.get_unix_time_from_system(), cfg)
	if motivo != "":
		avisar("Não deu para correr: %s." % motivo, false)
		return
	avisar("%s %s%s." % ["Largada!" if n > 1 or jogador.vitorias.has(evento_id) else "Largada:",
			dados.evento(evento_id)["nome"], "" if n == 1 else " ×%d" % n])
	correr_iniciado.emit()
	if Prologo.deve_ultima_corrida(dados, jogador):
		historia("ULTIMA_CORRIDA_ADRIAN")
	historia("CORRIDA_INICIO")
	if dados.evento(evento_id)["restricoes"].get("licenca", "") == "ELITE":
		historia("CORRIDA_RESISTENCIA")
	for g in jogador.carreira.escalacao(evento_id, int(jogador.fila.get("semente", -1))):
		historia("CORRIDA_CONTRA:" + String(g["piloto"]["id"]))
