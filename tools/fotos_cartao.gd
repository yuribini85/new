extends SceneTree
## Fotos de referência para o pedido das ilustrações dos cartões
## (tools/pacote_arte_cartoes.py): a foto do modelo 3D de cada carro, com a
## carroceria branca, em build/ref_cartoes/<id>.png. Mostram silhueta e
## proporção para o artista; não entram no jogo. Precisa de tela (xvfb).
## Uso: godot --path . --script res://tools/fotos_cartao.gd -- id1,id2,...

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var d := root.get_node("Dados")
	var ids: Array = Array(OS.get_cmdline_user_args()[0].split(",")) if not OS.get_cmdline_user_args().is_empty() else []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/ref_cartoes"))
	for id in ids:
		var base: Dictionary = d.carro(id)
		if base.is_empty():
			push_error("carro desconhecido: %s" % id)
			continue
		var tex := Estudio.foto(base, Color.WHITE)
		for k in 8:
			await process_frame
		var img := tex.get_image()
		if img == null or img.is_empty():
			push_error("sem foto: %s" % id)
			continue
		img.save_png(ProjectSettings.globalize_path("res://build/ref_cartoes/%s.png" % id))
		print("foto ", id)
	quit()
