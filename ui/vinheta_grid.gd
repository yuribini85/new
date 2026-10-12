class_name VinhetaGrid
extends Control
## Ficha de uma equipe do The Grid (proposta "The Grid Pack"): interface
## animada por cima de tudo, montada com os dados da equipe (nada escrito na
## arte). Posição, emblema e nome; os pilotos (o primeiro na frente, o outro
## atrás e mais escuro); o jeito da equipe; como desafiar, com os botões para
## as telas que existem (Corridas e Arena). Entra em fases; um toque completa;
## com Reduzir animações, já aparece pronta. Fica até "Continuar".
## `id` = equipe; "fim" = o Grid vencido (a sua equipe no topo).

signal fechou
signal ir(aba: int)

const FASE_S := 0.3  # intervalo entre as fases da entrada
const ENTRADA_S := 0.35  # cada fase aparece em tanto

var _dados: Node
var _jogador: Node
var _equipe: Dictionary
var _fases: Array = []  # Controls na ordem em que aparecem
var _tween: Tween
var _cor := Aba.COR_DESTAQUE


## contexto: "proximo" (acabou de ser revelada), "primeiro" (a #10, entrada no
## Grid), "rever" (aberta da lista).
func _init(dados: Node, jogador: Node, id: String, contexto: String, aba_corridas: int, aba_arena: int) -> void:
	_dados = dados
	_jogador = jogador
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fim := id == "fim"
	_equipe = {} if fim else TheGrid.equipe(dados, id)
	if not _equipe.is_empty() and _equipe.has("cores"):
		_cor = Color(String(_equipe["cores"]["carro"]))
	var fundo := ColorRect.new()
	fundo.color = Color(0.05, 0.05, 0.06)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_fases.append(fundo)
	var faixa := Control.new()
	faixa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.draw.connect(_faixa.bind(faixa))
	add_child(faixa)
	_fases.append(faixa)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right"]:
		m.add_theme_constant_override("margin_" + lado, 28)
	m.add_theme_constant_override("margin_top", 36)
	m.add_theme_constant_override("margin_bottom", 32)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var sobre := Label.new()
	sobre.text = {"proximo": "THE GRID · PRÓXIMO ALVO", "primeiro": "THE GRID · PRIMEIRO ALVO"}.get(contexto, "THE GRID")
	if fim:
		sobre.text = "THE GRID"
	Tipografia.rotulo(sobre, "semibold", 22)
	sobre.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	v.add_child(sobre)
	_fases.append(sobre)
	v.add_child(_topo(fim))
	if fim:
		_fim(v)
	else:
		_pilotos(v)
		_desafio(v, aba_corridas, aba_arena)
	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	espaco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(espaco)
	var b := Button.new()
	Tipografia.acao_primaria(b, "Continuar", Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 30, 76)
	b.pressed.connect(_fechar)
	v.add_child(b)
	_fases.append(b)


func _ready() -> void:
	if Preferencias.reduzir_animacoes:
		return
	for f in _fases:
		f.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	for i in _fases.size():
		_tween.tween_property(_fases[i], "modulate:a", 1.0, ENTRADA_S).set_delay(i * FASE_S)


## Um toque durante a entrada completa tudo.
func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if toque and _tween != null and _tween.is_running():
		_tween.kill()
		for f in _fases:
			f.modulate.a = 1.0
		accept_event()


func _fechar() -> void:
	fechou.emit()
	queue_free()


## Faixa diagonal na cor da equipe atrás do topo (a composição do estudo).
func _faixa(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y * 0.42
	c.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.38, 0), Vector2(w, 0), Vector2(w, h * 0.55),
			Vector2(w * 0.62, h)]), Color(_cor, 0.55))
	c.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.3, 0), Vector2(w * 0.36, 0), Vector2(w * 0.6, h),
			Vector2(w * 0.54, h)]), Color(_cor.lightened(0.25), 0.4))


## Número da posição numa caixa escura, o emblema grande e o nome.
func _topo(fim: bool) -> Control:
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	t.add_child(h)
	var caixa := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.04, 0.92)
	sb.set_content_margin_all(14)
	caixa.add_theme_stylebox_override("panel", sb)
	caixa.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(caixa)
	var n := Label.new()
	n.text = "#%d" % (1 if fim else int(_equipe["grid"]))
	Tipografia.numero(n, 96)
	caixa.add_child(n)
	var logo := TextureRect.new()
	var arq := ""
	if fim:
		arq = String(EquipeJogador.dados_equipe(_dados, _jogador).get("logo", ""))
		if arq == "":  # equipe ainda sem identidade: o emblema padrão
			for e in _dados.lista("equipes"):
				if e.get("jogador", false):
					arq = String(e.get("logo", ""))
	else:
		arq = String(_equipe.get("logo", ""))
	logo.texture = load(arq) if arq != "" and ResourceLoader.exists(arq) else null
	logo.custom_minimum_size = Vector2(250, 250)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(logo)
	_fases.append(h)
	var nome := Label.new()
	nome.text = (IdentidadeEquipe.nome(_dados, _jogador) if fim else String(_equipe["nome"])).to_upper()
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Tipografia.rotulo(nome, "semibold", 54)
	nome.add_theme_color_override("font_color", Color(0.96, 0.94, 0.9))
	t.add_child(nome)
	if not fim:
		var lic := String(_equipe.get("nivel", ""))
		var dl: Dictionary = _dados.item("licencas", lic) if _dados.existe("licencas", lic) else {}
		var sub := Label.new()
		sub.text = "%s · %s" % [String(dl.get("nome", lic)), String(_equipe.get("personalidade", ""))]
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Tipografia.rotulo(sub, "regular", 24)
		sub.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
		t.add_child(sub)
		_fases.append(sub)
	_fases.append(nome)
	return t


## Os pilotos com retrato: o primeiro na frente, o segundo atrás, menor e mais
## escuro. Com a arte do dirigente (equipes.json → retrato_dirigente), ele vai
## na frente e os dois pilotos atrás; sem ela, só o nome dele embaixo.
func _pilotos(v: VBoxContainer) -> void:
	# Os dois primeiros, os com retrato antes; sem arte, a silhueta do jogo.
	var pilotos: Array = Array(_equipe.get("pilotos", [])).duplicate()
	pilotos.sort_custom(func(a, b): return _tem_retrato(a) and not _tem_retrato(b))
	var com_retrato: Array = pilotos.slice(0, 2)
	if com_retrato.is_empty():
		return
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(area)
	_fases.append(area)
	var dirigente := String(_equipe.get("dirigente", ""))
	var arte_dirigente := String(_equipe.get("retrato_dirigente", ""))
	if arte_dirigente != "" and ResourceLoader.exists(arte_dirigente):
		# O dirigente recortado na frente; os dois pilotos atrás, apagados.
		area.custom_minimum_size = Vector2(0, 420)
		for i in com_retrato.size():
			area.add_child(_retrato(com_retrato[i], Vector2(230 + i * 190, 30 + i * 24), Vector2(180, 210), 0.45))
		var d := TextureRect.new()
		d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # antes do tamanho (senão vale o da textura)
		d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		d.texture = load(arte_dirigente)
		d.position = Vector2(-10, 0)
		d.size = Vector2(260, 390)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(d)
		area.add_child(_legenda("DIRIGENTE · " + dirigente.to_upper(), Vector2(0, 392)))
		return
	area.custom_minimum_size = Vector2(0, 360 + (34 if dirigente != "" else 0))
	# Atrás primeiro (desenha embaixo).
	if com_retrato.size() > 1:
		area.add_child(_retrato(com_retrato[1], Vector2(250, 40), Vector2(240, 280), 0.5))
	area.add_child(_retrato(com_retrato[0], Vector2(0, 0), Vector2(270, 315), 1.0))
	if dirigente != "":
		area.add_child(_legenda("DIRIGENTE · " + dirigente.to_upper(), Vector2(0, 364)))


func _legenda(texto: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = texto
	Tipografia.rotulo(l, "semibold", 22)
	l.add_theme_color_override("font_color", Aba.COR_DESTAQUE)
	l.position = pos
	return l


static func _tem_retrato(p: Dictionary) -> bool:
	return Assets.get_asset(String(p.get("id", "")), "retrato") != null


func _retrato(p: Dictionary, pos: Vector2, tam: Vector2, luz: float) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = tam + Vector2(0, 44)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var moldura := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(_cor.lightened(0.2), 0.9 * luz)
	sb.set_border_width_all(3)
	moldura.add_theme_stylebox_override("panel", sb)
	moldura.size = tam
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # escala uniforme, recorta
	r.clip_contents = true
	r.texture = Assets.get_asset(String(p.get("id", "")), "retrato") if _tem_retrato(p) \
			else Aba.arte("piloto_silhueta_%d" % (1 + absi(hash(String(p.get("id", "")))) % 3))
	r.size = tam
	r.modulate = Color(luz, luz, luz)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(r)
	c.add_child(moldura)
	var nome := Label.new()
	nome.text = String(p["nome"]).to_upper()
	Tipografia.rotulo(nome, "semibold", 22)
	nome.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87, lerpf(0.6, 1.0, luz)))
	nome.position = Vector2(0, tam.y + 6)
	c.add_child(nome)
	return c


## Como desafiar (a regra que já existe, TheGrid) e os botões para as telas.
func _desafio(v: VBoxContainer, aba_corridas: int, aba_arena: int) -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	sb.border_color = _cor
	sb.border_width_left = 6
	sb.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", sb)
	v.add_child(p)
	_fases.append(p)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 10)
	p.add_child(c)
	var t := Label.new()
	var vencida: bool = _equipe["id"] in TheGrid.vencidas(_jogador)
	t.text = "VENCIDA" if vencida else "COMO DESAFIAR"
	Tipografia.rotulo(t, "semibold", 24)
	t.add_theme_color_override("font_color", Aba.COR_BOM if vencida else Aba.COR_DESTAQUE)
	c.add_child(t)
	var lic := String(_equipe.get("nivel", ""))
	var dl: Dictionary = _dados.item("licencas", lic) if _dados.existe("licencas", lic) else {}
	var txt := Label.new()
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.text = ("Ficou para trás no Grid." if vencida else
			"Vença uma prova %s em que ela corra (Corridas), ou o campeonato da arena com ela na luta (Arena)."
			% String(dl.get("nome", lic)))
	Tipografia.rotulo(txt, "regular", 24)
	c.add_child(txt)
	if vencida:
		return
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	c.add_child(h)
	for par in [["Corridas", aba_corridas], ["Arena", aba_arena]]:
		var b := Button.new()
		Tipografia.acao_primaria(b, "%s   →" % par[0], Color(0.2, 0.21, 0.24), Color.WHITE, 24, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			ir.emit(int(par[1]))
			_fechar())
		h.add_child(b)


func _fim(v: VBoxContainer) -> void:
	var t := Label.new()
	t.text = "O Grid é seu. Ninguém acima."
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Tipografia.rotulo(t, "semibold", 34)
	t.add_theme_color_override("font_color", Aba.COR_DESTAQUE)
	v.add_child(t)
	_fases.append(t)
