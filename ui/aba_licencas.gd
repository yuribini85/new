extends Aba

## Ficha de uma equipe do Grid (VinhetaGrid): id e contexto ("proximo",
## "primeiro", "rever").
signal vinheta(id: String, contexto: String)

## Licenças com a lista de séries liberadas aberta.
var _expandida := {}

const NOMES_CATEGORIA := PecasTexto.NOMES_CATEGORIA
## Brasão da licença atual no topo (altura, px) e o da próxima no cartão.
const ALTURA_BRASAO := 230.0
const BRASAO_CARTAO := 190.0
## Linhas do Grid na tela: id -> {linha, risco}.
var _linhas_grid := {}
var _toque_grid := Vector2.INF


func _init(d: Node, j: Node) -> void:
	super(d, j, "Carreira")


## Carreira: o brasão da licença atual, os objetivos, o cartão da próxima
## licença (só ela) e a coleção por workshop. Recomeçar e a versão ficam nas
## Configurações.
func construir() -> void:
	var l := Licencas.new(dados, jogador)
	var agora := Time.get_unix_time_from_system()
	_brasao()
	_objetivos()
	_meta_dia()
	_the_grid()
	if not _licencas_apresentadas():
		return  # tutorial do dono: licença e coleção só depois de a Mara apresentar
	var c := carro_ativo()
	var proxima := {}
	for lic in dados.lista("licencas"):
		if l.estado(lic["id"], agora) != Licencas.COMPLETE:
			proxima = lic
			break
	if not proxima.is_empty():
		var st := l.estado(proxima["id"], agora)
		var v := _cartao_proxima(l, proxima, st, agora)
		# Sem avaliação (decisão do usuário, 2026-10-17): o treino terminado
		# concede a licença sozinho (Principal._checar_licencas).
		if st == Licencas.TRAINING:
			# Relógio do treino na tela: reconstrói a cada segundo enquanto treina.
			var t := Timer.new()
			t.wait_time = 1.0
			t.autostart = true
			t.timeout.connect(func(): mudou.emit())
			conteudo.add_child(t)
	_colecao()


## No tutorial do dono, a licença entra depois da prova com a primeira peça
## (CW_P06C, SECOND_RACE_DONE); antes disso, a Carreira mostra só o Grid.
func _licencas_apresentadas() -> bool:
	return jogador.historia == null or jogador.personagem != "dono" or not jogador.licencas.is_empty() \
			or jogador.flags.has("SECOND_RACE_DONE") or jogador.flags.has("LICENSE_SYSTEM_UNLOCKED")


## Licença mais alta conquistada (vazio sem nenhuma).
func _licenca_atual() -> Dictionary:
	var atual := {}
	for lic in dados.lista("licencas"):
		if lic["id"] in jogador.licencas:
			atual = lic
	return atual


## Topo: o brasão da licença atual sobre o cenário, com o nome embaixo. Sem
## licença, o brasão da primeira, apagado.
func _brasao() -> void:
	var atual := _licenca_atual()
	var mostrar: Dictionary = atual if not atual.is_empty() else (dados.lista("licencas")[0] if not dados.lista("licencas").is_empty() else {})
	var faixa := ilustracao("fundo_carreira", ALTURA_BRASAO + 140.0)
	cenario_topo(faixa)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 70  # abaixo das abas penduradas do cabeçalho
	v.offset_bottom = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.add_child(v)
	var tex := selo_licenca(String(mostrar.get("id", "")))
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(0, ALTURA_BRASAO)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if atual.is_empty():
			t.modulate = Color(0.35, 0.35, 0.38)
		v.add_child(t)
		if not atual.is_empty():
			ancora("LIC_" + String(atual["id"]), t)
	var nome := Label.new()
	nome.text = String(atual.get("nome", "Sem licença")).to_upper()
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tipografia.rotulo(nome, "semibold", 40)
	nome.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87) if not atual.is_empty() else COR_SECUNDARIA)
	nome.add_theme_constant_override("outline_size", 6)
	nome.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	v.add_child(nome)


## Objetivos no padrão das outras telas: título de seção fora do cartão; o
## próximo passo em destaque (borda ocre, botão principal IR) e, embaixo, a
## lista com ✓ verde nos feitos e um anel nos que faltam.
func _objetivos() -> void:
	var lista := Objetivos.lista(jogador, dados)
	var atual := Objetivos.atual(lista)
	titulo_secao("OBJETIVOS")
	if atual < lista.size():
		var o: Dictionary = lista[atual]
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = COR_CARTAO
		sb.set_corner_radius_all(14)
		sb.set_content_margin_all(18)
		sb.border_color = COR_DESTAQUE
		sb.set_border_width_all(2)
		p.add_theme_stylebox_override("panel", sb)
		conteudo.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		p.add_child(v)
		var k := Label.new()
		k.text = "PRÓXIMO PASSO"
		Tipografia.rotulo(k, "medium", 20)
		k.add_theme_color_override("font_color", COR_DESTAQUE)
		v.add_child(k)
		var t := Label.new()
		t.text = String(o["texto"])
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Tipografia.rotulo(t, "semibold", 32)
		t.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
		v.add_child(t)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		Tipografia.acao_primaria(b, "Ir   →", COR_DESTAQUE, Color(0.1, 0.1, 0.1), 34, Tipografia.ALTURA_SECUNDARIA)
		b.pressed.connect(func(): ir_para.emit(o["aba"]))
		v.add_child(b)
	# Só o que falta (pedido do usuário): os já cumpridos não aparecem.
	var faltam: Array = []
	for i in lista.size():
		if i != atual and not lista[i]["feito"]:
			faltam.append(lista[i])
	if faltam.is_empty():
		return
	var resto := cartao()
	resto.add_theme_constant_override("separation", 6)
	for o in faltam:
		_linha_objetivo(o, resto)


## Meta do dia (decisão 109): as tarefas de hoje com o progresso e, cumprida,
## COLETAR com a recompensa. Some antes das licenças serem apresentadas.
func _meta_dia() -> void:
	if MetaDia.config(dados).is_empty() or not _licencas_apresentadas():
		return
	var est := MetaDia.estado(dados, jogador)
	if est["tarefas"].is_empty():
		return
	titulo_secao("META DO DIA")
	var c := cartao()
	c.add_theme_constant_override("separation", 10)
	var valor := MetaDia.recompensa(dados, jogador)
	for id in est["tarefas"]:
		var t := MetaDia.tarefa(dados, String(id))
		var p := MetaDia.progresso(dados, jogador, String(id))
		var feita: bool = p[0] >= p[1]
		var coletada: bool = id in est["coletadas"]
		var h := fileira(c)
		var tx := rotulo(String(t.get("texto", "")), FONTE_PEQUENA + 2, COR_SECUNDARIA if coletada else Color.WHITE, h)
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if coletada:
			var ok := IconeVetor.new("check", COR_BOM)
			ok.custom_minimum_size = Vector2(34, 34)
			ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(ok)
		elif feita:
			var b := Button.new()
			Tipografia.acao_primaria(b, "COLETAR %s" % dinheiro(valor), COR_DESTAQUE, Color(0.1, 0.1, 0.1), 22, 56)
			b.custom_minimum_size = Vector2(200, 56)
			b.pressed.connect(func():
				var v := MetaDia.coletar(dados, jogador, String(id))
				if v > 0:
					Sons.tocar_ui(self, "moeda", -4.0)
					avisar("Meta do dia: +%s giros." % dinheiro(v))
				mudou.emit())
			h.add_child(b)
		else:
			var n := rotulo("%d/%d" % [p[0], p[1]], 0, COR_DESTAQUE, h)
			Tipografia.numero(n, 26)
			n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rotulo("Cada tarefa paga %s giros. Novas amanhã." % dinheiro(valor), FONTE_PEQUENA - 2, COR_SECUNDARIA, c)


## The Grid, a lista negra (TheGrid): as dez equipes do topo, da #1 em cima à
## #10 embaixo, com o emblema, a licença em que correm e o estado: vencida
## (verde), a da vez (ocre, com o que fazer) ou à frente (apagada).
func _the_grid() -> void:
	var lista: Array = TheGrid.equipes(dados)
	if lista.is_empty():
		return
	var pos: int = TheGrid.posicao(dados, jogador)
	ancora("GRID", titulo_secao("THE GRID"))
	# Fora do Grid, nada: a lista já mostra a da vez (pedido do usuário).
	if pos > 0:
		var sua := rotulo("%s: #%d do Grid." % [IdentidadeEquipe.nome(dados, jogador), pos], FONTE_PEQUENA + 2,
				COR_SECUNDARIA)
		sua.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var vez: Dictionary = TheGrid.da_vez(dados, jogador)
	var feitas: Array = TheGrid.vencidas(jogador)
	var c := cartao()
	c.add_theme_constant_override("separation", 10)
	_linhas_grid = {}
	if vez.is_empty():
		rotulo("O Grid é seu. Ninguém acima.", FONTE_PEQUENA + 2, COR_BOM, c)
	var invertida := lista.duplicate()
	invertida.reverse()  # #1 em cima
	for e in invertida:
		var venc: bool = e["id"] in feitas
		var da_vez: bool = not vez.is_empty() and e["id"] == vez["id"]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		# A linha: a faixa (HBox) e, por cima, o risco das vencidas (camada, não
		# mexe no emblema). Vencida fica apagada e riscada; toque abre a ficha.
		var linha := Control.new()
		linha.custom_minimum_size.y = 148 if da_vez else 128
		linha.modulate = Color(0.72, 0.72, 0.72) if venc else Color(1, 1, 1, 1.0 if da_vez else 0.55)
		linha.mouse_filter = Control.MOUSE_FILTER_PASS
		c.add_child(linha)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.add_child(h)
		# A linha acompanha o texto (a da vez quebra em duas).
		var base_alto := linha.custom_minimum_size.y
		h.minimum_size_changed.connect(func(): linha.custom_minimum_size.y = maxf(base_alto, h.get_combined_minimum_size().y))
		var risco := ColorRect.new()
		risco.color = COR_RUIM
		risco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		risco.anchor_top = 0.5
		risco.anchor_bottom = 0.5
		risco.anchor_right = 1.0
		risco.offset_left = 92
		risco.offset_right = -44
		risco.offset_top = -2
		risco.offset_bottom = 3
		risco.visible = venc
		linha.add_child(risco)
		_linhas_grid[e["id"]] = {"linha": linha, "risco": risco}
		if venc or da_vez:
			linha.gui_input.connect(_toque_linha_grid.bind(String(e["id"])))
		var n := Label.new()
		n.text = "#%d" % int(e["grid"])
		n.custom_minimum_size.x = 92
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Tipografia.numero(n, 50 if da_vez else 44)
		n.add_theme_color_override("font_color", COR_DESTAQUE if da_vez else (COR_BOM if venc else COR_SECUNDARIA))
		h.add_child(n)
		var logo := TextureRect.new()
		logo.texture = load(String(e["logo"])) if ResourceLoader.exists(String(e.get("logo", ""))) else null
		logo.custom_minimum_size = Vector2(136, 136) if da_vez else Vector2(120, 120)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(logo)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", -2)
		h.add_child(v)
		var nome := Label.new()
		nome.text = String(e["nome"]).to_upper()
		Tipografia.rotulo(nome, "semibold", 38 if da_vez else 34)
		nome.add_theme_color_override("font_color", COR_DESTAQUE if da_vez else Color(0.93, 0.91, 0.87))
		v.add_child(nome)
		var lic: Dictionary = dados.item("licencas", String(e.get("nivel", ""))) if dados.existe("licencas", String(e.get("nivel", ""))) else {}
		var nome_lic := String(lic.get("nome", e.get("nivel", "")))
		var detalhe := "VENCIDA" if venc else (("Vença o desafio da equipe (precisa da %s)" % nome_lic) if da_vez else nome_lic)
		var d := Label.new()
		d.text = detalhe
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", FONTE_PEQUENA + 5)
		d.add_theme_color_override("font_color", COR_BOM if venc else COR_SECUNDARIA)
		v.add_child(d)
		if venc:
			var ok := IconeVetor.new("check", COR_BOM)
			ok.custom_minimum_size = Vector2(40, 40)
			ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(ok)
	for id in _linhas_grid:
		var hh: Control = _linhas_grid[id]["linha"].get_child(0)
		_linhas_grid[id]["linha"].custom_minimum_size.y = maxf(_linhas_grid[id]["linha"].custom_minimum_size.y, hh.get_combined_minimum_size().y)
	_animar_grid.call_deferred()


## Toque (sem arrastar) numa linha vencida ou na da vez: reabre a ficha.
func _toque_linha_grid(e: InputEvent, id: String) -> void:
	var botao: bool = e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT
	if not (botao or e is InputEventScreenTouch):
		return
	if e.pressed:
		_toque_grid = e.position
	elif _toque_grid != Vector2.INF and e.position.distance_to(_toque_grid) < 14.0:
		_toque_grid = Vector2.INF
		vinheta.emit(id, "rever")


## Depois de vencer uma equipe: a tela desce até o Grid, o risco atravessa a
## vencida (que apaga), a próxima acende e a ficha dela abre. Sem nada para
## riscar, só a ficha que ainda não apareceu (a #10, na entrada no Grid).
## Nada se repete: o risco e a ficha ficam marcados no save.
func _animar_grid() -> void:
	if not is_visible_in_tree():
		return
	var riscar := TheGrid.riscar_pendente(jogador)
	var ficha := TheGrid.ficha_pendente(dados, jogador)
	var contexto := "primeiro" if TheGrid.vencidas(jogador).is_empty() else "proximo"
	if riscar == "" or not _linhas_grid.has(riscar):
		if riscar != "":
			TheGrid.riscada(jogador)
		if ficha != "":
			vinheta.emit(ficha, contexto)
		return
	TheGrid.riscada(jogador)
	get_node("/root/SaveManager").salvar()
	var linha: Control = _linhas_grid[riscar]["linha"]
	var risco: ColorRect = _linhas_grid[riscar]["risco"]
	# A rolagem só conhece a altura da lista depois do layout.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(linha):
		if ficha != "":
			vinheta.emit(ficha, contexto)
		return
	mostrar_controle(linha)
	if Preferencias.reduzir_animacoes:
		if ficha != "":
			vinheta.emit(ficha, contexto)
		return
	var vez: Dictionary = TheGrid.da_vez(dados, jogador)
	var proxima: Control = _linhas_grid[vez["id"]]["linha"] if not vez.is_empty() and _linhas_grid.has(vez["id"]) else null
	# Estado de antes: a vencida acesa e sem risco; a próxima apagada.
	linha.modulate = Color.WHITE
	risco.pivot_offset = Vector2.ZERO
	risco.scale.x = 0.0
	if proxima != null:
		proxima.modulate = Color(1, 1, 1, 0.55)
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_property(risco, "scale:x", 1.0, 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(linha, "modulate", Color(0.72, 0.72, 0.72), 0.8)
	if proxima != null:
		t.tween_property(proxima, "modulate", Color(1.35, 1.25, 1.0), 0.35)
		t.tween_property(proxima, "modulate", Color.WHITE, 0.45)
	t.tween_interval(0.5)
	if ficha != "":
		t.tween_callback(func(): vinheta.emit(ficha, contexto))


## Requisito de licença como linha da tela: com maiúscula e a contagem "(n)"
## presa à palavra de antes (espaço sem quebra), para não descer sozinha.
static func _texto_requisito(t: String) -> String:
	if t == "":
		return t
	return (t.left(1).to_upper() + t.substr(1)).replace(" (", "\u00a0(")


func _linha_objetivo(o: Dictionary, pai: Control) -> void:
	_linha_marcada(String(o["texto"]), "feito" if o["feito"] else "pendente", pai, 27)


## Linha com marca vetorial: "feito" (✓ verde), "falta" (✗ vermelho) ou
## "pendente" (anel). Usada nos objetivos e nos requisitos de licença.
func _linha_marcada(texto: String, estado: String, pai: Control, tamanho: int) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14 if tamanho > 24 else 10)
	pai.add_child(h)
	var marca := Control.new()
	var lado := 30.0 if tamanho > 24 else 24.0
	marca.custom_minimum_size = Vector2(lado, lado)
	marca.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(marca)
	if estado != "pendente":
		var ok := IconeVetor.new("check" if estado == "feito" else "x", COR_BOM if estado == "feito" else COR_RUIM)
		ok.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ok.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marca.add_child(ok)
	else:
		var anel := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = COR_SECUNDARIA
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(11)
		anel.add_theme_stylebox_override("panel", sb)
		anel.position = Vector2(4, 4)
		anel.size = Vector2(lado - 8.0, lado - 8.0)
		anel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marca.add_child(anel)
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Tipografia.rotulo(l, "regular", tamanho)
	l.add_theme_color_override("font_color", COR_SECUNDARIA if estado == "feito" else Color(0.86, 0.87, 0.9))
	h.add_child(l)


## Coleção por workshop, em lista (a mesma linha das Lojas) com a barra de
## quanto da frota dela você tem; tocar abre os carros (os que faltam, em
## silhueta preta com "descobrir").
func _colecao() -> void:
	var tenho := {}
	for c in jogador.garagem.lista():
		tenho[c.id] = true
	titulo_secao("COLEÇÃO · %d DE %d" % [tenho.size(), dados.lista("carros").size()])
	for w in dados.workshops():
		var carros: Array = dados.lista("carros").filter(func(c): return c["fabricante"] in w.get("fabricantes", []))
		if carros.is_empty():
			continue
		var meus := carros.filter(func(c): return tenho.has(c["id"])).size()
		linha_workshop(w, "%d/%d" % [meus, carros.size()], _abrir_workshop.bind(w, carros, tenho),
				float(meus) / carros.size())


## Os carros da workshop em grade: os seus com foto e nome (tocar abre a
## ficha); os que faltam em silhueta preta, com "descobrir".
func _abrir_workshop(w: Dictionary, carros: Array, tenho: Dictionary) -> void:
	painel.emit(String(w.get("nome", "")), func(pv):
		var g := GridContainer.new()
		g.columns = 3
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 8)
		pv.add_child(g)
		for c in carros:
			var meu: bool = tenho.has(c["id"])
			var b := Button.new()
			b.custom_minimum_size = Vector2(0, 140)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.disabled = not meu
			var sb := StyleBoxFlat.new()
			sb.bg_color = COR_CARTAO.lightened(0.04)
			sb.set_corner_radius_all(10)
			for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
				b.add_theme_stylebox_override(estado, sb)
			var v := VBoxContainer.new()
			v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(v)
			var img := icone_carro(c)
			img.custom_minimum_size = Vector2(0, 96)
			if not meu:
				img.modulate = Color(0, 0, 0)  # silhueta 100% preta
			v.add_child(img)
			var l := Label.new()
			l.text = nome_curto(c["nome"]) if meu else "DESCOBRIR"
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			Tipografia.rotulo(l, "medium" if meu else "semibold", 20)
			l.add_theme_color_override("font_color", Color.WHITE if meu else COR_SECUNDARIA)
			l.add_theme_color_override("font_disabled_color", COR_SECUNDARIA)
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.clip_text = true
			v.add_child(l)
			if meu:
				b.pressed.connect(func(): ficha_modelo(c))
			g.add_child(b), [["Fechar", func(): pass]])


## Renda por nível de licença, somando as sessões registradas: base medida
## para decidir patrocínio e staff (decisão 38), sem estimar.
func _renda(v: VBoxContainer, sessoes: Array) -> void:
	var r := RegistroSessao.renda_por_nivel(sessoes)
	if r.is_empty():
		return
	rotulo("Renda por nível (todas as sessões)", FONTE_PEQUENA + 2, Color.WHITE, v)
	var ordem: Array = dados.carreira().get("niveis", [])
	var niveis: Array = r.keys()
	niveis.sort_custom(func(a, b): return ordem.find(a) < ordem.find(b))
	for n in niveis:
		var x: Dictionary = r[n]
		var ganho: int = int(x["premio"]) + int(x["bonus"])
		var minutos: float = float(x["duracao_s"]) / 60.0
		rotulo("%s: %d corrida%s · %d%% vitórias · %s giros por corrida · %s giros por minuto de corrida%s" % [
				n, x["corridas"], "" if x["corridas"] == 1 else "s", roundi(100.0 * x["vitorias"] / x["corridas"]),
				dinheiro(roundi(float(ganho) / x["corridas"])),
				dinheiro(roundi(ganho / minutos)) if minutos > 0.0 else "—",
				" · %d com o jogo fechado" % x["offline"] if int(x["offline"]) > 0 else ""],
				FONTE_PEQUENA, COR_SECUNDARIA, v)


## Saves de teste (Cenarios): cada um num arquivo próprio; o seu jogo não muda.
func _cenarios(v: VBoxContainer) -> void:
	var sm := get_node("/root/SaveManager")
	rotulo("Cenários de teste", FONTE_PEQUENA + 2, Color.WHITE, v)
	if sm.cenario != "":
		rotulo("Em uso: %s" % _nome_cenario(sm.cenario), FONTE_PEQUENA, COR_INFO, v)
		botao("Voltar ao meu jogo", func():
			sm.voltar_ao_jogo()
			avisar("De volta ao seu jogo.")
			ir_para.emit(GARAGEM), true, true, v)
	for c in Cenarios.LISTA:
		linha(String(c["nome"]), [["Abrir", _abrir_cenario.bind(c)]], null, v)
		rotulo(String(c["detalhe"]), FONTE_PEQUENA - 2, COR_SECUNDARIA, v)


func _abrir_cenario(c: Dictionary) -> void:
	var erro: String = get_node("/root/SaveManager").usar_cenario(String(c["id"]))
	if erro != "":
		avisar("Não deu: %s." % erro, false)
		return
	avisar("Cenário: %s. Seu jogo ficou salvo." % c["nome"])
	ir_para.emit(GARAGEM)


static func _nome_cenario(id: String) -> String:
	for c in Cenarios.LISTA:
		if c["id"] == id:
			return String(c["nome"])
	return id


## Playtest (docs/playtest_percurso.md): modo e resumo do registro local. Fica
## na tela de Configurações (engrenagem do cabeçalho).
func _modo_teste(v: VBoxContainer) -> void:
	separador(v)
	rotulo("Modo de playtest", FONTE_PEQUENA + 2, Color.WHITE, v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for m in [["", "Desligado"], ["clareza", "Clareza"], ["ritmo", "Ritmo"]]:
		var b := Button.new()
		b.text = m[1]
		b.toggle_mode = true
		b.button_pressed = Preferencias.modo_teste == m[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 58)
		b.pressed.connect(func():
			if Preferencias.modo_teste != "":
				RegistroSessao.fim(jogador)
			Preferencias.modo_teste = m[0]
			Preferencias.salvar()
			RegistroSessao.inicio(jogador)
			mudou.emit())
		h.add_child(b)
	v.add_child(h)
	nota("", "Só para testes", "Clareza: pode pular a corrida. Ritmo: sem pular, para medir sessão e renda. "
			+ "Ligado, o aparelho registra as sessões (só local).", v)
	if Preferencias.modo_teste != "" and Preferencias.ferramentas_teste():
		_cenarios(v)
		# A loja do aparelho ainda não existe: libera as compras para testar.
		botao("Liberar as compras da Loja (teste)", func():
			for p in LojaReal.produtos(dados):
				LojaReal.conceder(dados, jogador, String(p["id"]))
			get_node("/root/SaveManager").salvar()
			avisar("Compras liberadas (teste).")
			mudou.emit(), false, true, v)
	var sessoes := RegistroSessao.sessoes()
	if sessoes.is_empty():
		return
	for i in sessoes.size():
		var s: Dictionary = sessoes[i]
		var dur: float = float(s["fim"]) - float(s["inicio"])
		var corrida: float = float(s["telas"].get("Corrida", 0.0))
		var minutos_fila := 0.0
		for f in s["filas"]:
			minutos_fila += float(f["duracao_s"]) * int(f["repeticoes"]) / 60.0
		var aus: float = float(s["ausencia_antes_s"])
		rotulo("Sessão %d (%s): %.0f min · assistindo %.0f min · %d fila%s (%.0f min) · %d pulo%s · %s→%s · %s→%s giros%s" % [
				i + 1, s["modo"], dur / 60.0, corrida / 60.0, s["filas"].size(), "" if s["filas"].size() == 1 else "s",
				minutos_fila, s["pulos"], "" if s["pulos"] == 1 else "s", s["fase_inicio"], s["fase_fim"],
				dinheiro(int(s["saldo_inicio"])), dinheiro(int(s["saldo_fim"])),
				" · ausente %.0f min antes" % (aus / 60.0) if aus >= 0.0 else ""], FONTE_PEQUENA, COR_SECUNDARIA, v)
		var fc: Array = s.get("fps_corrida", [])
		if not fc.is_empty():
			var o := fc.duplicate()
			o.sort()
			rotulo("    corrida: %d fps (mediana) · %d fps (pior 5%%)" % [o[o.size() / 2], o[int(o.size() * 0.05)]],
					FONTE_PEQUENA, COR_SECUNDARIA, v)
	_renda(v, sessoes)
	rotulo("Arquivo: %s" % ProjectSettings.globalize_path(RegistroSessao.CAMINHO), FONTE_PEQUENA - 2, COR_NEUTRA, v)
	botao_texto("Apagar registro", func():
		RegistroSessao.limpar()
		RegistroSessao.inicio(jogador)
		mudou.emit(), v)


func _recomecar() -> void:
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.carro_ativo = -1
	jogador.ultima_corrida = {}
	if not dados.historia().is_empty():
		Prologo.iniciar(dados, jogador)  # recomeça pelo prólogo (decisão 32)
	avisar("Carreira recomeçada com %s giros." % dinheiro(jogador.economia.saldo))
	ir_para.emit(GARAGEM)
	historia("GAME_START")


const TEXTO_ESTADO := {
	Licencas.LOCKED: "BLOQUEADA", Licencas.AVAILABLE: "PRONTA PARA TREINAR", Licencas.TRAINING: "EM TREINO",
	Licencas.READY: "TREINO CONCLUÍDO", Licencas.COMPLETE: "CONQUISTADA",
}


## Cartão da próxima licença (decisão 33), no formato do cartão de corrida:
## o brasão à esquerda; à direita o nome, o que libera, os requisitos e o
## treino; embaixo, a ação (iniciar o treino) ou o andamento. Retorna a coluna
## do cartão.
func _cartao_proxima(l: Licencas, lic: Dictionary, st: String, agora: float) -> VBoxContainer:
	var v := cartao_com_fundo(arte("fundo_carreira"), st != Licencas.LOCKED)
	ancora("LICENSE_REQUIREMENTS", v)
	ancora("LIC_" + String(lic["id"]), v)
	if st == Licencas.AVAILABLE:
		historia("LICENCA_DISPONIVEL:" + String(lic["id"]))
	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 14)
	v.add_child(corpo)
	var esq := VBoxContainer.new()
	esq.custom_minimum_size = Vector2(170, 0)
	esq.alignment = BoxContainer.ALIGNMENT_CENTER
	corpo.add_child(esq)
	var tex := selo_licenca(String(lic["id"]))
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(170, BRASAO_CARTAO)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if st == Licencas.LOCKED:
			t.modulate = Color(0.45, 0.45, 0.48)
		esq.add_child(t)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	corpo.add_child(col)
	var sobre := rotulo("PRÓXIMA LICENÇA · " + TEXTO_ESTADO[st], 0, COR_SECUNDARIA, col)
	Tipografia.rotulo(sobre, "medium", 18)
	sobre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var titulo := Label.new()
	titulo.text = String(lic["nome"]).to_upper()
	Tipografia.rotulo(titulo, "semibold", 40)
	titulo.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	col.add_child(titulo)
	var provas: int = dados.lista("eventos").filter(func(e): return e["restricoes"].get("licenca") == lic["id"]).size()
	var dur := l.treino_s(lic["id"])
	var libera := rotulo("Libera %d corrida%s · treino de %s" % [provas, "" if provas == 1 else "s", _duracao(dur)], 0,
			Color(0.86, 0.87, 0.9), col)
	libera.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Tipografia.rotulo(libera, "regular", 27)
	for r in l.requisitos(lic["id"]):
		_linha_marcada(_texto_requisito(String(r["texto"])), "feito" if r["ok"] else "falta", col, 24)
	match st:
		Licencas.AVAILABLE:
			rotulo("Grátis · continua com o jogo fechado", FONTE_PEQUENA - 2, COR_SECUNDARIA, col)
			var b := Button.new()
			Tipografia.acao_primaria(b, "Iniciar treino   →", COR_DESTAQUE, Color(0.1, 0.1, 0.1), 34, Tipografia.ALTURA_SECUNDARIA)
			b.pressed.connect(func():
				var erro := l.iniciar_treino(lic["id"], Time.get_unix_time_from_system())
				if erro != "":
					avisar(erro, false)
				else:
					historia("LICENCA_TREINO_INICIO")
				mudou.emit())
			v.add_child(b)
		Licencas.TRAINING:
			var falta := l.restante(lic["id"], agora)
			var barra := BarraDentes.new(roundi(10.0 * (1.0 - falta / maxf(dur, 1.0))), 10, 10.0)
			col.add_child(barra)
			rotulo("Treino: faltam %s" % _duracao(falta), FONTE_PEQUENA, COR_INFO, col)
		Licencas.READY:
			rotulo("Treino concluído: a licença sai em instantes.", FONTE_PEQUENA, COR_BOM, col)
	return v


static func _duracao(s: float) -> String:
	var t := ceili(s)
	if t >= 3600:
		return "%d h %02d min" % [t / 3600, (t % 3600) / 60]
	if t >= 60:
		return "%d min %02d s" % [t / 60, t % 60]
	return "%d s" % t
