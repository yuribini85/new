class_name PistasIdle
extends ScrollContainer
## Tela PISTAS do Chrome Racing Team (docs/idle/plano.md): as cinco modalidades
## e o caminho de cada uma. No alto, uma placa por modalidade (aberta, a da
## corrida em ocre, fechada com o cadeado e o que falta para abrir); embaixo, a
## escada das ligas da modalidade escolhida, da primeira à última, com a pista,
## o carro, o prêmio do 1º lugar e onde a equipe está. CORRER AQUI leva a
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


func atualizar() -> void:
	var e: IdleEstado = tela.estado
	if _escolhida == "" or not e.liberada(_escolhida):
		_escolhida = e.modalidade
	for c in _lista.get_children():
		c.queue_free()
	_modalidades(e)
	_cabecalho(e)
	_escada(e)


func _modalidades(e: IdleEstado) -> void:
	var grade := GridContainer.new()
	grade.columns = 5
	grade.add_theme_constant_override("h_separation", 8)
	_lista.add_child(grade)
	for m in e.cfg["modalidades"]:
		var id := String(m["id"])
		var aberta := e.liberada(id)
		var marcada := id == _escolhida
		var na_corrida := id == e.modalidade
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 132)
		var cor := IdleUI.COR_CARTAO_CLARO if aberta else IdleUI.COR_CARTAO
		var borda := IdleUI.COR_OURO if marcada else Color(1, 1, 1, 0.08)
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, IdleUI.caixa(cor, 12, 6, borda, 3 if marcada else 1))
		b.pressed.connect(func():
			_escolhida = id
			atualizar())
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 2)
		b.add_child(v)
		IdleUI.icone(String(m.get("icone", "icone_pista")) if aberta else "icone_cadeado", 44, v,
				Color.WHITE if aberta else IdleUI.COR_BLOQUEADO)
		var n := IdleUI.rotulo(String(m["nome"]).to_upper(), 17, IdleUI.COR_OURO if na_corrida else
				(Color.WHITE if aberta else IdleUI.COR_BLOQUEADO), v)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sub := "LIGA %d/%d" % [int(e._m(id)["liga"]) + 1, m["ligas"].size()] if aberta else "FECHADA"
		var s := IdleUI.rotulo(sub, 14, IdleUI.COR_SECUNDARIA if aberta else IdleUI.COR_BLOQUEADO, v)
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
	IdleUI.rotulo(String(m["nome"]).to_upper(), 44, Color.WHITE, v, "display")
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
	var p := e.piloto_escalado(_escolhida)
	var nome_p := String(IdleEstado.dados_piloto(tela.dados, String(p["id"])).get("nome", "")) if not p.is_empty() else "SEM PILOTO"
	IdleUI.rotulo(nome_p.to_upper(), 22, Color.WHITE if not p.is_empty() else IdleUI.COR_RUIM, linha)
	if _escolhida != e.modalidade:
		var b := IdleUI.botao("CORRER AQUI", IdleUI.COR_BOTAO, 26, 64, _lista)
		b.pressed.connect(func(): correr_em.emit(_escolhida))


func _escada(e: IdleEstado) -> void:
	var m := e.dados_modalidade(_escolhida)
	var aberta := e.liberada(_escolhida)
	var atual := int(e._m(_escolhida)["liga"]) if aberta else -1
	var venceu := bool(e._m(_escolhida)["venceu"]) if aberta else false
	for i in m["ligas"].size():
		var l: Dictionary = m["ligas"][i]
		var feita: bool = i < atual or (i == atual and venceu)
		var aqui: bool = i == atual
		var fechada: bool = i > atual
		var p := PanelContainer.new()
		var borda := IdleUI.COR_OURO if aqui else Color(1, 1, 1, 0.06)
		p.add_theme_stylebox_override("panel", IdleUI.caixa(IdleUI.COR_CARTAO_CLARO if aqui else IdleUI.COR_CARTAO, 12, 8,
				borda, 3 if aqui else 1))
		_lista.add_child(p)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		p.add_child(h)
		var num := IdleUI.rotulo(str(i + 1), 40, IdleUI.COR_OURO if aqui else (Color.WHITE if feita else IdleUI.COR_BLOQUEADO),
				h, "display")
		num.custom_minimum_size = Vector2(44, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var mini := IdleUI.imagem_cobrindo(IdleUI.banner_pista(String(l["pista"])), 84, h, 1.0 if not fechada else 0.35)
		mini.custom_minimum_size = Vector2(150, 84)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(v)
		IdleUI.rotulo(String(l["nome"]).to_upper(), 22, Color.WHITE if not fechada else IdleUI.COR_BLOQUEADO, v)
		var carro: Array = IdleEstado._perto_de(tela.dados, float(l["potencia"]) * float(e.cfg["carro_do_jogador"]),
				m.get("categorias", []))
		var detalhe := "%s · %s" % [_nome_pista(String(l["pista"])), String(carro[0]["nome"]) if not carro.is_empty() else ""]
		var d := IdleUI.rotulo(detalhe, 17, IdleUI.COR_SECUNDARIA, v)
		d.clip_text = true
		var dir := VBoxContainer.new()
		dir.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(dir)
		if feita:
			IdleUI.icone("icone_ok", 34, dir)
		elif aqui:
			IdleUI.rotulo("AQUI", 18, IdleUI.COR_OURO, dir).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			IdleUI.icone("icone_cadeado", 30, dir, IdleUI.COR_BLOQUEADO)
		var premio := IdleUI.rotulo("1º $%s" % IdleUI.curto(float(e.cfg["premio_p1"]) * float(l["multiplicador"])), 16,
				IdleUI.COR_DINHEIRO if not fechada else IdleUI.COR_BLOQUEADO, dir)
		premio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _nome_pista(id: String) -> String:
	for a in tela.dados.arena().get("arenas", []):
		if String(a["id"]) == id:
			return String(a["nome"])
	return Aba.nome_pista(id)
