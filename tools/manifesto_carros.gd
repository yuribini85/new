extends SceneTree
## Completa arte/carros/manifesto.json com a geometria de cada vista: tamanho
## da tela e retângulo ocupado pelo carro, medidos nos sprites atuais. Os
## provisórios (tools/gerar_sprites.gd) já estão na escala e na posição certas
## (docs/arte_carros.md); o importador encaixa a arte final nesse retângulo.
## Só preenche o que falta: carro novo, rode gerar_sprites.gd e depois este.
## Uso: godot --headless --path . --script res://tools/manifesto_carros.gd

const MANIFESTO := "res://arte/carros/manifesto.json"
const Importador := preload("res://tools/importar_kit_pista.gd")


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var itens: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFESTO))
	var d: Node = root.get_node_or_null("Dados")
	var ids := itens.map(func(i): return i["id"])
	if d != null:
		for b in d.lista("carros"):
			if not ids.has(b["id"]):
				printerr("sem descrição no manifesto: %s" % b["id"])
	for it in itens:
		for vista in ["topo", "iso"]:
			if it.has(vista):
				continue
			var caminho := "res://arte/carros/%s_%s.png" % [it["id"], vista]
			if not FileAccess.file_exists(caminho):
				printerr("sem sprite: %s" % caminho)
				continue
			var img := Image.load_from_file(caminho)
			img.convert(Image.FORMAT_RGBA8)
			var r := Importador._contorno(img)
			it[vista] = {"tela": [img.get_width(), img.get_height()], "rect": [r.position.x, r.position.y, r.size.x, r.size.y]}
	var f := FileAccess.open(MANIFESTO, FileAccess.WRITE)
	f.store_string(JSON.stringify(itens, " ", false) + "\n")
	print("manifesto dos carros: %d modelos" % itens.size())
	quit()
