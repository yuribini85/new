extends SceneTree
## Importa a arte da interface (docs/linguagem.md) para res://arte/ui/, seguindo
## arte/ui/ui_manifesto.json:
##   icone, emblema, silhueta: exige fundo transparente (ou magenta chapado),
##     recorta o desenho e encaixa no tamanho do manifesto, sem distorcer
##     (silhueta apoiada na borda de baixo);
##   icone e emblema: o amarelo vira ocre (tools/ocre_ui.gd), menos medalhas e troféus;
##   miniatura, banner, fundo: corta ao centro na proporção do manifesto (o que
##     sobra nas bordas sai) e redimensiona.
## Relatório por arquivo; reprovado não substitui o atual.
## Uso: godot --headless --path . --script res://tools/importar_ui.gd -- --origem=/pasta [--destino=/outra/pasta]

const MANIFESTO := "res://arte/ui/ui_manifesto.json"
const DESTINO_PADRAO := "res://arte/ui/"
const Kit := preload("res://tools/importar_kit_pista.gd")
const Ocre := preload("res://tools/ocre_ui.gd")


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
	var resumo := {"importado": 0, "reprovado": 0, "faltando": 0}
	for it in itens:
		var nome: String = it["nome"]
		var caminho := origem.path_join(nome + ".png")
		if not FileAccess.file_exists(caminho):
			resumo["faltando"] += 1
			print("faltando   %s" % nome)
			continue
		var img := Image.load_from_file(caminho)
		if img == null or img.is_empty():
			resumo["reprovado"] += 1
			print("reprovado  %s: não abre como imagem" % nome)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var tam := Vector2i(int(it["largura_px"]), int(it["altura_px"]))
		var r: Array = _recortado(img, tam, it["tipo"] == "silhueta") if it["tipo"] in ["icone", "emblema", "silhueta"] \
				else _cobrir(img, tam)
		resumo[r[0]] += 1
		print("%-10s %s: %s" % [r[0], nome, r[1]])
		if r[0] == "importado":
			if Ocre.aplica(nome, it["tipo"]):
				Ocre.recolorir(r[2])  # o destaque da interface é ocre
			(r[2] as Image).save_png(destino + nome + ".png")
	print("\n%d importados · %d reprovados · %d faltando" % [resumo["importado"], resumo["reprovado"], resumo["faltando"]])
	quit()


## Desenho com fundo transparente: recorta e encaixa centrado (ou apoiado embaixo).
func _recortado(img: Image, tam: Vector2i, apoiar: bool) -> Array:
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
	# Margem de 4% para o desenho não encostar na borda.
	var area := Vector2(tam) * 0.92
	var escala := minf(area.x / usado.size.x, area.y / usado.size.y)
	var novo := Vector2i(maxi(1, roundi(usado.size.x * escala)), maxi(1, roundi(usado.size.y * escala)))
	recorte.resize(novo.x, novo.y, Image.INTERPOLATE_LANCZOS)
	var final := Image.create(tam.x, tam.y, false, Image.FORMAT_RGBA8)
	final.fill(Color(0, 0, 0, 0))
	var pos := (tam - novo) / 2
	if apoiar:
		pos.y = tam.y - novo.y
	final.blit_rect(recorte, Rect2i(Vector2i.ZERO, novo), pos)
	return ["importado", ("fundo magenta removido; " if magenta else "") + "recortado em %dx%d" % [tam.x, tam.y], final]


## Imagem cheia: corte central na proporção pedida e redimensiona.
func _cobrir(img: Image, tam: Vector2i) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var alvo := float(tam.x) / tam.y
	var corte := Rect2i(0, 0, w, h)
	if float(w) / h > alvo:
		var nw := roundi(h * alvo)
		corte = Rect2i((w - nw) / 2, 0, nw, h)
	else:
		var nh := roundi(w / alvo)
		corte = Rect2i(0, (h - nh) / 2, w, nh)
	var r := img.get_region(corte)
	r.resize(tam.x, tam.y, Image.INTERPOLATE_LANCZOS)
	for y in tam.y:
		for x in tam.x:
			var c := r.get_pixel(x, y)
			if c.a < 1.0:
				c.a = 1.0
				r.set_pixel(x, y, c)
	return ["importado", "cortado %dx%d → %dx%d" % [corte.size.x, corte.size.y, tam.x, tam.y], r]
