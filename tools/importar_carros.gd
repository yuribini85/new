extends SceneTree
## Importa a arte final dos carros (docs/arte_carros.md) para res://arte/carros/,
## seguindo arte/carros/manifesto.json: para cada modelo, <id>_iso.png e
## <id>_topo.png. Exige fundo transparente (ou magenta chapado #FF00FF), recorta
## o carro e o encaixa, sem distorcer, no retângulo que o provisório ocupava
## (mesma escala de 160 px/m e mesma posição), na tela do tamanho do manifesto.
## Relatório: corrigido (com avisos de proporção) ou reprovado; reprovado não
## substitui o arquivo atual.
## Rodas do isométrico: rodas_iso_fixas do manifesto (marcadas à mão, para
## desenho em que a detecção falha: aro escuro em carro preto) ou parte do palpite do manifesto (rodas_iso) e acerta o
## centro pelo pneu escuro do desenho; grava em arte/carros/rodas.json (o
## efeito de roda girando usa).
## Uso: godot --headless --path . --script res://tools/importar_carros.gd -- --origem=/pasta [--destino=/outra/pasta]

const MANIFESTO := "res://arte/carros/manifesto.json"
const DESTINO_PADRAO := "res://arte/carros/"
const RODAS := "res://arte/carros/rodas.json"
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
	var rodas: Dictionary = {}
	if FileAccess.file_exists(RODAS):
		rodas = JSON.parse_string(FileAccess.get_file_as_string(RODAS))
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
				# Rodas marcadas à mão no manifesto valem mais que as achadas.
				if vista == "iso" and it.has("rodas_iso_fixas"):
					rodas[it["id"]] = it["rodas_iso_fixas"]
				elif vista == "iso" and it.has("rodas_iso"):
					rodas[it["id"]] = acertar_rodas(r[2], it["rodas_iso"])
	if destino == DESTINO_PADRAO:
		var f := FileAccess.open(RODAS, FileAccess.WRITE)
		f.store_string(JSON.stringify(rodas, " ", true) + "\n")
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
	# Isométrico: rodas no chão, ou seja, a base do desenho na base do
	# retângulo do provisório (centrado na largura). Se o desenho é mais baixo
	# que o provisório, centrar o deixaria flutuando.
	var pos := alvo.get_center() - novo / 2
	if vista == "iso":
		pos.y = alvo.end.y - novo.y
	final.blit_rect(recorte, Rect2i(Vector2i.ZERO, novo), pos)
	var notas := ("fundo magenta removido; " if magenta else "") + "encaixado em %dx%d" % [novo.x, novo.y]
	var proporcao := (float(usado.size.x) / usado.size.y) / (float(alvo.size.x) / alvo.size.y)
	# De cima, a proporção é a do carro (comprimento x largura): diferença
	# grande é carro largo ou estreito demais. No isométrico, é o ângulo.
	var limite := 0.12 if vista == "topo" else 0.2
	if absf(proporcao - 1.0) > limite:
		notas += "; proporção %.2f× a esperada (%s), conferir" % [proporcao,
				"largura do carro" if vista == "topo" else "ângulo da câmera"]
	return ["corrigido", notas, final]


## Rodas do isométrico: acha os aros no desenho (regiões claras cercadas pelo
## pneu escuro, mais altas que largas, na metade de baixo do carro) e fica com
## o aro mais perto de cada palpite (projeção do carro em código). A elipse da
## roda é a do aro aumentada até o pneu. Roda sem aro achado (aro escuro, carro
## preto) segue a outra: o palpite deslocado do mesmo tanto.
const PNEU_POR_ARO := 1.45


static func acertar_rodas(img: Image, palpite: Array) -> Array:
	var aros := _aros(img)
	var r := []
	var achado := []
	for p in palpite:
		var c := Vector2(p["c"][0], p["c"][1])
		var melhor: Variant = null
		var bp := Vector2(p["b"][0], p["b"][1]).length()
		for aro: Rect2 in aros:
			var d := aro.get_center().distance_to(c)
			# Aro do tamanho de uma roda deste carro (o palpite dá a ordem de grandeza).
			if aro.size.y < bp * 0.9 or aro.size.y > bp * 2.4:
				continue
			if d < 130.0 and (melhor == null or d < (melhor as Rect2).get_center().distance_to(c)):
				melhor = aro
		achado.append(melhor)
	for k in palpite.size():
		var p: Dictionary = palpite[k]
		var c := Vector2(p["c"][0], p["c"][1])
		var a := Vector2(p["a"][0], p["a"][1])
		var b := Vector2(p["b"][0], p["b"][1])
		var aro: Variant = achado[k]
		if aro == null:
			for j in palpite.size():
				if j != k and achado[j] != null:
					var outro: Dictionary = palpite[j]
					c += (achado[j] as Rect2).get_center() - Vector2(outro["c"][0], outro["c"][1])
					aro = Rect2(c - (achado[j] as Rect2).size * 0.5, (achado[j] as Rect2).size)
					break
		if aro != null:
			var ar: Rect2 = aro
			c = ar.get_center()
			a = Vector2(ar.size.x * 0.5 * PNEU_POR_ARO, 0.0)
			b = Vector2(0.0, -ar.size.y * 0.5 * PNEU_POR_ARO)
			if achado[k] == null:
				# Emprestada da outra roda: a altura vem do ponto em que o pneu
				# toca o chão (o mais baixo da silhueta logo abaixo).
				var chao := _mais_baixo(img, c.x, absf(a.x) * 0.6)
				if chao.y > 0.0 and absf(chao.y - absf(b.y) - c.y) < absf(b.y):
					c.y = chao.y - absf(b.y)
		r.append({"c": [snappedf(c.x, 0.1), snappedf(c.y, 0.1)], "a": [snappedf(a.x, 0.1), snappedf(a.y, 0.1)],
				"b": [snappedf(b.x, 0.1), snappedf(b.y, 0.1)], "achada": achado[k] != null})
	return r


## Regiões claras e opacas totalmente cercadas de pixels escuros (pneu), na
## metade de baixo do carro, agrupadas; só as com cara de aro visto de lado.
static func _aros(img: Image) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var usado := img.get_used_rect()
	var tipo := PackedByteArray()
	tipo.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			tipo[y * w + x] = 0 if c.a < 0.5 else (1 if c.get_luminance() < 0.22 and c.s < 0.4 else 2)
	var visto := PackedByteArray()
	visto.resize(w * h)
	var pedacos := []
	for y0 in range(usado.position.y + usado.size.y / 3, usado.end.y):
		for x0 in range(usado.position.x, usado.end.x):
			var i0 := y0 * w + x0
			if tipo[i0] != 2 or visto[i0] == 1:
				continue
			var pilha := [i0]
			visto[i0] = 1
			var fora := false
			var mn := Vector2i(x0, y0)
			var mx := Vector2i(x0, y0)
			var area := 0
			while not pilha.is_empty():
				var i: int = pilha.pop_back()
				var x := i % w
				var y := i / w
				area += 1
				mn = mn.min(Vector2i(x, y))
				mx = mx.max(Vector2i(x, y))
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var xx := x + d.x
					var yy := y + d.y
					if xx < 0 or yy < 0 or xx >= w or yy >= h:
						fora = true
						continue
					var j := yy * w + xx
					if tipo[j] == 0:
						fora = true
					elif tipo[j] == 2 and visto[j] == 0:
						visto[j] = 1
						pilha.append(j)
			var tam := mx - mn + Vector2i.ONE
			if not fora and area > 40 and tam.x < 140 and tam.y < 140:
				pedacos.append(Rect2(mn, tam))
	# Raios e aro saem em pedaços: junta os vizinhos.
	var grupos := []
	for r: Rect2 in pedacos:
		var junto := false
		for gi in grupos.size():
			if (grupos[gi] as Rect2).grow(20).intersects(r):
				grupos[gi] = (grupos[gi] as Rect2).merge(r)
				junto = true
				break
		if not junto:
			grupos.append(r)
	return grupos.filter(func(g: Rect2) -> bool:
		var prop := g.size.y / maxf(g.size.x, 1.0)
		return g.size.x > 25 and g.size.y > 35 and prop > 1.15 and prop < 2.3)


## Pixel opaco mais baixo da silhueta entre x0 - meia e x0 + meia.
static func _mais_baixo(img: Image, x0: float, meia: float) -> Vector2:
	var melhor := Vector2(-1, -1)
	for x in range(maxi(0, int(x0 - meia)), mini(img.get_width(), int(x0 + meia) + 1)):
		for y in range(img.get_height() - 1, -1, -1):
			if img.get_pixel(x, y).a > 0.5:
				if y > melhor.y:
					melhor = Vector2(x, y)
				break
	return melhor
