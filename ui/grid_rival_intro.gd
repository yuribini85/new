class_name GridRivalIntro
extends Control
## Intro de uma equipe do The Grid na revelação (decisão 88, encurtada na 96):
## o choque (o emblema da rival cai de cima, o da sua equipe sobe de baixo, o
## corte e o VS batem no meio) e o confronto (os quatro pilotos da rival em
## cartões, a sua equipe, o que está em jogo e o desafio), em poucos segundos,
## como cabe num idle. Tudo sai dos dados (montar): o número e o apelido de
## equipes.json, os carros especiais do desafio (GridDesafio) e o prêmio médio
## de vitória da licença, em giros. Um toque completa a animação; "Pular" vai
## direto ao confronto; com Reduzir animações, o confronto já pronto. Fica até
## "Continuar".

signal fechou
signal ir(aba: int)

const TINTA := Color("0c0a0a")
const SANGUE := Color("cf1f24")
const OURO := Color("d8a73c")
const OSSO := Color("efe6d3")
const ACO := Color("8d8680")
const LINHA := Color(0.94, 0.9, 0.83, 0.14)
## Choque: tempo do emblema da rival e o da sua equipe chegarem e o VS bater (s).
const CHOQUE_S := 2.1
## Largura do emblema da sua equipe (o da Wreckage é um letreiro largo).
const MARCA_LARGURA := 460.0

var _dados: Node
var _info: Dictionary
var _contexto: String
var _abas: Array
var _curto := false
var _cam: Control  # o que treme
var _cena: Control  # a fase atual (sai inteira na troca, com os tweens dela)
var _flash: ColorRect
var _flash_v: ColorRect
var _faixas: Array = []  # glitch entre as fases
var _botao_pular: Button
var _avancar := false
var _pulou := false
var _no_confronto := false
var _tw_confronto: Tween


## contexto: "proximo" (acabou de ser revelada) ou "primeiro" (a #10, entrada no Grid).
func _init(dados: Node, jogador: Node, id: String, contexto: String, aba_corridas: int, aba_arena: int) -> void:
	_dados = dados
	_contexto = contexto
	_abas = [aba_corridas, aba_arena]
	_info = montar(dados, jogador, TheGrid.equipe(dados, id))
	_info["jogador_nome"] = IdentidadeEquipe.nome(dados, jogador) if jogador != null else ""
	var nossa: Dictionary = EquipeJogador.identidade(dados, jogador) if jogador != null else {}
	_info["jogador_logo"] = String(nossa.get("logo", ""))
	_info["jogador_subtitulo"] = bool(nossa.get("subtitulo", true))
	_curto = Preferencias.reduzir_animacoes
	name = "GridRivalIntro"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = TINTA
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_cam = _cheio(Control.new())
	add_child(_cam)
	_cena = _cheio(Control.new())
	_cam.add_child(_cena)
	var linhas := _cheio(Control.new())
	linhas.draw.connect(_linhas.bind(linhas))
	add_child(linhas)
	for i in 8:
		var f := ColorRect.new()
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.modulate.a = 0.0
		add_child(f)
		_faixas.append(f)
	_flash = _cheio(ColorRect.new())
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	_flash_v = _cheio(ColorRect.new())
	_flash_v.color = Color(SANGUE, 0)
	add_child(_flash_v)
	_botao_pular = Button.new()
	Tipografia.acao_secundaria(_botao_pular, "Pular ›", Color(0.93, 0.92, 0.88, 0.85), 30, 80)
	_botao_pular.custom_minimum_size.x = 150
	_botao_pular.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_botao_pular.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_botao_pular.offset_right = -16
	_botao_pular.offset_top = Dialogo.PULAR_Y
	_botao_pular.pressed.connect(pular)
	add_child(_botao_pular)


## Dados da intro (testável sem tela): {nome, grid, licenca, logo, cor, modo,
## resumo, premio, pilotos: [{id, nome, numero, apelido, estilo, vaga, perfil,
## carro, cv: [3], ritmo, consistencia, agressividade, carimbo}]}.
static func montar(dados: Node, jogador: Node, eq: Dictionary) -> Dictionary:
	if eq.is_empty():
		return {}
	var lic := String(eq.get("nivel", ""))
	var nome_lic := String(dados.item("licencas", lic).get("nome", lic)) if dados.existe("licencas", lic) else lic
	var d := GridDesafio.de(dados, eq)
	var modo := String(d.get("modo", "corrida"))
	var n := 1 if modo == "corrida" else 2
	var esp := GridDesafio.especiais(dados, eq, n)
	var do_desafio: Array = GridDesafio.pilotos(dados, jogador, eq, modo, n).map(func(p): return String(p["id"]))
	var tracos: Dictionary = EquipeJogador.config(dados).get("tracos", {})
	var perfis: Dictionary = dados.carreira().get("perfis_piloto", {})
	var teto: Dictionary = GestaoEquipe.cfg_treino(dados).get("teto", {})
	var base_id := String(dados.carreira()["piloto_jogador"])
	var corrida := Carreira.new(dados, jogador)
	var desafio_curto := "Corrida 1x1" if modo == "corrida" else "Arena 2x2"
	var pilotos := []
	var lista: Array = eq.get("pilotos", [])
	for i in lista.size():
		var pe: Dictionary = lista[i]
		var g := EquipeJogador._do_grid(dados, eq, pe)
		var k := do_desafio.find(String(pe["id"]))
		var adv: Dictionary = esp[k] if k >= 0 and k < esp.size() else {}
		var base: Dictionary = dados.piloto(String(adv.get("piloto", base_id)))
		if base.is_empty():
			base = dados.piloto(base_id)
		var at := corrida.piloto_na_vaga(base, {"equipe": eq, "piloto": pe, "segundo": false})
		var carro := ""
		if not adv.is_empty() and dados.existe("carros", String(adv["carro"])):
			var c: Dictionary = dados.carro(String(adv["carro"]))
			carro = "%s · %d cv" % [c["nome"], roundi(float(c["potencia"]) * float(adv.get("potencia_mult", 1.0)))]
		var cv := []
		if i == 0:
			cv.append("Lidera a equipe")
		cv.append(("No desafio: " + desafio_curto) if k >= 0 else "Fora do desafio")
		if String(pe.get("personalidade", "")) != "":
			cv.append(String(pe["personalidade"]))
		cv.append(nome_lic)
		var perfil := String(pe.get("perfil", eq.get("perfil", "")))
		pilotos.append({"id": String(pe["id"]), "nome": String(pe["nome"]), "numero": int(pe.get("numero", i + 1)),
				"apelido": String(pe.get("apelido", "")),
				"estilo": String(tracos.get(String(g["traco"]), {}).get("nome", String(g["traco"]))),
				"vaga": String(g["tipo"]), "perfil": String(perfis.get(perfil, {}).get("nome", perfil)),
				"carro": carro, "cv": cv.slice(0, 3),
				"ritmo": float(teto.get(lic, base.get("ritmo", 1.0))),
				"consistencia": float(at.get("consistencia", 0.0)), "agressividade": float(at.get("agressividade", 0.0)),
				"carimbo": "CAPITÃO" if i == 0 else String(g["tipo"]).to_upper()})
	return {"id": String(eq["id"]), "nome": String(eq["nome"]), "grid": int(eq.get("grid", 0)), "licenca": nome_lic,
			"logo": String(eq.get("logo", "")), "cor": Color(String(eq.get("cores", {}).get("carro", "#cf1f24"))),
			"modo": modo, "resumo": GridDesafio.resumo(dados, eq), "premio": GestaoEquipe.premio_referencia(dados, lic),
			"pilotos": pilotos}


func _ready() -> void:
	_rodar()


func _rodar() -> void:
	await get_tree().process_frame  # o tamanho da tela
	if not _curto and not _pulou:
		_trocar_cena()
		_avancar = false
		await _choque()
	if is_inside_tree() and not _no_confronto:
		_confronto()


## Um toque: no choque, pula para o confronto; nele, completa a entrada.
func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if not toque:
		return
	if _no_confronto:
		_completar()
	else:
		_avancar = true  # o choque termina na hora
	accept_event()


## Vai direto ao confronto, já pronto.
func pular() -> void:
	if _no_confronto:
		return
	_pulou = true
	_avancar = true
	_confronto()


func _fechar() -> void:
	fechou.emit()
	queue_free()


# ------------------------------------------------------------------ fases

## O emblema da rival cai de cima, o da sua equipe sobe de baixo; o corte
## vermelho atravessa e o VS bate no meio, com clarão e tremor.
func _choque() -> void:
	var meio := size.y * 0.5
	var rival := _textura(_info.get("logo", ""), Vector2(340, 340))
	rival.position = Vector2((size.x - 340.0) / 2.0, meio - 470.0)
	_cena.add_child(rival)
	var rk := _rotulo("#%d DO GRID · %s" % [int(_info["grid"]), String(_info["nome"]).to_upper()],
			"display_eb", 40, OSSO, HORIZONTAL_ALIGNMENT_CENTER)
	rk.position = Vector2(20, meio - 120.0)
	rk.size = Vector2(size.x - 40, 50)
	_cena.add_child(rk)
	var nossa := _marca()
	nossa.position = Vector2((size.x - nossa.size.x) / 2.0, meio + 150.0)
	_cena.add_child(nossa)
	var corte := ColorRect.new()
	corte.color = SANGUE
	corte.size = Vector2(size.x + 300, 14)
	corte.position = Vector2(-150, meio - 7.0)
	corte.pivot_offset = corte.size / 2.0
	corte.rotation_degrees = -7.0
	corte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cena.add_child(corte)
	var vs := _rotulo("VS", "display", 200, OSSO, HORIZONTAL_ALIGNMENT_CENTER)
	vs.add_theme_constant_override("outline_size", 12)
	vs.add_theme_color_override("font_outline_color", TINTA)
	vs.size = Vector2(size.x, 200)
	vs.position = Vector2(0, meio - 110.0)
	vs.pivot_offset = vs.size / 2.0
	_cena.add_child(vs)
	rival.pivot_offset = rival.custom_minimum_size / 2.0
	# O estado de partida já no primeiro quadro (o from() de um passo com atraso
	# só vale quando ele começa).
	var alvo_rival := rival.position.y
	var alvo_nossa := nossa.position.y
	rival.position.y = -400.0
	nossa.position.y = size.y + 100.0
	rk.modulate.a = 0.0
	corte.scale.x = 0.0
	vs.modulate.a = 0.0
	var tw := _cena.create_tween().set_parallel(true)
	tw.tween_property(rival, "position:y", alvo_rival, 0.28) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _impacto(_flash_v, 0.5, 0.8)).set_delay(0.28)
	tw.tween_property(rk, "modulate:a", 1.0, 0.2).set_delay(0.35)
	tw.tween_property(nossa, "position:y", alvo_nossa, 0.28).set_delay(0.55) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _impacto(_flash, 0.4, 0.8)).set_delay(0.83)
	tw.tween_property(corte, "scale:x", 1.0, 0.18).set_delay(1.0) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(vs, "scale", Vector2.ONE, 0.2).from(Vector2.ONE * 3.0).set_delay(1.1) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(vs, "modulate:a", 1.0, 0.2).set_delay(1.1)
	tw.tween_callback(func(): _impacto(_flash_v, 0.7, 1.6)).set_delay(1.3)
	tw.tween_property(rival, "scale", Vector2.ONE * 1.06, 0.8).set_delay(1.3)
	await _esperar(CHOQUE_S)
	_glitch()


## O emblema da sua equipe (o letreiro da Wreckage, ou o escolhido na
## identidade, com o nome embaixo) ou, sem arte, o nome em texto.
func _marca() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo := String(_info.get("jogador_logo", ""))
	var nome := String(_info.get("jogador_nome", "")).to_upper()
	var tex: Texture2D = load(logo) if logo != "" and ResourceLoader.exists(logo) else null
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
		var alto := minf(MARCA_LARGURA * tex.get_height() / tex.get_width(), 220.0)
		r.custom_minimum_size = Vector2(MARCA_LARGURA, alto)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(r)
	if tex == null or bool(_info.get("jogador_subtitulo", true)):
		var l := _rotulo(nome, "display", 56 if tex == null else 34, SANGUE, HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = MARCA_LARGURA
		v.add_child(l)
	v.size = v.get_combined_minimum_size()
	return v


## Confronto: a equipe e os quatro cartões, VS, a sua equipe, o que está em
## jogo e o desafio. Fica até "Continuar".
func _confronto() -> void:
	_no_confronto = true
	_trocar_cena()
	_botao_pular.visible = false
	var pronto := _curto or _pulou
	var m := MarginContainer.new()
	_cheio(m)
	for lado in ["left", "right"]:
		m.add_theme_constant_override("margin_" + lado, 28)
	m.add_theme_constant_override("margin_top", 48)
	# Os botões acima dos rótulos do pé (PRÓXIMA DISPUTA, RIVAL #N).
	m.add_theme_constant_override("margin_bottom", 56)
	_cena.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var logo := _textura(_info.get("logo", ""), Vector2(120, 120))
	v.add_child(logo)
	var nome := _rotulo(String(_info["nome"]).to_upper(), "display", 58, OSSO, HORIZONTAL_ALIGNMENT_CENTER)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nome)
	# A posição no Grid em destaque (pedido do usuário); sem as linhas miúdas.
	var rk := _rotulo("#%d DO GRID" % int(_info["grid"]), "display", 46, OURO, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(rk)
	var cartoes := HBoxContainer.new()
	cartoes.alignment = BoxContainer.ALIGNMENT_CENTER
	cartoes.add_theme_constant_override("separation", 0)
	cartoes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cartoes)
	var internos: Array = []
	var pilotos: Array = _info["pilotos"]
	for k in pilotos.size():
		var c := _cartao(pilotos[k])
		cartoes.add_child(c[0])
		internos.append(c[1])
	var vs := Control.new()
	vs.custom_minimum_size = Vector2(0, 124)
	vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(vs)
	var corte := ColorRect.new()
	corte.color = SANGUE
	corte.size = Vector2(size.x + 200, 12)
	corte.position = Vector2(-128, 58)
	corte.pivot_offset = corte.size / 2.0
	corte.rotation_degrees = -6.0
	corte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vs.add_child(corte)
	var vs_l := _rotulo("VS", "display", 130, OSSO, HORIZONTAL_ALIGNMENT_CENTER)
	vs_l.add_theme_constant_override("outline_size", 10)
	vs_l.add_theme_color_override("font_outline_color", TINTA)
	vs_l.size = Vector2(size.x - 56, 130)
	vs_l.position = Vector2(0, -16)
	vs_l.pivot_offset = vs_l.size / 2.0
	vs.add_child(vs_l)
	var nos := CenterContainer.new()
	nos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nos.add_child(_marca())
	v.add_child(nos)
	var jogo := VBoxContainer.new()
	jogo.add_theme_constant_override("separation", 2)
	v.add_child(_divisoria())
	v.add_child(jogo)
	jogo.add_child(_rotulo("RECOMPENSA DA VITÓRIA", "display_eb", 24, OSSO, HORIZONTAL_ALIGNMENT_CENTER))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	jogo.add_child(h)
	var moeda := _textura("res://arte/ui/cabecalho/icone_giros.png", Vector2(52, 52))
	h.add_child(moeda)
	var valor := _rotulo("+" + Aba.dinheiro(int(_info["premio"])), "display", 72, OURO)
	h.add_child(valor)
	var desafio := _rotulo(String(_info["resumo"]), "mono_sb", 18, OSSO, HORIZONTAL_ALIGNMENT_CENTER)
	desafio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	jogo.add_child(desafio)
	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	espaco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(espaco)
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 12)
	v.add_child(botoes)
	var b := Button.new()
	Tipografia.acao_primaria(b, "Continuar", Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 30, Tipografia.ALTURA_SECUNDARIA)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(_fechar)
	botoes.add_child(b)
	if pronto:
		return
	_impacto(_flash, 0.7, 0.0)
	for c in [logo, nome, rk, nos, jogo, botoes]:
		c.modulate.a = 0.0
	vs_l.modulate.a = 0.0
	corte.scale.x = 0.0
	for c in internos:
		c.modulate.a = 0.0
	var tw := _cena.create_tween().set_parallel(true)
	_tw_confronto = tw
	# Depois do choque, o VS já bateu: aqui tudo entra junto, em ~1,3 s.
	tw.tween_property(logo, "modulate:a", 1.0, 0.25)
	tw.tween_property(nome, "modulate:a", 1.0, 0.2).set_delay(0.1)
	tw.tween_property(rk, "modulate:a", 1.0, 0.2).set_delay(0.15)
	for k in internos.size():
		var c: Control = internos[k]
		tw.tween_property(c, "position:y", 0.0, 0.25).from(-300.0).set_delay(0.15 + k * 0.07) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(0.15 + k * 0.07)
	tw.tween_property(corte, "scale:x", 1.0, 0.15).set_delay(0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(vs_l, "scale", Vector2.ONE, 0.15).from(Vector2.ONE * 2.2).set_delay(0.5) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(vs_l, "modulate:a", 1.0, 0.15).set_delay(0.5)
	tw.tween_callback(func(): _impacto(_flash_v, 0.45, 0.9)).set_delay(0.65)
	tw.tween_property(nos, "modulate:a", 1.0, 0.25).set_delay(0.6)
	tw.tween_property(jogo, "modulate:a", 1.0, 0.25).set_delay(0.8)
	tw.tween_method(func(x: float): valor.text = "+" + Aba.dinheiro(int(x)), 0.0, float(_info["premio"]), 0.6) \
			.set_delay(0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(botoes, "modulate:a", 1.0, 0.25).set_delay(1.05)


## Completa a entrada do confronto (toque).
func _completar() -> void:
	if _tw_confronto != null and _tw_confronto.is_valid() and _tw_confronto.is_running():
		_tw_confronto.custom_step(60.0)


# ------------------------------------------------------------------ peças

func _cheio(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _trocar_cena() -> void:
	if _cena != null:
		_cena.queue_free()
	_cena = _cheio(Control.new())
	_cam.add_child(_cena)
	_cam.position = Vector2.ZERO
	_flash.color.a = 0.0
	_flash_v.color.a = 0.0


## Espera `s` segundos, ou até um toque/Pular.
func _esperar(s: float) -> void:
	var fim := Time.get_ticks_msec() + int(s * 1000.0)
	while is_inside_tree() and not _avancar and Time.get_ticks_msec() < fim:
		await get_tree().process_frame


func _rotulo(texto: String, peso: String, tamanho: int, cor: Color,
		alinhar := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = texto
	Tipografia.rotulo(l, peso, tamanho)
	l.add_theme_color_override("font_color", cor)
	l.horizontal_alignment = alinhar
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _textura(arq, tam: Vector2) -> TextureRect:
	var t := TextureRect.new()
	var a := String(arq)
	t.texture = load(a) if a != "" and ResourceLoader.exists(a) else null
	t.custom_minimum_size = tam
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _divisoria() -> ColorRect:
	var d := ColorRect.new()
	d.color = LINHA
	d.custom_minimum_size = Vector2(0, 1)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


## Piloto do confronto, corpo inteiro: [vaga no contêiner, figura que cai].
func _cartao(p: Dictionary) -> Array:
	var vaga := Control.new()
	vaga.custom_minimum_size = Vector2(160, 306)
	vaga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := Control.new()
	c.size = Vector2(160, 306)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vaga.add_child(c)
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # antes do tamanho (senão vale o da textura)
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
	var corpo: Texture2D = Assets.get_asset(String(p["id"]), "corpo")
	r.texture = corpo if corpo != null else Assets.get_asset(String(p["id"]), "retrato")
	r.size = Vector2(160, 236)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(r)
	# Faixa na frente da base do corpo e atrás do número e do apelido: o corte
	# do desenho some num degradê e os nomes ficam sobre uma placa (os cartões
	# lado a lado formam uma faixa só).
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.32, 1.0])
	grad.colors = PackedColorArray([Color(TINTA, 0.0), Color(TINTA, 0.95), Color(TINTA, 1.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var faixa := TextureRect.new()
	faixa.texture = gt
	faixa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	faixa.stretch_mode = TextureRect.STRETCH_SCALE  # degradê: sem proporção
	faixa.position = Vector2(0, 186)
	faixa.size = Vector2(160, 120)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(faixa)
	var placa := ColorRect.new()
	placa.color = Color("1d1a19")
	placa.position = Vector2(0, 229)
	placa.size = Vector2(160, 78)
	placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(placa)
	var filete := ColorRect.new()
	filete.color = SANGUE
	filete.position = Vector2(0, 226)
	filete.size = Vector2(160, 3)
	filete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(filete)
	var num := _rotulo(str(int(p["numero"])), "display", 32, SANGUE, HORIZONTAL_ALIGNMENT_CENTER)
	num.position = Vector2(0, 230)
	num.size = Vector2(160, 0)
	c.add_child(num)
	var ap := _rotulo(String(p["apelido"]).to_upper(), "display_eb", 25, OSSO, HORIZONTAL_ALIGNMENT_CENTER)
	ap.position = Vector2(0, 268)
	ap.size = Vector2(160, 0)
	c.add_child(ap)
	return [vaga, c]


## Linhas de varredura bem leves por cima de tudo.
func _linhas(c: Control) -> void:
	var y := 0.0
	while y < c.size.y:
		c.draw_line(Vector2(0, y), Vector2(c.size.x, y), Color(0, 0, 0, 0.12), 1.0)
		y += 4.0


# ------------------------------------------------------------------ efeitos

## Clarão (branco ou vermelho) e tremor; nada com Reduzir animações.
func _impacto(r: ColorRect, pico: float, tremor: float) -> void:
	if _curto or not is_inside_tree():
		return
	r.color.a = pico
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if tremor > 0.0:
		_tremer(tremor)


func _tremer(amp: float) -> void:
	if _curto or not is_inside_tree():
		return
	var tw := create_tween()
	for p in [Vector2(-14, 6), Vector2(11, -6), Vector2(-7, 3), Vector2(4, -2), Vector2.ZERO]:
		tw.tween_property(_cam, "position", p * amp, 0.076)


## Faixas que cortam a tela na troca de fase.
func _glitch() -> void:
	if _curto or not is_inside_tree():
		return
	var tw := create_tween().set_parallel(true)
	for k in _faixas.size():
		var f: ColorRect = _faixas[k]
		f.color = [SANGUE, Color(OSSO, 0.85), Color.BLACK][k % 3]
		f.size = Vector2(size.x + 400, randf_range(8, 64))
		f.position = Vector2(randf_range(-300, 100), randf_range(0, size.y))
		f.modulate.a = 1.0
		tw.tween_property(f, "modulate:a", 0.0, 0.28).set_delay(randf() * 0.08)
		tw.tween_property(f, "position:x", f.position.x + randf_range(-100, 100), 0.28)
