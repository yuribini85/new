class_name CartaoMomento
extends PanelContainer
## Cartão do momento de decisão na corrida (decisão 117, MomentosCorrida):
## título, a situação e duas escolhas, com uma barra que esvazia em `janela_s`.
## Sem toque até lá, fecha sem ordem nenhuma.

signal escolhido(id: String)

## Texto de cada escolha (o id vem de data/simulacao.json, "momentos.opcoes").
const ROTULOS := {
	"atacar": ["ATACAR AGORA", "Tenta passar já, no limite"],
	"esperar": ["ESPERAR A RETA", "Guarda o carro e ataca depois"],
	"defender": ["FECHAR A PORTA", "Acelera para segurar a posição"],
	"poupar": ["POUPAR PNEUS", "Deixa vir e volta mais forte"],
}

var _barra: ColorRect
var _janela := 4.0
var _resta := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.92)
	sb.border_color = Aba.COR_DESTAQUE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)
	visible = false


## Mostra o momento `m` (MomentosCorrida.detectar) com as escolhas do tipo.
func abrir(m: Dictionary, escolhas: Array, nome_rival: String, janela_s: float) -> void:
	for c in get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var titulo := Label.new()
	titulo.text = "VÁCUO! HORA DE DECIDIR" if m["tipo"] == MomentosCorrida.ATAQUE else "PRESSÃO ATRÁS!"
	Tipografia.rotulo(titulo, "semibold", 34)
	titulo.add_theme_color_override("font_color", Aba.COR_DESTAQUE)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)
	var sub := Label.new()
	sub.text = ("%s está %d m à frente" if m["tipo"] == MomentosCorrida.ATAQUE else "%s está %d m atrás") \
			% [nome_rival, roundi(float(m["distancia"]))]
	Tipografia.rotulo(sub, "medium", 24)
	sub.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	for i in escolhas.size():
		var id: String = escolhas[i][0]
		var rot: Array = ROTULOS.get(id, [id.to_upper(), ""])
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		h.add_child(col)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		if i == 0:
			Tipografia.acao_primaria(b, rot[0], Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 26, 76)
		else:
			Tipografia.acao_neutra(b, rot[0], 26, 76)
		b.pressed.connect(func(): _escolher(id))
		col.add_child(b)
		var dica := Label.new()
		dica.text = rot[1]
		Tipografia.rotulo(dica, "regular", 20)
		dica.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
		dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(dica)
	_barra = ColorRect.new()
	_barra.color = Aba.COR_DESTAQUE
	_barra.custom_minimum_size = Vector2(0, 6)
	v.add_child(_barra)
	_janela = maxf(janela_s, 0.5)
	_resta = _janela
	visible = true


func aberto() -> bool:
	return visible


func fechar() -> void:
	visible = false
	_resta = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_resta -= delta
	if _barra != null:
		_barra.scale.x = clampf(_resta / _janela, 0.0, 1.0)
	if _resta <= 0.0:
		fechar()


func _escolher(id: String) -> void:
	fechar()
	escolhido.emit(id)
