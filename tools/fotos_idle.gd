extends SceneTree
## Fotos da tela do Chrome Racing Team (docs/idle/plano.md), como o jogador vê.
## Uso (precisa de tela: xvfb-run): godot --resolution 405x720 --script res://tools/fotos_idle.gd -- --saida=/pasta/
##   [--segundos=2,10,30] [--dinheiro=5000] [--liga=0]

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var saida := "user://fotos_idle/"
	var tempos := [2.0, 10.0, 30.0]
	var dinheiro := 0.0
	var liga := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--segundos="):
			tempos = Array(arg.trim_prefix("--segundos=").split(",")).map(func(x): return float(x))
		elif arg.begins_with("--dinheiro="):
			dinheiro = float(arg.trim_prefix("--dinheiro="))
		elif arg.begins_with("--liga="):
			liga = int(arg.trim_prefix("--liga="))
	DirAccess.make_dir_recursive_absolute(saida)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IdleEstado.ARQUIVO_SAVE))
	var tela: Control = load("res://idle/idle.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.estado.dinheiro = dinheiro
	tela.estado.liga = liga
	if liga > 0:
		tela._nova_corrida()
	var t := 0.0
	var k := 0
	while k < tempos.size():
		await process_frame
		t += 1.0 / 30.0
		if t >= float(tempos[k]):
			root.get_texture().get_image().save_png(saida.path_join("idle_%d.png" % k))
			k += 1
	quit()
