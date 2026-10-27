class_name JornalIdle
extends PanelContainer
## A primeira página do jornal do bairro (The Fastfather,
## docs/idle/identidade_fastfather.md): a manchete da subida de liga, a foto da
## pista em sépia com retícula, as notas da edição e colunas de texto miúdo.
## A tela põe os botões em `corpo`. Papel amarelado, tinta preta, filetes
## duplos, o nome do jornal em letreiro art déco.

## Apresentação, não balanceamento.
const PAPEL := Color("e8dcc0")
const TINTA := Color("1c1611")
const NOME := "GAZETA DO CAIS"

var corpo: VBoxContainer


func _init(manchete: String, foto: Texture2D, legenda: String, notas: Array) -> void:
	var sb := IdleUI.caixa(PAPEL, 2, 22, Color("8a7a5a"), 1)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(6, 10)
	add_theme_stylebox_override("panel", sb)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 8)
	add_child(corpo)
	var topo := HBoxContainer.new()
	corpo.add_child(topo)
	var ed := IdleUI.rotulo("EDIÇÃO EXTRA", 14, TINTA, topo)
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	IdleUI.rotulo("5 CENTAVOS", 14, TINTA, topo)
	_filete(2)
	var nome := IdleUI.rotulo(NOME, 46, TINTA, corpo, "deco")
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_filete(4)
	var m := IdleUI.rotulo(manchete, 40, TINTA, corpo, "display")
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if foto != null:
		var f := TextureRect.new()
		f.texture = foto
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # escala uniforme, recorta
		f.custom_minimum_size = Vector2(0, 220)
		f.clip_contents = true
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://idle/sepia.gdshader")
		f.material = sm
		corpo.add_child(f)
		var leg := IdleUI.rotulo(legenda, 16, TINTA, corpo, "regular")
		leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for n in notas:
		var l := IdleUI.rotulo(String(n), 22, TINTA, corpo)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var colunas := _Colunas.new()
	colunas.custom_minimum_size = Vector2(0, 64)
	corpo.add_child(colunas)


func _filete(alto: int) -> void:
	var r := ColorRect.new()
	r.color = TINTA
	r.custom_minimum_size = Vector2(0, alto)
	corpo.add_child(r)


## Colunas de texto miúdo (traços), só para a página parecer um jornal.
class _Colunas extends Control:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 13
		var col := (size.x - 24.0) / 3.0
		for c in 3:
			var x := c * (col + 12.0)
			for k in int(size.y / 9.0):
				var fim := col if k % 5 != 4 else col * rng.randf_range(0.3, 0.7)
				draw_line(Vector2(x, 4 + k * 9), Vector2(x + fim, 4 + k * 9), Color(JornalIdle.TINTA, 0.35), 3.0)
