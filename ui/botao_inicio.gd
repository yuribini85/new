class_name BotaoInicio
extends Button
## Botões da tela inicial (referência do usuário): cantos chanfrados.
## Principal: ocre com borda clara, brilho em volta e quadriculado de bandeira
## nos dois lados, apagando para o centro. Secundário: placa escura
## translúcida, borda clara fina e duas barras inclinadas ("//") em cada lado.
## Só desenho; o toque é o do Button.

const CHANFRO := 16
const COR_ESCURA := Color(0.04, 0.07, 0.13, 0.84)
const COR_BORDA_SEC := Color(0.78, 0.84, 0.93, 0.75)
const COR_BARRAS := Color(0.55, 0.68, 0.9, 0.9)

var principal := false
var cor := Color.WHITE


func _init(texto: String, principal_: bool, cor_: Color, tamanho: int, altura: float, largura: float) -> void:
	principal = principal_
	cor = cor_
	if principal:
		Tipografia.acao_primaria(self, texto, cor, Color(0.08, 0.07, 0.06), tamanho, altura)
	else:
		Tipografia.acao_secundaria(self, texto, Color(0.95, 0.93, 0.89), tamanho, altura)
		flat = false
	add_theme_font_override("font", Tipografia.fonte("display" if principal else "display_eb"))
	custom_minimum_size = Vector2(largura, altura)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	focus_mode = Control.FOCUS_NONE
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(estado, _caixa(estado))
	if not principal:
		add_theme_color_override("font_hover_color", Color.WHITE)
		add_theme_color_override("font_pressed_color", Color.WHITE)


func _caixa(estado: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(CHANFRO)
	sb.corner_detail = 1  # um segmento por canto: chanfro reto
	sb.anti_aliasing = true
	if principal:
		var base := cor.lightened(0.08) if estado == "hover" else (cor.darkened(0.12) if estado == "pressed" else cor)
		sb.bg_color = base
		sb.set_border_width_all(3)
		sb.border_color = Color("ff9a2e")
		sb.shadow_color = Color(1.0, 0.45, 0.1, 0.5)
		sb.shadow_size = 16
	else:
		sb.bg_color = COR_ESCURA.lightened(0.08) if estado in ["hover", "pressed"] else COR_ESCURA
		sb.set_border_width_all(2)
		sb.border_color = COR_BORDA_SEC
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 6
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	return sb


func _draw() -> void:
	if principal:
		_quadriculado(true)
		_quadriculado(false)
	else:
		_barras(true)
		_barras(false)


## Quadriculado de bandeira num lado, apagando em direção ao centro.
func _quadriculado(esquerda: bool) -> void:
	var lado := size.y * 0.16
	var linhas := 4
	var colunas := 4
	var y0 := (size.y - linhas * lado) / 2.0
	var escura := Color("8a4a0e")
	for c in colunas:
		var x := 14.0 + c * lado if esquerda else size.x - 14.0 - (c + 1) * lado
		var a := 0.75 * (1.0 - float(c) / colunas)
		for l in linhas:
			if (c + l) % 2 == 0:
				draw_rect(Rect2(x, y0 + l * lado, lado, lado), Color(escura.r, escura.g, escura.b, a))


## Duas barras inclinadas ("//") perto da borda.
func _barras(esquerda: bool) -> void:
	var h := size.y * 0.36
	var w := h * 0.22
	var incl := h * 0.42
	var y0 := (size.y - h) / 2.0
	for k in 2:
		var x := 22.0 + k * (w + 6.0) if esquerda else size.x - 22.0 - incl - w - (1 - k) * (w + 6.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x + incl, y0), Vector2(x + incl + w, y0),
				Vector2(x + w, y0 + h), Vector2(x, y0 + h)]), COR_BARRAS)
