extends SceneTree
## Gera web/shell.html (tela de carregamento da versão web) a partir de
## web/shell_modelo.html, com a logo do jogo embutida (o navegador mostra a
## tela antes de baixar o jogo), sobre fundo preto.
## Uso: godot --headless --path . --script res://tools/gerar_shell_web.gd

const MODELO := "res://web/shell_modelo.html"
const SAIDA := "res://web/shell.html"
const LARGURA_LOGO := 720


func _initialize() -> void:
	# Logo reduzido (o original é grande demais para ir dentro da página).
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://arte/ui/logo.png"))
	if img.get_width() > LARGURA_LOGO:
		img.resize(LARGURA_LOGO, roundi(img.get_height() * float(LARGURA_LOGO) / img.get_width()), Image.INTERPOLATE_LANCZOS)
	var logo := img.save_png_to_buffer()
	var html := FileAccess.get_file_as_string(MODELO).replace("{{LOGO}}", Marshalls.raw_to_base64(logo))
	var f := FileAccess.open(SAIDA, FileAccess.WRITE)
	f.store_string(html)
	f.close()
	print("web/shell.html: %d KB (logo %d KB)" % [html.length() / 1024, logo.size() / 1024])
	quit()
