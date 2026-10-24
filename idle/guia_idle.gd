class_name GuiaIdle
extends Control
## Tutorial leve do Chrome Racing Team, no estilo do Destaque do Chrome &
## Wreckage: depois da conversa que abre uma função, o resto da tela escurece,
## um contorno dourado pulsa em volta do que tocar, uma seta balança apontando
## para lá e uma frase curta diz onde tocar (a voz do TUTORIAL: o texto exato do
## botão, uma frase). Não segura o toque: o jogador toca direto no destacado, e
## qualquer toque (ou o tempo) fecha a dica. Sem alvo, só a frase, no alto.

## Apresentação, não balanceamento.
const MARGEM := 8.0
const ESPESSURA := 4.0
const ESCURO := 0.55
const ENTRADA_S := 0.25
const DURACAO_S := 10.0
const SETA := 22.0

var _retangulo := Callable()  # -> Rect2 global do alvo (Rect2() sem alvo)
var _caixa: PanelContainer
var _texto: Label
var _t := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_caixa = PanelContainer.new()
	_caixa.add_theme_stylebox_override("panel", IdleUI.caixa(Color(IdleUI.COR_CARTAO, 0.97), 14, 14, IdleUI.COR_OURO, 2))
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caixa)
	_texto = IdleUI.rotulo("", 22, IdleUI.COR_TEXTO, _caixa)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## `retangulo`: devolve o retângulo global do alvo (segue a tela se ela mudar).
func mostrar(texto: String, retangulo := Callable()) -> void:
	_retangulo = retangulo
	_texto.text = texto
	_t = 0.0
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, ENTRADA_S)
	Sons.tocar_ui(self, "toque", -10.0, 1.3)
	queue_redraw()


func limpar() -> void:
	visible = false
	_retangulo = Callable()


func ativo() -> bool:
	return visible


func _alvo() -> Rect2:
	if not _retangulo.is_valid():
		return Rect2()
	var r: Rect2 = _retangulo.call()
	return Rect2(r.position - get_global_rect().position, r.size).grow(MARGEM) if r.has_area() else Rect2()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t >= DURACAO_S:
		limpar()
		return
	_posicionar_caixa(_alvo())
	queue_redraw()


## A frase do lado com mais espaço (acima ou abaixo do alvo); sem alvo, no alto.
func _posicionar_caixa(r: Rect2) -> void:
	var largura := minf(size.x - 48.0, 520.0)
	_caixa.custom_minimum_size = Vector2(largura, 0)
	_caixa.size = Vector2(largura, 0)
	var h := _caixa.get_combined_minimum_size().y
	var x := clampf((r.get_center().x if r.has_area() else size.x * 0.5) - largura * 0.5, 24.0, size.x - largura - 24.0)
	var y := size.y * 0.22
	if r.has_area():
		var acima := r.position.y > size.y - r.end.y
		y = r.position.y - h - SETA * 2.2 if acima else r.end.y + SETA * 2.2
	_caixa.position = Vector2(x, clampf(y, 24.0, size.y - h - 24.0))


func _draw() -> void:
	var r := _alvo()
	var escuro := Color(0, 0, 0, ESCURO)
	if not r.has_area():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, ESCURO * 0.5))
		return
	# O resto da tela escurece; o alvo fica limpo.
	draw_rect(Rect2(0, 0, size.x, r.position.y), escuro)
	draw_rect(Rect2(0, r.end.y, size.x, size.y - r.end.y), escuro)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), escuro)
	draw_rect(Rect2(r.end.x, r.position.y, size.x - r.end.x, r.size.y), escuro)
	var pulso := 0.6 + 0.4 * sin(_t * TAU / 1.1)
	draw_rect(r, Color(IdleUI.COR_OURO, pulso), false, ESPESSURA)
	draw_rect(r.grow(4.0 + 4.0 * pulso), Color(IdleUI.COR_OURO, 0.25 * pulso), false, 2.0)
	# Seta entre a frase e o alvo, balançando na direção do alvo.
	var acima := _caixa.position.y < r.position.y
	var balanco := sin(_t * TAU / 0.8) * 6.0
	var ponta := Vector2(r.get_center().x, (r.position.y - 6.0 if acima else r.end.y + 6.0) + (balanco if acima else -balanco))
	var d := -1.0 if acima else 1.0
	draw_colored_polygon(PackedVector2Array([ponta, ponta + Vector2(-SETA * 0.7, d * SETA), ponta + Vector2(SETA * 0.7, d * SETA)]),
			IdleUI.COR_OURO)
