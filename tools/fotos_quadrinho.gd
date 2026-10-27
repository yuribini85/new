extends SceneTree
## Fotos das cenas em quadrinho (CenaQuadrinho, data/idle/cenas.json): uma por
## fala pedida, parada com a fala inteira no balão.
## Uso (precisa de tela: xvfb-run): godot --path . --script res://tools/fotos_quadrinho.gd -- \
##   --cena=abertura --falas=0,3,9 --saida=/pasta [--fundo=loja/fundo] [--alto=1280]

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var cena := "abertura"
	var falas := [0]
	var saida := "user://"
	var fundo := ""
	var alto := 1280
	var prefixo := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cena="):
			cena = arg.trim_prefix("--cena=")
		elif arg.begins_with("--falas="):
			falas = Array(arg.trim_prefix("--falas=").split(",")).map(func(x): return int(x))
		elif arg.begins_with("--saida="):
			saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--fundo="):
			fundo = arg.trim_prefix("--fundo=")
		elif arg.begins_with("--fonte_fala="):
			# Comparar fontes das falas sem mudar o jogo.
			var v := FontVariation.new()
			v.base_font = load(arg.trim_prefix("--fonte_fala="))
			v.fallbacks = [ThemeDB.fallback_font]
			Tipografia._cache["fala"] = v
		elif arg.begins_with("--prefixo="):
			prefixo = arg.trim_prefix("--prefixo=")
		elif arg.begins_with("--alto="):
			alto = int(arg.trim_prefix("--alto="))
	root.size = Vector2i(720, alto)
	root.content_scale_size = Vector2i(720, alto)
	for i in falas:
		var base := Control.new()
		base.size = Vector2(720, alto)
		root.add_child(base)
		if fundo != "":
			var tr := TextureRect.new()
			tr.texture = load("res://arte/fastfather/%s.webp" % fundo)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.size = base.size
			base.add_child(tr)
		var q := CenaQuadrinho.new(cena)
		q.parar_em = i
		base.add_child(q)
		for k in 30:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/%s%s_%02d.png" % [saida, prefixo, cena, i])
		base.queue_free()
		await process_frame
	quit()
