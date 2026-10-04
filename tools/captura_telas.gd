extends SceneTree
## Captura as telas com dados de teste para revisão visual.
## Uso (precisa de display; em servidor, sob xvfb-run):
##   godot --script res://tools/captura_telas.gd -- --dados=res://tests/fixtures/ --saida=/caminho/
## Gera <saida>/<n>_<aba>.png e a do editor de pista. Começa um jogo novo (o save de teste é ignorado).

var _saida := "user://capturas/"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	DirAccess.make_dir_recursive_absolute(_saida)
	_rodar.call_deferred()


func _rodar() -> void:
	var dados := root.get_node("Dados")
	var jogador := root.get_node("Jogador")
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.economia.creditar(5000)
	jogador.carreira = Carreira.new(dados, jogador)
	jogador.fila_ctrl = Fila.new(jogador.carreira, jogador, float(dados.carreira()["teto_offline_s"]))
	var uid: int = jogador.concessionaria.comprar_carro(dados.carro("forte"))
	jogador.concessionaria.comprar_carro(dados.carro("fraco"))
	jogador.carro_ativo = uid
	jogador.concessionaria.comprar_peca(jogador.garagem.carro(uid), dados.peca("turbo"))
	# Corrida iniciada há 25 s para a captura mostrar carros em movimento.
	jogador.fila_ctrl.iniciar("aberto", uid, 3, Time.get_unix_time_from_system() - 25.0)

	var tela: Control = load("res://scenes/principal.tscn").instantiate()
	root.add_child(tela)
	var abas: TabContainer = tela._abas
	var total := abas.get_tab_count()
	for i in total:
		abas.current_tab = i
		for k in 6:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png(_saida.path_join("%d_%s.png" % [i + 1, abas.get_tab_title(i).to_lower()]))
	tela.queue_free()
	var editor: Control = load("res://tools/editor_pista.tscn").instantiate()
	root.add_child(editor)
	for k in 6:
		await process_frame
	root.get_texture().get_image().save_png(_saida.path_join("%d_editor_pista.png" % (total + 1)))
	quit()
