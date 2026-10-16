extends Aba
## Equipe do jogador (Second Driver Motorsport), visível depois de criada.
## Placeholders (documento, seção 4): logo = texto da equipe. Duas partes:
## EQUIPE (caixa, pilotos e o carro do segundo; o patrocínio fica na Carreira) e SEDE (melhorias
## da equipe, GestaoEquipe).

const PARTES := [["equipe", "EQUIPE"], ["sede", "SEDE"]]
## Segundo piloto: busto na aba (cabeça à cintura do corpo 600 × 900) e o palco
## da escolha, com o corpo inteiro.
const BUSTO := Vector2(190, 230)
const PALCO_ALTURA := 470.0

var _parte := "equipe"


func _init(d: Node, j: Node) -> void:
	super(d, j, "Equipe")


func construir() -> void:
	var eq := EquipeJogador.dados_equipe(dados, jogador)
	if eq.is_empty():
		cabecalho("Equipe")
		rotulo("A equipe ainda não existe.", 0, COR_SECUNDARIA)
		# Como ela abre: a história a cria depois do primeiro carro.
		rotulo("Ela abre com o primeiro carro: compre um nas Lojas." if jogador.garagem.lista().is_empty()
				else "Ela abre na história: siga o próximo passo da Carreira.", FONTE_PEQUENA, COR_SECUNDARIA)
		return
	_topo(eq)
	if GestaoEquipe.aberta(dados, jogador):
		_partes()
		if _parte == "sede":
			_sede()
			return
	_caixa()
	_pilotos(eq)
	titulo_secao("CONQUISTAS")
	var vit := 0
	for k in jogador.vitorias:
		vit += int(jogador.vitorias[k])
	var tit := 0
	for k in jogador.titulos:
		tit += int(jogador.titulos[k])
	numeros([[str(vit), "vitórias"], [str(tit), "títulos"], [str(jogador.garagem.lista().size()), "carros"],
			[str(jogador.licencas.size()), "licenças"]])


## Topo como o da Carreira: o cenário com a logo da equipe (ou o nome, sem
## arte) no centro e "Motorsport" embaixo.
func _topo(eq: Dictionary) -> void:
	var faixa := ilustracao("fundo_carreira", 330.0)
	cenario_topo(faixa)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 70  # abaixo das abas penduradas do cabeçalho
	v.offset_bottom = -14
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.add_child(v)
	# O logo do dado da equipe (a campanha pode trocar: historia.json → equipe).
	var arquivo := String(eq.get("logo", ""))
	var tex: Texture2D = load(arquivo) if arquivo != "" and ResourceLoader.exists(arquivo) else null
	if tex != null:
		var img := TextureRect.new()
		img.texture = tex
		img.custom_minimum_size = Vector2(0, 170)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(img)
	else:
		# Placeholder (documento, seção 4): logo = texto da equipe.
		var nome := Label.new()
		nome.text = String(eq["nome"]).to_upper()
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Tipografia.rotulo(nome, "semibold", 64)
		nome.add_theme_color_override("font_color", COR_DESTAQUE)
		nome.add_theme_constant_override("outline_size", 8)
		nome.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		v.add_child(nome)
	var sub := Label.new()
	sub.visible = tex == null or eq.get("subtitulo", true)  # o logo já pode trazer o "MOTORSPORT"
	sub.text = "M O T O R S P O R T"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tipografia.rotulo(sub, "medium", 24)
	sub.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	v.add_child(sub)


## As duas partes da tela (como os filtros das Corridas).
func _partes() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	conteudo.add_child(h)
	for parte in PARTES:
		var b := Button.new()
		b.text = parte[1]
		b.toggle_mode = true
		b.button_pressed = _parte == parte[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Tipografia.rotulo(b, "semibold", 24)
		b.custom_minimum_size = Vector2(0, Tipografia.ALTURA_SECUNDARIA)
		b.pressed.connect(func():
			_parte = parte[0]
			mudou.emit())
		h.add_child(b)


## Caixa único (o saldo), as peças e a folha de cada corrida.
func _caixa() -> void:
	if not GestaoEquipe.aberta(dados, jogador):
		return  # decisão 69: a equipe nasce no começo; caixa e folha, com a International
	titulo_secao("CAIXA", "Prêmios, patrocínio e staff entram e saem do mesmo caixa.")
	var c := cartao()
	var h := fileira(c)
	var moeda_i := icone("cabecalho/icone_giros", 40, h)
	moeda_i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n := Label.new()
	n.text = dinheiro(jogador.economia.saldo)
	Tipografia.numero(n, 44)
	n.add_theme_color_override("font_color", COR_DESTAQUE)
	h.add_child(n)
	if jogador.economia.credito_pecas > 0:
		rotulo("+ %s peças (desmanche e arena; pagam a blindagem)" % dinheiro(jogador.economia.credito_pecas),
				FONTE_PEQUENA + 2, COR_SECUNDARIA, c)
	var f := EquipeJogador.folha(dados, jogador)
	if not GestaoEquipe.aberta(dados, jogador):
		_linha_folha(c, "Patrocínio por corrida", "patrocinio", int(f["patrocinio"]), "+")
	_linha_folha(c, "Staff por corrida", "custo_staff", int(f["staff"]), "−")


## Sede: as melhorias da equipe, cada uma com os níveis em dentes, o efeito e
## o preço do próximo nível.
func _sede() -> void:
	titulo_secao("SEDE", "Melhorias da equipe, pagas com o caixa.")
	for m in dados.equipe().get("sede", []):
		var n := GestaoEquipe.nivel(jogador, m["id"])
		var total := int(m["niveis"])
		var v := cartao()
		var cab := fileira(v)
		var nome := rotulo(String(m["nome"]), 0, Color.WHITE, cab)
		Tipografia.rotulo(nome, "semibold", 30)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Tipografia.rotulo(rotulo("NÍVEL %d/%d" % [n, total], 0, COR_SECUNDARIA, cab), "medium", 20)
		var dentes := BarraDentes.new(n, total, 12.0)
		dentes.custom_minimum_size = Vector2(0, 12)
		v.add_child(dentes)
		rotulo(String(m["descricao"]), FONTE_PEQUENA + 2, Color(0.86, 0.87, 0.9), v).autowrap_mode = \
				TextServer.AUTOWRAP_WORD_SMART
		rotulo(_texto_efeito(m, n), FONTE_PEQUENA, COR_SECUNDARIA, v)
		var preco := GestaoEquipe.preco_melhoria(dados, jogador, m["id"])
		var b := Button.new()
		if preco <= 0:
			Tipografia.acao_primaria(b, "Nível máximo", COR_NEUTRA, Color(0.9, 0.9, 0.9), 26, Tipografia.ALTURA_SECUNDARIA)
			b.disabled = true
		else:
			Tipografia.acao_primaria(b, "Melhorar · %s" % dinheiro(preco), COR_DESTAQUE, Color(0.1, 0.1, 0.1), 26,
					Tipografia.ALTURA_SECUNDARIA)
			moeda(b, 26)
			b.disabled = not jogador.economia.pode_pagar(preco)
			b.pressed.connect(func():
				var motivo := GestaoEquipe.comprar_melhoria(dados, jogador, String(m["id"]))
				if motivo != "":
					avisar("Não deu: %s." % motivo, false)
					return
				Sons.tocar_ui(self, "moeda", -4.0)
				avisar("%s: nível %d." % [m["nome"], GestaoEquipe.nivel(jogador, m["id"])])
				historia("SEDE_MELHORADA")
				mudou.emit())
		v.add_child(b)


## "Agora: +1 contrato · próximo: +2" (efeito somado pelo nível).
static func _texto_efeito(m: Dictionary, n: int) -> String:
	var f := func(k: int) -> String:
		var x := float(m["por_nivel"]) * k
		match String(m["efeito"]):
			"contratos":
				return "+%d contrato%s" % [int(x), "" if int(x) == 1 else "s"]
			_:
				return "+%d%%" % roundi(x * 100.0)
	var t := "Agora: %s" % (f.call(n) if n > 0 else "nada")
	if n < int(m["niveis"]):
		t += " · próximo nível: %s" % f.call(n + 1)
	return t


## Valor ainda sem número (pendente de playtest) não aparece para o jogador.
func _linha_folha(pai: Control, texto: String, chave: String, v: int, sinal: String) -> void:
	var definido := EquipeJogador.definido(dados, chave)
	if not definido:
		return
	var h := fileira(pai)
	var l := rotulo(texto, FONTE_PEQUENA + 2, COR_SECUNDARIA, h)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := rotulo("%s %s giros" % [sinal, dinheiro(v)], FONTE_PEQUENA + 2, Color.WHITE, h)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## Decisão 69: você administra; quem pilota é contratado. Três vagas: o piloto
## de corrida (o primeiro, no tutorial do começo) e os dois de arena (abrem com
## o tutorial da arena, aos 3 carros).
func _pilotos(eq: Dictionary) -> void:
	titulo_secao("PILOTOS", "Um piloto de corrida e dois de arena. Piloto de corrida não luta na arena.")
	if not EquipeJogador.exige_piloto(jogador) and Prologo.piloto(dados, jogador) != "":
		var cp := cartao()
		_linha_piloto(cp, EquipeJogador.nome_jogador(dados, jogador), "PILOTO PRINCIPAL")
	for p in eq.get("pilotos", []):
		if String(p["id"]).begins_with(String(jogador.personagem) + "_"):
			_linha_piloto(cartao(), String(p["nome"]), "PILOTO PRINCIPAL")
	for vaga in EquipeJogador.VAGAS_PILOTO:
		var c := cartao()
		_vaga_piloto(vaga, c)
		if EquipeJogador.piloto_vaga(jogador, vaga) != "":
			_treino(c, EquipeJogador.piloto_vaga(jogador, vaga))
		if vaga == "arena2" and EquipeJogador.piloto_vaga(jogador, vaga) != "":
			_carro_companheiro()


func _vaga_piloto(vaga: String, pai: Control) -> void:
	var id := EquipeJogador.piloto_vaga(jogador, vaga)
	var tipo := "corrida" if vaga == "corrida" else "arena"
	if not EquipeJogador.vaga_aberta(jogador, vaga):
		_linha_piloto(pai, "Sem carro disponível", EquipeJogador.NOMES_VAGA[vaga])
		rotulo("Os pilotos de arena chegam com a arena: 3 carros na garagem.", FONTE_PEQUENA, COR_SECUNDARIA, pai)
		return
	if id == "":
		_linha_piloto(pai, "Vaga livre", EquipeJogador.NOMES_VAGA[vaga])
		var b := Button.new()
		Tipografia.acao_primaria(b, "Contratar piloto de %s   →" % tipo, COR_DESTAQUE, Color(0.1, 0.1, 0.1), 26, 64)
		b.pressed.connect(_escolher_segundo.bind(vaga))
		pai.add_child(b)
		if vaga == "corrida":
			ancora("PILOTO_CORRIDA", b)
		return
	var h := fileira(pai)
	h.add_theme_constant_override("separation", 12)
	var busto := TextureRect.new()
	busto.texture = _busto(id)
	busto.custom_minimum_size = BUSTO
	busto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	busto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(busto)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	_linha_piloto(v, String(EquipeJogador.piloto(dados, id).get("nome", id)), EquipeJogador.NOMES_VAGA[vaga])
	var tr := EquipeJogador.traco(dados, id)
	if not tr.is_empty():
		_selo_traco(String(tr["nome"]), v)
	if EquipeJogador.piloto(dados, id).has("equipe"):
		rotulo("Ex-%s." % EquipeJogador.piloto(dados, id)["equipe"], FONTE_PEQUENA, COR_SECUNDARIA, v)
	var por_nivel := int(GestaoEquipe.cfg_treino(dados).get("xp_por_nivel", 0))
	if por_nivel > 0:
		rotulo("Experiência: %d/%d %s para o próximo nível" % [EquipeJogador.xp(jogador, id), por_nivel,
				"corridas" if vaga == "corrida" else "lutas"], FONTE_PEQUENA, COR_SECUNDARIA, v)
	var falta := ArenaCarreira.recuperacao_s(jogador, id)
	if falta > 0.0:
		rotulo("EM RECUPERAÇÃO (%s na arena): volta em %s." % [EquipeJogador.flexao(
				EquipeJogador.genero(dados, id), "atropelado", "atropelada"), ArenaCarreira.texto_tempo(falta)],
				FONTE_PEQUENA, COR_RUIM, v)
	if EquipeJogador.em_embalo(jogador, id):
		rotulo("EMBALO: o próximo treino leva metade do tempo.", FONTE_PEQUENA, COR_BOM, v)
	botao_texto("Trocar piloto  →", _escolher_segundo.bind(vaga), v).alignment = HORIZONTAL_ALIGNMENT_LEFT


## Atributos (decisão 70) e treino do piloto: ritmo, consistência e
## agressividade em barras; a energia (treinar gasta, volta enchendo); o botão
## do próximo nível. `piloto_id` "" = o treino da equipe (sem contratados).
func _treino(pai: Control, piloto_id := "") -> void:
	var base := float(dados.piloto(dados.carreira()["piloto_jogador"])["ritmo"])
	if piloto_id != "":
		var a := EquipeJogador.atributos(dados, jogador, piloto_id)
		# Ritmo: o ganho do treino sobre o piloto-base, e a barra na mesma
		# escala (cheia no teto da licença): o número e a barra dizem o mesmo.
		var teto_r := maxf(GestaoEquipe.teto(dados, jogador), base + 0.0001)
		var ganho := float(a["ritmo"]) - base
		for it in [["Ritmo", ganho / (teto_r - base), "+%s%%" % Aba.decimal(ganho * 100.0, 1)],
				["Consistência", float(a["consistencia"]), "%d%%" % roundi(float(a["consistencia"]) * 100.0)],
				["Agressividade", float(a["agressividade"]), "%d%%" % roundi(float(a["agressividade"]) * 100.0)]]:
			_barra_atributo(pai, it[0], clampf(float(it[1]), 0.0, 1.0), it[2])
		var e := GestaoEquipe.energia(jogador, piloto_id, Time.get_unix_time_from_system())
		_barra_atributo(pai, "Energia", e, "%d%%" % roundi(e * 100.0), COR_BOM if e >= 1.0 else COR_DESTAQUE)
	if not GestaoEquipe.aberta(dados, jogador) or GestaoEquipe.cfg_treino(dados).is_empty():
		return
	var atual := GestaoEquipe.ritmo(dados, jogador, base, piloto_id)
	var teto := maxf(GestaoEquipe.teto(dados, jogador), base)
	if piloto_id == "":
		var h := fileira(pai)
		var l := rotulo("Ritmo", FONTE_PEQUENA + 2, COR_SECUNDARIA, h)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := rotulo("%s%% · teto %s%%" % [Aba.decimal(atual * 100.0, 1), Aba.decimal(teto * 100.0, 1)],
				FONTE_PEQUENA + 2, Color.WHITE, h)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var agora := Time.get_unix_time_from_system()
	if GestaoEquipe.treinando(jogador, piloto_id):
		var resta := maxf(float(jogador.equipe[GestaoEquipe._chave(piloto_id)]["fim"]) - agora, 0.0)
		rotulo("Treinando o nível %d: a energia enche em %s (também com o app fechado)." % [
				GestaoEquipe.nivel_treino(jogador, piloto_id) + 1, horas_min(resta)], FONTE_PEQUENA, COR_BOM, pai)
		return
	if not GestaoEquipe.pode_treinar(dados, jogador, base, piloto_id):
		rotulo("Ritmo no teto desta licença (%s%%). A próxima licença libera mais." % Aba.decimal(teto * 100.0, 1),
				FONTE_PEQUENA, COR_SECUNDARIA, pai)
		return
	var preco := GestaoEquipe.preco_treino(dados, jogador, piloto_id)
	var b := Button.new()
	Tipografia.acao_primaria(b, "Treinar ritmo · %s · %s" % [dinheiro(preco), horas_min(GestaoEquipe.duracao_treino(dados, jogador, piloto_id))],
			COR_DESTAQUE, Color(0.1, 0.1, 0.1), 24, Tipografia.ALTURA_SECUNDARIA)
	moeda(b, 24)
	b.disabled = not jogador.economia.pode_pagar(preco)
	b.pressed.connect(func():
		var motivo := GestaoEquipe.treinar(dados, jogador, base, Time.get_unix_time_from_system(), piloto_id)
		if motivo != "":
			avisar("Não deu: %s." % motivo, false)
			return
		Sons.tocar_ui(self, "moeda", -4.0)
		avisar("Treino começou: a energia volta enchendo.")
		mudou.emit())
	pai.add_child(b)


## Uma linha de atributo: nome, barra em dentes e o valor.
func _barra_atributo(pai: Control, nome: String, fracao: float, texto: String, cor := COR_DESTAQUE) -> void:
	var h := fileira(pai)
	var l := rotulo(nome, FONTE_PEQUENA, COR_SECUNDARIA, h)
	l.custom_minimum_size.x = 170
	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.max_value = 1.0
	barra.value = fracao
	barra.custom_minimum_size = Vector2(0, 12)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = cor
	barra.add_theme_stylebox_override("fill", cheio)
	h.add_child(barra)
	var v := rotulo(texto, FONTE_PEQUENA, Color.WHITE, h)
	v.custom_minimum_size.x = 90
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## Barra de atributo que anima até o valor ({barra, texto}); _animar_barra.
func _barra_animada(pai: Control, nome: String) -> Dictionary:
	var h := fileira(pai)
	var l := rotulo(nome.to_upper(), FONTE_PEQUENA, COR_SECUNDARIA, h)
	l.custom_minimum_size.x = 210
	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.max_value = 1.0
	barra.custom_minimum_size = Vector2(0, 14)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = COR_DESTAQUE
	cheio.set_corner_radius_all(3)
	barra.add_theme_stylebox_override("fill", cheio)
	h.add_child(barra)
	var v := rotulo("", FONTE_PEQUENA, Color.WHITE, h)
	v.custom_minimum_size.x = 80
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return {"barra": barra, "texto": v}


func _animar_barra(b: Dictionary, valor: float, dur: float) -> void:
	var barra: ProgressBar = b["barra"]
	var texto: Label = b["texto"]
	var de := barra.value
	var alvo := clampf(valor, 0.0, 1.0)
	if dur <= 0.0 or Preferencias.reduzir_animacoes:
		barra.set_meta("valor", valor)
		barra.value = alvo
		texto.text = "%d%%" % roundi(valor * 100.0)
		return
	var de_txt := float(barra.get_meta("valor", 0.0))
	barra.set_meta("valor", valor)
	var tw := barra.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float):
		barra.value = lerpf(de, alvo, t)
		texto.text = "%d%%" % roundi(lerpf(de_txt, valor, t) * 100.0), 0.0, 1.0, dur)


## Os candidatos um por vez, de corpo inteiro na garagem (referência do
## usuário): setas em caixa para passar; a placa com o nome sobre as pernas;
## estilo, os atributos com ícones e Contratar.
func _escolher_segundo(vaga: String = "corrida") -> void:
	var tipo := "corrida" if vaga == "corrida" else "arena"
	# Decisão 71: o mercado do período (renova a cada dia); o atual da vaga junto.
	var agora_m := Time.get_unix_time_from_system()
	var lista: Array = EquipeJogador.oferta(dados, jogador, tipo, agora_m)
	var atual_id := EquipeJogador.piloto_vaga(jogador, vaga)
	if atual_id != "":
		lista.push_front(EquipeJogador.piloto(dados, atual_id))
	if lista.is_empty():
		avisar("Ninguém no mercado agora. Renova em %s." % horas_min(EquipeJogador.renova_em(dados, agora_m)), false)
		return
	var ids := lista.map(func(c): return String(c["id"]))
	var estado := {"i": maxi(ids.find(atual_id), 0)}
	var estilo_painel := {"fora_fecha": true, "titulo_pincel": true,
			"fundo": Assets.get_asset("garagem_pilotos", "cenario")}
	painel_estilo.emit("SELEÇÃO DE PILOTOS", func(pv):
		pv.add_theme_constant_override("separation", 8)
		_renova_em(pv)
		var palco := Control.new()
		palco.custom_minimum_size = Vector2(0, PALCO_ALTURA)
		pv.add_child(palco)
		var corpo := TextureRect.new()
		corpo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# O piloto vai do palco até trás do Contratar: placa, estilo e atributos
		# ficam por cima dele (a borda de baixo da arte some atrás do botão).
		corpo.offset_top = 10
		corpo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		corpo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		palco.add_child(corpo)
		var contador := Label.new()
		contador.add_theme_font_override("font", Tipografia.fonte("display"))
		contador.add_theme_font_size_override("font_size", 40)
		contador.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		palco.add_child(contador)
		contador.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		contador.offset_left = -130
		contador.offset_right = -10
		contador.offset_top = 14
		contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var nome := _placa_nome(pv)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 8)
		pv.add_child(info)
		var linha_estilo := HBoxContainer.new()
		linha_estilo.add_theme_constant_override("separation", 12)
		info.add_child(linha_estilo)
		var vao := Control.new()
		vao.custom_minimum_size = Vector2(104, 0)
		linha_estilo.add_child(vao)
		var estilo := Label.new()
		estilo.text = "ESTILO:"
		Tipografia.rotulo(estilo, "semibold", 32)
		estilo.add_theme_color_override("font_color", Color(0.86, 0.86, 0.86))
		linha_estilo.add_child(estilo)
		var selo := CenterContainer.new()
		linha_estilo.add_child(selo)
		linha_estilo.add_child(_riscos())
		# Os atributos em barras que andam na troca: o estilo muda a
		# consistência e a agressividade (o ritmo cresce depois, no treino).
		var quadro := PanelContainer.new()
		var sbq := StyleBoxFlat.new()
		sbq.bg_color = Color(0.03, 0.03, 0.04, 0.82)
		sbq.border_color = Color(1, 1, 1, 0.12)
		sbq.set_border_width_all(1)
		sbq.set_corner_radius_all(8)
		sbq.content_margin_left = 18
		sbq.content_margin_right = 18
		sbq.content_margin_top = 4
		sbq.content_margin_bottom = 4
		quadro.add_theme_stylebox_override("panel", sbq)
		info.add_child(quadro)
		var linhas := VBoxContainer.new()
		linhas.add_theme_constant_override("separation", 0)
		quadro.add_child(linhas)
		var barras := []
		var itens := [["velocimetro", "Ritmo"], ["mira", "Consistência"], ["punho", "Agressividade"]]
		for k in itens.size():
			if k > 0:
				var sep := ColorRect.new()
				sep.color = Color(1, 1, 1, 0.1)
				sep.custom_minimum_size = Vector2(0, 1)
				linhas.add_child(sep)
			barras.append(_linha_atributo(linhas, itens[k][0], itens[k][1]))
		var b := _botao_contratar(info)
		var na_equipe := Label.new()
		na_equipe.text = "NA EQUIPE"
		Tipografia.rotulo(na_equipe, "semibold", 28)
		na_equipe.add_theme_color_override("font_color", COR_DESTAQUE)
		na_equipe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		na_equipe.custom_minimum_size = Vector2(0, Tipografia.ALTURA_SECUNDARIA)  # no lugar do Contratar
		na_equipe.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var sbn := StyleBoxFlat.new()  # cobre a base do piloto, como o Contratar
		sbn.bg_color = Color(0.05, 0.05, 0.06, 0.95)
		sbn.border_color = Color(COR_DESTAQUE, 0.6)
		sbn.set_border_width_all(2)
		sbn.set_corner_radius_all(6)
		na_equipe.add_theme_stylebox_override("normal", sbn)
		info.add_child(na_equipe)
		var fechar := Button.new()
		Tipografia.acao_secundaria(fechar, "FECHAR", Color(0.9, 0.9, 0.92), 32, Tipografia.ALTURA_SECUNDARIA)
		var sbf := StyleBoxFlat.new()
		sbf.bg_color = Color(0.07, 0.08, 0.1, 0.92)
		sbf.border_color = Color(1, 1, 1, 0.28)
		sbf.set_border_width_all(2)
		sbf.set_corner_radius_all(8)
		for e in ["normal", "hover", "pressed", "focus"]:
			fechar.add_theme_stylebox_override(e, sbf)
		fechar.flat = false  # acao_secundaria deixa chato (sem caixa)
		fechar.pressed.connect(func(): fechar_painel.emit())
		info.add_child(fechar)
		fechar.item_rect_changed.connect(func():
			corpo.offset_bottom = fechar.global_position.y - 12.0 - (palco.global_position.y + palco.size.y))
		var mostrar := func(lado: int):
			var c: Dictionary = lista[estado["i"]]
			var atual: bool = c["id"] == atual_id
			var outra := EquipeJogador.vaga_do_piloto(jogador, String(c["id"]))
			corpo.texture = Assets.get_asset(String(c["id"]), "corpo")
			if corpo.texture == null:  # genérico ainda sem corpo: o retrato; sem arte, a silhueta
				corpo.texture = Assets.get_asset(String(c["id"]), "retrato")
			if corpo.texture == null:
				corpo.texture = Aba.arte("piloto_silhueta_%d" % (1 + absi(hash(String(c["id"]))) % 3))
			nome.text = String(c["nome"]).to_upper()
			for f in selo.get_children():
				f.queue_free()
			var tr: Dictionary = EquipeJogador.config(dados).get("tracos", {}).get(String(c["traco"]), {})
			_selo_traco(String(tr.get("nome", "")), selo, 28)
			linha_estilo.visible = String(tr.get("nome", "")) != ""
			contador.text = "%d / %d" % [estado["i"] + 1, lista.size()]
			var at := EquipeJogador.atributos(dados, jogador if atual else null, String(c["id"]))
			var valores := [float(at.get("ritmo", 1.0)), float(at.get("consistencia", 0.0)), float(at.get("agressividade", 0.0))]
			for k in barras.size():
				_animar_barra(barras[k], valores[k], 0.0 if lado == 0 and Preferencias.reduzir_animacoes else 0.35)
			b.visible = not atual and outra == ""
			na_equipe.visible = atual or outra != ""
			na_equipe.text = "NA EQUIPE" if atual else ("NA EQUIPE · " + String(EquipeJogador.NOMES_VAGA.get(outra, "")))
			if lado != 0 and not Preferencias.reduzir_animacoes:
				corpo.modulate.a = 0.0
				corpo.position.x = 40.0 * lado
				var tw := corpo.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(corpo, "modulate:a", 1.0, 0.22)
				tw.tween_property(corpo, "position:x", 0.0, 0.28)
		if lista.size() > 1:
			for lado in [-1, 1]:
				_seta_caixa(palco, lado, func():
					estado["i"] = posmod(estado["i"] + lado, lista.size())
					mostrar.call(lado))
		b.pressed.connect(func():
			var c: Dictionary = lista[estado["i"]]
			var motivo := EquipeJogador.contratar(dados, jogador, String(c["id"]), vaga)
			if motivo != "":
				avisar("Não deu: %s." % motivo, false)
				return
			Sons.tocar_ui(self, "moeda", -4.0)
			avisar("%s entra na equipe: %s." % [c["nome"], String(EquipeJogador.NOMES_VAGA[vaga]).to_lower()])
			fechar_painel.emit()
			mudou.emit()
			historia("PILOTO_CONTRATADO", {"vaga": vaga}))
		mostrar.call(0), [], estilo_painel)


## Placa do nome logo abaixo do piloto: faixa escura inclinada com o risco
## dourado à esquerda. Devolve o Label do nome.
func _placa_nome(pai: Control) -> Label:
	var placa := Control.new()
	placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placa.custom_minimum_size = Vector2(0, 78)
	pai.add_child(placa)
	placa.draw.connect(func():
		var w := placa.size.x
		var h := placa.size.y
		placa.draw_colored_polygon(PackedVector2Array([Vector2(46, 8), Vector2(w, 8), Vector2(w, h),
				Vector2(18, h)]), Color(0.06, 0.06, 0.07, 0.94))
		placa.draw_line(Vector2(46, 8), Vector2(w, 8), Color(1, 1, 1, 0.14), 2.0)
		placa.draw_colored_polygon(PackedVector2Array([Vector2(62, 8), Vector2(78, 8), Vector2(56, h - 8),
				Vector2(40, h - 8)]), COR_DESTAQUE)
		placa.draw_colored_polygon(PackedVector2Array([Vector2(84, 8), Vector2(90, 8), Vector2(68, h - 8),
				Vector2(62, h - 8)]), Color(COR_DESTAQUE, 0.6)))
	var nome := Label.new()
	nome.add_theme_font_override("font", Tipografia.fonte("display"))
	nome.add_theme_font_size_override("font_size", 58)
	nome.add_theme_color_override("font_color", Color(0.96, 0.94, 0.9))
	nome.clip_text = true
	nome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nome.offset_left = 104
	nome.offset_top = 8
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placa.add_child(nome)
	return nome


## Três riscos dourados inclinados (enfeite ao lado do estilo).
func _riscos() -> Control:
	var r := Control.new()
	r.custom_minimum_size = Vector2(96, 36)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.draw.connect(func():
		for k in 3:
			var x := 6.0 + k * 28.0
			r.draw_colored_polygon(PackedVector2Array([Vector2(x + 12, 0), Vector2(x + 25, 0),
					Vector2(x + 13, 36), Vector2(x, 36)]), COR_DESTAQUE))
	return r


## Seta em caixa (escura, borda dourada) na lateral do palco.
func _seta_caixa(palco: Control, lado: int, ao_tocar: Callable) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.05, 0.78)
	sb.border_color = Color(COR_DESTAQUE, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	for e in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(e, sb)
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if lado < 0 else Control.PRESET_CENTER_RIGHT)
	b.offset_top = -80
	b.offset_bottom = -6
	if lado < 0:
		b.offset_left = 4
		b.offset_right = 70
	else:
		b.offset_left = -70
		b.offset_right = -4
	var ic := IconeVetor.new("chevron", COR_DESTAQUE)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.pivot_offset = Vector2(33, 37)
	ic.rotation = PI if lado < 0 else 0.0
	ic.resized.connect(func(): ic.pivot_offset = ic.size / 2.0)
	b.add_child(ic)
	b.pressed.connect(ao_tocar)
	palco.add_child(b)


## Linha do quadro de atributos: ícone, nome, barra e o valor ({barra, texto},
## como _barra_animada, para _animar_barra).
func _linha_atributo(pai: Control, icone_: String, nome: String) -> Dictionary:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.custom_minimum_size = Vector2(0, 42)
	pai.add_child(h)
	var ic := IconeVetor.new(icone_, Color(0.85, 0.85, 0.87))
	ic.cor_fundo = Color(0.05, 0.05, 0.06)  # furos do desenho na cor do quadro
	ic.custom_minimum_size = Vector2(40, 40)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := Label.new()
	l.text = nome.to_upper()
	Tipografia.rotulo(l, "semibold", 24)
	l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	l.custom_minimum_size.x = 180
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.max_value = 1.0
	barra.custom_minimum_size = Vector2(0, 18)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(1, 1, 1, 0.08)
	fundo.set_corner_radius_all(4)
	barra.add_theme_stylebox_override("background", fundo)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = COR_DESTAQUE
	cheio.set_corner_radius_all(4)
	barra.add_theme_stylebox_override("fill", cheio)
	h.add_child(barra)
	var v := Label.new()
	Tipografia.numero(v, 28)
	v.add_theme_color_override("font_color", Color.WHITE)
	v.custom_minimum_size.x = 76
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	return {"barra": barra, "texto": v}


## Contratar: grande e dourado, com a bandeira, riscos à esquerda e a seta.
func _botao_contratar(pai: Control) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 84)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_DESTAQUE
	sb.border_color = COR_DESTAQUE.lightened(0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	var apertado := sb.duplicate()
	apertado.bg_color = COR_DESTAQUE.darkened(0.15)
	for e in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(e, sb)
	b.add_theme_stylebox_override("pressed", apertado)
	pai.add_child(b)
	var riscos := Control.new()
	riscos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riscos.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	riscos.offset_right = 120
	riscos.draw.connect(func():
		var h := riscos.size.y
		for k in 4:
			var x := 14.0 + k * 22.0
			riscos.draw_colored_polygon(PackedVector2Array([Vector2(x + 26, 6), Vector2(x + 34, 6),
					Vector2(x + 8, h - 6), Vector2(x, h - 6)]), Color(0, 0, 0, 0.09)))
	b.add_child(riscos)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 26)
	b.add_child(h)
	var escuro := Color(0.09, 0.08, 0.06)
	var bandeira := IconeVetor.new("bandeira", escuro)
	bandeira.custom_minimum_size = Vector2(52, 52)
	bandeira.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bandeira)
	var t := Label.new()
	t.text = "CONTRATAR"
	Tipografia.rotulo(t, "display_eb", 50)
	t.add_theme_color_override("font_color", escuro)
	h.add_child(t)
	var seta := IconeVetor.new("chevron", escuro)
	seta.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	seta.offset_left = -70
	seta.offset_right = -20
	b.add_child(seta)
	return b


## "Renova em" com o relógio em destaque, contando a cada segundo.
func _renova_em(pai: Control) -> void:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	pai.add_child(h)
	var r := Label.new()
	r.text = "RENOVA EM"
	Tipografia.rotulo(r, "semibold", 24)
	r.add_theme_color_override("font_color", Color(0.86, 0.86, 0.88))
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(r)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.04, 0.85)
	sb.border_color = COR_DESTAQUE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 18
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	h.add_child(p)
	var dentro := HBoxContainer.new()
	dentro.add_theme_constant_override("separation", 14)
	p.add_child(dentro)
	var ic := IconeVetor.new("cronometro", Color(0.86, 0.86, 0.88))
	ic.custom_minimum_size = Vector2(34, 34)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dentro.add_child(ic)
	var t := Label.new()
	t.add_theme_font_override("font", Tipografia.fonte("display"))
	t.add_theme_font_size_override("font_size", 42)
	t.add_theme_color_override("font_color", COR_DESTAQUE)
	dentro.add_child(t)
	var tique := func():
		var falta := int(EquipeJogador.renova_em(dados, Time.get_unix_time_from_system()))
		t.text = "%02d:%02d:%02d" % [falta / 3600, falta / 60 % 60, falta % 60]
	tique.call()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(tique)
	h.add_child(timer)


## Busto: o corpo inteiro recortado da cabeça à cintura (sem esticar).
func _busto(piloto_id: String) -> Texture2D:
	var corpo := Assets.get_asset(piloto_id, "corpo")
	if corpo == null:
		return Assets.get_asset(piloto_id, "retrato")
	# Justo na silhueta: a largura da figura e, dela, a altura na proporção do quadro.
	var usado := corpo.get_image().get_used_rect()
	var a := AtlasTexture.new()
	a.atlas = corpo
	a.region = Rect2(usado.position.x, usado.position.y, usado.size.x,
			minf(usado.size.x * BUSTO.y / BUSTO.x, usado.size.y))
	return a


## Sombra no chão, sob os pés.
func _sombra_chao() -> TextureRect:
	var t := TextureRect.new()
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	g.gradient = Gradient.new()
	g.gradient.colors = PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0)])
	t.texture = g
	t.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	t.offset_left = -170
	t.offset_right = 170
	t.offset_top = -52
	t.offset_bottom = -4
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Traço como selo: texto escuro sobre a cor de destaque.
func _selo_traco(texto: String, pai: Control, tamanho := 18) -> void:
	if texto == "":
		return
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_DESTAQUE
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := Label.new()
	l.text = texto.to_upper()
	Tipografia.rotulo(l, "semibold", tamanho)
	l.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	p.add_child(l)
	pai.add_child(p)


func _linha_piloto(pai: Control, nome: String, papel: String) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	pai.add_child(v)
	var p := Label.new()
	p.text = papel
	Tipografia.rotulo(p, "medium", 18)
	p.add_theme_color_override("font_color", COR_SECUNDARIA)
	v.add_child(p)
	var n := Label.new()
	n.text = nome
	Tipografia.rotulo(n, "semibold", 34)
	n.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	v.add_child(n)


## O carro do segundo piloto é o da vaga ARENA 2 da escalação (decisão 68:
## nas corridas só corre um piloto; ele vai para a arena). Trocar é na Oficina.
func _carro_companheiro() -> void:
	titulo_secao("CARRO DO SEGUNDO PILOTO")
	var car := Escalacao.carro(jogador, "arena2")
	if car == null:
		proximo_passo("Ele corre na arena com o carro da vaga ARENA 2. Escale um na Oficina.", "Ir para a Oficina", GARAGEM)
		return
	var v := cartao()
	var h := fileira(v)
	h.add_child(icone_carro(car.base, false, CarroBloco.cor_do_carro(car)))
	rotulo(car.base["nome"], 28, Color.WHITE, h)
	rotulo("Na arena, ARENA 2 da escalação. Trocar na Oficina.", FONTE_PEQUENA, COR_SECUNDARIA, v)
