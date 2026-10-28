class_name PilotosIdle
extends ScrollContainer
## Tela RAPAZES do The Fastfather (pedido do usuário, 2026-10-27: quem corre é
## sempre o sobrinho; os rapazes da família lutam na Rinha, que roda ao lado da
## corrida). Mesma mecânica de antes (contratos + fusão, como o Race Star): no
## alto, o rapaz que está na Rinha (o de nível mais alto, sozinho); embaixo, os
## contratos (grátis a cada poucas horas e por vídeo) e os rapazes em silhueta:
## tocar num mostra EVOLUIR (com outro do mesmo nível, que sai da família e leva
## o escolhido um nível acima). Nomes em data/idle/cenas.json → "rapazes".

signal mudou

const COLUNAS := 3

var tela: Node  # tela_idle.gd: estado, dados, anuncios
var _lista: VBoxContainer
var _escolhido := -1  # uid
var _botao_gratis: Button
var _t := 0.0


func _init(tela_: Node) -> void:
	tela = tela_
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 14)
	add_child(_lista)
	IdleUI.rolagem_fina(self)


func atualizar() -> void:
	var e: IdleEstado = tela.estado
	if e.piloto(_escolhido).is_empty():
		_escolhido = -1
	for c in _lista.get_children():
		c.queue_free()
	_escalado(e)
	_contratos(e)
	_elenco(e)


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5 or not is_visible_in_tree() or _botao_gratis == null or not is_instance_valid(_botao_gratis):
		return
	_t = 0.0
	_texto_gratis()


static func _agora() -> float:
	return Time.get_unix_time_from_system()


func _nome(p: Dictionary) -> String:
	return PilotosIdle.nome_rapaz(p)


## "Paulie Fumaça": pela ordem de contratação, cada rapaz é uma figura do
## elenco (nome, apelido e arte casados); depois do último, o elenco volta com
## outro apelido.
static func nome_rapaz(p: Dictionary) -> String:
	if p.is_empty():
		return ""
	var r: Dictionary = CenaQuadrinho.carregar("rapazes")
	var elenco: Array = r.get("elenco", [])
	var uid := int(p["uid"])
	if elenco.is_empty():
		return "Rapaz %d" % uid
	var i := (uid - 1) % elenco.size()
	var volta := (uid - 1) / elenco.size()
	var apelido := String(elenco[i]["apelido"])
	var apelidos: Array = r.get("apelidos", [])
	if volta > 0 and not apelidos.is_empty():
		apelido = String(apelidos[(i * 3 + volta * 5) % apelidos.size()])
	return "%s %s" % [elenco[i]["nome"], apelido]


## A arte de corpo inteiro do rapaz (a figura do elenco dele).
static func arte_rapaz(p: Dictionary) -> String:
	var elenco: Array = CenaQuadrinho.carregar("rapazes").get("elenco", [])
	if p.is_empty() or elenco.is_empty():
		return ""
	return "res://arte/fastfather/rapazes/%s.png" % elenco[(int(p["uid"]) - 1) % elenco.size()]["arte"]


func _escalado(e: IdleEstado) -> void:
	var p := e.melhor_rapaz()
	var cartao := IdleUI.painel(IdleUI.COR_CARTAO_CLARO, 16, 14, _lista)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	cartao.add_child(h)
	h.add_child(_retrato(p, 170))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	IdleUI.rotulo("NA RINHA", 18, IdleUI.COR_OURO, v)
	if p.is_empty():
		IdleUI.rotulo("SEM RAPAZES", 36, IdleUI.COR_TEXTO, v, "display")
		IdleUI.rotulo("Contrate um rapaz abaixo.", 20, IdleUI.COR_SECUNDARIA, v)
		return
	var n := IdleUI.rotulo(_nome(p).to_upper(), 38, IdleUI.COR_TEXTO, v, "display")
	n.clip_text = true
	IdleUI.rotulo(IdleUI.nv(int(p["nivel"])).to_upper(), 20, IdleUI.COR_SECUNDARIA, v)
	v.add_child(_estrelas(int(p["nivel"]), int(e.cfg_pilotos().get("nivel_max", 8)), 22))
	IdleUI.rotulo("O mais forte da família vai para a Rinha.", 17, IdleUI.COR_SECUNDARIA, v, "regular")


func _contratos(e: IdleEstado) -> void:
	var linha := VBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	_lista.add_child(linha)
	_botao_gratis = IdleUI.botao("", IdleUI.COR_BOTAO, 24, 84, linha)
	_botao_gratis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_botao_gratis.pressed.connect(func():
		var p := e.usar_contrato_gratis(tela.dados, _agora())
		if not p.is_empty():
			_novo(p))
	_texto_gratis()
	var dia := Time.get_date_string_from_system()
	var restam := e.contratos_video_restantes(dia)
	var video := IdleUI.botao_premio("CONTRATAR · %d HOJE" % restam if restam > 0 else "VOLTE AMANHÃ", 22, 84, linha)
	video.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	video.disabled = restam <= 0
	video.pressed.connect(func():
		tela.anuncios.premiado(func():
			var p := e.usar_contrato_video(tela.dados, Time.get_date_string_from_system(), int(_agora() * 1000.0) % 1000003)
			if not p.is_empty():
				_novo(p)))


func _texto_gratis() -> void:
	var e: IdleEstado = tela.estado
	var falta := e.contrato_em - _agora()
	_botao_gratis.disabled = falta > 0.0
	_botao_gratis.text = "CONTRATAR GRÁTIS" if falta <= 0.0 else "GRÁTIS EM %s" % IdleUI.relogio(falta)


func _elenco(e: IdleEstado) -> void:
	var titulo := VBoxContainer.new()
	titulo.add_theme_constant_override("separation", 0)
	_lista.add_child(titulo)
	IdleUI.rotulo("SEUS RAPAZES (%d)" % e.pilotos.size(), 24, IdleUI.COR_TEXTO, titulo)
	IdleUI.rotulo("2 rapazes do mesmo nível = 1 rapaz de nível acima", 16, IdleUI.COR_SECUNDARIA, titulo, "regular")
	var ordem: Array = e.pilotos.duplicate()
	ordem.sort_custom(func(a, b): return int(a["nivel"]) > int(b["nivel"]) if int(a["nivel"]) != int(b["nivel"]) \
			else int(a["uid"]) < int(b["uid"]))
	var grade := GridContainer.new()
	grade.columns = COLUNAS
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 10)
	_lista.add_child(grade)
	for p in ordem:
		grade.add_child(_cartao(e, p))
	if _escolhido >= 0:
		_acoes(e, e.piloto(_escolhido))


func _cartao(e: IdleEstado, p: Dictionary) -> Control:
	var uid := int(p["uid"])
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 250)
	var marcado := uid == _escolhido
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, IdleUI.caixa(IdleUI.COR_CARTAO_CLARO if marcado else IdleUI.COR_CARTAO, 12, 6,
				IdleUI.COR_OURO if marcado else IdleUI.COR_BORDA, 3 if marcado else 1))
	b.pressed.connect(func():
		Sons.tocar_ui(self, "toque", -6.0)
		_escolhido = -1 if _escolhido == uid else uid
		atualizar())
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 6
	v.offset_bottom = -6
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var r := _retrato(p, 150)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(r)
	var sobrenome := _nome(p).get_slice(" ", _nome(p).get_slice_count(" ") - 1)
	var n := IdleUI.rotulo(sobrenome.to_upper(), 18, IdleUI.COR_TEXTO, v)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	var onde := "NA RINHA" if int(e.melhor_rapaz().get("uid", -1)) == uid else ""
	var s := IdleUI.rotulo(onde if onde != "" else "RESERVA", 14, IdleUI.COR_OURO if onde != "" else IdleUI.COR_SECUNDARIA, v)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


## EVOLUIR (dois do mesmo nível viram um acima) para o rapaz escolhido.
func _acoes(e: IdleEstado, p: Dictionary) -> void:
	var caixa := IdleUI.painel(IdleUI.COR_CARTAO_CLARO, 14, 12, _lista)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	caixa.add_child(v)
	IdleUI.rotulo("%s · %s" % [_nome(p).to_upper(), IdleUI.nv(int(p["nivel"]))], 24, IdleUI.COR_TEXTO, v)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	v.add_child(linha)
	var par := _par_para_fundir(e, p)
	var fundir := IdleUI.botao("EVOLUIR › %s" % IdleUI.nv(int(p["nivel"]) + 1), IdleUI.COR_BOTAO, 22, 64, linha)
	fundir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fundir.disabled = par < 0
	fundir.pressed.connect(func():
		var nome_sai := _nome(e.piloto(par))
		if e.fundir(int(p["uid"]), par):
			tela.celebrar(2)
			mudou.emit()
			tela.mostrar_aviso("%s EVOLUIU PARA %s!" % [_nome(p).to_upper(), IdleUI.nv(int(p["nivel"])).to_upper()],
					"%s deixou a família" % nome_sai)
			atualizar())
	if par < 0:
		IdleUI.rotulo("Para evoluir, contrate outro rapaz %s." % IdleUI.nv(int(p["nivel"])), 17, IdleUI.COR_SECUNDARIA, v)


## O parceiro da fusão: outro piloto do mesmo nível, de preferência um reserva.
func _par_para_fundir(e: IdleEstado, p: Dictionary) -> int:
	var melhor := -1
	for o in e.pilotos:
		if e.pode_fundir(int(p["uid"]), int(o["uid"])):
			var reserva: bool = not e.escalados.values().has(int(o["uid"]))
			if melhor < 0 or reserva:
				melhor = int(o["uid"])
				if reserva:
					break
	return melhor


## Contrato novo: o retrato aparece grande, com nome, perfil e nível.
func _novo(p: Dictionary) -> void:
	tela.celebrar(2)
	mudou.emit()
	atualizar()
	tela.mostrar_aviso("NOVO RAPAZ: %s" % _nome(p).to_upper(), "Nv. 1 · entrou para a família")


## Busto do piloto saindo do quadro: a moldura começa abaixo do topo
## (SAIDA_CABECA do lado) e o busto, de fundo transparente, fica por cima, com
## a cabeça inteira passando da borda.
const SAIDA_CABECA := 0.26

func _retrato(p: Dictionary, lado: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(lado, lado)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := Panel.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.offset_top = lado * SAIDA_CABECA
	var sb := IdleUI.caixa(GaragemIdle.PAPEL_SILHUETA, 10, 0, IdleUI.COR_BORDA, 1)
	sb.border_color = IdleUI.COR_OURO.darkened(0.35) if not p.is_empty() else IdleUI.COR_BORDA
	sb.border_width_top = 3
	fundo.add_theme_stylebox_override("panel", sb)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(fundo)
	if p.is_empty():
		var vazio := IdleUI.icone("icone_piloto", int(lado * 0.4), c, IdleUI.COR_BLOQUEADO)
		vazio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vazio.offset_top = lado * SAIDA_CABECA
		return c
	var t := TextureRect.new()
	t.texture = IdleUI.busto_de(PilotosIdle.arte_rapaz(p))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(t)
	var selo := PanelContainer.new()
	selo.add_theme_stylebox_override("panel", IdleUI.caixa(IdleUI.COR_OURO, 8, 4))
	selo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	selo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	selo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	selo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(selo)
	var n := IdleUI.rotulo(IdleUI.nv(int(p["nivel"])).to_upper(), 16 if lado < 150 else 20, IdleUI.COR_TINTA, selo)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return c


## Nível em quadradinhos ocre (cheios até o nível).
func _estrelas(nivel: int, maximo: int, lado: float) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for i in maximo:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(lado, lado * 0.6)
		r.color = IdleUI.COR_OURO if i < nivel else IdleUI.COR_BORDA
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(r)
	return h
