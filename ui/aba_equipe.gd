extends Aba
## Equipe do jogador (Second Driver Motorsport), visível depois de criada.
## Placeholders (documento, seção 4): logo = texto da equipe. Gestão leve
## (fase 9): caixa, folha por corrida, segundo piloto e o carro dele.


func _init(d: Node, j: Node) -> void:
	super(d, j, "Equipe")


func construir() -> void:
	var eq := EquipeJogador.dados_equipe(dados, jogador)
	if eq.is_empty():
		cabecalho("Equipe")
		rotulo("A equipe ainda não existe.", 0, COR_SECUNDARIA)
		return
	_topo(eq)
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
	var tex := Assets.get_asset(String(eq["id"]), "logo") if String(eq.get("logo", "")) != "" else null
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
	sub.text = "M O T O R S P O R T"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tipografia.rotulo(sub, "medium", 24)
	sub.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	v.add_child(sub)


## Caixa único (o saldo) e a folha de cada corrida.
func _caixa() -> void:
	titulo_secao("CAIXA", "Patrocínio e staff entram e saem a cada corrida; os prêmios caem no mesmo caixa.")
	var c := cartao()
	var h := fileira(c)
	var moeda_i := icone("cabecalho/icone_giros", 40, h)
	moeda_i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n := Label.new()
	n.text = dinheiro(jogador.economia.saldo)
	Tipografia.numero(n, 44)
	n.add_theme_color_override("font_color", COR_DESTAQUE)
	h.add_child(n)
	var f := EquipeJogador.folha(dados, jogador)
	_linha_folha(c, "Patrocínio por corrida", "patrocinio", int(f["patrocinio"]), "+")
	_linha_folha(c, "Staff por corrida", "custo_staff", int(f["staff"]), "−")


func _linha_folha(pai: Control, texto: String, chave: String, v: int, sinal: String) -> void:
	var definido := EquipeJogador.definido(dados, chave)
	var h := fileira(pai)
	var l := rotulo(texto, FONTE_PEQUENA + 2, COR_SECUNDARIA, h)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := rotulo("%s %s giros" % [sinal, dinheiro(v)] if definido else "a definir no playtest", FONTE_PEQUENA + 2,
			Color.WHITE if definido else COR_NEUTRA.lightened(0.3), h)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _pilotos(eq: Dictionary) -> void:
	titulo_secao("PILOTOS")
	var c := cartao()
	if Prologo.piloto(dados, jogador) != "":
		_linha_piloto(c, EquipeJogador.nome_jogador(dados, jogador), "PILOTO PRINCIPAL")
	for p in eq.get("pilotos", []):
		if String(p["id"]).begins_with(String(jogador.personagem) + "_"):
			_linha_piloto(c, String(p["nome"]), "PILOTO PRINCIPAL")
	if jogador.segundo_piloto != "":
		_linha_piloto(c, EquipeJogador.nome_segundo(dados, jogador), "SEGUNDO PILOTO")
		nota("icone_piloto", "Corre com você", "Na mesma prova, com outro carro da garagem. "
				+ "Vale para a equipe quem chegar na frente; os dois pontuam no campeonato.", c)
		_carro_companheiro()
	else:
		nota("icone_info", "Segundo piloto", "Um segundo piloto chega mais adiante na carreira.", c)


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


## Carro do segundo piloto: qualquer carro da garagem; corre se for elegível
## e diferente do seu na prova. Miniaturas como na janela da garagem.
func _carro_companheiro() -> void:
	var carros: Array = jogador.garagem.lista()
	titulo_secao("CARRO DO SEGUNDO PILOTO")
	if carros.size() < 2:
		nota("icone_alerta", "Falta um segundo carro", "Compre outro carro para o segundo piloto correr com você.")
		return
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	conteudo.add_child(g)
	for car in carros:
		var escolhido: bool = car.uid == jogador.carro_companheiro
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 146)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = COR_CARTAO
		sb.set_corner_radius_all(8)
		sb.border_color = COR_DESTAQUE if escolhido else Color(1, 1, 1, 0.08)
		sb.set_border_width_all(2)
		for estado in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(estado, sb)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		b.add_child(v)
		var img := icone_carro(car.base, false, CarroBloco.cor_do_carro(car))
		img.custom_minimum_size = Vector2(0, 100)
		v.add_child(img)
		var l := Label.new()
		l.text = nome_curto(car.base["nome"])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Tipografia.rotulo(l, "medium", 22)
		l.add_theme_color_override("font_color", COR_DESTAQUE if escolhido else Color.WHITE)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		v.add_child(l)
		b.pressed.connect(func():
			jogador.carro_companheiro = car.uid
			mudou.emit())
		g.add_child(b)
	if jogador.garagem.carro(jogador.carro_companheiro) == null:
		rotulo("Escolha um carro para ele correr.", FONTE_PEQUENA, COR_RUIM)
