extends SceneTree
## Chrome Racing Team: em que dia de calendário um jogador vence cada liga de
## cada modalidade (docs/idle/plano.md, metas de ritmo). O jogador abre o app
## `sessoes_dia` vezes por dia e joga `sessao_min` minutos (a primeira sessão,
## `primeira_min`); entre as sessões entra a renda com o app fechado, até
## offline_max_h (data/idle/idle.json). Ele corre na modalidade aberta mais
## nova que ainda tem liga para vencer, compra a melhoria mais barata dela
## enquanto der, usa o contrato grátis (e `videos` contratos por vídeo ao dia),
## funde pilotos do mesmo nível e escala o melhor na modalidade da corrida.
## Uso: godot --headless --path . -s tools/calibrar_idle.gd [-- sessoes_dia=4 sessao_min=8
##        primeira_min=15 limite_dias=60 videos=0]

var e: IdleEstado
var d: Node


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


## A modalidade aberta mais nova com liga por vencer (ou a última).
func _escolher_modalidade() -> void:
	var alvo := ""
	for id in e.liberadas():
		var m := e._m(id)
		var fim: bool = int(m["liga"]) >= e.dados_modalidade(id)["ligas"].size() - 1 and bool(m["venceu"])
		if not fim:
			alvo = id
	if alvo != "" and alvo != e.modalidade:
		e.trocar_modalidade(alvo)


## Contratos, fusões e o melhor piloto livre na modalidade da corrida.
func _pilotos(agora: float, dia: String, videos: int) -> void:
	e.usar_contrato_gratis(d, agora)
	for i in videos:
		e.usar_contrato_video(d, dia, int(agora) + i)
	var fundiu := true
	while fundiu:
		fundiu = false
		for a in e.pilotos:
			for b in e.pilotos:
				if e.pode_fundir(int(a["uid"]), int(b["uid"])):
					e.fundir(int(a["uid"]), int(b["uid"]))
					fundiu = true
					break
			if fundiu:
				break
	var melhor := {}
	for p in e.pilotos:
		if melhor.is_empty() or int(p["nivel"]) > int(melhor["nivel"]):
			melhor = p
	if not melhor.is_empty():
		e.escalar(e.modalidade, int(melhor["uid"]))


func _rodar() -> void:
	var args := {"sessoes_dia": "4", "sessao_min": "8", "primeira_min": "15", "limite_dias": "60", "videos": "0"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	d = root.get_node("Dados")
	e = IdleEstado.new()
	# O jogador aceita toda a escada de desbloqueios (a renda abre na 4ª
	# corrida, as melhorias logo no começo): mede a economia, não a escada.
	for dd in e.cfg_desbloqueios():
		e.oferecidos.append(String(dd["id"]))
		e.desbloqueados.append(String(dd["id"]))
	var sessoes := int(args["sessoes_dia"])
	var intervalo := 86400.0 / maxf(sessoes, 1)
	var duracao_sessao := float(args["primeira_min"]) * 60.0
	var inicio := 1.8e9
	var relogio := 0.0  # calendário (s)
	var ativo := 0.0  # tempo de app aberto (s)
	var na_sessao := 0.0
	var semente := 1
	var corridas_liga := 0
	var abertas := e.liberadas()
	print("dia     modalidade liga                         corridas  níveis do piloto")
	_pilotos(inicio, "d0", 0)
	while relogio < float(args["limite_dias"]) * 86400.0:
		if na_sessao >= duracao_sessao:
			# Fecha o app até a próxima sessão; a renda entra até o teto.
			var fora := intervalo - na_sessao
			e.dinheiro += e.renda_s() * minf(fora, float(e.cfg["offline_max_h"]) * 3600.0)
			relogio += fora
			na_sessao = 0.0
			duracao_sessao = float(args["sessao_min"]) * 60.0
			_escolher_modalidade()
			_pilotos(inicio + relogio, "d%d" % int(relogio / 86400.0), int(args["videos"]))
			_comprar_tudo()
		var r := e.correr(d, semente, false)
		semente += 1
		var dur: float = float(r["duracao"]) / 2.0 if e.e_arena() else float(r["carros"]["jogador"]["tempo_total"])
		dur += 6.0  # semáforo e chegada
		ativo += dur
		relogio += dur
		na_sessao += dur
		e.dinheiro += e.renda_s() * dur
		e.concluir(IdleEstado.posicao(r))
		corridas_liga += 1
		_comprar_tudo()
		if e.venceu:
			var niveis := e.pilotos.map(func(p): return int(p["nivel"]))
			print("%6.2f  %-10s %-28s %8d  %s" % [relogio / 86400.0, e.modalidade, e.dados_liga()["nome"], corridas_liga,
					str(niveis)])
			corridas_liga = 0
			if not e.subir_liga():
				# Última liga da modalidade: segue na próxima aberta, se houver.
				var antes := e.modalidade
				_escolher_modalidade()
				if e.modalidade == antes:
					break
			_pilotos(inicio + relogio, "d%d" % int(relogio / 86400.0), 0)
			if e.liberadas().size() > abertas.size():
				abertas = e.liberadas()
				print("        abriu %s" % abertas.back())
				_escolher_modalidade()
	print("total %.1f min de app aberto, %.1f dias, %d corridas" % [ativo / 60.0, relogio / 86400.0, e.corridas])
	quit()
