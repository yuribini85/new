extends SceneTree
## Fotos da loja da abertura (GaragemIdle com a conversa do Tony): uma por fala
## pedida (-1 = depois da conversa, com a compra na tela).
## Uso (precisa de tela: xvfb-run): godot --path . --script res://tools/fotos_loja.gd -- --falas=0,4,5,-1 --saida=/pasta

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var falas := [0]
	var saida := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--falas="):
			falas = Array(arg.trim_prefix("--falas=").split(",")).map(func(x): return int(x))
		elif arg.begins_with("--saida="):
			saida = arg.trim_prefix("--saida=")
	root.size = Vector2i(720, 1280)
	root.content_scale_size = Vector2i(720, 1280)
	for i in falas:
		var e := IdleEstado.new()
		var base := Control.new()
		base.size = Vector2(720, 1280)
		root.add_child(base)
		var g := GaragemIdle.new(e, Color.GOLD, {}, true)
		g.parar_cena_em = i if i >= 0 else 99
		base.add_child(g)
		var quadros := 40 if i >= 0 else 60
		if i < 0:
			# Sem conversa: só a loja com a compra.
			for c in g.get_children():
				if c is CenaQuadrinho:
					c.queue_free()
			g._ficha.modulate.a = 1.0
			g._pulsar(0)
		for k in quadros:
			await process_frame
		root.get_texture().get_image().save_png("%s/loja_%02d.png" % [saida, i if i >= 0 else 99])
		base.queue_free()
		await process_frame
	quit()
