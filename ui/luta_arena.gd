class_name LutaArena
extends Control
## Tela da luta (já resolvida): a arena em 3D, o painel de integridade, o
## tempo e "Pular". No fim, a faixa do resultado (posição, pontos, giros e,
## se foi o caso, o carro perdido) e o botão de voltar. Por cima de tudo.

signal acabou(final: Dictionary)

const VELOCIDADE := 1.0  # tempo da luta por segundo de tela
const FIM_S := 1.2  # depois do último quadro, antes do resultado
const CONTAGEM_S := 3.0  # largada 3-2-1, como na corrida

var _dados: Dictionary
var _vista: Arena3D
var _hud: HudArena
var _relogio: Label
var _pular: Button
var _fim := -1.0
var _faixa: PanelContainer
var _contagem := CONTAGEM_S
var _sons: Sons
var _semaforo: Control


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
	add_child(_vista)
	_hud = HudArena.new()
	_hud.position = Vector2(16, 70)
	_hud.limite_re = float(params.get("limite_re", 0.9))
	add_child(_hud)
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
	# Semáforo da largada por cima da arena (o mesmo da corrida).
	_semaforo = Control.new()
	_semaforo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_semaforo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_semaforo.draw.connect(func(): HudCorrida.semaforo(_semaforo, _semaforo.size, _contagem, 0.48))  # abaixo do painel
	add_child(_semaforo)
	_sons = Sons.new()
	add_child(_sons)
	_vista.ready.connect(func(): _vista.mostrar(_dados["resultado"], params, _dados["modelos"], _dados["pinturas"]))


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
		_hud.linhas = _linhas()
		return
	if _fim < 0.0:
		_vista.tempo = minf(_vista.tempo + delta * VELOCIDADE, _vista.duracao())
	_vista.atualizar(delta)
	_relogio.text = "%d s" % int(_vista.tempo)
	_hud.linhas = _linhas()
	if _vista.tempo >= _vista.duracao() and _fim < 0.0:
		_fim = 0.0
		_pular.visible = false
	if _fim >= 0.0:
		_fim += delta
		if _fim >= FIM_S and _faixa == null:
			_mostrar_final()


func _linhas() -> Array:
	var r: Dictionary = _dados["resultado"]
	var amostras: Array = r["amostras"]
	var a: Dictionary = amostras[mini(_vista._i + 1, amostras.size() - 1)]
	var l := []
	# Você em cima; os outros na ordem da largada.
	var ids: Array = r["carros"].keys().filter(func(x): return x != "jogador")
	if r["carros"].has("jogador"):
		ids.push_front("jogador")
	for id in ids:
		l.append({"id": id, "nome": _dados["nomes"].get(id, id), "cor": Aba.COR_DESTAQUE if id == "jogador" else CarroBloco.cor_do_id(id),
				"dano": a[id]["dano"], "eliminado": a[id]["eliminado"], "voce": id == "jogador"})
	return l


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
	t.text = ("CARRO PERDIDO" if f["perdeu"] else ("ÚLTIMO DE PÉ" if f["posicao"] == 1 else "%dº LUGAR" % f["posicao"]))
	Tipografia.rotulo(t, "semibold", 44)
	t.add_theme_color_override("font_color", Aba.COR_RUIM if f["perdeu"] else Aba.COR_DESTAQUE)
	v.add_child(t)
	if f["perdeu"]:
		var d := Label.new()
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.text = "O %s foi eliminado e saiu da garagem." % f["carro"]
		Tipografia.rotulo(d, "regular", 26)
		v.add_child(d)
	# Pontos e prêmio no padrão dos números do jogo (valor grande, moeda).
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	for par in [[str(f["pontos"]), "pontos"], [Aba.dinheiro(f["premio"]), ""]]:
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
	Tipografia.acao_primaria(b, "Voltar à arena", Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 30, 76)
	b.pressed.connect(func():
		acabou.emit(f)
		queue_free())
	v.add_child(b)
