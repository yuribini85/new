extends SceneTree
## Chrome Racing Team: quanto tempo um jogador leva para vencer cada liga
## (docs/idle/plano.md, metas de ritmo). O jogador assiste às corridas em
## sequência e, depois de cada uma, compra a melhoria mais barata enquanto der.
## Com sessoes_dia > 0 mede em dias de calendário: o jogador abre o app
## sessoes_dia vezes por dia, joga sessao_min minutos e, entre as sessões, a
## renda com o app fechado entra até offline_max_h (data/idle/idle.json). A
## primeira sessão dura primeira_min.
## Uso: godot --headless --path . -s tools/calibrar_idle.gd [-- ligas=11 limite_h=3
##        sessoes_dia=4 sessao_min=8 primeira_min=15 limite_dias=60]

var e: IdleEstado


func _initialize() -> void:
	_rodar.call_deferred()


func _comprar_tudo() -> void:
	while true:
		var mais_barata := ""
		for m in e.cfg["melhorias"]:
			if not e.no_maximo(m["id"]) and (mais_barata == "" or e.custo(m["id"]) < e.custo(mais_barata)):
				mais_barata = m["id"]
		if mais_barata == "" or not e.comprar(mais_barata):
			break


func _rodar() -> void:
	var args := {"ligas": "11", "limite_h": "3", "sessoes_dia": "0", "sessao_min": "8", "primeira_min": "15",
			"limite_dias": "60"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var d: Node = root.get_node("Dados")
	e = IdleEstado.new()
	var sessoes := int(args["sessoes_dia"])
	var intervalo := 86400.0 / maxf(sessoes, 1)
	var duracao_sessao := float(args["primeira_min"]) * 60.0
	var relogio := 0.0  # calendário (s)
	var ativo := 0.0  # tempo de app aberto (s)
	var na_sessao := 0.0
	var inicio_liga := 0.0
	var corridas_liga := 0
	var semente := 1
	print("liga                      %s  corridas  posições (últimas)        níveis" % ("     dia" if sessoes > 0 else "tempo p/ vencer"))
	var posicoes := []
	var limite := float(args["limite_dias"]) * 86400.0 if sessoes > 0 else float(args["limite_h"]) * 3600.0
	while e.liga < int(args["ligas"]) and (relogio if sessoes > 0 else ativo) < limite:
		if sessoes > 0 and na_sessao >= duracao_sessao:
			# Fecha o app até a próxima sessão; a renda entra até o teto.
			var fora := intervalo - na_sessao
			e.dinheiro += e.renda_s() * minf(fora, float(e.cfg["offline_max_h"]) * 3600.0)
			relogio += fora
			na_sessao = 0.0
			duracao_sessao = float(args["sessao_min"]) * 60.0
			_comprar_tudo()
		var r := e.correr(d, semente, false)
		semente += 1
		var dur := float(r["carros"]["jogador"]["tempo_total"])
		ativo += dur
		relogio += dur
		na_sessao += dur
		e.dinheiro += e.renda_s() * dur
		var pos := IdleEstado.posicao(r)
		posicoes.append(pos)
		e.concluir(pos)
		corridas_liga += 1
		_comprar_tudo()
		if e.venceu:
			var quando := "%7.2f" % (relogio / 86400.0) if sessoes > 0 else "%6.1f min" % ((ativo - inicio_liga) / 60.0)
			print("%-25s %s  %8d  %-24s  %s" % [e.dados_liga()["nome"], quando, corridas_liga,
					str(posicoes.slice(maxi(posicoes.size() - 8, 0))), str(e.niveis)])
			if not e.subir_liga():
				break
			inicio_liga = ativo
			corridas_liga = 0
			posicoes = []
	print("total %.1f min de app aberto, %.1f dias, %d corridas (%.0f s por corrida)" % [ativo / 60.0,
			relogio / 86400.0, e.corridas, ativo / maxf(e.corridas, 1)])
	quit()
