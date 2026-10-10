extends SceneTree
## Folha com a foto de todos os carros (revisão visual do desenho dos modelos).
## Uso (precisa de display): godot --script res://tools/folha_carros.gd -- --saida=/caminho.png

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var saida := "user://folha_carros.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			saida = arg.trim_prefix("--saida=")
	var d: Node = root.get_node("Dados")
	var fundo := ColorRect.new()
	fundo.color = Color(0.12, 0.13, 0.16)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fundo)
	var grade := GridContainer.new()
	grade.columns = 3
	grade.position = Vector2(8, 8)
	root.add_child(grade)
	for c in d.lista("carros"):
		var v := VBoxContainer.new()
		v.add_child(Estudio.imagem(c, CarroBloco.cor_do_id(c["id"]), Vector2(232, 130)))
		var l := Label.new()
		l.text = "%s · %s %s %d cv" % [c["nome"], c["categoria"], c["tracao"], c["potencia"]]
		l.add_theme_font_size_override("font_size", 14)
		v.add_child(l)
		grade.add_child(v)
	for k in 10:
		await process_frame
	root.get_texture().get_image().save_png(saida)
	quit()
