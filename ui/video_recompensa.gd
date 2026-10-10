class_name VideoRecompensa
extends Control
## Lugar do vídeo com recompensa (decisão 39). Até o plugin de anúncios entrar
## (AdMob, Android/iOS, depois do MVP), mostra um vídeo de teste com contagem:
## mesmo fluxo, mesma recompensa. Fechar antes do fim não dá a recompensa.

signal terminou(assistiu: bool)

const DURACAO_TESTE_S := 5.0

var _t := 0.0
var _barra: ProgressBar
var _contagem: Label
var _fechou := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.02, 0.03, 0.97)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 0)
	v.add_theme_constant_override("separation", 22)
	centro.add_child(v)
	var icone := IconeVetor.new("acelerar", Cabecalho.COR_NUMERO)
	icone.custom_minimum_size = Vector2(0, 120)
	v.add_child(icone)
	var t := Label.new()
	t.text = "VÍDEO DE TESTE"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tipografia.rotulo(t, "semibold", 40)
	v.add_child(t)
	var d := Label.new()
	d.text = "Aqui entra o anúncio de verdade. Assista até o fim para as corridas andarem mais rápido."
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_font_size_override("font_size", 26)
	d.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
	v.add_child(d)
	_barra = ProgressBar.new()
	_barra.show_percentage = false
	_barra.max_value = DURACAO_TESTE_S
	_barra.custom_minimum_size = Vector2(0, 12)
	v.add_child(_barra)
	_contagem = Label.new()
	_contagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tipografia.numero(_contagem, 34)
	_contagem.add_theme_color_override("font_color", Cabecalho.COR_NUMERO)
	v.add_child(_contagem)
	var fechar := Button.new()
	Tipografia.acao_secundaria(fechar, "Fechar sem recompensa")
	fechar.pressed.connect(func(): _fim(false))
	v.add_child(fechar)


func _process(delta: float) -> void:
	_t += delta
	_barra.value = _t
	_contagem.text = "%d" % ceili(maxf(DURACAO_TESTE_S - _t, 0.0))
	if _t >= DURACAO_TESTE_S:
		_fim(true)


func _fim(assistiu: bool) -> void:
	if _fechou:
		return
	_fechou = true
	terminou.emit(assistiu)
	queue_free()
