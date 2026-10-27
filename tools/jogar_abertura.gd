extends SceneTree
## Jogo novo do começo, sem tocar na tela (as cenas passam sozinhas): título →
## abertura → loja → compra do ferro-velho → fala da largada → corrida. Uma
## foto a cada --passo segundos em --saida (ab_000.png...).
## Uso (precisa de tela: xvfb-run): godot --path . --script res://tools/jogar_abertura.gd -- --saida=/pasta [--segundos=90] [--passo=1.5] [--desde=0]

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var saida := "user://abertura"
	var segundos := 90.0
	var passo := 1.5
	var desde := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--segundos="):
			segundos = float(arg.trim_prefix("--segundos="))
		elif arg.begins_with("--desde="):
			desde = float(arg.trim_prefix("--desde="))
		elif arg.begins_with("--passo="):
			passo = float(arg.trim_prefix("--passo="))
	DirAccess.make_dir_recursive_absolute(saida)
	IdleEstado.new().salvar(Time.get_unix_time_from_system())  # save novo
	var tela: Control = load("res://idle/idle.tscn").instantiate()
	root.add_child(tela)
	var t := 0.0
	var proxima := 0.0
	var n := 0
	while t < segundos:
		await process_frame
		t += 1.0 / 30.0
		if tela._conversa != null and tela._conversa.has_method("_mostrar_pular") and int(t * 30.0) % 30 == 0:
			print("%.1f cena %s" % [t, tela._conversa.get("_id")])
		if t > 1.0 and tela._titulo != null:
			tela._titulo.fechar()
		var loja: GaragemIdle = tela._loja_abertura
		if loja != null and loja._ficha.modulate.a >= 1.0 and not loja.estado.tem_carro("cupe_1928"):
			loja._acao()
		if t >= proxima and t >= desde:
			proxima += passo
			root.get_texture().get_image().save_png(saida.path_join("ab_%03d.png" % n))
			n += 1
	quit()
