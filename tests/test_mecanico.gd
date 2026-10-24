extends "res://tests/base_teste.gd"

const JogadorScript := preload("res://autoload/jogador.gd")


func _jogador(d: Node) -> Node:
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000)
	j.carreira = Carreira.new(d, j)
	return j


func test_avaliacao_usa_as_mesmas_sementes_e_e_reprodutivel() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	var c: Carro = j.garagem.carro(uid)
	var a := Mecanico.avaliar(j.carreira, "aberto", uid, c)
	var b := Mecanico.avaliar(j.carreira, "aberto", uid, c)
	igual(a, b, "mesmas sementes, mesma avaliação")
	igual(a["posicoes"].size(), Mecanico.amostras_para(d.evento("aberto")), "amostras")
	igual(Mecanico.amostras_para({"voltas": 2}), Mecanico.AMOSTRAS, "prova curta: todas as amostras")
	igual(Mecanico.amostras_para({"voltas": 30}), 3, "30 voltas: 3 corridas")
	igual(Mecanico.amostras_para({"voltas": 99}), Mecanico.AMOSTRAS_MIN, "99 voltas: o mínimo")
	verificar(a["faixa"][0] <= a["faixa"][1], "faixa ordenada")
	igual(Mecanico.texto_faixa([1, 1]), "1º", "faixa de um valor")
	igual(Mecanico.texto_faixa([1, 3]), "1º–3º", "faixa")
	j.free()
	d.free()


func test_opcao_que_atravessa_o_limite_avisa_a_prova_perdida() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	var c: Carro = j.garagem.carro(uid)
	# 100 cv FF de 1990: cabe na Copa FF (até 120 cv); com turbo vai a 150.
	verificar("ff_ate_120" in Mecanico.provas_possiveis(d, c), "antes: pode correr a Copa FF")
	var r := Mecanico.analisar(j.carreira, "aberto", uid, 10)
	var por_id := {}
	for o in r["opcoes"]:
		por_id[o["item"]["id"]] = o
	verificar(por_id.has("turbo"), "turbo melhora a posição no Aberto: %s" % [r["opcoes"].map(func(o): return o["item"]["id"])])
	if por_id.has("turbo"):
		igual(por_id["turbo"]["perde"], ["Copa FF"], "turbo tira o carro da Copa FF")
	if por_id.has("alivio"):
		igual(por_id["alivio"]["perde"], [], "alívio de peso não tira de nada")
	j.free()
	d.free()


func test_ordem_por_ganho_por_giro() -> void:
	var base := {"media": 6.0}
	var boas := [
		{"nome": "cara", "preco": 1000, "media": 2.0},
		{"nome": "barata", "preco": 100, "media": 5.0},
		{"nome": "sua", "preco": 0, "media": 5.5},
	]
	var r := Mecanico.ordenar(boas, base, 3)
	igual(r.map(func(o): return o["nome"]), ["sua", "barata", "cara"],
			"já é sua primeiro; depois a que mais melhora por giro (1 posição por 100 > 4 por 1000)")
	perto(r[1]["ganho"], 1.0, 0.001, "ganho em posições médias")
	igual(Mecanico.ordenar(boas, base, 1).size(), 1, "até o máximo")


func test_carro_sugerido_abre_prova_ou_resolve_a_travada() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	var s := Mecanico.carro_sugerido(d, j, j.garagem.carro(uid))
	igual(s.get("carro", {}).get("id"), "fraco", "300 cv FR não entra na Copa FF: o FF de 100 cv abre")
	igual(s.get("prova"), "Copa FF", "a prova que ele abre")
	j.free()
	j = _jogador(d)
	uid = j.concessionaria.comprar_carro(d.carro("fraco"))
	verificar(Mecanico.carro_sugerido(d, j, j.garagem.carro(uid)).is_empty(), "o forte não abre prova nova")
	igual(Mecanico.carro_sugerido(d, j, j.garagem.carro(uid), ["aberto"]).get("carro", {}).get("id"), "forte",
			"travado no Aberto: o mais forte resolve")
	j.vitorias["aberto"] = 1
	verificar(Mecanico.carro_sugerido(d, j, j.garagem.carro(uid), ["aberto"]).is_empty(), "prova vencida não conta")
	j.free()
	d.free()


func test_derrotas_seguidas_so_em_prova_nao_vencida() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	var perder := func(ev: String) -> void:
		var c: Dictionary = j.carreira.preparar(ev, uid, 7, false)
		var cl: Array = c["resultado"]["classificacao"]
		cl.erase("jogador")
		cl.append("jogador")
		j.carreira.aplicar(c)
	perder.call("aberto")
	perder.call("aberto")
	igual(j.derrotas_seguidas, 2, "duas derrotas em prova não vencida")
	j.vitorias["serie_1"] = 1
	perder.call("serie_1")
	igual(j.derrotas_seguidas, 2, "repetição de prova vencida não conta")
	var c: Dictionary = j.carreira.preparar("aberto", uid, 7, false)
	var cl: Array = c["resultado"]["classificacao"]
	cl.erase("jogador")
	cl.push_front("jogador")
	j.carreira.aplicar(c)
	igual(j.derrotas_seguidas, 0, "a vitória zera")
	j.free()
	d.free()
