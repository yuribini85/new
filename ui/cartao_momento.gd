class_name CartaoMomento
extends PanelContainer
## Cartão do momento de decisão na corrida (decisão 117, MomentosCorrida):
## título, a situação e duas escolhas, com uma barra que esvazia em `janela_s`.
## Sem toque até lá, fecha sem ordem nenhuma.

signal escolhido(id: String)
## A janela acabou sem toque.
signal expirou

## Texto de cada escolha (o id vem de data/simulacao.json, "momentos.opcoes").
const ROTULOS := {
	"atacar": ["ATACAR AGORA", "Tenta passar já, no limite"],
	"esperar": ["ESPERAR A RETA", "Guarda o carro e ataca depois"],
	"defender": ["FECHAR A PORTA", "Acelera para segurar a posição"],
	"poupar": ["POUPAR PNEUS", "Deixa vir e volta mais forte"],
}
## O que o HUD mostra no toque (%s: o rival).
const ACAO := {
	"atacar": ["ATAQUE!", "Pra cima de %s"],
	"esperar": ["PACIÊNCIA...", "O bote vem na reta"],
	"defender": ["PORTA FECHADA!", "Segurando %s"],
	"poupar": ["POUPANDO PNEUS", "Deixa %s vir e responde depois"],
}
## Saída depois do toque: o botão acende e o cartão cresce e some (técnico).
const SAIDA_S := 0.22

var _barra: ColorRect
var _janela := 4.0
var _resta := 0.0
var _aberto := false
var _saida: Tween


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
	if _saida != null:
		_saida.kill()
	scale = Vector2.ONE
	modulate = Color.WHITE
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
		b.pressed.connect(func(): _escolher(id, b))
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
	_aberto = true
	visible = true


func aberto() -> bool:
	return _aberto


func fechar() -> void:
	if _saida != null:
		_saida.kill()
	_aberto = false
	visible = false
	_resta = 0.0


func _process(delta: float) -> void:
	if not _aberto:
		return
	_resta -= delta
	if _barra != null:
		_barra.scale.x = clampf(_resta / _janela, 0.0, 1.0)
	if _resta <= 0.0 and _aberto:
		fechar()
		expirou.emit()


func _escolher(id: String, botao: Button) -> void:
	if not _aberto:
		return
	_aberto = false
	escolhido.emit(id)
	if Preferencias.reduzir_animacoes:
		fechar()
		return
	# O botão escolhido acende; o cartão cresce um pouco e some.
	botao.modulate = Color(1.6, 1.5, 1.2)
	pivot_offset = size * 0.5
	_saida = create_tween().set_parallel()
	_saida.tween_property(self, "scale", Vector2(1.12, 1.12), SAIDA_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_saida.tween_property(self, "modulate:a", 0.0, SAIDA_S).set_delay(SAIDA_S * 0.4)
	_saida.chain().tween_callback(fechar)
