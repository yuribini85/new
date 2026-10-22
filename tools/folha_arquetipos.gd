extends SceneTree
## Folha de comparação dos arquétipos de carro (decisão 130, E3): para cada
## arquétipo, alguns carros antes (forma medida) e depois (o traço do tipo).
## Uso (precisa de tela: xvfb-run): godot --script res://tools/folha_arquetipos.gd -- --saida=/caminho.png [--por=3]

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var saida := "user://folha_arquetipos.png"
	var por := 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--por="):
			por = int(arg.trim_prefix("--por="))
	var d: Node = root.get_node("Dados")
	var grupos := {}
	for c in d.lista("carros"):
		var a := Carroceria.arquetipo(c, Carroceria.escola(String(c.get("fabricante", ""))))
		if a == "" or not Carroceria.tem(c["id"]):
			continue
		if not grupos.has(a):
			grupos[a] = []
		if grupos[a].size() < por:
			grupos[a].append(c)
	var fundo := ColorRect.new()
	fundo.color = Color(0.12, 0.13, 0.16)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fundo)
	var grade := GridContainer.new()
	grade.columns = 2 if por == 1 else 4
	grade.position = Vector2(8, 8)
	root.add_child(grade)
	# antes e depois lado a lado (dois carros por linha)
	var celulas := {}
	for ligado in [false, true]:
		Carroceria.arquetipos_ligados = ligado
		Carroceria.limpar_cache()
		for a in grupos:
			for c in grupos[a]:
				var v := VBoxContainer.new()
				var cor := Color(0.6, 0.62, 0.66) if not ligado else Color(0.85, 0.2, 0.15)
				v.add_child(Estudio.imagem(c, cor, Vector2(400, 222) if por == 1 else Vector2(200, 112)))
				var l := Label.new()
				l.text = "%s · %s · %d" % [a if ligado else "antes", c["id"], c["ano"]]
				l.add_theme_font_size_override("font_size", 11)
				v.add_child(l)
				celulas["%s|%s" % [c["id"], ligado]] = v
	for a in grupos:
		for c in grupos[a]:
			grade.add_child(celulas["%s|false" % c["id"]])
			grade.add_child(celulas["%s|true" % c["id"]])
	for k in 12:
		await process_frame
	root.get_texture().get_image().save_png(saida)
	quit()
