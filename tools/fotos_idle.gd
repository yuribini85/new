extends SceneTree
## Fotos da tela do Chrome Racing Team (docs/idle/plano.md), como o jogador vê.
## Uso (precisa de tela: xvfb-run): godot --resolution 405x720 --script res://tools/fotos_idle.gd -- --saida=/pasta/
##   [--segundos=2,10,30] [--dinheiro=5000] [--liga=0] [--abas=corrida,pistas,pilotos]
##   [--contratos=0] [--abertas=1] [--nova_liga] [--fora_h=0]
## --abas: uma foto de cada tela depois dos segundos; --contratos: pilotos a
## mais no elenco; --abertas: quantas modalidades abertas (as anteriores na
## liga que abre a próxima); --nova_liga: a janela de liga nova na última foto;
## --fora_h: horas com o app fechado (mostra a faixa da renda).

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
	e.dinheiro = dinheiro
	for i in contratos:
		e.contratar(dados, 100 + i)
	e.salvar(agora - fora_h * 3600.0)
	var tela: Control = load("res://idle/idle.tscn").instantiate()
	root.add_child(tela)
	await process_frame
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
	for aba in abas:
		tela._abrir(aba)
		for i in 10:
			await process_frame
		root.get_texture().get_image().save_png(saida.path_join("idle_%s.png" % aba))
	quit()
