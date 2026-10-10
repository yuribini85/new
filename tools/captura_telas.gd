extends SceneTree
## Captura as telas com dados de teste para revisão visual.
## Uso (precisa de display; em servidor, sob xvfb-run):
##   godot --script res://tools/captura_telas.gd -- --dados=res://tests/fixtures/ --saida=/caminho/
##   godot --script res://tools/captura_telas.gd -- --so-pistas --saida=/caminho/
## Gera <saida>/<n>_<aba>.png e uma do editor para cada pista. Começa um jogo novo (o save de teste é ignorado).

var _saida := "user://capturas/"
## --so-pistas: só o editor de pistas (funciona com data/ ainda incompleto).
var _so_pistas := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg == "--so-pistas":
			_so_pistas = true
	DirAccess.make_dir_recursive_absolute(_saida)
	_rodar.call_deferred()


func _rodar() -> void:
	var dados := root.get_node("Dados")
	if _so_pistas:
		await _capturar_pistas(dados, 1)
		quit()
		return
	var jogador := root.get_node("Jogador")
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.carreira = Carreira.new(dados, jogador)
	jogador.fila_ctrl = Fila.new(jogador.carreira, jogador, float(dados.carreira()["teto_offline_s"]))
	# Começo de carreira: o usado mais caro que o saldo inicial paga, e o
	# primeiro evento em que ele pode correr. Funciona com qualquer data/.
	var ofertas := Usados.estoque(dados.lista("carros"), 0, jogador.usados_vendidos)
	ofertas = ofertas.filter(func(o): return jogador.economia.pode_pagar(o["preco"]))
	var uid := -1
	if not ofertas.is_empty():
		var o: Dictionary = ofertas.back()
		uid = jogador.concessionaria.comprar_usado(o, dados.carro(o["carro_id"]), jogador.usados_vendidos)
	else:
		for c in dados.lista("carros"):
			uid = jogador.concessionaria.comprar_carro(c)
			if uid > 0:
				break
	jogador.carro_ativo = uid
	for ev in dados.lista("eventos"):
		# Corrida iniciada há 25 s para a captura mostrar carros em movimento.
		jogador.vitorias[ev["id"]] = 1  # repetir exige a prova já vencida
		if jogador.fila_ctrl.iniciar(ev["id"], uid, 3, Time.get_unix_time_from_system() - 25.0) == "":
			break
	# Termina a primeira corrida para o painel "Última corrida" aparecer; a
	# segunda fica em andamento, iniciada há 25 s.
	var agora := Time.get_unix_time_from_system()
	jogador.fila_ctrl.adiantar(agora - 25.0)
	var rel: Dictionary = jogador.fila_ctrl.processar(agora - 25.0)

	var tela: Control = load("res://scenes/principal.tscn").instantiate()
	root.add_child(tela)
	var abas: TabContainer = tela._abas
	var total := abas.get_tab_count()
	for i in total:
		tela._ir_para(i)
		for k in 6:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png(_saida.path_join("%d_%s.png" % [i + 1, abas.get_tab_title(i).to_lower()]))
	# Competições rolada até os cartões; resultado de uma corrida.
	tela._ir_para(3)
	for k in 3:
		await process_frame
	tela._abas.get_child(3).scroll_vertical = 640
	for k in 4:
		await process_frame
	root.get_texture().get_image().save_png(_saida.path_join("4_competições_cartoes.png"))
	if not rel.get("corridas", []).is_empty():
		tela._resultado(rel["corridas"][0], false)
		for k in 8:
			await process_frame
		root.get_texture().get_image().save_png(_saida.path_join("%d_resultado.png" % (total + 1)))
		tela._sobre.fechar()
	# Bancada do primeiro contrato, montada e avaliada.
	var contratos: Array = dados.lista("contratos")
	if not contratos.is_empty():
		var carreira = tela._todas[5]
		tela._ir_para(5)
		carreira._abrir_bancada(contratos[0])
		carreira._montagem = jogador.montagens.get(contratos[0]["id"], {"pecas": [], "ajuste_cambio": ""})
		carreira._enviar(contratos[0])
		carreira.atualizar()
		for k in 6:
			await process_frame
		root.get_texture().get_image().save_png(_saida.path_join("%d_bancada.png" % (total + 1)))
		carreira.scroll_vertical = 100000
		for k in 6:
			await process_frame
		root.get_texture().get_image().save_png(_saida.path_join("%d_bancada_relatorio.png" % (total + 1)))
	tela.queue_free()
	await _capturar_pistas(dados, total + 1)
	quit()


func _capturar_pistas(dados: Node, primeiro: int) -> void:
	var editor: Control = load("res://tools/editor_pista.tscn").instantiate()
	root.add_child(editor)
	for i in dados.lista("pistas").size():
		editor._selecionar(i)
		for k in 6:
			await process_frame
		root.get_texture().get_image().save_png(_saida.path_join("%d_pista_%s.png" % [primeiro + i, dados.lista("pistas")[i]["id"]]))
	editor.queue_free()
