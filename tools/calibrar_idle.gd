extends SceneTree
## The Fastfather: em que dia de calendário um jogador vence cada liga de
## cada modalidade (docs/idle/plano.md, metas de ritmo). O jogador abre o app
## `sessoes_dia` vezes por dia e joga `sessao_min` minutos (a primeira sessão,
## `primeira_min`); entre as sessões entra a renda com o app fechado, até
## offline_max_h (data/idle/idle.json). Ele corre na modalidade aberta mais
## nova que ainda tem liga para vencer, compra a melhoria mais barata dela
## enquanto der, usa o contrato grátis (e `videos` contratos por vídeo ao dia),
## funde rapazes do mesmo nível (o melhor luta na Rinha, que roda ao lado da
## corrida enquanto o app está aberto; quem corre é sempre o sobrinho).
## Divisão nova com carro na garagem: junta o dinheiro (sem comprar melhorias)
## correndo onde está, compra o carro e só então troca.
## Com o app aberto, toca o jornaleiro sempre que ele aparece (no meio do
## intervalo_s, a partir de a_partir_corridas; `jornaleiro=0` desliga). Ao vencer
## o Grande Campeonato muda de cidade, até `cidades` cidades.
## Uso: godot --headless --path . -s tools/calibrar_idle.gd [-- sessoes_dia=4 sessao_min=8
##        primeira_min=15 limite_dias=60 videos=0 jornaleiro=1 cidades=1]

var e: IdleEstado
var d: Node
var esperando_carro := ""  # divisão nova à espera do dinheiro do carro


func _initialize() -> void:
	_rodar.call_deferred()


func _comprar_tudo() -> void:
	if esperando_carro != "":
		var c := e.carro_da_modalidade(esperando_carro)
		if e.comprar_carro(String(c["id"])):
			esperando_carro = ""
			_escolher_modalidade()
		return
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
		if e.e_arena(id):
			continue  # a Rinha roda em paralelo, não é escolhida
		var m := e._m(id)
		var fim: bool = int(m["liga"]) >= e.dados_modalidade(id)["ligas"].size() - 1 and bool(m["venceu"])
		if not fim:
			alvo = id
	if alvo != "" and alvo != e.modalidade:
		var c := e.carro_da_modalidade(alvo)
		if not c.is_empty() and not e.tem_carro(String(c["id"])):
			var caixa := e.dinheiro
			if not e.comprar_carro(String(c["id"])):
				esperando_carro = alvo
				return
			print("        comprou %s por $%d (caixa $%d)" % [c["id"], int(e.preco_carro(c)), int(caixa)])
		esperando_carro = ""
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
	var args := {"sessoes_dia": "4", "sessao_min": "8", "primeira_min": "15", "limite_dias": "60", "videos": "0", "jornaleiro": "1", "cidades": "1"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	d = root.get_node("Dados")
	e = IdleEstado.new()
	# O primeiro carro sai da garagem logo no começo (o dinheiro inicial o paga).
	var primeiro := e.carro_da_modalidade()
	if not primeiro.is_empty():
		e.comprar_carro(String(primeiro["id"]))
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
	var rinha_t := 0.0
	var rinha_ganho := 0.0
	var lutas := 0
	var abertas := e.liberadas()
	var cj := e.cfg_jornaleiro()
	var jorn_cada := (float(cj["intervalo_s"][0]) + float(cj["intervalo_s"][1])) * 0.5
	var jorn_t := 0.0
	var jorn_n := 0
	var jorn_ganho := 0.0
	var cidade_inicio := 0.0
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
		dur += 2.2  # chegada e o bipe da largada seguinte (ciclo sem fim, 2026-10-28)
		ativo += dur
		relogio += dur
		na_sessao += dur
		e.dinheiro += e.renda_s() * dur
		e.concluir(IdleEstado.posicao(r))
		corridas_liga += 1
		if args["jornaleiro"] != "0" and e.corridas >= int(cj["a_partir_corridas"]):
			jorn_t += dur
			if jorn_t >= jorn_cada:
				jorn_t -= jorn_cada
				var g := e.gorjeta_jornaleiro()
				e.dinheiro += g
				jorn_ganho += g
				jorn_n += 1
		# A Rinha luta ao lado: lutas (de ~duracao/2 s, mais a pausa) cabem nesse tempo.
		# Para andar rápido, uma luta simulada por corrida vale por todas as que cabem nela.
		if e.rinha_aberta():
			rinha_t += dur
			var l := e.lutar_rinha(d, semente * 31 + 7, false)
			var cada := float(l["duracao"]) / 2.0 + 5.0
			var n := int(rinha_t / cada)
			if n > 0:
				rinha_t -= n * cada
				var antes := e.dinheiro
				e.pagar_rinha(IdleEstado.posicao(l))
				var p := e.dinheiro - antes
				e.dinheiro += p * (n - 1)
				rinha_ganho += p * n
				lutas += n
		_comprar_tudo()
		if e.venceu and esperando_carro != "" and not e.subir_liga():
			continue  # na última liga, juntando para o carro da divisão nova
		if e.venceu:
			var niveis := e.pilotos.map(func(p): return int(p["nivel"]))
			print("%6.2f  %-10s %-28s %8d  %s" % [relogio / 86400.0, e.modalidade, e.dados_liga()["nome"], corridas_liga,
					str(niveis)])
			corridas_liga = 0
			if not e.subir_liga():
				# Última liga da modalidade: segue na próxima aberta, se houver.
				var antes := e.modalidade
				_escolher_modalidade()
				if e.modalidade == antes and esperando_carro == "":
					if e.cidade + 1 >= int(args["cidades"]) or not e.mudar_de_cidade():
						break
					print("        NOVA CIDADE %d (×%.0f) após %.2f dias nesta cidade" % [e.cidade + 1,
							e.multiplicador_cidade(), (relogio - cidade_inicio) / 86400.0])
					cidade_inicio = relogio
					abertas = e.liberadas()
					esperando_carro = ""
					_escolher_modalidade()
			_pilotos(inicio + relogio, "d%d" % int(relogio / 86400.0), 0)
			if e.liberadas().size() > abertas.size():
				abertas = e.liberadas()
				print("        abriu %s" % abertas.back())
				_escolher_modalidade()
	print("total %.1f min de app aberto, %.1f dias, %d corridas" % [ativo / 60.0, relogio / 86400.0, e.corridas])
	print("rinha: %d lutas, $%d em prêmios" % [lutas, int(rinha_ganho)])
	print("jornaleiro: %d gorjetas, $%d; troféus %d; cidade %d" % [jorn_n, int(jorn_ganho), e.trofeus.size(), e.cidade + 1])
	quit()
