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
	# Fichas do Grid já vistas: a intro da equipe da vez não cobre as capturas
	# (ela tem captura própria no fim).
	for e in TheGrid.equipes(dados):
		TheGrid.marcar_vista(jogador, String(e["id"]))
	TheGrid.marcar_vista(jogador, "fim")
	# Uma corrida terminada (para o resultado e o painel "Última corrida") e
	# outra em andamento, iniciada há 25 s (carros em movimento).
	var agora := Time.get_unix_time_from_system()
	var rel := {}
	var evento := ""
	for ev in dados.lista("eventos"):
		if jogador.fila_ctrl.iniciar(ev["id"], uid, 1, agora - 25.0) == "":
			evento = ev["id"]
			break
	if evento != "":
		jogador.fila_ctrl.adiantar(agora)
		rel = jogador.fila_ctrl.processar(agora)
		jogador.vitorias[evento] = maxi(int(jogador.vitorias.get(evento, 0)), 1)  # repetir exige a prova já vencida
		jogador.fila_ctrl.iniciar(evento, uid, 1, agora - 25.0)

	var tela: Control = load("res://scenes/principal.tscn").instantiate()
	root.add_child(tela)
	var abas: TabContainer = tela._abas
	var total := abas.get_tab_count()
	for i in total:
		if abas.get_tab_title(i) == "Oficina antiga":
			continue  # índice reservado (a Oficina antiga saiu)
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
	# Intro da equipe da vez no Grid (pulada até o confronto) e a ficha dela.
	var vez := TheGrid.da_vez(dados, jogador)
	if not vez.is_empty():
		var intro := GridRivalIntro.new(dados, jogador, String(vez["id"]), "primeiro", 3, 7)
		tela.add_child(intro)
		for k in 30:
			await process_frame
		root.get_texture().get_image().save_png(_saida.path_join("%d_grid_intro.png" % (total + 1)))
		intro.pular()
		for k in 90:
			await process_frame
		root.get_texture().get_image().save_png(_saida.path_join("%d_grid_confronto.png" % (total + 1)))
		intro.queue_free()
		var ficha := VinhetaGrid.new(dados, jogador, String(vez["id"]), "rever", 3, 7)
		tela.add_child(ficha)
		for k in 60:
			await process_frame
		root.get_texture().get_image().save_png(_saida.path_join("%d_grid_ficha.png" % (total + 1)))
		ficha.queue_free()
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
