class_name TelaVolta
extends Control
## "Enquanto você esteve fora" (decisão 108): tela própria, por cima de tudo,
## quando o jogo volta com renda do patrocínio, corridas terminadas ou treino
## concluído. O número dos giros sobe contando; embaixo, o que mais aconteceu.
## COLETAR fecha (o dinheiro já está no caixa); DOBRAR COM VÍDEO assiste ao
## vídeo com recompensa e paga a renda offline mais uma vez (só a do patrocínio).
## Com Reduzir animações, os números já aparecem prontos.

signal dobrar(valor: int)
signal fechou

const COR := Color("e8b04a")
const CONTA_S := 1.2
## Diferença mínima entre o tempo fora e o que rendeu para avisar do teto.
const TETO_AVISO_S := 600.0

var _valor := 0
var _numero: Label
var _botao_dobrar: Button


## rel: o relatório de volta (patrocinio, corridas, premio_total, carros_premio,
## patrocinios_encerrados, patrocinios_assinados, aviso_vagas).
func _init(rel: Dictionary, dados: Node) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_valor = int(rel.get("patrocinio", 0))
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.03, 0.035, 0.98)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right"]:
		m.add_theme_constant_override("margin_" + lado, 36)
	m.add_theme_constant_override("margin_top", 120)
	m.add_theme_constant_override("margin_bottom", 60)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)
	var sobre := Label.new()
	sobre.text = "ENQUANTO VOCÊ ESTEVE FORA"
	sobre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sobre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sobre.add_theme_font_override("font", Tipografia.fonte("display"))
	sobre.add_theme_font_size_override("font_size", 52)
	sobre.add_theme_color_override("font_color", Color.WHITE)
	v.add_child(sobre)
	if _valor > 0:
		var pat := Label.new()
		pat.text = "PATROCÍNIO"
		pat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pat.add_theme_font_override("font", Tipografia.fonte("mono_sb"))
		pat.add_theme_font_size_override("font_size", 22)
		pat.add_theme_color_override("font_color", Color(COR, 0.8))
		v.add_child(pat)
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 12)
		v.add_child(h)
		var moeda := TextureRect.new()
		moeda.texture = load(Cabecalho.PASTA + "icone_giros.png")
		moeda.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		moeda.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		moeda.custom_minimum_size = Vector2(64, 72)
		h.add_child(moeda)
		_numero = Label.new()
		_numero.text = "+0"
		Tipografia.numero(_numero, 96)
		_numero.add_theme_color_override("font_color", COR)
		h.add_child(_numero)
	var linhas := []
	var corridas: Array = rel.get("corridas", [])
	if not corridas.is_empty():
		var vit := corridas.filter(func(c): return c["posicao"] == 1).size()
		linhas.append("%d corrida%s · %d vitória%s · +%s giros em prêmios" % [corridas.size(),
				"" if corridas.size() == 1 else "s", vit, "" if vit == 1 else "s", Aba.dinheiro(int(rel.get("premio_total", 0)))])
	if not rel.get("carros_premio", []).is_empty():
		linhas.append("Carro de prêmio na garagem")
		if String(rel.get("aviso_vagas", "")) != "":
			linhas.append(String(rel["aviso_vagas"]))
	for nome in rel.get("patrocinios_encerrados", []):
		linhas.append("Contrato de %s encerrado" % nome)
	for nome in rel.get("patrocinios_assinados", []):
		linhas.append("Novo contrato: %s" % nome)
	# Bateu no teto da renda offline (decisão 104): curto e direto.
	var fora := float(rel.get("fora_s", 0.0))
	var pago := float(rel.get("pago_s", 0.0))
	if pago > 0.0 and fora - pago >= TETO_AVISO_S:
		linhas.append("Limite da renda offline: %s de %s. Cada título novo: +1 h." % [_horas(pago), _horas(fora)])
	for t in linhas:
		var l := Label.new()
		l.text = t
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Tipografia.rotulo(l, "medium", 26)
		l.add_theme_color_override("font_color", Color(0.88, 0.87, 0.84))
		v.add_child(l)
	var esp := Control.new()
	esp.custom_minimum_size = Vector2(0, 24)
	v.add_child(esp)
	if _valor > 0:
		_botao_dobrar = _botao(v, "DOBRAR COM VÍDEO  ·  +%s" % Aba.dinheiro(_valor), COR, Color(0.08, 0.07, 0.05))
		_botao_dobrar.pressed.connect(func():
			_botao_dobrar.disabled = true
			dobrar.emit(_valor))
	var col := _botao(v, "COLETAR", Color(0.18, 0.19, 0.22), Color.WHITE)
	col.pressed.connect(sair)


func _ready() -> void:
	Sons.tocar_ui(self, "moeda", -4.0)
	if _numero == null:
		return
	if Preferencias.reduzir_animacoes:
		_numero.text = "+" + Aba.dinheiro(_valor)
		return
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): _numero.text = "+" + Aba.dinheiro(roundi(x)), 0.0, float(_valor), CONTA_S)


## O vídeo terminou: mostra a renda dobrada (o Principal já pagou).
func dobrado() -> void:
	if _numero == null:
		return
	_botao_dobrar.text = "DOBRADO"
	var de := _valor
	_valor *= 2
	if Preferencias.reduzir_animacoes:
		_numero.text = "+" + Aba.dinheiro(_valor)
		return
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): _numero.text = "+" + Aba.dinheiro(roundi(x)), float(de), float(_valor), CONTA_S)
	tw.parallel().tween_property(_numero, "scale", Vector2(1.15, 1.15), CONTA_S * 0.5)
	tw.tween_property(_numero, "scale", Vector2.ONE, 0.2)


## O vídeo não foi até o fim: o botão volta.
func liberar_dobro() -> void:
	if _botao_dobrar != null:
		_botao_dobrar.disabled = false


static func _horas(s: float) -> String:
	return "%d h" % roundi(s / 3600.0) if s >= 3600.0 else "%d min" % maxi(1, roundi(s / 60.0))


func sair() -> void:
	fechou.emit()
	queue_free()


func _botao(pai: Control, texto: String, cor: Color, cor_texto: Color) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 96)
	Tipografia.acao_primaria(b, texto, cor, cor_texto, 34, 96)
	pai.add_child(b)
	return b
