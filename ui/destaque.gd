class_name Destaque
extends Control
## Destaque do tutorial (HIGHLIGHT_* das cenas): o resto da tela perde o
## destaque (escurece) e um contorno pulsante envolve o controle, sem pegar
## toque. Fica até outro destaque, a troca de tela ou limpar(); se a tela for
## reconstruída, procura o controle de novo pela âncora (`buscar`). Fica abaixo
## da caixa de diálogo, que continua legível. Se a âncora passa a outro
## controle (a janela aberta por cima traz o botão a tocar), o destaque vai
## junto e avisa (`alvo_mudou`), para a caixa do diálogo sair da frente.

signal alvo_mudou(r: Rect2)

## Apresentação, não balanceamento.
const MARGEM := 8.0
const ESPESSURA := 5.0
const ESCURO := 0.55
const ENTRADA_S := 0.3

var _alvo: Control
var _buscar: Callable
var _aparecia := true
var _t := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## `buscar`: devolve o controle atual da âncora (ou null) depois de uma
## reconstrução da tela.
func mostrar(alvo: Control, buscar := Callable()) -> void:
	_alvo = alvo
	_buscar = buscar
	_t = 0.0
	_aparecia = true
	visible = true
	queue_redraw()


func limpar() -> void:
	visible = false
	_alvo = null
	_buscar = Callable()


func ativo() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _buscar.is_valid():
		# A âncora manda: outro controle, o destaque vai junto; escondido (ex.:
		# o botão da janela sumiu para este candidato), não desenha; nenhum, sai.
		var novo = _buscar.call()
		if not is_instance_valid(novo):
			limpar()
			return
		var aparece := _valido(novo)
		if aparece and (novo != _alvo or not _aparecia):
			alvo_mudou.emit((novo as Control).get_global_rect())
		_alvo = novo
		_aparecia = aparece
	elif not _valido(_alvo):
		limpar()
		return
	queue_redraw()


func _valido(c: Variant) -> bool:
	return is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree()


func _draw() -> void:
	if not visible or not _valido(_alvo):
		return
	var r := _alvo.get_global_rect().grow(MARGEM)
	r.position -= get_global_rect().position
	var entrada := smoothstep(0.0, ENTRADA_S, _t)
	# O resto da tela escurece (quatro faixas em volta do alvo).
	var sombra := Color(0, 0, 0, ESCURO * entrada)
	var tela := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(0, 0, tela.size.x, maxf(r.position.y, 0.0)), sombra)
	draw_rect(Rect2(0, r.end.y, tela.size.x, maxf(tela.size.y - r.end.y, 0.0)), sombra)
	draw_rect(Rect2(0, r.position.y, maxf(r.position.x, 0.0), r.size.y), sombra)
	draw_rect(Rect2(r.end.x, r.position.y, maxf(tela.size.x - r.end.x, 0.0), r.size.y), sombra)
	var pulso := 0.55 + 0.45 * sin(_t * TAU * 1.2)
	var cor := Aba.COR_DESTAQUE
	cor.a = pulso * entrada
	draw_rect(r, cor, false, ESPESSURA)
	var halo := Aba.COR_DESTAQUE
	halo.a = 0.25 * pulso * entrada
	draw_rect(r.grow(ESPESSURA), halo, false, ESPESSURA * 2.0)
