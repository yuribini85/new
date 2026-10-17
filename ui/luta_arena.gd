class_name LutaArena
extends Control
## Tela da luta (já resolvida): a arena em 3D, o painel de integridade, o
## tempo e "Pular". No fim, a faixa do resultado (posição, pontos, giros e,
## se foi o caso, o carro perdido) e o botão de voltar. Por cima de tudo.

signal acabou(final: Dictionary)

const VELOCIDADE := 1.0  # tempo da luta por segundo de tela
const FIM_S := 1.2  # depois do último quadro, antes do resultado
const CONTAGEM_S := 3.0  # largada 3-2-1, como na corrida
## Câmeras: [nome, modo da Arena3D, ícone (arte/ui/cameras)].
const CAMERAS := [["Sua briga", "briga", "jogador"], ["Arena inteira", "geral", "geral"],
		["Dinâmica", "dinamica", "auto"]]

var _dados: Dictionary
var _vista: Arena3D
var _hud: HudArena
var _vida: PainelVidaArena
var _relogio: Label
var _pular: Button
var _fim := -1.0
var _faixa: PanelContainer
var _contagem := CONTAGEM_S
var _sons: Sons
var _semaforo: Control
var _cameras_botoes: Array = []


func _init(dados_luta: Dictionary, params: Dictionary) -> void:
	_dados = dados_luta
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = Color(0.06, 0.06, 0.07)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	_vista = Arena3D.new()
	_vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vista.modo = Preferencias.camera_arena if Preferencias.camera_arena in CAMERAS.map(func(c): return c[1]) else "briga"
	add_child(_vista)
	_hud = HudArena.new()
	_hud.position = Vector2(16, 70)
	add_child(_hud)
	# A integridade dos seus carros, grande, embaixo à esquerda (ao lado de Pular).
	_vida = PainelVidaArena.new()
	_vida.limite_re = float(params.get("limite_re", 0.9))
	_vida.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	add_child(_vida)
	_relogio = Label.new()
	Tipografia.rotulo(_relogio, "semibold", 30)
	_relogio.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_relogio.offset_left = -170
	_relogio.offset_right = -18
	_relogio.offset_top = 18
	_relogio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_relogio)
	var titulo := Label.new()
	titulo.text = "ARENA"
	Tipografia.rotulo(titulo, "semibold", 34)
	titulo.add_theme_color_override("font_color", Aba.COR_DESTAQUE)
	titulo.position = Vector2(18, 16)
	add_child(titulo)
	_pular = Button.new()
	Tipografia.acao_primaria(_pular, "Pular", Color(0.15, 0.15, 0.17), Color.WHITE, 26, 64)
	_pular.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_pular.offset_left = -200
	_pular.offset_right = -16
	_pular.offset_top = -84
	_pular.offset_bottom = -16
	_pular.pressed.connect(func():
		_contagem = -1.0
		_semaforo.queue_redraw()
		_vista.tempo = _vista.duracao())
	add_child(_pular)
	add_child(_seletor_cameras())
	# Semáforo da largada por cima da arena (o mesmo da corrida).
	_semaforo = Control.new()
	_semaforo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_semaforo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_semaforo.draw.connect(func(): HudCorrida.semaforo(_semaforo, _semaforo.size, _contagem, 0.48))  # abaixo do painel
	add_child(_semaforo)
	_sons = Sons.new()
	add_child(_sons)
	_vista.faixas_pintura = _dados.get("faixas", {})
	_vista.blindagens = _dados.get("blindagens", {})
	_vista.ready.connect(func(): _vista.mostrar(_dados["resultado"], params, _dados["modelos"], _dados["pinturas"]))


## Os três modos em ícones, no alto à direita (o escolhido em âmbar), como o
## seletor da corrida. A escolha fica para as próximas lutas.
func _seletor_cameras() -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Aba.COR_CARTAO, 0.7)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(3)
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	p.offset_left = -16 - 3 * 64 - 10
	p.offset_right = -16
	p.offset_top = 70
	p.offset_bottom = 70 + 58
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	p.add_child(h)
	var vazio := StyleBoxEmpty.new()
	var marcado := StyleBoxFlat.new()
	marcado.bg_color = Aba.COR_DESTAQUE
	marcado.set_corner_radius_all(8)
	for c in CAMERAS:
		var b := Button.new()
		b.tooltip_text = c[0]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(64, 52)
		var ic := TextureRect.new()
		ic.texture = Aba.arte("cameras/" + String(c[2]))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		ic.offset_left = -20
		ic.offset_right = 20
		ic.offset_top = -20
		ic.offset_bottom = 20
		b.add_child(ic)
		for estado in ["normal", "hover", "focus", "disabled"]:
			b.add_theme_stylebox_override(estado, vazio)
		for estado in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(estado, marcado)
		b.pressed.connect(_camera.bind(String(c[1])))
		h.add_child(b)
		_cameras_botoes.append(b)
	_marcar_camera()
	return p


func _camera(modo: String) -> void:
	_vista.modo = modo
	_marcar_camera()
	if Preferencias.camera_arena != modo:
		Preferencias.camera_arena = modo
		Preferencias.salvar()


func _marcar_camera() -> void:
	for i in _cameras_botoes.size():
		var marcado: bool = CAMERAS[i][1] == _vista.modo
		_cameras_botoes[i].button_pressed = marcado
		(_cameras_botoes[i].get_child(0) as TextureRect).modulate = Color(0.1, 0.1, 0.1) if marcado else Aba.COR_SECUNDARIA


func _process(delta: float) -> void:
	if _vista.duracao() <= 0.0:
		return
	if _contagem >= 0.0:
		# Largada: os carros parados no lugar até as luzes apagarem.
		if _contagem == CONTAGEM_S:
			_sons.largada(false)  # o "3"
		var antes := ceili(_contagem)
		_contagem -= delta
		if _contagem <= 0.0:
			_contagem = -1.0
			_sons.largada(true)
		elif ceili(_contagem) < antes:
			_sons.largada(false)
		_semaforo.queue_redraw()
		_vista.atualizar(delta)
		_relogio.text = "0 s"
		_placar()
		return
	if _fim < 0.0:
		_vista.tempo = minf(_vista.tempo + delta * VELOCIDADE, _vista.duracao())
	_vista.atualizar(delta)
	_relogio.text = "%d s" % int(_vista.tempo)
	_placar()
	if _vista.tempo >= _vista.duracao() and _fim < 0.0:
		_fim = 0.0
		_pular.visible = false
	if _fim >= 0.0:
		_fim += delta
		if _fim >= FIM_S and _faixa == null:
			_mostrar_final()


## Placar em cima e, embaixo, a integridade dos seus carros; o placar aberto
## desce até logo acima dela.
func _placar() -> void:
	var l := _linhas()
	_hud.linhas = l
	_vida.carros = l.filter(func(x): return x.has("dano") and x["voce"])
	_vida.position = Vector2(16, size.y - 16 - _vida.size.y)
	_hud.altura_max = _vida.position.y - 16 - _hud.position.y


## O placar por equipe: o nome da equipe e, embaixo, os dois pilotos com o
## dano do carro. Equipes de pé em cima (a sua primeiro); quando os dois carros
## de uma equipe caem, ela recebe a posição e desce, de cima para baixo.
func _linhas() -> Array:
	var r: Dictionary = _dados["resultado"]
	var amostras: Array = r["amostras"]
	var a: Dictionary = amostras[mini(_vista._i + 1, amostras.size() - 1)]
	var info: Dictionary = _dados.get("equipes", {})
	var grupos := {}  # equipe -> [ids]
	var ordem := []
	var ids: Array = r["carros"].keys()
	ids.sort_custom(func(x, y): return _ordem_id(x) < _ordem_id(y))
	for id in ids:
		var eq := String(r["carros"][id].get("equipe", id))
		if not grupos.has(eq):
			grupos[eq] = []
			ordem.append(eq)
		grupos[eq].append(id)
	var de_pe := []
	var caidas := []
	for eq in ordem:
		if grupos[eq].any(func(id): return not a[id]["eliminado"]):
			de_pe.append(eq)
		else:
			caidas.append(eq)
	var queda := func(eq): return grupos[eq].reduce(func(m, id): return maxf(m, float(r["carros"][id]["eliminado_em"])), -INF)
	caidas.sort_custom(func(x, y): return queda.call(x) > queda.call(y))
	var acabou := _fim >= 0.0
	if acabou:
		var venc := String(r.get("equipe_vencedora", ""))
		de_pe.sort_custom(func(x, y): return x == venc and y != venc)
	var l := []
	var n := 0
	for eq in de_pe + caidas:
		n += 1
		var caiu: bool = caidas.has(eq)
		var primeiro: String = grupos[eq][0]
		var e: Dictionary = info.get(primeiro, {})
		var voce: bool = eq == "jogador"
		var cor: Color = e.get("cor", Aba.COR_DESTAQUE if voce else CarroBloco.cor_do_id(primeiro))
		var pos := n if caiu or acabou or de_pe.size() == 1 else 0
		l.append({"tipo": "equipe", "nome": String(e.get("nome", "")) if String(e.get("nome", "")) != "" else eq.to_upper(),
				"cor": cor, "posicao": pos, "eliminado": caiu, "voce": voce})
		for id in grupos[eq]:
			l.append({"id": id, "nome": _dados["nomes"].get(id, id), "carro": String(_dados["modelos"].get(id, {}).get("nome", "")),
					"cor": cor, "dano": a[id]["dano"], "eliminado": a[id]["eliminado"], "voce": voce})
	return l


static func _ordem_id(id: String) -> String:
	return {"jogador": "0", "parceiro": "1"}.get(id, "2" + id)


func _mostrar_final() -> void:
	var f: Dictionary = _dados["final"]
	_faixa = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.06, 0.94)
	sb.border_color = Aba.COR_RUIM if f["perdeu"] else Aba.COR_DESTAQUE
	sb.border_width_top = 4
	sb.set_content_margin_all(24)
	_faixa.add_theme_stylebox_override("panel", sb)
	_faixa.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_faixa.offset_top = -420
	add_child(_faixa)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_faixa.add_child(v)
	var t := Label.new()
	t.text = "CARRO PERDIDO" if f["perdeu"] else ("SUA DUPLA VENCEU" if f.get("venceu_equipe", f["posicao"] == 1) \
			else "%dº LUGAR" % f["posicao"])
	Tipografia.rotulo(t, "semibold", 44)
	t.add_theme_color_override("font_color", Aba.COR_RUIM if f["perdeu"] else Aba.COR_DESTAQUE)
	v.add_child(t)
	var notas := []
	if f.get("demo", false):
		# Demonstração: o jogador só assistiu; vale quem venceu.
		t.text = "VENCEU: %s" % String(f.get("vencedora", "")).to_upper() if String(f.get("vencedora", "")) != "" \
				else "FIM DA LUTA"
		var dd := Label.new()
		dd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dd.text = "Demonstração: seis duplas, a última de pé vence."
		Tipografia.rotulo(dd, "regular", 26)
		v.add_child(dd)
	elif f.get("simulacao", false):
		var posicao_eq := _linhas().filter(func(l): return l.get("tipo", "") == "equipe" and l["voce"])
		if not posicao_eq.is_empty() and int(posicao_eq[0]["posicao"]) > 0 and not f["venceu_equipe"]:
			t.text = "SUA DUPLA: %dº" % int(posicao_eq[0]["posicao"])
		notas.append("Simulação: nada mudou na garagem nem no campeonato.")
	if f["perdeu"]:
		notas.append("O %s foi eliminado e saiu da garagem." % f["carro"])
	if f.get("perdeu_parceiro", false):
		notas.append("O carro da sua dupla foi eliminado e saiu da garagem.")
	if f.get("venceu_equipe", false) and f["perdeu"]:
		notas.append("Mesmo assim, a sua dupla ficou de pé.")
	for at in f.get("atropelados", []):
		var falta := float(at.get("fora_s", 0.0))
		notas.append(("Fuga do fogo: %s levou um atropelamento e fica fora por %s." % [at["nome"],
				ArenaCarreira.texto_tempo(falta)]) if falta > 0.0
				else ("Fuga do fogo: %s levou um atropelamento, mas já se levantou." % at["nome"]))
	if f.get("subiu_nivel", false):
		notas.append("Próximo campeonato: uma equipe a mais.")
	# Desafio do The Grid (decisão 74): o placar da série.
	var serie: Dictionary = f.get("serie", {})
	if not serie.is_empty():
		if int(serie.get("rounds", 1)) > 1:
			notas.append("Série: %d × %d." % [int(serie["vitorias"]), int(serie["derrotas"])])
		if serie["venceu"]:
			notas.append("Desafio vencido: a equipe ficou para trás no Grid.")
		elif serie["fim"]:
			notas.append("Desafio perdido. Dá para desafiar de novo.")
		else:
			notas.append("Próximo round na Arena: os carros destruídos são trocados.")
	if int(f.get("pecas_destruidos", 0)) > 0:
		notas.append("Rivais destruídos pela sua dupla: +%s peças." % Aba.dinheiro(int(f["pecas_destruidos"])))
	if int(f.get("pecas_perdidos", 0)) > 0:
		notas.append("Do que sobrou dos seus: +%s peças." % Aba.dinheiro(int(f["pecas_perdidos"])))
	for txt in notas:
		var d := Label.new()
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.text = txt
		Tipografia.rotulo(d, "regular", 26)
		v.add_child(d)
	# Pontos e prêmio no padrão dos números do jogo (valor grande, moeda).
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.visible = not f.get("demo", false)  # a demonstração não tem pontos da sua dupla
	v.add_child(h)
	for par in ([[str(f["pontos"]), "pontos"]] if f.get("simulacao", false) else [[str(f["pontos"]), "pontos"], [Aba.dinheiro(f["premio"]), ""]]):
		var n := Label.new()
		n.text = par[0]
		Tipografia.numero(n, 40)
		n.add_theme_color_override("font_color", Aba.COR_DESTAQUE if par[1] == "" else Color.WHITE)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(n)
		if par[1] != "":
			var u := Label.new()
			u.text = par[1] + "   ·"
			Tipografia.rotulo(u, "medium", 24)
			u.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
			u.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(u)
		else:
			var moeda := TextureRect.new()
			moeda.texture = Aba.arte(Aba.ICONE_GIROS)
			moeda.custom_minimum_size = Vector2(32, 32)
			moeda.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			moeda.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			moeda.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(moeda)
	var b := Button.new()
	Tipografia.acao_primaria(b, "Voltar à arena", Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 30, Tipografia.ALTURA_SECUNDARIA)
	b.pressed.connect(func():
		acabou.emit(f)
		queue_free())
	v.add_child(b)
