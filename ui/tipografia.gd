class_name Tipografia
extends RefCounted
## Tipografia das ações (tokens): Barlow Condensed, condensada e técnica, nos
## botões e títulos curtos; o texto corrido segue na fonte padrão, que lê melhor
## em parágrafo. Começa na tela inicial; as outras telas adotam pelos mesmos
## tokens (acao_primaria, acao_secundaria).
## Números (giros, prêmios, atributos, posição, velocidade): Racing Sans One.
## Licenças das fontes: ui/fontes/LICENCA-Barlow.txt e LICENCA-RacingSansOne.txt (OFL).

const ARQUIVOS := {
	"semibold": "res://ui/fontes/BarlowCondensed-SemiBold.ttf",
	"medium": "res://ui/fontes/BarlowCondensed-Medium.ttf",
	"regular": "res://ui/fontes/BarlowCondensed-Regular.ttf",
	"numero": "res://ui/fontes/RacingSansOne-Regular.ttf",
}
## Espaço extra entre letras (px), proporcional à caixa alta condensada.
const ESPACO_LETRAS := {"semibold": 2, "medium": 2, "regular": 1, "numero": 1}
const TAMANHO_PRIMARIA := 50
const TAMANHO_SECUNDARIA := 30
const ALTURA_PRIMARIA := 108  # área de toque confortável (>= 88)
const ALTURA_SECUNDARIA := 88
const RAIO := 8

static var _cache := {}


## A família no peso pedido, com o espaçamento entre letras do token.
static func fonte(peso: String) -> Font:
	if not _cache.has(peso):
		var base: Font = load(ARQUIVOS[peso])
		if base is FontFile:
			base.allow_system_fallback = false  # ver Principal._simbolos
		var v := FontVariation.new()
		v.base_font = base
		v.spacing_glyph = ESPACO_LETRAS[peso]
		# Acentos e símbolos que a família não tenha: a fonte padrão do tema.
		v.fallbacks = [ThemeDB.fallback_font]
		_cache[peso] = v
	return _cache[peso]


## Ação principal: preenchida no ocre, texto escuro, caixa alta.
static func acao_primaria(b: Button, texto: String, fundo := Aba.COR_DESTAQUE, cor := Color(0.1, 0.1, 0.1),
		tamanho := TAMANHO_PRIMARIA, altura := ALTURA_PRIMARIA) -> void:
	b.text = texto.to_upper()
	b.custom_minimum_size.y = altura
	b.add_theme_font_override("font", fonte("semibold"))
	b.add_theme_font_size_override("font_size", tamanho)
	var normal := _caixa(fundo)
	# Pressionado: um tom abaixo, sem animação.
	var pressionado := _caixa(fundo.darkened(0.18))
	var foco := _caixa(fundo)
	foco.border_color = Color(1, 1, 1, 0.85)
	foco.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressionado)
	b.add_theme_stylebox_override("focus", foco)
	b.add_theme_stylebox_override("disabled", _caixa(fundo.darkened(0.5)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, cor)
	b.add_theme_color_override("font_disabled_color", cor.lerp(fundo, 0.5))


## Ação de mesmo peso que a principal mas sem o destaque (ex.: vender): fundo
## escuro com borda fina, texto claro.
static func acao_neutra(b: Button, texto: String, tamanho := TAMANHO_SECUNDARIA, altura := ALTURA_SECUNDARIA) -> void:
	acao_primaria(b, texto, Aba.COR_CARTAO, Color(0.86, 0.87, 0.9), tamanho, altura)
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBoxFlat = (b.get_theme_stylebox(estado) as StyleBoxFlat).duplicate()
		sb.border_color = Color(1, 1, 1, 0.5 if estado == "focus" else 0.12)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override(estado, sb)
	b.add_theme_color_override("font_disabled_color", Color(0.86, 0.87, 0.9, 0.4))


## Ação secundária: sem fundo, caixa alta, área de toque maior que o texto.
static func acao_secundaria(b: Button, texto: String, cor := Color(0.86, 0.87, 0.9),
		tamanho := TAMANHO_SECUNDARIA, altura := ALTURA_SECUNDARIA) -> void:
	b.text = texto.to_upper()
	b.flat = true
	b.custom_minimum_size.y = altura
	b.add_theme_font_override("font", fonte("medium"))
	b.add_theme_font_size_override("font_size", tamanho)
	b.add_theme_color_override("font_color", cor)
	b.add_theme_color_override("font_hover_color", cor)
	b.add_theme_color_override("font_pressed_color", Aba.COR_DESTAQUE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", cor.darkened(0.5))
	var vazio := StyleBoxEmpty.new()
	for estado in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(estado, vazio)
	var foco := StyleBoxFlat.new()
	foco.bg_color = Color(0, 0, 0, 0)
	foco.border_color = Color(1, 1, 1, 0.5)
	foco.border_width_bottom = 2
	b.add_theme_stylebox_override("focus", foco)


## Fonte dos números (Racing Sans One, desenho original, sem efeitos).
static func fonte_numero() -> Font:
	return fonte("numero")


## Número na tela: Racing Sans One no tamanho pedido.
static func numero(l: Control, tamanho: int) -> void:
	l.add_theme_font_override("font", fonte_numero())
	l.add_theme_font_size_override("font_size", tamanho)


## Rótulo na família das ações (títulos curtos, rótulos em caixa alta).
static func rotulo(l: Control, peso: String, tamanho: int) -> void:
	l.add_theme_font_override("font", fonte(peso))
	l.add_theme_font_size_override("font_size", tamanho)


static func _caixa(cor: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(RAIO)
	sb.set_content_margin_all(12)
	return sb
