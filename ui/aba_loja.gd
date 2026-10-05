extends Aba

## Perspectiva para quem está escolhendo o primeiro carro: faixa de posição de
## cada usado, de fábrica, em corridas simuladas da primeira prova sem licença
## (a de menor prêmio). Estimativa, não promessa. Uma vez por dia de jogo.
var _previsao := {}  # {"dia", "evento", "avaliacoes": {carro_id: Mecanico.avaliar()}}


func _init(d: Node, j: Node) -> void:
	super(d, j, "Mercado")


## "usados" ou "novos": a seção aberta (mantida ao voltar para o Mercado).
var _secao := "usados"


func construir() -> void:
	rotulo("Mercado", FONTE_TITULO)
	var ofertas := Usados.estoque(dados.lista("carros"), jogador.dias, jogador.usados_vendidos)
	var novos: Array = dados.lista("carros").filter(func(c): return c.get("novo", true))
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 8)
	for s in [["usados", "Usados (%d)" % ofertas.size()], ["novos", "Novos (%d)" % novos.size()]]:
		var b := Button.new()
		b.text = s[1]
		b.toggle_mode = true
		b.button_pressed = _secao == s[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(func():
			_secao = s[0]
			mudou.emit())
		abas.add_child(b)
	conteudo.add_child(abas)
	if _secao == "usados":
		rotulo("Mudam conforme você corre (cada corrida é um dia). %s" % (
				"★ = foi bem nos testes da prova mais fácil." if jogador.garagem.lista().is_empty() else ""),
				FONTE_PEQUENA, COR_SECUNDARIA)
		if ofertas.is_empty():
			rotulo("Nenhum usado hoje. Volte depois de algumas corridas.", 0, COR_SECUNDARIA)
		var prev := _prever(ofertas)
		var grade := _grade()
		for o in ofertas:
			var c: Dictionary = dados.carro(o["carro_id"])
			var a: Dictionary = prev.get("avaliacoes", {}).get(o["carro_id"], {})
			var estrela: bool = not a.is_empty() and a["media"] <= 1.5
			var restam: int = int(o.get("fim", jogador.dias)) - jogador.dias + 1
			var extras := [["sai em %d corrida%s" % [restam, "" if restam == 1 else "s"], COR_NEUTRA.lightened(0.3)]]
			if not a.is_empty():
				extras.push_front(["%s%s nos testes, de fábrica, em %s" % ["★ " if estrela else "",
						Mecanico.texto_faixa(a["faixa"]), prev["evento"]], COR_BOM if estrela else COR_NEUTRA.lightened(0.3)])
			_bloco(grade, c, int(o["preco"]), "★" if estrela else "", extras,
					func(): _escolher(jogador.concessionaria.comprar_usado(o, c, jogador.usados_vendidos), c, int(o["preco"])))
	else:
		rotulo("Sempre disponíveis. Modelos antigos só aparecem nos usados.", FONTE_PEQUENA, COR_SECUNDARIA)
		var grade := _grade()
		for c in novos:
			_bloco(grade, c, int(c["preco"]), "", [], func(): _escolher(jogador.concessionaria.comprar_carro(c), c, int(c["preco"])))


func _grade() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	conteudo.add_child(g)
	return g


## Bloco do catálogo: foto, nome, preço e o essencial (potência e tração).
## Tocar abre a ficha, onde está o botão de compra.
func _bloco(grade: GridContainer, c: Dictionary, preco: int, marca: String, extras: Array, comprar: Callable) -> void:
	var pode: bool = jogador.economia.pode_pagar(preco)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 250)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_CARTAO
	sb.set_corner_radius_all(14)
	for estado in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(estado, sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 6
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var img := icone_carro(c)
	img.custom_minimum_size = Vector2(0, 120)
	v.add_child(img)
	for t in [[c["nome"] + ("  " + marca if marca != "" else ""), 27, Color.WHITE],
			["%d cv · %s" % [c["potencia"], c["tracao"]], 23, COR_SECUNDARIA],
			["%s Cr" % dinheiro(preco), 32, Color.WHITE if pode else Color(0.72, 0.73, 0.78)]]:
		var l := Label.new()
		l.text = t[0]
		l.add_theme_font_size_override("font_size", t[1])
		l.add_theme_color_override("font_color", t[2])
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		v.add_child(l)
	var falta := "" if pode else "Faltam %s Cr" % dinheiro(preco - jogador.economia.saldo)
	b.pressed.connect(func(): ficha_modelo(c, extras + [["revenda %s Cr" % dinheiro(revenda(c)), COR_NEUTRA.lightened(0.3)]],
			["Comprar · %s Cr" % dinheiro(preco), comprar, true] if pode else [falta, comprar, false]))
	grade.add_child(b)


func _prever(ofertas: Array) -> Dictionary:
	if jogador.carreira == null:
		return {}
	if _previsao.get("dia", -1) == jogador.dias:
		return _previsao
	var sem_licenca: Array = dados.lista("eventos").filter(func(e): return not e["restricoes"].has("licenca") and not e["premios"].is_empty())
	if sem_licenca.is_empty():
		return {}
	sem_licenca.sort_custom(func(a, b): return a["premios"][0] < b["premios"][0])
	var ev: Dictionary = sem_licenca[0]
	var avaliacoes := {}
	for o in ofertas:
		var c := Carro.new(dados.carro(o["carro_id"]))
		c.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
		avaliacoes[o["carro_id"]] = Mecanico.avaliar(jogador.carreira, ev["id"], -1, c)
	_previsao = {"dia": jogador.dias, "evento": ev["nome"], "avaliacoes": avaliacoes}
	return _previsao


## O primeiro carro já entra em uso, e a tela vai para a Garagem, que mostra o
## próximo passo.
func _escolher(uid: int, c: Dictionary, preco: int) -> void:
	if uid <= 0:
		avisar("Não deu para comprar %s: %s." % [c["nome"], "saldo insuficiente" if not jogador.economia.pode_pagar(preco)
				else "saiu do estoque"], false)
		return
	if jogador.carro_ativo < 0:
		jogador.carro_ativo = uid
	entrega(jogador.garagem.carro(uid))
