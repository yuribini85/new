extends Aba

signal correr_iniciado

## Estimativas simuladas sob demanda: chave (prova + carro + peças) -> faixa,
## ou "..." enquanto calcula.
var _estimativas := {}
## Filtro aberto (mantido ao voltar): "nao_vencidas" ou "todas".
var _filtro := "nao_vencidas"
## Cartões mostrados de uma vez (cada um custa ~10 ms para montar; a lista toda
## travava a troca de tela). "Mostrar mais" acrescenta outro lote.
const LOTE := 12
## Cartão horizontal da corrida: imagem da pista à esquerda e o título.
const LARGURA_IMAGEM_CARTAO := 210.0
const ALTURA_IMAGEM_CARTAO := 200.0
const TITULO_CARTAO := 40
const TITULO_CARTAO_MIN := 26
## Selo da licença exigida, no canto do cartão (px).
const SELO_CARTAO := 84.0
var _limite := LOTE

const FILTROS := [["nao_vencidas", "NÃO VENCIDAS"], ["todas", "TODAS AS CORRIDAS"]]
## Altura do topo (cenário com o carro atual).
## Cor de fundo da imagem da pista (o tema dela na corrida).
const FUNDO_PISTA := {"anel_do_vale": Color(0.16, 0.3, 0.18), "parque_das_docas": Color(0.22, 0.24, 0.28),
		"serra_alta": Color(0.26, 0.25, 0.17), "pista_de_testes": Color(0.36, 0.3, 0.22),
		"circuito_misto": Color(0.3, 0.28, 0.16)}


func _init(d: Node, j: Node) -> void:
	super(d, j, "Correr")


func construir() -> void:
	# Decisão 69: quem corre é o piloto de corrida contratado.
	if EquipeJogador.exige_piloto(jogador) and EquipeJogador.piloto_vaga(jogador, "corrida") == "" \
			and not jogador.garagem.lista().is_empty():
		cabecalho("Corridas", "", "fundo_competicoes")
		if not EquipeJogador.criada(jogador):
			# A aba Equipe abre com o tutorial, depois da primeira peça que a Mara
			# pede: antes disso, mandar para a Equipe era um beco sem saída.
			proximo_passo("A equipe abre com o primeiro carro: depois dele, contrate o piloto de corrida.",
					"Ir para as Lojas", LOJA)
			return
		proximo_passo("A equipe precisa de um piloto de corrida. Contrate na aba Equipe.", "Ir para a Equipe", EQUIPE)
		return
	# O carro da vaga CORRIDA da escalação (decisão 68).
	var garagem := Escalacao.garantir_corrida(jogador)
	if garagem == null:
		cabecalho("Corridas", "", "fundo_competicoes")
		if jogador.garagem.lista().is_empty():
			proximo_passo("Você precisa de um carro para correr.", "Ir para as Lojas", LOJA)
		else:
			proximo_passo("Os seus carros estão na arena. Escale um carro para as corridas na Oficina.",
					"Ir para a Oficina", GARAGEM)
		return
	var topo := topo_carro(garagem)
	var trocar := Button.new()
	Tipografia.acao_secundaria(trocar, "Carro de corrida · trocar na Oficina", Color(0.93, 0.91, 0.87), 22)
	sobre_imagem(trocar)
	trocar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	trocar.offset_left = -420
	trocar.offset_right = -16
	# Área de toque inteira (ALTURA_SECUNDARIA) logo abaixo das abas penduradas.
	trocar.offset_top = Cabecalho.ALTURA_MARCADOR
	trocar.offset_bottom = Cabecalho.ALTURA_MARCADOR + Tipografia.ALTURA_SECUNDARIA
	trocar.pressed.connect(func():
		jogador.carro_ativo = garagem.uid
		ir_para.emit(GARAGEM))
	topo.add_child(trocar)
	var c := garagem
	if not jogador.fila.is_empty():
		_fila()
	# Decisão 74: o desafio da equipe da vez do The Grid, quando é na pista.
	cartao_desafio_grid("corrida", func(eq: Dictionary): _correr(GridDesafio.PREFIXO + String(eq["id"])))
	# Próxima prova: a mais favorável ao carro entre as não vencidas, em
	# destaque (o jogador não precisa comparar 200 cartões).
	var proxima := ""
	var fav := _favoraveis(c)
	if not fav.is_empty() and jogador.fila.is_empty():
		proxima = String(fav[0]["ev"]["id"])
		titulo_secao("PRÓXIMA PROVA", "A mais favorável ao seu carro entre as que você ainda não venceu."
				if Carreira.nivel_forca(float(fav[0]["melhor"])) > 0
				else "Seu carro está mais fraco que os rivais em todas as provas abertas: melhore-o na Oficina ou troque de carro nas Lojas.")
		_cartao_evento(c, fav[0]["ev"], [])
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
		b.custom_minimum_size = Vector2(0, Tipografia.ALTURA_SECUNDARIA)  # área de toque de 88 px
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
		if (_filtro == "nao_vencidas" and jogador.vitorias.has(ev["id"])) or ev["id"] == proxima:
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
func _fila() -> void:
	# A prova correndo, no mesmo cartão das provas da lista: banner da pista,
	# estado, traçado, título; no lugar dos prêmios, o tempo e o ganho, e o
	# botão para assistir. Sem parar: a prova termina sozinha.
	var f: Dictionary = jogador.fila
	var ev: Dictionary = dados.evento(f["evento_id"])
	var tex := arte("banner_" + String(Corrida3D.TEMA_DE.get(ev["pista"], ev["pista"])))
	var v := cartao_com_fundo(tex, true)
	var cab := _cabeca_cartao(ev, v, "CORRENDO", COR_BOM, true, _selo(ev, v) != null)
	var col: VBoxContainer = cab["col"]
	_premios(ev, col, true)
	# Recém-inscrita, ainda sendo resolvida aos poucos: o tempo aparece quando ficar pronta.
	var dur: float = jogador.fila_ctrl.duracao_atual() if jogador.fila_ctrl.pronta(false) else 0.0
	if dur > 0.0:
		var decorrido := clampf(Aceleracao.agora(jogador) - float(f["inicio"]), 0.0, dur)
		var falta := dur * int(f["restantes"]) - decorrido
		var tempo := rotulo("Termina em %s" % _tempo(falta), 0, Color.WHITE, col)
		Tipografia.rotulo(tempo, "semibold", 26)
	var ganho := _ganho_estimado(ev, f)
	if ganho != "":
		rotulo(ganho, FONTE_PEQUENA, COR_BOM, col).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lo := rotulo("Termina mesmo com o app fechado", FONTE_PEQUENA - 2, COR_SECUNDARIA, col)
	lo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := Button.new()
	Tipografia.acao_primaria(b, "Assistir   →", COR_BOM, Color(0.1, 0.1, 0.1), 34, Tipografia.ALTURA_SECUNDARIA)
	b.pressed.connect(func(): ir_para.emit(CORRIDA))
	v.add_child(b)


## Faixa de ganho pelas posições já obtidas nesta fila (ou na última vez nesta
## prova). Estimativa, não promessa.
func _ganho_estimado(ev: Dictionary, f: Dictionary) -> String:
	var pos: Array = f.get("posicoes", [])
	if pos.is_empty() and jogador.historico.has(ev["id"]):
		pos = [jogador.historico[ev["id"]]["ultima_pos"]]
	if pos.is_empty():
		return ""
	var premios: Array = ev["premios"]
	var p := func(posicao: int) -> int: return int(premios[posicao - 1]) if posicao >= 1 and posicao <= premios.size() else 0
	var n := int(f["restantes"])
	var melhor: int = p.call(int(pos.min())) * n
	var pior: int = p.call(int(pos.max())) * n
	if melhor == pior:
		return "Ganho previsto até o fim: ≈ %s giros" % dinheiro(melhor)
	return "Ganho previsto até o fim: %s a %s giros (pelas posições até agora)" % [dinheiro(pior), dinheiro(melhor)]


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
	if pode:
		# Os carros do grid saem prontos daqui (um por quadro) e a largada não trava.
		Carroceria.preparar([c.id] + ev["adversarios"].map(func(a): return String(a["carro"])))
	var vitorias: int = jogador.vitorias.get(ev["id"], 0)
	var tex := arte("banner_" + String(Corrida3D.TEMA_DE.get(ev["pista"], ev["pista"])))
	var v := cartao_com_fundo(tex, pode)
	ancora("EVENT_CARD", v)
	var selo := _selo(ev, v)
	# A prova do tutorial (etapa 1 do campeonato do prólogo): cartão, etapas,
	# competitividade e o botão, cada um com a sua âncora.
	var tutorial: bool = ev["id"] == _evento_tutorial()
	if tutorial:
		ancora("COPA", v)
	var estado_txt := ("VENCIDA ×%d" % vitorias) if vitorias > 0 else ("ABERTA" if pode else "BLOQUEADA")
	var estado_cor := COR_BOM if vitorias > 0 else (COR_DESTAQUE if pode else COR_NEUTRA)
	var cab := _cabeca_cartao(ev, v, estado_txt, estado_cor, pode, selo != null)
	var col: VBoxContainer = cab["col"]
	var etapas: Array = cab["etapas"]
	var k_etapa: int = cab["k_etapa"]
	var lp: Label = cab["linha"]
	var lic := String(ev["restricoes"].get("licenca", ""))
	if lic != "" and selo == null:
		ancora("LICENCA_" + lic, lp)
	if not etapas.is_empty():
		var prog := rotulo(_progresso_curto(ev, etapas, k_etapa), FONTE_PEQUENA - 2, COR_DESTAQUE.lightened(0.2), col)
		prog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if tutorial:
			ancora("ETAPAS", prog)
	_premios(ev, col, pode)
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
		Tipografia.acao_primaria(bc, rotulo_correr + "   →", COR_DESTAQUE, Color(0.1, 0.1, 0.1), 34, Tipografia.ALTURA_SECUNDARIA)
		bc.pressed.connect(func():
			_correr(ev["id"])
			mudou.emit())
		v.add_child(bc)
		if tutorial:
			ancora("DISPUTAR", bc)
	else:
		# Bloqueada: o motivo no lugar do DISPUTAR, num botão vermelho. Tocar
		# explica a recusa (e a história pode comentar).
		var pede_licenca: bool = motivos.any(func(m): return String(m).begins_with("licença"))
		var br := Button.new()
		Tipografia.acao_primaria(br, " · ".join(motivos), COR_BLOQUEIO, Color(0.98, 0.95, 0.93), 28, Tipografia.ALTURA_SECUNDARIA)
		br.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		br.icon = icone_reduzido("icone_cadeado", 34)
		br.add_theme_constant_override("h_separation", 12)
		br.pressed.connect(func() -> void:
			avisar("Inscrição recusada: %s." % ", ".join(motivos), false)
			var ctx := {"evento": ev["id"]}
			if not (pede_licenca and historia("LICENCA_EXIGIDA", ctx)):
				historia("EVENTO_BLOQUEADO", ctx))
		v.add_child(br)


## Prêmios do 1º ao 3º, cada um com a moeda (o ícone já diz giros).
func _premios(ev: Dictionary, col: VBoxContainer, pode: bool) -> void:
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


## Selo da licença exigida no canto de cima, à direita, por cima do cartão.
func _selo(ev: Dictionary, v: VBoxContainer) -> Texture2D:
	var selo := selo_licenca(String(ev["restricoes"].get("licenca", "")))
	if selo != null:
		var cima := Control.new()
		cima.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.get_parent().get_parent().add_child(cima)  # o painel do cartão: ocupa ele todo
		var t := TextureRect.new()
		t.texture = selo
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		t.offset_left = -10 - SELO_CARTAO
		t.offset_right = -10
		t.offset_top = 8
		t.offset_bottom = 8 + SELO_CARTAO
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cima.add_child(t)
		ancora("LICENCA_" + String(ev["restricoes"]["licenca"]), t)  # tutorial: "olha a licença exigida"
	return selo


## Topo comum dos cartões de prova (o da lista e o da prova correndo): faixa
## da esquerda com o estado e o traçado; à direita, série, título (etapa ou
## nome), pista e voltas. {col, etapas, k_etapa, linha}.
func _cabeca_cartao(ev: Dictionary, v: VBoxContainer, estado_txt: String, estado_cor: Color, pode: bool,
		com_selo: bool) -> Dictionary:
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
	estado.text = estado_txt
	Tipografia.rotulo(estado, "semibold", 18)
	estado.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	var sb_estado := StyleBoxFlat.new()
	sb_estado.bg_color = estado_cor
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
	var sobre := rotulo((serie if not etapas.is_empty() else _tipo(ev)[0]).to_upper(), 0, COR_SECUNDARIA, col)
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
	var livre := 720.0 - 2.0 * MARGEM_LATERAL - 32.0 - LARGURA_IMAGEM_CARTAO - 14.0 - (SELO_CARTAO if com_selo else 0.0)
	var tam := TITULO_CARTAO
	var fonte_titulo := titulo.get_theme_font("font")
	while tam > TITULO_CARTAO_MIN and fonte_titulo.get_string_size(titulo.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > livre:
		tam -= 2
	titulo.add_theme_font_size_override("font_size", tam)
	var linha := [nome_pista(ev["pista"]), "%d volta%s" % [ev["voltas"], "" if ev["voltas"] == 1 else "s"]]
	# A licença exigida é o selo no canto (sem selo, vai escrita na linha).
	var lic := String(ev["restricoes"].get("licenca", ""))
	if lic != "" and not com_selo:
		linha.append("licença " + lic.capitalize())
	var sem_lic: Dictionary = ev["restricoes"].duplicate()
	sem_lic.erase("licenca")
	linha.append_array(_regras(sem_lic).slice(0, 2))
	var lp := rotulo(" · ".join(linha), FONTE_PEQUENA, Color(0.86, 0.87, 0.9), col)
	lp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return {"col": col, "etapas": etapas, "k_etapa": k_etapa, "linha": lp}


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
	var nivel := Carreira.nivel_forca(r)
	# Tons sóbrios (a faixa do nível fica mais viva; as outras, apagadas).
	var tons := TONS_FORCA
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	pai.add_child(v)
	var topo := HBoxContainer.new()
	v.add_child(topo)
	var t := rotulo("SEU CARRO", 0, COR_SECUNDARIA, topo)
	Tipografia.rotulo(t, "medium", 18)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	var n := rotulo(Carreira.NOMES_FORCA[nivel], 0, tons[nivel].lightened(0.35), topo)
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


## Prova do tutorial de eventos: a primeira prova que o carro em uso já pode
## correr (só antes da primeira corrida).
func _evento_tutorial() -> String:
	if jogador.personagem == "dono" and not jogador.flags.has("FIRST_RACE_DONE"):
		var c: Carro = Escalacao.carro(jogador, "corrida")
		if c != null:
			# A mais favorável ao carro (era a primeira do arquivo, e o jogador
			# perdia as primeiras provas com um carro que vencia outra).
			var fav := _favoraveis(c)
			if not fav.is_empty():
				return String(fav[0]["ev"]["id"])
	return ""


## Provas favoráveis ao carro (Carreira.provas_favoraveis), uma vez por
## construção da tela.
var _fav_cache := {}
func _favoraveis(c: Carro) -> Array:
	var chave := _chave({"id": "fav"}, c) + "|" + str(jogador.licencas) + "|" + str(jogador.vitorias.size())
	if not _fav_cache.has(chave):
		_fav_cache = {chave: jogador.carreira.provas_favoraveis(c)}
	return _fav_cache[chave]


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
	return jogador.carreira.forca_relativa(ev, c)


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
	var a: Dictionary = await Mecanico.avaliar_aos_poucos(jogador.carreira, ev["id"], c.uid, c, get_tree(), Fila.FATIA_MS)
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
	var motivo: String = jogador.fila_ctrl.iniciar(evento_id, Escalacao.uid(jogador, "corrida"), 1, Aceleracao.agora(jogador))
	if motivo != "":
		avisar("Não deu para correr: %s." % motivo, false)
		return
	correr_iniciado.emit()
	historia("CORRIDA_INICIO", ctx)
	if dados.evento(evento_id)["restricoes"].get("licenca", "") == "ELITE":
		historia("CORRIDA_RESISTENCIA")
	for g in jogador.carreira.escalacao(evento_id, int(jogador.fila.get("semente", -1))):
		historia("CORRIDA_CONTRA:" + String(g["piloto"]["id"]))
