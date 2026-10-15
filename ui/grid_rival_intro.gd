class_name GridRivalIntro
extends Control
## Intro de uma equipe do The Grid na revelação (decisão 88, protótipo do
## usuário "GridRivalIntro"): terminal, emblema, os quatro pilotos (número,
## retrato que ganha cor, nome, apelido, estilo, carro, currículo, barras e
## carimbo) e o confronto com a sua equipe. Tudo sai dos dados (montar): o
## número e o apelido de equipes.json, o estilo pelo traço do perfil (mercado),
## os carros especiais do desafio (GridDesafio), o teto de treino da licença
## (ritmo), a consistência e a agressividade pelas regras da corrida
## (Carreira.piloto_na_vaga) e o prêmio médio de vitória da licença, em giros.
## Um toque passa para o próximo piloto; "Pular" vai direto ao confronto; com
## Reduzir animações, sem terminal, efeitos nem digitação. Fica até "Continuar".

signal fechou
signal ir(aba: int)

const TINTA := Color("0c0a0a")
const SANGUE := Color("cf1f24")
const OURO := Color("d8a73c")
const OSSO := Color("efe6d3")
const ACO := Color("8d8680")
const LINHA := Color(0.94, 0.9, 0.83, 0.14)
const PILOTO_S := 6.0  # cada piloto na versão completa
const RETRATO_Y := 200.0  # alto do retrato de corpo (o rosto abaixo do Pular)
const PILOTO_CURTO_S := 3.5  # com Reduzir animações
const ROTACAO_CARTOES := [-4.0, 3.0, -3.0, 4.0]

const SHADER_RETRATO := """
shader_type canvas_item;
uniform float cor : hint_range(0.0, 1.0) = 1.0;
uniform float fundo_corte = 0.62;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 pb = clamp((vec3(g) * 1.5 - 0.5) * 1.3 + 0.5, 0.0, 1.0);
	c.rgb = mix(pb, c.rgb, cor);
	c.a *= 1.0 - smoothstep(fundo_corte, fundo_corte + 0.3, UV.y);
	COLOR = c;
}
"""

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
var _hud: Array = []
var _avancar := false
var _pulou := false
var _no_confronto := false
var _shader: Shader
var _tw_confronto: Tween


## contexto: "proximo" (acabou de ser revelada) ou "primeiro" (a #10, entrada no Grid).
func _init(dados: Node, jogador: Node, id: String, contexto: String, aba_corridas: int, aba_arena: int) -> void:
	_dados = dados
	_contexto = contexto
	_abas = [aba_corridas, aba_arena]
	_info = montar(dados, jogador, TheGrid.equipe(dados, id))
	_info["jogador_nome"] = IdentidadeEquipe.nome(dados, jogador) if jogador != null else ""
	_curto = Preferencias.reduzir_animacoes
	name = "GridRivalIntro"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shader = Shader.new()
	_shader.code = SHADER_RETRATO
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
	_montar_hud()
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
	var fases: Array = []
	if not _curto:
		fases.append(_fase_terminal)
	fases.append(_fase_emblema)
	for i in Array(_info.get("pilotos", [])).size():
		fases.append(_fase_piloto.bind(i))
	for f in fases:
		if _pulou or not is_inside_tree():
			break
		_trocar_cena()
		_avancar = false
		await f.call()
	if is_inside_tree() and not _no_confronto:
		_confronto()


## Um toque: durante os pilotos, o próximo; no confronto, completa a entrada.
func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if not toque:
		return
	if _no_confronto:
		_completar()
	else:
		_avancar = true
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

## "> THE GRID · RANKING ATUALIZADO" e a próxima rival, digitado.
func _fase_terminal() -> void:
	var nome_j := String(_info.get("jogador_nome", "")).to_upper()
	var linhas := ["> THE GRID · RANKING ATUALIZADO",
			("> %s ENTRA NO GRID" % nome_j) if _contexto == "primeiro" else ("> %s SOBE PARA #%d" % [nome_j, int(_info["grid"]) + 1]),
			"> PRÓXIMO ADVERSÁRIO:", "> #%d %s" % [int(_info["grid"]), String(_info["nome"]).to_upper()]]
	var v := VBoxContainer.new()
	v.position = Vector2(48, size.y * 0.4)
	v.size = Vector2(size.x - 96, 0)
	v.add_theme_constant_override("separation", 18)
	_cena.add_child(v)
	var tw := _cena.create_tween()
	for i in linhas.size():
		var l := _rotulo(linhas[i], "mono_sb" if i in [1, 3] else "mono", 26,
				[OSSO, OURO, OSSO, SANGUE][i])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.visible_ratio = 0.0
		v.add_child(l)
		tw.tween_property(l, "visible_ratio", 1.0, 0.45).set_delay(0.25)
	await _esperar(3.6)


## Emblema que cai com impacto, "#N DO GRID", o nome e a licença.
func _fase_emblema() -> void:
	var v := _coluna(size.y * 0.16)
	var logo := _textura(_info.get("logo", ""), Vector2(380, 380))
	v.add_child(logo)
	var eq := _rotulo("#%d DO GRID" % int(_info["grid"]), "display_eb", 40, SANGUE, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(eq)
	var nome := _rotulo(String(_info["nome"]).to_upper(), "display", 96, OSSO, HORIZONTAL_ALIGNMENT_CENTER)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nome)
	var sub := _rotulo("%s · %d PILOTOS" % [String(_info["licenca"]).to_upper(),
			Array(_info["pilotos"]).size()], "mono", 22, ACO, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(sub)
	if _curto:
		await _esperar(2.0)
		return
	for c in [eq, nome, sub]:
		c.modulate.a = 0.0
	logo.pivot_offset = logo.custom_minimum_size / 2.0
	logo.scale = Vector2.ONE * 3.2
	logo.modulate.a = 0.0
	var tw := _cena.create_tween().set_parallel(true)
	tw.tween_property(logo, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(logo, "modulate:a", 1.0, 0.32)
	tw.tween_callback(func(): _impacto(_flash_v, 0.8, 1.3)).set_delay(0.3)
	tw.tween_property(logo, "scale", Vector2.ONE * 1.05, 3.2).set_delay(0.32)
	tw.tween_property(eq, "modulate:a", 1.0, 0.5).set_delay(0.7)
	tw.tween_property(nome, "modulate:a", 1.0, 0.22).set_delay(0.95)
	tw.tween_callback(func(): _tremer(0.7)).set_delay(1.17)
	tw.tween_property(sub, "modulate:a", 1.0, 0.4).set_delay(1.6)
	await _esperar(3.6)
	_glitch()


## Um piloto: número gigante vazado, retrato (preto e branco → cor), ficha e carimbo.
func _fase_piloto(i: int) -> void:
	var p: Dictionary = _info["pilotos"][i]
	var total := Array(_info["pilotos"]).size()
	var num := _rotulo(str(int(p["numero"])), "display", 600, Color(SANGUE, 0.07))
	num.add_theme_constant_override("outline_size", 5)
	num.add_theme_color_override("font_outline_color", SANGUE)
	num.position = Vector2(-8, -40)
	_cena.add_child(num)
	var arte: Texture2D = Assets.get_asset(String(p["id"]), "corpo")
	if arte == null:
		arte = Assets.get_asset(String(p["id"]), "retrato")
	var ret := TextureRect.new()
	ret.texture = arte
	ret.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ret.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
	ret.size = Vector2(512, 768)
	# Abaixo do Pular (fixo em Dialogo.PULAR_Y, como no diálogo): o botão não
	# cobre o rosto.
	ret.position = Vector2(size.x - 512 + 24, RETRATO_Y)
	ret.pivot_offset = Vector2(256, 230)
	ret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	ret.material = mat
	_cena.add_child(ret)
	# Sombra que apaga o pé do retrato atrás da ficha.
	var sombra := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(TINTA, 0), Color(TINTA, 1)])
	gr.offsets = PackedFloat32Array([0.0, 0.35])
	gt.gradient = gr
	sombra.texture = gt
	sombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sombra.position = Vector2(0, 600)
	sombra.size = Vector2(size.x, size.y - 600)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cena.add_child(sombra)
	var v := VBoxContainer.new()
	v.position = Vector2(40, 650)
	v.size = Vector2(size.x - 80, 0)
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cena.add_child(v)
	var tag := _rotulo("PILOTO %d / %d · %s" % [i + 1, total, String(_info["nome"]).to_upper()], "mono", 17, ACO)
	v.add_child(tag)
	var nome := _rotulo(String(p["nome"]).to_upper(), "display", 84, OSSO)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.add_theme_constant_override("line_spacing", -18)
	v.add_child(nome)
	var apelido := _rotulo("“%s”" % String(p["apelido"]).to_upper() if String(p["apelido"]) != "" else "", "display_eb", 46, SANGUE)
	v.add_child(apelido)
	var campos := HBoxContainer.new()
	campos.add_theme_constant_override("separation", 24)
	v.add_child(_divisoria())
	v.add_child(campos)
	campos.add_child(_campo("ESTILO", String(p["estilo"]), "vaga de %s · %s" % [p["vaga"], String(p["perfil"]).to_lower()]))
	var car := String(p["carro"])
	campos.add_child(_campo("CARRO", car.get_slice(" · ", 0) if car != "" else "RESERVA",
			("%s · nº %d" % [car.get_slice(" · ", 1), int(p["numero"])]) if car != "" else "nº %d" % int(p["numero"])))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	v.add_child(cv)
	cv.add_child(_rotulo("CURRÍCULO", "mono", 14, ACO))
	var itens: Array = []
	for t in p["cv"]:
		var li := _rotulo("—  " + String(t), "mono", 18, OSSO)
		li.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(li)
		itens.append(li)
	var barras := VBoxContainer.new()
	barras.add_theme_constant_override("separation", 8)
	v.add_child(barras)
	var preenchimentos: Array = []
	# As três na mesma escala: em %, barra cheia em 100% (o ritmo, perto de
	# 100%, com uma casa para as diferenças entre licenças aparecerem).
	for b in [["RITMO", float(p["ritmo"]), 1], ["CONSISTÊNCIA", float(p["consistencia"]), 0],
			["AGRESSIVIDADE", float(p["agressividade"]), 0]]:
		var linha := _barra(b[0], b[1], b[2])
		barras.add_child(linha[0])
		preenchimentos.append(linha[1])
	# Carimbo.
	var carimbo := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = SANGUE
	sb.set_border_width_all(7)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 4
	sb.content_margin_bottom = 0
	carimbo.add_theme_stylebox_override("panel", sb)
	carimbo.add_child(_rotulo(String(p["carimbo"]), "carimbo", 84, SANGUE))
	carimbo.position = Vector2(36, 470)
	carimbo.rotation_degrees = -8.0
	carimbo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cena.add_child(carimbo)
	carimbo.modulate.a = 0.95
	if _curto:
		mat.set_shader_parameter("cor", 1.0)
		await _esperar(PILOTO_CURTO_S)
		return
	# Entrada (os tempos do protótipo).
	mat.set_shader_parameter("cor", 0.0)
	for c in [tag, apelido, campos, cv, barras, carimbo]:
		c.modulate.a = 0.0
	for li in itens:
		li.modulate.a = 0.0
	for f in preenchimentos:
		f.scale.x = 0.0
	nome.visible_ratio = 0.0
	num.modulate.a = 0.0
	ret.modulate.a = 0.0
	await get_tree().process_frame  # o tamanho do carimbo para o pivô
	if not is_instance_valid(carimbo) or carimbo.is_queued_for_deletion() or _avancar:
		return
	carimbo.pivot_offset = carimbo.size / 2.0
	var tw := _cena.create_tween().set_parallel(true)
	tw.tween_property(num, "position:x", -8.0, 0.5).from(-300.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(num, "modulate:a", 1.0, 0.5)
	tw.tween_property(num, "position:x", 40.0, 6.0).set_delay(0.5)
	tw.tween_property(ret, "position:x", ret.position.x, 0.5).from(ret.position.x + 190.0).set_delay(0.2) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(ret, "modulate:a", 1.0, 0.5).set_delay(0.2)
	tw.tween_callback(func(): _impacto(_flash, 0.85, 0.0)).set_delay(0.42)
	tw.tween_property(mat, "shader_parameter/cor", 1.0, 0.7).set_delay(0.95)
	tw.tween_property(ret, "scale", Vector2.ONE * 1.05, 6.0).set_delay(0.5)
	tw.tween_property(tag, "modulate:a", 1.0, 0.3).set_delay(0.45)
	tw.tween_property(nome, "visible_ratio", 1.0, 0.55).set_delay(0.7)
	tw.tween_property(apelido, "modulate:a", 1.0, 0.4).set_delay(1.35)
	tw.tween_property(campos, "modulate:a", 1.0, 0.35).set_delay(1.65)
	tw.tween_property(cv, "modulate:a", 1.0, 0.3).set_delay(1.9)
	for k in itens.size():
		tw.tween_property(itens[k], "modulate:a", 1.0, 0.3).set_delay(2.0 + k * 0.16)
	tw.tween_property(barras, "modulate:a", 1.0, 0.2).set_delay(2.4)
	for k in preenchimentos.size():
		tw.tween_property(preenchimentos[k], "scale:x", 1.0, 0.7).from(0.0).set_delay(2.5 + k * 0.12) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(carimbo, "scale", Vector2.ONE, 0.22).from(Vector2.ONE * 2.8).set_delay(4.3) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(carimbo, "rotation_degrees", -8.0, 0.22).from(-22.0).set_delay(4.3)
	tw.tween_property(carimbo, "modulate:a", 0.95, 0.22).set_delay(4.3)
	tw.tween_callback(func(): _impacto(_flash_v, 0.55, 1.3 if i == total - 1 else 1.0)).set_delay(4.5)
	await _esperar(PILOTO_S + (0.4 if i == total - 1 else 0.0))
	_glitch()


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
	var logo := _textura(_info.get("logo", ""), Vector2(150, 150))
	v.add_child(logo)
	var nome := _rotulo(String(_info["nome"]).to_upper(), "display", 64, OSSO, HORIZONTAL_ALIGNMENT_CENTER)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nome)
	var rk := _rotulo("#%d DO GRID · %s" % [int(_info["grid"]), String(_info["licenca"]).to_upper()],
			"mono", 18, ACO, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(rk)
	var cartoes := HBoxContainer.new()
	cartoes.alignment = BoxContainer.ALIGNMENT_CENTER
	cartoes.add_theme_constant_override("separation", 6)
	cartoes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cartoes)
	var internos: Array = []
	var pilotos: Array = _info["pilotos"]
	for k in pilotos.size():
		var c := _cartao(pilotos[k], ROTACAO_CARTOES[k % ROTACAO_CARTOES.size()])
		cartoes.add_child(c[0])
		internos.append(c[1])
	var vs := Control.new()
	vs.custom_minimum_size = Vector2(0, 150)
	vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(vs)
	var corte := ColorRect.new()
	corte.color = SANGUE
	corte.size = Vector2(size.x + 200, 12)
	corte.position = Vector2(-128, 70)
	corte.pivot_offset = corte.size / 2.0
	corte.rotation_degrees = -6.0
	corte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vs.add_child(corte)
	var vs_l := _rotulo("VS", "display", 150, OSSO, HORIZONTAL_ALIGNMENT_CENTER)
	vs_l.add_theme_constant_override("outline_size", 10)
	vs_l.add_theme_color_override("font_outline_color", TINTA)
	vs_l.size = Vector2(size.x - 56, 150)
	vs_l.position = Vector2(0, -16)
	vs_l.pivot_offset = vs_l.size / 2.0
	vs.add_child(vs_l)
	var nos := _rotulo(String(_info.get("jogador_nome", "")).to_upper(), "display", 60, SANGUE, HORIZONTAL_ALIGNMENT_CENTER)
	nos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nos)
	var nos_sub := _rotulo("FORA DO GRID · DESAFIANTE" if _contexto == "primeiro"
			else "#%d DO GRID · DESAFIANTE" % (int(_info["grid"]) + 1), "mono", 18, ACO, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(nos_sub)
	var jogo := VBoxContainer.new()
	jogo.add_theme_constant_override("separation", 2)
	v.add_child(_divisoria())
	v.add_child(jogo)
	jogo.add_child(_rotulo("VITÓRIA NA %s · MÉDIA" % String(_info["licenca"]).to_upper(), "mono", 15, ACO,
			HORIZONTAL_ALIGNMENT_CENTER))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	jogo.add_child(h)
	var moeda := _textura("res://arte/ui/cabecalho/icone_giros.png", Vector2(52, 52))
	h.add_child(moeda)
	var valor := _rotulo(Aba.dinheiro(int(_info["premio"])), "display", 72, OURO)
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
	var ir_b := Button.new()
	var arena := String(_info.get("modo", "")) != "corrida"
	Tipografia.acao_primaria(ir_b, "%s   →" % ("Arena" if arena else "Corridas"), Color(0.2, 0.21, 0.24), Color.WHITE, 26,
			Tipografia.ALTURA_SECUNDARIA)
	ir_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ir_b.pressed.connect(func():
		ir.emit(int(_abas[1 if arena else 0]))
		_fechar())
	botoes.add_child(ir_b)
	var b := Button.new()
	Tipografia.acao_primaria(b, "Continuar", Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 26, Tipografia.ALTURA_SECUNDARIA)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(_fechar)
	botoes.add_child(b)
	if pronto:
		return
	_impacto(_flash, 0.7, 0.0)
	for c in [logo, nome, rk, nos, nos_sub, jogo, botoes]:
		c.modulate.a = 0.0
	vs_l.modulate.a = 0.0
	corte.scale.x = 0.0
	for c in internos:
		c.modulate.a = 0.0
	var tw := _cena.create_tween().set_parallel(true)
	_tw_confronto = tw
	tw.tween_property(logo, "modulate:a", 1.0, 0.5)
	tw.tween_property(nome, "modulate:a", 1.0, 0.3).set_delay(0.25)
	tw.tween_property(rk, "modulate:a", 1.0, 0.3).set_delay(0.45)
	for k in internos.size():
		var c: Control = internos[k]
		tw.tween_property(c, "position:y", 0.0, 0.4).from(-300.0).set_delay(0.5 + k * 0.15) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate:a", 1.0, 0.3).set_delay(0.5 + k * 0.15)
	tw.tween_property(corte, "scale:x", 1.0, 0.25).set_delay(1.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(vs_l, "scale", Vector2.ONE, 0.22).from(Vector2.ONE * 2.6).set_delay(1.7) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(vs_l, "modulate:a", 1.0, 0.22).set_delay(1.7)
	tw.tween_callback(func(): _impacto(_flash_v, 0.6, 1.4)).set_delay(1.92)
	tw.tween_property(nos, "modulate:a", 1.0, 0.35).set_delay(2.4)
	tw.tween_property(nos_sub, "modulate:a", 1.0, 0.4).set_delay(2.8)
	tw.tween_property(jogo, "modulate:a", 1.0, 0.3).set_delay(3.1)
	tw.tween_method(func(x: float): valor.text = Aba.dinheiro(int(x)), 0.0, float(_info["premio"]), 1.2) \
			.set_delay(3.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(botoes, "modulate:a", 1.0, 0.3).set_delay(3.6)


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


func _coluna(topo: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.position = Vector2(40, topo)
	v.size = Vector2(size.x - 80, 0)
	v.add_theme_constant_override("separation", 16)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cena.add_child(v)
	return v


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


## Campo da ficha: rótulo pequeno, valor grande e uma nota.
func _campo(titulo: String, valor: String, nota: String) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 2)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(_rotulo(titulo, "mono", 14, ACO))
	var v := _rotulo(valor.to_upper(), "display_eb", 28, OSSO)
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(v)
	c.add_child(_rotulo(nota, "mono", 15, ACO))
	return c


## [linha, preenchimento]: rótulo, trilho com o preenchimento e o valor.
## Barra de um atributo (1 = 100% = cheia) com o valor em % (vírgula, pt-BR).
func _barra(titulo: String, valor: float, casas: int) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _rotulo(titulo, "mono", 15, ACO)
	t.custom_minimum_size.x = 170
	h.add_child(t)
	var trilho := ColorRect.new()
	trilho.color = Color(OSSO, 0.08)
	trilho.custom_minimum_size = Vector2(0, 10)
	trilho.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trilho.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(trilho)
	var f := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.colors = PackedColorArray([SANGUE, OURO])
	gt.gradient = gr
	gt.width = 64
	gt.height = 4
	f.texture = gt
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_SCALE
	f.anchor_bottom = 1.0
	f.anchor_right = clampf(valor, 0.0, 1.0)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trilho.add_child(f)
	var n := _rotulo("%s%%" % Aba.decimal(valor * 100.0, casas), "mono_sb", 16, OSSO, HORIZONTAL_ALIGNMENT_RIGHT)
	n.custom_minimum_size.x = 76
	h.add_child(n)
	return [h, f]


## Cartão "polaroide" do confronto: [vaga no contêiner, cartão que cai].
func _cartao(p: Dictionary, rot: float) -> Array:
	var vaga := Control.new()
	vaga.custom_minimum_size = Vector2(158, 200)
	vaga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = OSSO
	sb.set_content_margin_all(7)
	sb.content_margin_bottom = 4
	c.add_theme_stylebox_override("panel", sb)
	c.size = Vector2(150, 196)
	c.position = Vector2(4, 0)
	c.pivot_offset = c.size / 2.0
	c.rotation_degrees = rot
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vaga.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var r := TextureRect.new()
	r.texture = Assets.get_asset(String(p["id"]), "retrato")
	r.custom_minimum_size = Vector2(136, 136)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(r)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var ap := _rotulo(String(p["apelido"]).to_upper(), "display_eb", 18, TINTA)
	ap.clip_text = true
	ap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ap)
	h.add_child(_rotulo(str(int(p["numero"])), "display", 22, SANGUE))
	return [vaga, c]


func _montar_hud() -> void:
	var cantos := [["THE GRID // RANKING", Control.PRESET_TOP_LEFT],
			["PRÓXIMA DISPUTA", Control.PRESET_BOTTOM_LEFT],
			["RIVAL #%d" % int(_info.get("grid", 0)), Control.PRESET_BOTTOM_RIGHT]]
	for c in cantos:
		var l := _rotulo(c[0], "mono", 15, Color(ACO, 0.8))
		l.set_anchors_and_offsets_preset(c[1])
		l.grow_horizontal = Control.GROW_DIRECTION_BEGIN if c[1] == Control.PRESET_BOTTOM_RIGHT else Control.GROW_DIRECTION_END
		l.grow_vertical = Control.GROW_DIRECTION_BEGIN if c[1] != Control.PRESET_TOP_LEFT else Control.GROW_DIRECTION_END
		var dx := -20.0 if c[1] == Control.PRESET_BOTTOM_RIGHT else 20.0
		var dy := 20.0 if c[1] == Control.PRESET_TOP_LEFT else -14.0
		l.offset_left += dx
		l.offset_right += dx
		l.offset_top += dy
		l.offset_bottom += dy
		add_child(l)
		_hud.append(l)


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
