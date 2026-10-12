extends Aba
## Equipe do jogador (Second Driver Motorsport), visível depois de criada.
## Placeholders (documento, seção 4): logo = texto da equipe. Duas partes:
## EQUIPE (caixa, pilotos e o carro do segundo; o patrocínio fica na Carreira) e SEDE (melhorias
## da equipe, GestaoEquipe).

const PARTES := [["equipe", "EQUIPE"], ["sede", "SEDE"]]
## Segundo piloto: busto na aba (cabeça à cintura do corpo 600 × 900) e o palco
## da escolha, com o corpo inteiro.
const BUSTO := Vector2(190, 230)
const PALCO_ALTURA := 560.0

var _parte := "equipe"


func _init(d: Node, j: Node) -> void:
	super(d, j, "Equipe")


func construir() -> void:
	var eq := EquipeJogador.dados_equipe(dados, jogador)
	if eq.is_empty():
		cabecalho("Equipe")
		rotulo("A equipe ainda não existe.", 0, COR_SECUNDARIA)
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
		b.custom_minimum_size = Vector2(0, 60)
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
			Tipografia.acao_primaria(b, "Nível máximo", COR_NEUTRA, Color(0.9, 0.9, 0.9), 26, 60)
			b.disabled = true
		else:
			Tipografia.acao_primaria(b, "Melhorar · %s" % dinheiro(preco), COR_DESTAQUE, Color(0.1, 0.1, 0.1), 26, 60)
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


func _linha_folha(pai: Control, texto: String, chave: String, v: int, sinal: String) -> void:
	var definido := EquipeJogador.definido(dados, chave)
	var h := fileira(pai)
	var l := rotulo(texto, FONTE_PEQUENA + 2, COR_SECUNDARIA, h)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := rotulo("%s %s giros" % [sinal, dinheiro(v)] if definido else "a definir no playtest", FONTE_PEQUENA + 2,
			Color.WHITE if definido else COR_NEUTRA.lightened(0.3), h)
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
		_linha_piloto(pai, "Vaga fechada", EquipeJogador.NOMES_VAGA[vaga])
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
	var frase := String(EquipeJogador.piloto(dados, id).get("frase", ""))
	if frase != "":
		rotulo(frase, FONTE_PEQUENA, COR_SECUNDARIA, v)
	botao_texto("Trocar piloto  →", _escolher_segundo.bind(vaga), v).alignment = HORIZONTAL_ALIGNMENT_LEFT


## Atributos (decisão 70) e treino do piloto: ritmo, consistência e
## agressividade em barras; a energia (treinar gasta, volta enchendo); o botão
## do próximo nível. `piloto_id` "" = o treino da equipe (sem contratados).
func _treino(pai: Control, piloto_id := "") -> void:
	var base := float(dados.piloto(dados.carreira()["piloto_jogador"])["ritmo"])
	if piloto_id != "":
		var a := EquipeJogador.atributos(dados, jogador, piloto_id)
		# Ritmo: do piloto-base até o teto da licença (a faixa que o treino percorre).
		var teto_r := maxf(GestaoEquipe.teto(dados, jogador), base + 0.0001)
		for it in [["Ritmo", (float(a["ritmo"]) - base) / (teto_r - base), "%.1f%%" % (float(a["ritmo"]) * 100.0)],
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
		var v := rotulo("%.1f%% · teto %.1f%%" % [atual * 100.0, teto * 100.0], FONTE_PEQUENA + 2, Color.WHITE, h)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var agora := Time.get_unix_time_from_system()
	if GestaoEquipe.treinando(jogador, piloto_id):
		var resta := maxf(float(jogador.equipe[GestaoEquipe._chave(piloto_id)]["fim"]) - agora, 0.0)
		rotulo("Treinando o nível %d: a energia enche em %s (também com o app fechado)." % [
				GestaoEquipe.nivel_treino(jogador, piloto_id) + 1, horas_min(resta)], FONTE_PEQUENA, COR_BOM, pai)
		return
	if not GestaoEquipe.pode_treinar(dados, jogador, base, piloto_id):
		rotulo("Ritmo no teto desta licença (%.1f%%). A próxima licença libera mais." % (teto * 100.0),
				FONTE_PEQUENA, COR_SECUNDARIA, pai)
		return
	var preco := GestaoEquipe.preco_treino(dados, jogador, piloto_id)
	var b := Button.new()
	Tipografia.acao_primaria(b, "Treinar ritmo · %s · %s" % [dinheiro(preco), horas_min(GestaoEquipe.duracao_treino(dados, jogador, piloto_id))],
			COR_DESTAQUE, Color(0.1, 0.1, 0.1), 24, 60)
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


## Os candidatos um por vez, de corpo inteiro sob um foco de luz, com as setas
## da garagem para passar; embaixo, nome, traço, frase e Contratar.
func _escolher_segundo(vaga: String = "corrida") -> void:
	var tipo := "corrida" if vaga == "corrida" else "arena"
	var lista: Array = EquipeJogador.candidatos(dados).filter(func(c): return String(c.get("tipo", "corrida")) == tipo)
	var ids := lista.map(func(c): return String(c["id"]))
	var atual_id := EquipeJogador.piloto_vaga(jogador, vaga)
	var estado := {"i": maxi(ids.find(atual_id), 0)}
	painel.emit("Piloto de " + tipo, func(pv):
		var palco := Control.new()
		palco.custom_minimum_size = Vector2(0, PALCO_ALTURA)
		palco.clip_contents = true
		pv.add_child(palco)
		palco.add_child(_foco())
		var chao := _sombra_chao()
		palco.add_child(chao)
		var corpo := TextureRect.new()
		corpo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		corpo.offset_bottom = -18
		corpo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		corpo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		palco.add_child(corpo)
		var contador := Label.new()
		contador.add_theme_font_size_override("font_size", FONTE_PEQUENA)
		contador.add_theme_color_override("font_color", COR_SECUNDARIA)
		palco.add_child(contador)
		contador.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		contador.offset_left = -90
		contador.offset_right = -14
		contador.offset_top = 10
		contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 6)
		pv.add_child(info)
		var nome := Label.new()
		Tipografia.rotulo(nome, "semibold", 40)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_child(nome)
		var selo := CenterContainer.new()
		info.add_child(selo)
		var frase := rotulo("", FONTE_PEQUENA + 2, COR_SECUNDARIA, info)
		frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		frase.custom_minimum_size = Vector2(0, 64)
		var b := Button.new()
		info.add_child(b)
		var na_equipe := Label.new()
		na_equipe.text = "NA EQUIPE"
		Tipografia.rotulo(na_equipe, "semibold", 24)
		na_equipe.add_theme_color_override("font_color", COR_DESTAQUE)
		na_equipe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		na_equipe.custom_minimum_size = Vector2(0, 60)
		na_equipe.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		info.add_child(na_equipe)
		var mostrar := func(lado: int):
			var c: Dictionary = lista[estado["i"]]
			var atual: bool = c["id"] == atual_id
			var outra := EquipeJogador.vaga_do_piloto(jogador, String(c["id"]))
			corpo.texture = Assets.get_asset(String(c["id"]), "corpo")
			nome.text = String(c["nome"])
			for f in selo.get_children():
				f.queue_free()
			var tr: Dictionary = EquipeJogador.config(dados).get("tracos", {}).get(String(c["traco"]), {})
			_selo_traco(String(tr.get("nome", "")), selo)
			frase.text = String(c.get("frase", ""))
			contador.text = "%d / %d" % [estado["i"] + 1, lista.size()]
			Tipografia.acao_primaria(b, "Contratar", COR_DESTAQUE, Color(0.1, 0.1, 0.1), 24, 60)
			b.visible = not atual and outra == ""
			na_equipe.visible = atual or outra != ""
			na_equipe.text = "NA EQUIPE" if atual else ("NA EQUIPE · " + String(EquipeJogador.NOMES_VAGA.get(outra, "")))
			if lado != 0 and not Preferencias.reduzir_animacoes:
				corpo.modulate.a = 0.0
				corpo.position.x = 40.0 * lado
				var tw := corpo.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(corpo, "modulate:a", 1.0, 0.22)
				tw.tween_property(corpo, "position:x", 0.0, 0.28)
		setas_troca(palco, lista.size(), func(lado: int):
			estado["i"] = posmod(estado["i"] + lado, lista.size())
			mostrar.call(lado))
		b.pressed.connect(func():
			var c: Dictionary = lista[estado["i"]]
			var motivo := EquipeJogador.contratar(dados, jogador, String(c["id"]), vaga)
			if motivo != "":
				avisar("Não deu: %s." % motivo, false)
				return
			Sons.tocar_ui(self, "moeda", -4.0)
			avisar("%s contratado: %s." % [c["nome"], String(EquipeJogador.NOMES_VAGA[vaga]).to_lower()])
			fechar_painel.emit()
			mudou.emit()
			historia("PILOTO_CONTRATADO", {"vaga": vaga}))
		mostrar.call(0), [])


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


## Foco de luz quente atrás do piloto (o palco não tem fundo próprio).
func _foco() -> TextureRect:
	var t := TextureRect.new()
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.42)
	g.fill_to = Vector2(0.5, 1.0)
	g.gradient = Gradient.new()
	g.gradient.colors = PackedColorArray([Color(COR_DESTAQUE, 0.22), Color(COR_DESTAQUE, 0.0)])
	t.texture = g
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


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
func _selo_traco(texto: String, pai: Control) -> void:
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
	Tipografia.rotulo(l, "semibold", 18)
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
