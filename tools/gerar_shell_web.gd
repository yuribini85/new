extends SceneTree
## Gera as telas de carregamento da versão web a partir de
## web/shell_modelo.html, com a logo do jogo embutida (o navegador mostra a
## tela antes de baixar o jogo), sobre fundo preto: web/shell.html (Chrome &
## Wreckage) e web/shell_idle.html (The Fastfather, docs/idle/plano.md, com
## a logo de tools/gerar_logo_crt.py e o nome dele na aba do navegador).
## Uso: godot --headless --path . --script res://tools/gerar_shell_web.gd

const MODELO := "res://web/shell_modelo.html"
const LARGURA_LOGO := 720
const SAIDAS := [
	{"saida": "res://web/shell.html", "logo": "res://arte/ui/logo.png", "nome": ""},
	{"saida": "res://web/shell_idle.html", "logo": "res://arte/idle/logo.png", "nome": "The Fastfather"},
]


func _initialize() -> void:
	for s in SAIDAS:
		# Logo reduzido (o original é grande demais para ir dentro da página).
		var img := Image.load_from_file(ProjectSettings.globalize_path(s["logo"]))
		if img.get_width() > LARGURA_LOGO:
			img.resize(LARGURA_LOGO, roundi(img.get_height() * float(LARGURA_LOGO) / img.get_width()), Image.INTERPOLATE_LANCZOS)
		var logo := img.save_png_to_buffer()
		var html := FileAccess.get_file_as_string(MODELO).replace("{{LOGO}}", Marshalls.raw_to_base64(logo))
		if s["nome"] != "":
			html = html.replace("<title>$GODOT_PROJECT_NAME</title>", "<title>%s</title>" % s["nome"]) \
					.replace('alt="Chrome &amp; Wreckage"', 'alt="%s"' % s["nome"])
		var f := FileAccess.open(s["saida"], FileAccess.WRITE)
		f.store_string(html)
		f.close()
		print("%s: %d KB (logo %d KB)" % [s["saida"], html.length() / 1024, logo.size() / 1024])
	quit()
