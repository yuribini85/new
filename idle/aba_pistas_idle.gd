class_name PistasIdle
extends ScrollContainer
## Tela PISTAS do The Fastfather (docs/idle/plano.md): as cinco modalidades
## e o caminho de cada uma. No alto, uma placa por modalidade (aberta, a da
## corrida em ocre, fechada com o cadeado e o que falta para abrir); embaixo, a
## escada das ligas da modalidade escolhida, da primeira à última, com a pista,
## o carro (fora das divisões de época), o prêmio do 1º lugar e onde a equipe está. CORRER AQUI leva a
## corrida para a modalidade escolhida.

signal correr_em(modalidade: String)

var tela: Node  # tela_idle.gd: estado, dados
var _escolhida := ""
var _lista: VBoxContainer


func _init(tela_: Node) -> void:
	tela = tela_
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 12)
	add_child(_lista)
	IdleUI.rolagem_fina(self)


## Mural de cartazes de corrida colados na parede de tijolo, atrás da lista
## (data/idle/cenas.json → "cartazes"): papel creme e vinho, letreiro art
## déco, cada um levemente torto; apagados para a lista ler bem por cima.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1a110d"))
	for y in range(0, int(size.y), 26):
		var desloc := 0.0 if (y / 26) % 2 == 0 else 34.0
		for x in range(-68, int(size.x), 68):
			draw_rect(Rect2(x + desloc + 2, y + 2, 64, 22), Color("2a1912"))
	var textos: Array = CenaQuadrinho.carregar("cartazes").get("textos", [])
	if textos.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1931
	var deco := Tipografia.fonte("deco")
	var faixa := Tipografia.fonte("display")
	var k := 0
	var y := 30.0
	while y < size.y:
		for coluna in 2:
			var t: Array = textos[k % textos.size()]
			k += 1
			var c := Vector2(size.x * (0.27 + 0.46 * coluna) + rng.randf_range(-30, 30), y + rng.randf_range(0, 60))
			var papel := Color("e3d6b4") if k % 3 != 0 else Color("7e2522")
			var tinta := Color("6e1a1d") if k % 3 != 0 else Color("e9dfc4")
			draw_set_transform(c, deg_to_rad(rng.randf_range(-6.0, 6.0)))
			draw_rect(Rect2(-150, -100, 300, 200), Color(papel, 0.42))
			draw_rect(Rect2(-140, -90, 280, 180), Color(tinta, 0.35), false, 3.0)
			draw_string(deco, Vector2(-130, -20), String(t[0]), HORIZONTAL_ALIGNMENT_CENTER, 260, 30, Color(tinta, 0.5))
			draw_string(faixa, Vector2(-130, 40), String(t[1]), HORIZONTAL_ALIGNMENT_CENTER, 260, 22, Color(tinta, 0.45))
			draw_set_transform(Vector2.ZERO)
		y += 260.0


func atualizar() -> void:
	var e: IdleEstado = tela.estado
	if _escolhida == "" or not e.liberada(_escolhida):
		_escolhida = e.modalidade
	for c in _lista.get_children():
		c.queue_free()
	_nova_cidade(e)
	_modalidades(e)
	_cabecalho(e)
	_escada(e)


## Prestígio: depois do Grande Campeonato, a família pode mudar de cidade
## (cfg "cidades"). Primeiro toque arma, o segundo confirma.
func _nova_cidade(e: IdleEstado) -> void:
	if not e.pode_mudar_de_cidade():
		return
	var proxima: Dictionary = tela.cidade(e.cidade + 1)
	var mult := float(e.cfg_cidades().get("multiplicador", 1.0))
	var p := IdleUI.painel(IdleUI.COR_CARTAO, 12, 16, _lista)
	p.add_child(MolduraDeco.new(5.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	IdleUI.rotulo("NOVA CIDADE", 34, IdleUI.COR_OURO_CLARO, v, "deco")
	IdleUI.rotulo("%s · %s" % [String(proxima["lugar"]).to_upper(), proxima["ano"]], 26, IdleUI.COR_TEXTO, v, "display")
	IdleUI.rotulo("Lucro e prêmios ×%s para sempre" % IdleUI.curto(e.multiplicador_cidade() * mult), 22, IdleUI.COR_GANHO, v)
	var aviso := IdleUI.rotulo("Ficam: troféus, capangas e carros. Recomeçam: dinheiro, melhorias e ligas.",
			20, IdleUI.COR_SECUNDARIA, v)
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.custom_minimum_size.x = 600
	var b := IdleUI.botao("MUDAR PARA %s" % String(proxima["lugar"]).get_slice(",", 0).to_upper(), IdleUI.COR_OURO, 26, 96, v)
	var armado := [false]
	b.pressed.connect(func():
		if not armado[0]:
			armado[0] = true
			b.text = "CONFIRMAR MUDANÇA"
			IdleUI.pulsar(b, 1.06)
			return
		tela.mudar_de_cidade())


func _modalidades(e: IdleEstado) -> void:
	var grade := GridContainer.new()
	grade.columns = 5
	grade.add_theme_constant_override("h_separation", 8)
	_lista.add_child(grade)
	for m in e.cfg["modalidades"]:
		var id := String(m["id"])
		var aberta := e.liberada(id)
		if not aberta:
			continue  # o que ainda não abriu não aparece: a descoberta fica para quando abrir
		var marcada := id == _escolhida
		var na_corrida := id == e.modalidade
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 132)
		var cor := IdleUI.COR_CARTAO_CLARO if aberta else IdleUI.COR_CARTAO
		var borda := IdleUI.COR_OURO if marcada else IdleUI.COR_BORDA
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, IdleUI.caixa(cor, 12, 6, borda, 3 if marcada else 1))
		b.pressed.connect(func():
			Sons.tocar_ui(self, "toque", -6.0)
			_escolhida = id
			atualizar())
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 2)
		b.add_child(v)
		IdleUI.icone(String(m.get("icone", "icone_pista")) if aberta else "icone_cadeado", 44, v,
				IdleUI.COR_TEXTO if aberta else IdleUI.COR_BLOQUEADO)
		var n := IdleUI.rotulo(String(m.get("curto", m["nome"])).to_upper(), 17, IdleUI.COR_OURO if na_corrida else
				(IdleUI.COR_TEXTO if aberta else IdleUI.COR_BLOQUEADO), v)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.clip_text = true
		var sub := "LIGA %d/%d" % [int(e._m(id)["liga"]) + 1, m["ligas"].size()] if aberta else "FECHADA"
		var s := IdleUI.rotulo(sub, 14, IdleUI.COR_SECUNDARIA if aberta else IdleUI.COR_BLOQUEADO, v)
		s.clip_text = true
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grade.add_child(b)


func _cabecalho(e: IdleEstado) -> void:
	var m := e.dados_modalidade(_escolhida)
	var aberta := e.liberada(_escolhida)
	var placa := Control.new()
	placa.custom_minimum_size = Vector2(0, 200)
	placa.clip_contents = true
	_lista.add_child(placa)
	var liga_atual: Dictionary = m["ligas"][int(e._m(_escolhida)["liga"])] if aberta else m["ligas"][0]
	var img := IdleUI.imagem_cobrindo(IdleUI.banner_pista(String(liga_atual["pista"])), 200, placa,
			0.55 if aberta else 0.25)
	img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_right = -18
	v.offset_top = 14
	v.offset_bottom = -14
	v.alignment = BoxContainer.ALIGNMENT_END
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placa.add_child(v)
	IdleUI.rotulo(String(m["nome"]).to_upper(), 40, IdleUI.COR_TEXTO, v, "deco")
	if not aberta:
		var lib: Dictionary = m.get("libera", {})
		var antes := e.dados_modalidade(String(lib.get("modalidade", "")))
		IdleUI.rotulo("Abre quando %s chegar à liga %d" % [String(antes.get("nome", "")).to_upper(), int(lib.get("liga", 0)) + 1],
				22, IdleUI.COR_OURO, v)
		return
	var linha := HBoxContainer.new()
	v.add_child(linha)
	var renda := IdleUI.rotulo("RENDA $%s/s" % IdleUI.curto(e.renda_modalidade(_escolhida)), 24, IdleUI.COR_DINHEIRO, linha)
	renda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if e.e_arena(_escolhida):
		# A Rinha roda sozinha ao lado da corrida, com o melhor dos rapazes.
		var r := e.melhor_rapaz()
		IdleUI.rotulo(PilotosIdle.nome_rapaz(r).to_upper() if not r.is_empty() else "SEM CAPANGAS", 22,
				IdleUI.COR_TEXTO if not r.is_empty() else IdleUI.COR_RUIM, linha)
		IdleUI.rotulo("Luta sozinha o tempo todo: assista na aba RINHA.", 20, IdleUI.COR_OURO, _lista)
		return
	# Quem corre é sempre o sobrinho.
	IdleUI.rotulo("O SOBRINHO", 22, IdleUI.COR_TEXTO, linha)
	if _escolhida != e.modalidade:
		var b := IdleUI.botao("CORRER AQUI", IdleUI.COR_BOTAO, 26, 64, _lista)
		b.pressed.connect(func(): correr_em.emit(_escolhida))


func _escada(e: IdleEstado) -> void:
	var m := e.dados_modalidade(_escolhida)
	var aberta := e.liberada(_escolhida)
	var atual := int(e._m(_escolhida)["liga"]) if aberta else -1
	var venceu := bool(e._m(_escolhida)["venceu"]) if aberta else false
	# As ligas feitas, a atual e só a próxima (o alvo); as de depois não aparecem.
	for i in mini(m["ligas"].size(), atual + 2):
		var l: Dictionary = m["ligas"][i]
		var feita: bool = i < atual or (i == atual and venceu)
		var aqui: bool = i == atual
		var fechada: bool = i > atual
		var p := PanelContainer.new()
		var borda := IdleUI.COR_OURO if aqui else IdleUI.COR_BORDA
		p.add_theme_stylebox_override("panel", IdleUI.caixa(IdleUI.COR_CARTAO_CLARO if aqui else IdleUI.COR_CARTAO, 12, 8,
				borda, 3 if aqui else 1))
		_lista.add_child(p)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		p.add_child(h)
		var num := IdleUI.rotulo(str(i + 1), 40, IdleUI.COR_OURO if aqui else (IdleUI.COR_TEXTO if feita else IdleUI.COR_BLOQUEADO),
				h, "display")
		num.custom_minimum_size = Vector2(44, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var mini := IdleUI.imagem_cobrindo(IdleUI.banner_pista(String(l["pista"])), 84, h, 1.0 if not fechada else 0.35)
		mini.custom_minimum_size = Vector2(110, 84)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(v)
		var nome := IdleUI.rotulo(String(l["nome"]).to_upper(), 22, IdleUI.COR_TEXTO if not fechada else IdleUI.COR_BLOQUEADO, v)
		nome.clip_text = true
		# Divisão de época: o carro é o da garagem (o mesmo em todas as ligas).
		var detalhes := [_nome_pista(String(l["pista"]))]
		if not m.has("epoca"):
			var carro: Array = IdleEstado._perto_de(tela.dados, float(l["potencia"]) * float(e.cfg["carro_do_jogador"]),
					m.get("categorias", []))
			detalhes.append(String(carro[0]["nome"]) if not carro.is_empty() else "")
		for detalhe in detalhes:
			var d := IdleUI.rotulo(detalhe, 17, IdleUI.COR_SECUNDARIA, v, "regular")
			d.clip_text = true
		var dir := VBoxContainer.new()
		dir.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(dir)
		if feita:
			IdleUI.icone("icone_ok", 34, dir)
		elif aqui:
			IdleUI.rotulo("ATUAL", 18, IdleUI.COR_OURO, dir).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			IdleUI.icone("icone_cadeado", 30, dir, IdleUI.COR_BLOQUEADO)
		var premio := IdleUI.rotulo("1º $%s" % IdleUI.curto(float(e.cfg["premio_p1"]) * float(l["multiplicador"])), 16,
				IdleUI.COR_DINHEIRO if not fechada else IdleUI.COR_BLOQUEADO, dir)
		premio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _nome_pista(id: String) -> String:
	for a in tela.dados.arena().get("arenas", []):
		if String(a["id"]) == id:
			return String(a["nome"])
	return IdleUI.nome_pista(id)
