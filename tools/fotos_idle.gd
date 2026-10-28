extends SceneTree
## Fotos da tela do The Fastfather (docs/idle/plano.md), como o jogador vê.
## Uso (precisa de tela: xvfb-run): godot --resolution 405x720 --script res://tools/fotos_idle.gd -- --saida=/pasta/
##   [--segundos=2,10,30] [--dinheiro=5000] [--liga=0] [--abas=corrida,pistas,pilotos]
##   [--contratos=0] [--abertas=1] [--nova_liga] [--fora_h=0] [--modalidade=arena] [--novo]
##   [--corridas=0] [--abrir=pneus,patrocinio] [--ofertas=transmissao] [--guia=melhoria:pneus]
## --abas: uma foto de cada tela depois dos segundos ("config": a engrenagem; "trofeus": a coleção); --contratos: pilotos a
## mais no elenco; --abertas: quantas modalidades abertas (as anteriores na
## liga que abre a próxima); --nova_liga: a janela de liga nova na última foto;
## --fora_h: horas com o app fechado (mostra a faixa da renda).
## Sem --novo, a escada de desbloqueios vem toda aberta; com --novo, o começo do
## jogo (vista de cima, só o Motor, LARGAR), mais os passos de --abrir; --corridas
## põe corridas no total (a próxima conversa aparece se a condição dela cumprir).

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var saida := "user://fotos_idle/"
	var tempos := [2.0, 10.0, 30.0]
	var dinheiro := 0.0
	var liga := 0
	var abas := []
	var contratos := 0
	var abertas := 1
	var nova_liga := false
	var fora_h := 0.0
	var modalidade := ""
	var novo := false
	var corridas := 0
	var abrir := []
	var ofertas := []
	var guia := ""
	var cidade_foto := 0
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=")
		match kv[0]:
			"saida": saida = kv[1]
			"segundos": tempos = Array(kv[1].split(",")).map(func(x): return float(x))
			"dinheiro": dinheiro = float(kv[1])
			"liga": liga = int(kv[1])
			"abas": abas = Array(kv[1].split(","))
			"contratos": contratos = int(kv[1])
			"abertas": abertas = int(kv[1])
			"nova_liga": nova_liga = true
			"fora_h": fora_h = float(kv[1])
			"modalidade": modalidade = kv[1]
			"novo": novo = true
			"corridas": corridas = int(kv[1])
			"abrir": abrir = Array(kv[1].split(","))
			"fase": CenarioEpoca.fase_forcada = kv[1]  # dia, tarde ou noite
			"chuva": CenarioEpoca.chuva_forcada = int(kv[1])
			"cidade": cidade_foto = int(kv[1])
			"ofertas": ofertas = Array(kv[1].split(","))
			"guia": guia = kv[1]
	DirAccess.make_dir_recursive_absolute(saida)
	var dados: Node = root.get_node("Dados")
	# Save de partida: modalidades abertas, pilotos e o tempo fora.
	var e := IdleEstado.new()
	var agora := Time.get_unix_time_from_system()
	e.usar_contrato_gratis(dados, agora)
	for i in abertas:
		var m: Dictionary = e.cfg["modalidades"][i]
		e.trocar_modalidade(String(m["id"]))
		if i + 1 < abertas:
			e.liga = int(e.cfg["modalidades"][i + 1]["libera"]["liga"])
	e.trocar_modalidade(String(e.cfg["modalidades"][0]["id"]))
	e.liga = maxi(liga, e.liga)
	if modalidade != "":
		e.trocar_modalidade(modalidade)
	e.dinheiro = dinheiro
	for c in e.carros_garagem():  # os carros da garagem, já comprados
		e.garagem.append(String(c["id"]))
	for i in contratos:
		e.contratar(dados, 100 + i)
	e.corridas = corridas
	e.cidade = cidade_foto
	for d in e.cfg_desbloqueios():
		var id := String(d["id"])
		if not novo or id in abrir:
			e.oferecidos.append(id)
			e.desbloqueados.append(id)
		elif id in ofertas:
			e.oferecidos.append(id)
	e.salvar(agora - fora_h * 3600.0)
	var tela: Control = load("res://idle/idle.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.pular_titulo()
	var k := 0
	var t := 0.0
	while k < tempos.size():
		await process_frame
		t += 1.0 / 30.0
		if nova_liga and k == tempos.size() - 1 and t >= float(tempos[k]) - 1.0 and tela.estado.liga == liga:
			tela.estado.venceu = true
			tela._subir_liga()
		if t >= float(tempos[k]):
			root.get_texture().get_image().save_png(saida.path_join("idle_%d.png" % k))
			k += 1
	if guia != "":
		# --guia=alvo: a dica do tutorial leve nesse alvo, na foto idle_guia.png.
		tela._guiar(guia, "Toque aqui para testar a dica do tutorial.")
		for i in 20:
			await process_frame
		root.get_texture().get_image().save_png(saida.path_join("idle_guia.png"))
	for aba in abas:
		if aba == "config":
			tela._abrir_config()
		elif aba in ["combustivel", "fiscal"]:  # a janela que explica o bônus antes do anúncio
			tela._janela_bonus(aba)
		elif aba == "jornaleiro":  # o menino de pé e, na foto seguinte, o x2
			tela._jornaleiro.aparecer(30.0)
			for i in 40:
				await process_frame
			root.get_texture().get_image().save_png(saida.path_join("idle_jornaleiro_antes.png"))
			tela._pagar_jornaleiro()
		elif aba == "cidade":  # o Grande Campeonato vencido: o cartão NOVA CIDADE em Pistas
			var ligas: Array = tela.estado.dados_modalidade()["ligas"]
			for gc in ligas.size():
				if String(ligas[gc]["nome"]).ends_with("Grande Campeonato"):
					tela.estado.liga = gc
					tela.estado.venceu = true
			tela.estado.guias.append("subir")  # sem a dica de subir de liga por cima
			tela._abrir("pistas")
			for i in 20:
				await process_frame
			tela._abrir("pistas")
		elif aba == "estante":  # a garagem com cinco troféus na estante
			for tr in tela.estado.lista_trofeus().slice(0, 5):
				if not String(tr["pista"]) in tela.estado.trofeus:
					tela.estado.trofeus.append(String(tr["pista"]))
			tela._abrir("garagem")
		elif aba == "missoes_fds":  # MISSÕES num sábado, com o presente de hoje e o desafio quase feito
			var bias := float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
			tela.estado.agora_fixo = float(Time.get_unix_time_from_datetime_string("2026-10-31T15:00:00")) - bias
			tela.estado.presente = {"dia": MetaDia.dia(tela.estado.agora_fixo - 86400.0), "seq": 3}
			tela.estado.estado_desafio()["vitorias"] = 11
			tela.estado.tacas = ["Calabrese"]
			tela._abrir("metas")
		elif aba == "vazio":  # o dedo na corrida com a carga do acelerador no fim
			tela._segurando = true
			tela._toque_carga = 0.0
			for i in 30:
				await process_frame
			tela._abrir("corrida")
		elif aba == "geral":  # a pista inteira de cima (cenário da cidade)
			tela._abrir("corrida")
			tela._trocar_camera("geral")
			for i in 60:
				await process_frame
		elif aba == "dupla":  # a câmera dupla: 3D em cima, a pista em 2D embaixo, sem a oficina
			tela._abrir("corrida")
			tela._trocar_camera("dupla")
			for i in 60:
				await process_frame
		elif aba == "meia":  # o acelerador pela metade, sem o dedo
			tela._segurando = false
			tela._toque_carga = 0.5
			tela._abrir("corrida")
		elif aba == "fundadora":
			tela._abrir_fundadora()
		elif aba == "trofeus":  # a coleção, com os três primeiros ganhos
			for tr in tela.estado.lista_trofeus().slice(0, 3):
				if not String(tr["pista"]) in tela.estado.trofeus:
					tela.estado.trofeus.append(String(tr["pista"]))
			tela._trofeus_abertos(true)
		else:
			tela._abrir(aba)
		if aba == "rinha":  # a próxima luta começa com a tela aberta: a apresentação do VS
			var rinha = tela._paginas["rinha"]
			rinha._res = {}
			rinha._pausa = 0.0
			for i in 12:
				await process_frame
			root.get_texture().get_image().save_png(saida.path_join("idle_rinha_vs.png"))
		for i in 10:
			await process_frame
		root.get_texture().get_image().save_png(saida.path_join("idle_%s.png" % aba))
	quit()
