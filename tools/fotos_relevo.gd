extends SceneTree
## Fotos da pista com relevo (Relevo) numa corrida sintética: carros a
## velocidade constante, a câmera seguindo o jogador; fotografa quando o carro
## sai do chão e quando pousa, e alguns quadros no ar. Revisão visual das
## rampas e ondulações.
## Uso (precisa de tela: xvfb-run): godot --script res://tools/fotos_relevo.gd -- --pista=trilha_do_canion --saida=/pasta/

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var pid := "trilha_do_canion"
	var saida := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pista="):
			pid = arg.trim_prefix("--pista=")
		elif arg.begins_with("--saida="):
			saida = arg.trim_prefix("--saida=")
	var d: Node = root.get_node("Dados")
	var pista: Pista = d.pista(pid)
	var amostras := []
	for k in 1201:
		var t := k * 0.1
		amostras.append({"t": t, "s": {"jogador": 150.0 + 33.0 * t, "rival": 170.0 + 32.0 * t}})
	var fonte := CorridaVisual.new()
	var v3 := Corrida3D.new()
	v3.size = Vector2(720, 1280)
	root.add_child(v3)
	fonte.mostrar(pista, {"amostras": amostras, "voltas": 9, "carros": {}})
	v3.mostrar(pista, fonte, {"jogador": d.carro("hozuki_catana"), "rival": d.carro("kanaya_kestrel")})
	var fotos := 0
	var no_ar_antes := false
	var quadro := 0
	while fonte.tempo < 110.0 and fotos < 9:
		fonte.tempo += 1.0 / 30.0
		v3.atualizar(1.0 / 30.0)
		quadro += 1
		var no_ar: bool = v3._voo.has("jogador")
		if no_ar != no_ar_antes or (no_ar and quadro % 12 == 0):
			for k in 2:
				await process_frame
			root.get_texture().get_image().save_png(saida.path_join("relevo_%s_%d.png" % [pid, fotos]))
			fotos += 1
		no_ar_antes = no_ar
	quit()
