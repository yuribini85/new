extends SceneTree
## Fotos da tela da corrida como o jogador vê (revisão da corrida, decisão
## 131): o jogo inteiro (principal) no cenário completo, uma prova iniciada e
## fotos em sequência, sem tocar na tela; no fim, o menu •••.
## Uso (precisa de tela: xvfb-run): godot --resolution 405x720 --script res://tools/fotos_corrida.gd -- --saida=/pasta/
##   [--segundos=3,8,14,22,32] [--prova=ev_000] [--deixas=4]
## --deixas=N: em vez dos segundos, N fotos com uma deixa pintada na pista ou
## as setas no chão (deixa_0.png...), uma a cada meio segundo enquanto houver.

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var saida := "user://fotos_corrida/"
	var tempos := [3.0, 8.0, 14.0, 22.0, 32.0]
	var prova := ""
	var deixas := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--segundos="):
			tempos = Array(arg.trim_prefix("--segundos=").split(",")).map(func(x): return float(x))
		elif arg.begins_with("--deixas="):
			deixas = int(arg.trim_prefix("--deixas="))
		elif arg.begins_with("--prova="):
			prova = arg.trim_prefix("--prova=")
	DirAccess.make_dir_recursive_absolute(saida)
	var d: Node = root.get_node("Dados")
	var j: Node = root.get_node("Jogador")
	root.get_node("SaveManager").caminho = "user://save_fotos_corrida.json"
	Cenarios.montar(d, j, "completo")
	if deixas > 0:
		j.flags["PILOTAGEM_CARTAO"] = 1  # o COMO PILOTAR seguraria a largada
	var tela: Control = load("res://scenes/principal.tscn").instantiate()
	root.add_child(tela)
	for k in 10:
		await process_frame
	var agora := Aceleracao.agora(j)
	var ids: Array = [prova] if prova != "" else d.lista("eventos").map(func(e): return String(e["id"]))
	for id in ids:
		if j.fila_ctrl.iniciar(id, j.carro_ativo, 1, agora) == "":
			break
	tela._ir_para(4)
	var t := 0.0
	var k := 0
	var corrida: Control = tela._todas[4]
	var ultima := -INF
	while k < deixas and t < 600.0:
		await process_frame
		t += 1.0 / 30.0
		if (not corrida._deixas_pista.is_empty() or corrida._seta_lado != 0) and t - ultima >= 0.5:
			root.get_texture().get_image().save_png(saida.path_join("deixa_%d.png" % k))
			ultima = t
			k += 1
	if deixas > 0:
		tempos = []
	k = 0
	while k < tempos.size():
		await process_frame
		t += 1.0 / 30.0
		if t >= float(tempos[k]):
			root.get_texture().get_image().save_png(saida.path_join("corrida_%d.png" % k))
			k += 1
	corrida._abrir_menu()
	for n in 6:
		await process_frame
	root.get_texture().get_image().save_png(saida.path_join("corrida_menu.png"))
	quit()
