extends SceneTree
## Chrome Racing Team: quanto tempo um jogador leva para vencer cada liga
## (docs/idle/plano.md, metas de ritmo). O jogador assiste às corridas em
## sequência e, depois de cada uma, compra a melhoria mais barata enquanto der.
## Uso: godot --headless --path . -s tools/calibrar_idle.gd [-- ligas=4 limite_h=3]

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var args := {"ligas": "4", "limite_h": "3"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var d: Node = root.get_node("Dados")
	var e := IdleEstado.new()
	var t := 0.0
	var inicio_liga := 0.0
	var corridas_liga := 0
	var semente := 1
	print("liga                      tempo p/ vencer  corridas  posições (últimas)        níveis")
	var posicoes := []
	while e.liga < int(args["ligas"]) and t < float(args["limite_h"]) * 3600.0:
		var r := e.correr(d, semente, false)
		semente += 1
		var dur := float(r["carros"]["jogador"]["tempo_total"])
		t += dur
		e.dinheiro += e.renda_s() * dur
		var pos := IdleEstado.posicao(r)
		posicoes.append(pos)
		e.concluir(pos)
		corridas_liga += 1
		while true:
			var mais_barata := ""
			for m in e.cfg["melhorias"]:
				if not e.no_maximo(m["id"]) and (mais_barata == "" or e.custo(m["id"]) < e.custo(mais_barata)):
					mais_barata = m["id"]
			if mais_barata == "" or not e.comprar(mais_barata):
				break
		if e.venceu:
			print("%-25s %6.1f min  %8d  %-24s  %s" % [e.dados_liga()["nome"], (t - inicio_liga) / 60.0, corridas_liga,
					str(posicoes.slice(maxi(posicoes.size() - 8, 0))), str(e.niveis)])
			if not e.subir_liga():
				break
			inicio_liga = t
			corridas_liga = 0
			posicoes = []
	print("total %.1f min, %d corridas (%.0f s por corrida)" % [t / 60.0, e.corridas, t / maxf(e.corridas, 1)])
	quit()
