extends SceneTree
## Gera web/shell.html (tela de carregamento da versão web) a partir de
## web/shell_modelo.html, com a logo e o fundo da garagem embutidos (o
## navegador mostra a tela antes de baixar o jogo). O fundo vai reduzido e em
## JPEG para não pesar no carregamento.
## Uso: godot --headless --path . --script res://tools/gerar_shell_web.gd

const MODELO := "res://web/shell_modelo.html"
const SAIDA := "res://web/shell.html"
const LARGURA_FUNDO := 540
const QUALIDADE_FUNDO := 0.7


func _initialize() -> void:
	var logo := FileAccess.get_file_as_bytes("res://arte/ui/logo.png")
	var fundo := Image.load_from_file(ProjectSettings.globalize_path("res://arte/ui/fundo_garagem.png"))
	fundo.resize(LARGURA_FUNDO, roundi(fundo.get_height() * float(LARGURA_FUNDO) / fundo.get_width()), Image.INTERPOLATE_LANCZOS)
	var jpg := fundo.save_jpg_to_buffer(QUALIDADE_FUNDO)
	var html := FileAccess.get_file_as_string(MODELO)
	html = html.replace("{{LOGO}}", Marshalls.raw_to_base64(logo)).replace("{{FUNDO}}", Marshalls.raw_to_base64(jpg))
	var f := FileAccess.open(SAIDA, FileAccess.WRITE)
	f.store_string(html)
	f.close()
	print("web/shell.html: %d KB (logo %d KB, fundo %d KB)" % [html.length() / 1024, logo.size() / 1024, jpg.size() / 1024])
	quit()
