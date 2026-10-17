class_name FaixaTitulo
extends TextureRect
## Faixa dourada atrás do título de impacto (arte do usuário,
## arte/ui/faixa_titulo.png): duas linhas finas, os riscos à esquerda e as
## manchas de tinta nas pontas. O título fica entre as linhas (de MEIO_Y[0] a
## MEIO_Y[1] da altura), começando em TEXTO_X da largura. Escala uniforme.

const MEIO_Y := Vector2(0.28, 0.604)
const TEXTO_X := 0.12


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = Aba.arte("faixa_titulo")
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT  # o tamanho já vem na proporção (proporcao())


## Largura ÷ altura da arte (1 sem arte).
func proporcao() -> float:
	return 1.0 if texture == null else float(texture.get_width()) / texture.get_height()
