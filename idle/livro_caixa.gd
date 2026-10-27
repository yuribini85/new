class_name LivroCaixa
extends PanelContainer
## Página do livro-caixa do chefão (The Fastfather, BEM-VINDO DE VOLTA):
## papel pautado em azul, margem vermelha, as linhas escritas à mão (letra das
## falas) com o valor à direita e o TOTAL sublinhado duas vezes. A tela põe o
## título e os botões em `corpo`.

## Apresentação, não balanceamento.
const PAPEL := Color("efe6cf")
const TINTA := Color("1f2a44")  # tinta de caneta-tinteiro
const PAUTA := Color(0.35, 0.5, 0.75, 0.25)
const MARGEM := Color(0.75, 0.2, 0.2, 0.55)

var corpo: VBoxContainer


func _init() -> void:
	var sb := IdleUI.caixa(PAPEL, 2, 24, Color("8a7a5a"), 1)
	sb.content_margin_left = 64
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(6, 10)
	add_theme_stylebox_override("panel", sb)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 10)
	add_child(corpo)


func _draw() -> void:
	# Pauta e margem por baixo do conteúdo.
	var y := 30.0
	while y < size.y - 10.0:
		draw_line(Vector2(8, y), Vector2(size.x - 8, y), PAUTA, 1.0)
		y += 34.0
	draw_line(Vector2(48, 6), Vector2(48, size.y - 6), MARGEM, 2.0)
	draw_line(Vector2(52, 6), Vector2(52, size.y - 6), MARGEM, 1.0)


## Uma linha do livro: nome à esquerda, valor à direita.
func linha(nome: String, valor: String) -> void:
	var h := HBoxContainer.new()
	corpo.add_child(h)
	var n := IdleUI.rotulo(nome, 22, TINTA, h, "fala")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	IdleUI.rotulo(valor, 26, TINTA, h, "deco")


## O total, sublinhado duas vezes.
func total(nome: String, valor: String) -> void:
	var risco := ColorRect.new()
	risco.color = TINTA
	risco.custom_minimum_size = Vector2(0, 2)
	corpo.add_child(risco)
	var h := HBoxContainer.new()
	corpo.add_child(h)
	var n := IdleUI.rotulo(nome, 28, TINTA, h, "deco")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	IdleUI.rotulo(valor, 52, Color("1d5a35"), h, "deco")
	for k in 2:
		var r := ColorRect.new()
		r.color = Color(0.7, 0.15, 0.15)
		r.custom_minimum_size = Vector2(0, 2)
		corpo.add_child(r)
