extends SceneTree
## Importa o kit de arte das pistas gerado fora (agente de imagem) para
## res://arte/pistas/kit/, seguindo arte/pistas/kit_manifesto.json:
##   textura e faixa: redimensiona para o tamanho do manifesto, tira a
##     transparência e, se as bordas não emendam, torna repetível (mistura com
##     a própria imagem deslocada de meia volta, com máscara que zera nas bordas);
##   sprite: exige fundo transparente (cantos e boa parte da imagem), recorta o
##     que é usado e encaixa no tamanho do manifesto, centrado, sem distorcer.
##     Fundo magenta chapado (#FF00FF), plano B do gerador, vira transparente.
## Imprime um relatório: aprovado, corrigido (e por quê) ou reprovado (e por
## quê). Arquivo reprovado não substitui o atual.
## Uso: godot --headless --path . --script res://tools/importar_kit_pista.gd -- --origem=/pasta/com/os/png
##   [--destino=/outra/pasta]  (para conferir sem tocar no kit do jogo)

const MANIFESTO := "res://arte/pistas/kit_manifesto.json"
const DESTINO_PADRAO := "res://arte/pistas/kit/"
## Diferença média entre bordas opostas acima da qual a textura é corrigida.
const LIMITE_EMENDA := 0.06


func _initialize() -> void:
	var origem := ""
	var destino := DESTINO_PADRAO
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--origem="):
			origem = a.trim_prefix("--origem=")
		elif a.begins_with("--destino="):
			destino = a.trim_prefix("--destino=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino))
	if origem == "":
		printerr("uso: -- --origem=/pasta/com/os/png")
		quit(1)
		return
	var itens: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFESTO))
	var resumo := {"aprovado": 0, "corrigido": 0, "reprovado": 0, "faltando": 0}
	for it in itens:
		var caminho := origem.path_join(String(it["nome"]) + ".png")
		if not FileAccess.file_exists(caminho):
			resumo["faltando"] += 1
			print("faltando   %s" % it["nome"])
			continue
		var img := Image.load_from_file(caminho)
		if img == null or img.is_empty():
			resumo["reprovado"] += 1
			print("reprovado  %s: não abre como imagem" % it["nome"])
			continue
		img.convert(Image.FORMAT_RGBA8)
		var r: Array = _textura(img, it) if it["tipo"] != "sprite" else _sprite(img, it)
		var estado: String = r[0]
		resumo[estado] += 1
		print("%-10s %s%s" % [estado, it["nome"], (": " + r[1]) if r[1] != "" else ""])
		if estado != "reprovado":
			(r[2] as Image).save_png(destino + String(it["nome"]) + ".png")
	print("\n%d aprovados · %d corrigidos · %d reprovados · %d faltando" % [resumo["aprovado"], resumo["corrigido"],
			resumo["reprovado"], resumo["faltando"]])
	quit()


func _textura(img: Image, it: Dictionary) -> Array:
	var notas := []
	var w := int(it["largura_px"])
	var h := int(it["altura_px"])
	if img.get_width() != w or img.get_height() != h:
		notas.append("tamanho %dx%d → %dx%d" % [img.get_width(), img.get_height(), w, h])
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 1.0:
				c.a = 1.0
				img.set_pixel(x, y, c)
	# Faixa (zebra) tem listras de propósito entre a borda de cima e a de baixo.
	var emenda := _emenda(img) if it["tipo"] == "textura" else 0.0
	if emenda > LIMITE_EMENDA:
		img = _repetivel(img)
		notas.append("bordas não emendavam (%.2f): tornada repetível" % emenda)
	return ["corrigido" if not notas.is_empty() else "aprovado", ", ".join(notas), img]


func _sprite(img: Image, it: Dictionary) -> Array:
	var w := int(it["largura_px"])
	var h := int(it["altura_px"])
	var magenta := _tirar_magenta(img)
	var transparentes := 0
	var total := img.get_width() * img.get_height()
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).a < 0.1:
				transparentes += 1
	var fracao := float(transparentes) / float(total / 16)
	var cantos := [Vector2i(0, 0), Vector2i(img.get_width() - 1, 0), Vector2i(0, img.get_height() - 1),
			Vector2i(img.get_width() - 1, img.get_height() - 1)]
	if fracao < 0.08 or cantos.any(func(c): return img.get_pixelv(c).a > 0.1):
		return ["reprovado", "sem fundo transparente (refazer com fundo transparente)", img]
	var usado := _contorno(img)
	var recorte := img.get_region(usado)
	for y in recorte.get_height():
		for x in recorte.get_width():
			if recorte.get_pixel(x, y).a < 0.06:
				recorte.set_pixel(x, y, Color(0, 0, 0, 0))
	# Encaixa sem distorcer, centrado, no tamanho do manifesto.
	var escala := minf(float(w) / usado.size.x, float(h) / usado.size.y)
	var novo := Vector2i(maxi(1, roundi(usado.size.x * escala)), maxi(1, roundi(usado.size.y * escala)))
	recorte.resize(novo.x, novo.y, Image.INTERPOLATE_LANCZOS)
	var final := Image.create(w, h, false, Image.FORMAT_RGBA8)
	final.fill(Color(0, 0, 0, 0))
	final.blit_rect(recorte, Rect2i(Vector2i.ZERO, novo), (Vector2i(w, h) - novo) / 2)
	var proporcao := (float(usado.size.x) / usado.size.y) / (float(w) / h)
	var notas := ("fundo magenta removido; " if magenta else "") + "recortado e encaixado em %dx%d" % [w, h]
	if proporcao < 0.7 or proporcao > 1.43:
		notas += "; proporção muito diferente da pedida (%.2f×), conferir" % proporcao
	return ["corrigido", notas, final]


## Retângulo do objeto: pixels de alfa alto, com folga de 1%. Resíduos quase
## transparentes que o gerador deixa espalhados no fundo ficam de fora (o
## get_used_rect os contaria e o objeto sairia menor e fora de proporção).
static func _contorno(img: Image) -> Rect2i:
	var mn := Vector2i(img.get_width(), img.get_height())
	var mx := Vector2i(-1, -1)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.25:
				mn = mn.min(Vector2i(x, y))
				mx = mx.max(Vector2i(x, y))
	if mx.x < 0:
		return img.get_used_rect()
	var folga := maxi(1, roundi(maxf(img.get_width(), img.get_height()) * 0.01))
	var r := Rect2i(mn - Vector2i(folga, folga), mx - mn + Vector2i(1, 1) + Vector2i(folga, folga) * 2)
	return r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))


## Fundo magenta chapado (os quatro cantos magenta): vira transparente, com
## borda suave e sem o halo rosado nos pixels de transição.
static func _tirar_magenta(img: Image) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	for c in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		if _dist_magenta(img.get_pixelv(c)) > 0.25:
			return false
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var d := _dist_magenta(c)
			if d >= 0.45:
				continue
			var a := clampf((d - 0.2) / 0.25, 0.0, 1.0)
			# Tira o rosa: o canal verde é o que o magenta não tem.
			c.r = minf(c.r, c.g + 0.1)
			c.b = minf(c.b, c.g + 0.1)
			c.a = a
			img.set_pixel(x, y, c)
	return true


static func _dist_magenta(c: Color) -> float:
	return (absf(c.r - 1.0) + c.g + absf(c.b - 1.0)) / 3.0


## Diferença média entre colunas e linhas das bordas opostas (0 = emenda perfeita).
static func _emenda(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var soma := 0.0
	for y in h:
		var a := img.get_pixel(0, y)
		var b := img.get_pixel(w - 1, y)
		soma += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
	for x in w:
		var a := img.get_pixel(x, 0)
		var b := img.get_pixel(x, h - 1)
		soma += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
	return soma / float(w + h)


## Mistura a imagem com ela mesma deslocada de meia largura e meia altura: a
## cópia deslocada é contínua nas bordas, e a máscara usa só ela ali.
static func _repetivel(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var m := minf(minf(x, w - 1 - x) / (w * 0.25), minf(y, h - 1 - y) / (h * 0.25))
			m = clampf(m, 0.0, 1.0)
			var a := img.get_pixel(x, y)
			var b := img.get_pixel((x + w / 2) % w, (y + h / 2) % h)
			out.set_pixel(x, y, b.lerp(a, m))
	return out
