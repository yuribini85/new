extends SceneTree
## Fotos do cenário montado pelo kit, com a câmera de cima em pontos fixos de
## cada pista: largada, boxes e paddock, a curva mais fechada, a mata e uma
## vista média. Revisão de composição (onde vai cada coisa, sombras, escala).
## Uso (precisa de display): godot --path . --script res://tools/fotos_cenario.gd -- --saida=/pasta/ [--pista=id]
##   [--estilo=chapado]  (monta no estilo chapado, para comparar)

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var saida := "user://"
	var so := ""
	var estilo := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--pista="):
			so = arg.trim_prefix("--pista=")
		elif arg.begins_with("--estilo="):
			estilo = arg.trim_prefix("--estilo=")
	var d: Node = root.get_node("Dados")
	for pid in Corrida3D.KITS:
		if so != "" and pid != so:
			continue
		var pista: Pista = d.pista(pid)
		if pista == null:
			continue
		var fonte := CorridaVisual.new()
		fonte.mostrar(pista, {"amostras": [{"t": 0.0, "s": {}}], "voltas": 1, "carros": {}})
		var v3 := Corrida3D.new()
		if estilo != "":
			v3.estilo_forcado = estilo
		v3.size = Vector2(720, 1280)
		root.add_child(v3)
		v3.mostrar(pista, fonte, {})
		var cam: Camera3D = v3._camera
		# Curva mais fechada e o ponto da reta de largada.
		var i_curva := 0
		var raio_min := INF
		for i in pista.trechos.size():
			var r := float(pista.trechos[i].get("raio_m", 0.0))
			if r > 0.0 and r < raio_min:
				raio_min = r
				i_curva = i
		var s_curva: float = pista.inicios[i_curva] + float(pista.trechos[i_curva]["comprimento_m"]) * 0.5
		var i0 := pista.indice_em(0.5)
		var s_reta: float = pista.inicios[i0] + float(pista.trechos[i0]["comprimento_m"]) * 0.5
		var fotos := {
			"perto": [pista.posicao_em(s_curva), 45.0],
			"largada": [pista.posicao_em(0.0), 110.0],
			"boxes": [pista.posicao_em(s_reta), 260.0],
			"curva": [pista.posicao_em(s_curva), 200.0],
			"mata": [pista.posicao_em(s_curva) + Vector2.from_angle(pista.rumo_em(s_curva) - PI / 2.0) * 130.0, 200.0],
			"media": [pista.posicao_em(s_reta), 700.0],
		}
		for nome in fotos:
			var p: Vector2 = fotos[nome][0]
			v3._alvo_camera = Vector3(p.x, 0.0, -p.y)
			cam.size = fotos[nome][1]
			v3._camera_imediata()
			for k in 4:
				await process_frame
			root.get_texture().get_image().save_png(saida.path_join("cenario_%s_%s.png" % [pid, nome]))
		v3.queue_free()
		fonte.free()
	quit()
