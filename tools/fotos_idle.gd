extends SceneTree
## Fotos da tela do Chrome Racing Team (docs/idle/plano.md), como o jogador vê.
## Uso (precisa de tela: xvfb-run): godot --resolution 405x720 --script res://tools/fotos_idle.gd -- --saida=/pasta/
##   [--segundos=2,10,30] [--dinheiro=5000] [--liga=0] [--abas=corrida,pistas,pilotos]
##   [--contratos=0] [--abertas=1] [--nova_liga] [--fora_h=0] [--modalidade=arena] [--novo]
##   [--corridas=0] [--abrir=pneus,patrocinio] [--ofertas=transmissao] [--guia=melhoria:pneus]
## --abas: uma foto de cada tela depois dos segundos ("config": a engrenagem); --contratos: pilotos a
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
	for i in contratos:
		e.contratar(dados, 100 + i)
	e.corridas = corridas
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
		else:
			tela._abrir(aba)
		for i in 10:
			await process_frame
		root.get_texture().get_image().save_png(saida.path_join("idle_%s.png" % aba))
	quit()
