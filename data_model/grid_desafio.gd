class_name GridDesafio
extends RefCounted
## Desafios do The Grid (decisão 74, data/grid_desafios.json): a equipe da vez
## só fica para trás no desafio dela, contra os carros especiais da equipe.
## Corrida: 1x1, o piloto de corrida do jogador contra o da equipe, numa prova
## montada aqui (id "grid_<equipe>", lida por Dados.evento). Arena: 2x2, a
## dupla de arena contra dois pilotos da equipe; com rounds 3, melhor de 3, e
## os carros destruídos são trocados por outros da garagem entre os rounds.
## Carros especiais: os adversários reais da licença da equipe (eventos.json) com a maior relação potência/peso, com o ajuste de potência deles.
## A licença da equipe é exigida. Nada é inventado aqui: os números vêm dos
## dados.

const PREFIXO := "grid_"


static func cfg(dados: Node) -> Dictionary:
	return dados.grid_desafios()


## O desafio da equipe ({} se ela não está no Grid ou não há dados):
## {modo, pista|arena (ids reais), voltas, rounds, carros_min, n_pista|n_arena}.
static func de(dados: Node, equipe: Dictionary) -> Dictionary:
	if equipe.get("grid") == null:
		return {}
	var c: Dictionary = cfg(dados)
	var d: Dictionary = c.get("posicoes", {}).get(str(int(equipe["grid"])), {}).duplicate()
	if d.is_empty():
		return {}
	if d["modo"] == "corrida":
		d["n_pista"] = String(d["pista"])
		d["pista"] = String(c.get("pistas", {}).get(d["n_pista"], ""))
	else:
		d["n_arena"] = String(d["arena"])
		d["arena"] = String(c.get("arenas", {}).get(d["n_arena"], ""))
		d["rounds"] = int(d.get("rounds", 1))
		d["carros_min"] = int(d.get("carros_min", 2))
	return d


## Carros especiais da equipe: adversários reais (eventos.json) da
## licença dela, pela maior relação potência (com o ajuste) / peso, sem
## repetir no Grid: da #1 para a #10, cada equipe fica com os melhores ainda
## livres da sua licença (corrida 1, arena 2). `n` limita quantos devolver.
static func especiais(dados: Node, equipe: Dictionary, n: int) -> Array:
	var todos := _distribuir(dados)
	return Array(todos.get(String(equipe.get("id", "")), [])).slice(0, n)


static func _candidatos(dados: Node, lic: String) -> Array:
	var vistos := {}
	var lista := []
	for ev in dados.lista("eventos"):
		if String(ev["restricoes"].get("licenca", "")) != lic:
			continue
		for a in ev["adversarios"]:
			if vistos.has(a["carro"]) or not dados.existe("carros", a["carro"]):
				continue
			vistos[a["carro"]] = true
			var c: Dictionary = dados.carro(a["carro"])
			var r := float(c["potencia"]) * float(a.get("potencia_mult", 1.0)) / maxf(float(c["peso"]), 1.0)
			lista.append({"adv": a, "razao": r})
	lista.sort_custom(func(x, y): return x["razao"] > y["razao"] or (x["razao"] == y["razao"] and x["adv"]["carro"] < y["adv"]["carro"]))
	return lista.map(func(x): return x["adv"])


## equipe id -> [adversários], da #1 para a #10, sem repetir modelo (se a
## licença acabar, repete os dela).
static func _distribuir(dados: Node) -> Dictionary:
	var r := {}
	var usados := {}
	var ordem := TheGrid.equipes(dados)
	ordem.reverse()
	for e in ordem:
		var d := de(dados, e)
		var quer := 1 if d.get("modo", "corrida") == "corrida" else 2
		var cand := _candidatos(dados, String(e.get("nivel", "")))
		var escolha := cand.filter(func(a): return not usados.has(a["carro"])).slice(0, quer)
		for a in cand:
			if escolha.size() >= quer:
				break
			if not a in escolha:
				escolha.append(a)
		for a in escolha:
			usados[a["carro"]] = true
		r[String(e["id"])] = escolha
	return r


## Pilotos da equipe para o desafio: os do tipo (corrida/arena, pelo perfil),
## sem os que o jogador contratou; faltando, os outros da equipe.
static func pilotos(dados: Node, jogador: Node, equipe: Dictionary, tipo: String, n: int) -> Array:
	var livres: Array = Array(equipe.get("pilotos", [])).filter(
			func(p): return jogador == null or EquipeJogador.vaga_do_piloto(jogador, String(p["id"])) == "")
	var certos := livres.filter(func(p): return EquipeJogador._do_grid(dados, equipe, p)["tipo"] == tipo)
	for p in livres:
		if certos.size() >= n:
			break
		if not p in certos:
			certos.append(p)
	return certos.slice(0, n)


## Prova do desafio de corrida da equipe ({} se ela não corre na pista).
static func evento(dados: Node, equipe_id: String) -> Dictionary:
	var eq := TheGrid.equipe(dados, equipe_id)
	var d := de(dados, eq)
	if d.is_empty() or d["modo"] != "corrida" or not dados.existe("pistas", d["pista"]):
		return {}
	var esp := especiais(dados, eq, 1)
	if esp.is_empty():
		return {}
	return {"id": PREFIXO + equipe_id, "nome": "Desafio The Grid · %s" % eq["nome"], "pista": d["pista"],
			"voltas": int(d["voltas"]), "condicao": "seco", "restricoes": {"licenca": String(eq.get("nivel", ""))},
			"adversarios": [esp[0]], "premios": [], "grid_equipe": equipe_id}


## Escalação da prova do desafio: a equipe com o piloto de corrida dela.
static func escalacao(dados: Node, jogador: Node, ev: Dictionary) -> Array:
	var eq := TheGrid.equipe(dados, String(ev["grid_equipe"]))
	var p := pilotos(dados, jogador, eq, "corrida", 1)
	return [] if p.is_empty() else [{"equipe": eq, "piloto": p[0], "segundo": false}]


## Carros que podem ir para a arena no desafio: todos fora da vaga de corrida,
## os escalados na arena primeiro. Um carro sempre fica (nunca se perde o
## único): o da vaga de corrida ou, com ela vazia, o de menor uid.
static func carros_arena(jogador: Node) -> Array:
	var corrida := Escalacao.uid(jogador, "corrida")
	var todos: Array = jogador.garagem.lista()
	if corrida < 0 or not todos.any(func(c): return c.uid == corrida):
		corrida = -1
		for c in todos:
			if corrida < 0 or c.uid < corrida:
				corrida = c.uid
	# Fora o de corrida e os que estão no reparo (ArenaCarreira.reparo_s).
	var l: Array = todos.filter(func(c): return c.uid != corrida and not ArenaCarreira.em_reparo(jogador, c.uid))
	var esc := [Escalacao.uid(jogador, "arena1"), Escalacao.uid(jogador, "arena2")]
	l.sort_custom(func(a, b):
		var ia := esc.find(a.uid)
		var ib := esc.find(b.uid)
		ia = 9 if ia < 0 else ia
		ib = 9 if ib < 0 else ib
		return ia < ib if ia != ib else a.uid < b.uid)
	return l


## Série de melhor de 3 em andamento ({} se nenhuma): {equipe, vitorias, derrotas}.
static func serie(jogador: Node) -> Dictionary:
	return jogador.grid.get("serie", {})


## "" se pode desafiar a equipe da vez agora; senão, o motivo (texto da tela).
static func bloqueio(dados: Node, jogador: Node, equipe: Dictionary) -> String:
	var d := de(dados, equipe)
	if d.is_empty():
		return "Desafio indisponível."
	if TheGrid.da_vez(dados, jogador).get("id") != equipe.get("id"):
		return "Só a equipe da vez pode ser desafiada."
	var lic := String(equipe.get("nivel", ""))
	if lic != "" and not lic in jogador.licencas:
		var nome := String(dados.item("licencas", lic).get("nome", lic)) if dados.existe("licencas", lic) else lic
		return "Precisa da %s." % nome
	if d["modo"] == "corrida":
		# Uma corrida por vez; o desafio da arena abre com corrida em andamento (decisão 116).
		if not jogador.fila.is_empty():
			return "Há uma corrida em andamento: o desafio abre quando ela terminar."
		if EquipeJogador.exige_piloto(jogador) and EquipeJogador.piloto_vaga(jogador, "corrida") == "":
			return "Contrate um piloto de corrida (aba Equipe)."
		if Escalacao.carro(jogador, "corrida") == null:
			return "Escale o carro de corrida na Oficina."
		if ArenaCarreira.em_reparo(jogador, Escalacao.uid(jogador, "corrida")):
			return "O carro de corrida está no reparo (conserte na Oficina ou escale outro)."
		return ""
	if not jogador.flags.has(EquipeJogador.FLAG_ARENA):
		return ("A arena abre quando a garagem tiver 3 carros." if jogador.garagem.lista().size() < 3
				else "A arena abre depois do primeiro patrocínio (licença Club e uma corrida).")
	if EquipeJogador.piloto_vaga(jogador, "arena1") == "" or EquipeJogador.piloto_vaga(jogador, "arena2") == "":
		return "A dupla precisa de dois pilotos de arena contratados (aba Equipe)."
	var precisa := 2 if serie(jogador).get("equipe") == equipe["id"] else int(d["carros_min"])
	if carros_arena(jogador).size() < precisa:
		return ("Melhor de 3: pede %d carros fora o de corrida e fora do reparo (os quebrados são trocados)." % precisa
				if int(d["rounds"]) > 1 else "Pede 2 carros fora o de corrida e fora do reparo.")
	return ""


## Descrição curta: "Corrida 1x1 · Oval do Planalto · 2 voltas" / "Arena 2x2 ·
## Pátio da Pedreira · melhor de 3".
static func resumo(dados: Node, equipe: Dictionary) -> String:
	var d := de(dados, equipe)
	if d.is_empty():
		return ""
	if d["modo"] == "corrida":
		return "Corrida 1x1 · %s · %d voltas" % [Aba.nome_pista(String(d["pista"])), int(d["voltas"])]
	var nome := ""
	for a in dados.arena().get("arenas", []):
		if a["id"] == d["arena"]:
			nome = String(a["nome"])
	return "Arena 2x2 · %s%s" % [nome, " · melhor de 3" if int(d["rounds"]) > 1 else ""]


## Prepara a luta do desafio de arena: escala os dois primeiros carros livres
## (o round seguinte troca os destruídos) e monta a luta contra os especiais.
static func montar_arena(dados: Node, jogador: Node, equipe: Dictionary, semente: int) -> Dictionary:
	var livres := carros_arena(jogador)
	Escalacao.definir(jogador, "arena1", -1)
	Escalacao.definir(jogador, "arena2", -1)
	Escalacao.definir(jogador, "arena1", livres[0].uid)
	Escalacao.definir(jogador, "arena2", livres[1].uid)
	return ArenaCarreira.montar(dados, jogador, livres[0].uid, semente, -1, equipe)


## Depois de um round: conta a série; vence o desafio quem chegar a
## ceil(rounds/2). {round, vitorias, derrotas, fim (bool), venceu (bool)}.
static func registrar_round(dados: Node, jogador: Node, equipe: Dictionary, venceu_round: bool) -> Dictionary:
	var d := de(dados, equipe)
	var rounds := int(d.get("rounds", 1))
	var s := serie(jogador)
	if s.get("equipe") != equipe["id"]:
		s = {"equipe": equipe["id"], "vitorias": 0, "derrotas": 0}
	s["vitorias"] = int(s["vitorias"]) + (1 if venceu_round else 0)
	s["derrotas"] = int(s["derrotas"]) + (0 if venceu_round else 1)
	var precisa := rounds / 2 + 1
	var venceu: bool = int(s["vitorias"]) >= precisa
	var fim: bool = venceu or int(s["derrotas"]) >= precisa
	# Sem carros para o próximo round, a série acaba.
	if not fim and carros_arena(jogador).size() < 2:
		fim = true
	if fim:
		jogador.grid.erase("serie")
	else:
		jogador.grid["serie"] = s
	return {"round": int(s["vitorias"]) + int(s["derrotas"]), "vitorias": int(s["vitorias"]),
			"derrotas": int(s["derrotas"]), "fim": fim, "venceu": venceu, "rounds": rounds}
