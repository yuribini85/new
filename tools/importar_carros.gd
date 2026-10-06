extends SceneTree
## Importa a arte final dos carros (docs/arte_carros.md) para res://arte/carros/,
## seguindo arte/carros/manifesto.json: para cada modelo, <id>_iso.png e
## <id>_topo.png. Exige fundo transparente (ou magenta chapado #FF00FF), recorta
## o carro e o encaixa, sem distorcer, no retângulo que o provisório ocupava
## (mesma escala de 160 px/m e mesma posição), na tela do tamanho do manifesto.
## Relatório: corrigido (com avisos de proporção) ou reprovado; reprovado não
## substitui o arquivo atual.
## Uso: godot --headless --path . --script res://tools/importar_carros.gd -- --origem=/pasta [--destino=/outra/pasta]

const MANIFESTO := "res://arte/carros/manifesto.json"
const DESTINO_PADRAO := "res://arte/carros/"
const Kit := preload("res://tools/importar_kit_pista.gd")


func _initialize() -> void:
	var origem := ""
	var destino := DESTINO_PADRAO
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--origem="):
			origem = a.trim_prefix("--origem=")
		elif a.begins_with("--destino="):
			destino = a.trim_prefix("--destino=").trim_suffix("/") + "/"
	if origem == "":
		printerr("uso: -- --origem=/pasta/com/os/png")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino))
	var itens: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFESTO))
	var resumo := {"corrigido": 0, "reprovado": 0, "faltando": 0}
	for it in itens:
		for vista in ["iso", "topo"]:
			var nome := "%s_%s" % [it["id"], vista]
			var caminho := origem.path_join(nome + ".png")
			if not FileAccess.file_exists(caminho):
				resumo["faltando"] += 1
				print("faltando   %s" % nome)
				continue
			if not it.has(vista):
				resumo["reprovado"] += 1
				print("reprovado  %s: manifesto sem a geometria (rode tools/manifesto_carros.gd)" % nome)
				continue
			var img := Image.load_from_file(caminho)
			if img == null or img.is_empty():
				resumo["reprovado"] += 1
				print("reprovado  %s: não abre como imagem" % nome)
				continue
			img.convert(Image.FORMAT_RGBA8)
			var r := _encaixar(img, it[vista], vista)
			resumo[r[0]] += 1
			print("%-10s %s: %s" % [r[0], nome, r[1]])
			if r[0] != "reprovado":
				(r[2] as Image).save_png(destino + nome + ".png")
	print("\n%d importados · %d reprovados · %d faltando" % [resumo["corrigido"], resumo["reprovado"], resumo["faltando"]])
	quit()


func _encaixar(img: Image, geo: Dictionary, vista: String) -> Array:
	var magenta := Kit._tirar_magenta(img)
	var w := img.get_width()
	var h := img.get_height()
	for c in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		if img.get_pixelv(c).a > 0.1:
			return ["reprovado", "sem fundo transparente (refazer com fundo transparente)", img]
	var usado := Kit._contorno(img)
	var recorte := img.get_region(usado)
	for y in recorte.get_height():
		for x in recorte.get_width():
			if recorte.get_pixel(x, y).a < 0.06:
				recorte.set_pixel(x, y, Color(0, 0, 0, 0))
	var tela := Vector2i(int(geo["tela"][0]), int(geo["tela"][1]))
	var alvo := Rect2i(int(geo["rect"][0]), int(geo["rect"][1]), int(geo["rect"][2]), int(geo["rect"][3]))
	var escala := minf(float(alvo.size.x) / usado.size.x, float(alvo.size.y) / usado.size.y)
	if vista == "topo":
		# De cima, o comprimento manda (é a escala real do carro); a largura do
		# desenho vem junto, desde que caiba na tela.
		escala = minf(float(alvo.size.y) / usado.size.y, float(tela.x) / usado.size.x)
	var novo := Vector2i(maxi(1, roundi(usado.size.x * escala)), maxi(1, roundi(usado.size.y * escala)))
	recorte.resize(novo.x, novo.y, Image.INTERPOLATE_LANCZOS)
	var final := Image.create(tela.x, tela.y, false, Image.FORMAT_RGBA8)
	final.fill(Color(0, 0, 0, 0))
	final.blit_rect(recorte, Rect2i(Vector2i.ZERO, novo), alvo.get_center() - novo / 2)
	var notas := ("fundo magenta removido; " if magenta else "") + "encaixado em %dx%d" % [novo.x, novo.y]
	var proporcao := (float(usado.size.x) / usado.size.y) / (float(alvo.size.x) / alvo.size.y)
	# De cima, a proporção é a do carro (comprimento x largura): diferença
	# grande é carro largo ou estreito demais. No isométrico, é o ângulo.
	var limite := 0.12 if vista == "topo" else 0.2
	if absf(proporcao - 1.0) > limite:
		notas += "; proporção %.2f× a esperada (%s), conferir" % [proporcao,
				"largura do carro" if vista == "topo" else "ângulo da câmera"]
	return ["corrigido", notas, final]
