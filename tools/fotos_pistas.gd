extends SceneTree
## Fotos das pistas em 3D (visão do carro, pista toda e o modo velocidade:
## entrada e estabilizado), com uma corrida
## de verdade de cada uma. Revisão visual dos ambientes.
## Uso (precisa de display): godot --script res://tools/fotos_pistas.gd -- --saida=/pasta/
##   [--pista=id] [--estilo=chapado]

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
	var j: Node = root.get_node("Jogador")
	j.novo_jogo(d.economia(), d.pneu)
	j.licencas = ["CLUB", "SPORT"]
	j.economia.creditar(1000000)
	var feitas := {}
	for ev in d.lista("eventos"):
		if feitas.has(ev["pista"]) or (so != "" and ev["pista"] != so):
			continue
		var uid := -1
		for c in d.lista("carros"):
			var u: int = j.concessionaria.comprar_carro(c)
			if u > 0 and Elegibilidade.motivos(j.garagem.carro(u), ev["restricoes"], j.licencas).is_empty():
				uid = u
				break
		if uid < 0:
			continue
		var r: Dictionary = Carreira.new(d, j).preparar(ev["id"], uid, 1)
		var pista: Pista = d.pista(ev["pista"])
		var fonte := CorridaVisual.new()
		var v3 := Corrida3D.new()
		v3.estilo_forcado = estilo
		v3.size = Vector2(720, 900)
		root.add_child(v3)
		fonte.mostrar(pista, r["resultado"])
		var modelos := {"jogador": j.garagem.carro(uid).base}
		for i in ev["adversarios"].size():
			modelos["adv%d_%s" % [i, ev["adversarios"][i]["carro"]]] = d.carro(ev["adversarios"][i]["carro"])
		fonte.tempo = 25.0
		v3.mostrar(pista, fonte, modelos)
		for modo in [false, true]:
			v3.visao_geral = modo
			v3.atualizar(0.0)
			for k in 6:
				await process_frame
			root.get_texture().get_image().save_png(saida.path_join("pista_%s_%s.png" % [ev["pista"], "geral" if modo else "carro"]))
		v3.visao_geral = false
		# Avança a corrida quadro a quadro até o modo velocidade; fotografa no meio
		# da entrada e com ele estabilizado.
		var meio := false
		for k in 3000:
			fonte.tempo += 1.0 / 30.0
			v3.atualizar(1.0 / 30.0)
			if v3.modo == "velocidade" and not meio and v3._b > 0.45:
				meio = true
				await process_frame
				await process_frame
				root.get_texture().get_image().save_png(saida.path_join("pista_%s_entrada.png" % ev["pista"]))
			if v3.modo == "velocidade" and v3._t_modo > 0.8:
				await process_frame
				await process_frame
				root.get_texture().get_image().save_png(saida.path_join("pista_%s_velocidade.png" % ev["pista"]))
				break
		v3.queue_free()
		fonte.free()
		feitas[ev["pista"]] = true
	quit()
