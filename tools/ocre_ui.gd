extends SceneTree
## O destaque da interface é ocre (Aba.COR_DESTAQUE): o amarelo pintado nos
## ícones e emblemas vira ocre. Medalhas e troféus de ouro, prata e bronze
## ficam como estão (a cor é o grau). O importador da interface aplica o mesmo
## recolor em toda arte nova; rodar este script de novo não muda nada (o ocre
## já não é amarelo para ele).
## Uso: godot --headless --path . --script res://tools/ocre_ui.gd

const PASTA := "res://arte/ui/"
const MANIFESTO := "res://arte/ui/ui_manifesto.json"
## Faixa do amarelo (matiz 0..1) e o ocre de chegada.
const MATIZ_MIN := 0.108  # 39°: abaixo é laranja/bronze/ocre, não mexe
const MATIZ_MAX := 0.17  # 61°
const MATIZ_OCRE := 0.095  # 34°: longe do limite, para o arredondamento de 8 bits não voltar à faixa
const BRILHO := 0.83  # #F2B530 → #C8892B


static func aplica(nome: String, tipo: String) -> bool:
	return tipo in ["icone", "emblema"] and not (nome.begins_with("icone_medalha_") or nome.begins_with("icone_trofeu_"))


static func recolorir(img: Image) -> int:
	img.convert(Image.FORMAT_RGBA8)
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0 or c.h < MATIZ_MIN or c.h > MATIZ_MAX or c.s < 0.3 or c.v < 0.3:
				continue
			# A matiz sempre sai da faixa (por isso rodar de novo não muda nada); o
			# brilho cai pelo peso da saturação: bordas e tons quase neutros, pouco.
			var w := smoothstep(0.3, 0.55, c.s)
			img.set_pixel(x, y, Color.from_hsv(MATIZ_OCRE + (c.h - MATIZ_MIN) * 0.1, c.s, c.v * lerpf(1.0, BRILHO, w), c.a))
			n += 1
	return n


func _initialize() -> void:
	var itens: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFESTO))
	var total := 0
	for it in itens:
		var nome: String = it["nome"]
		var arq := PASTA + nome + ".png"
		if not aplica(nome, it["tipo"]) or not FileAccess.file_exists(arq):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(arq))
		var n := recolorir(img)
		if n > 0:
			img.save_png(ProjectSettings.globalize_path(arq))
			total += 1
			print("ocre  %s (%d px)" % [nome, n])
	print("\n%d arquivos recoloridos" % total)
	quit()
