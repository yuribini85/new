extends "res://tests/base_teste.gd"

const JogadorScript := preload("res://autoload/jogador.gd")


func _jogador(d: Node) -> Node:
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000)
	return j


func test_restricoes() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var fraco: Carro = j.garagem.carro(j.concessionaria.comprar_carro(d.carro("fraco")))
	var forte: Carro = j.garagem.carro(j.concessionaria.comprar_carro(d.carro("forte")))
	var r: Dictionary = d.evento("ff_ate_120")["restricoes"]
	igual(Elegibilidade.motivos(fraco, r, []), [], "fraco entra")
	igual(Elegibilidade.motivos(forte, r, []).size(), 2, "forte: tração e potência")
	j.concessionaria.comprar_peca(fraco, d.peca("turbo"))
	igual(Elegibilidade.motivos(fraco, r, []).size(), 1, "turbo passa de 120 cv")
	igual(Elegibilidade.motivos(fraco, {"ano_min": 1991}, []).size(), 1, "ano_min")
	igual(Elegibilidade.motivos(fraco, {"licenca": "b"}, []).size(), 1, "sem licença")
	igual(Elegibilidade.motivos(fraco, {"licenca": "b"}, ["b"]), [], "com licença")
	# Copas de marca: lista de modelos e versão de corrida (rua × corrida).
	igual(Elegibilidade.motivos(fraco, {"carros": ["fraco"], "corrida": false}, []), [], "modelo da copa, de rua")
	igual(Elegibilidade.motivos(forte, {"carros": ["fraco"]}, []).size(), 1, "modelo fora da copa")
	igual(Elegibilidade.motivos(fraco, {"corrida": true}, []).size(), 1, "de rua não entra na copa corrida")
	fraco.pecas["corrida"] = {"id": "kit", "categoria": "corrida", "preco": 0, "efeitos": []}
	igual(Elegibilidade.motivos(fraco, {"corrida": true}, []), [], "com kit entra na copa corrida")
	igual(Elegibilidade.motivos(fraco, {"corrida": false}, []).size(), 1, "com kit sai da copa de rua")
	j.free()
	d.free()


func test_vitoria_paga_premio_e_carro_premio_so_na_primeira() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var c := Carreira.new(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	var saldo: int = j.economia.saldo
	var r1 := c.disputar("aberto", uid, 1)
	igual(r1["posicao"], 1, "forte vence fraco")
	igual(j.economia.saldo, saldo + 500, "prêmio de 1º")
	verificar(r1["carro_premio_uid"] > 0, "carro-prêmio entregue")
	igual(j.garagem.carro(r1["carro_premio_uid"]).id, "forte", "modelo do prêmio")
	var r2 := c.disputar("aberto", uid, 2)
	igual(r2["carro_premio_uid"], -1, "segunda vitória sem carro")
	igual(j.vitorias["aberto"], 2, "vitórias")
	igual(j.dias, 2, "cada corrida é um dia")
	igual(j.garagem.lista().size(), 2, "garagem")
	j.free()
	d.free()


func test_jogador_larga_em_ultimo() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var c := Carreira.new(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	var saldo: int = j.economia.saldo
	var r := c.disputar("aberto", uid, 1)
	igual(r["classificacao"], ["adv0_fraco", "jogador"], "carro igual não passa")
	igual(j.economia.saldo, saldo + 100, "prêmio de 2º")
	verificar(not j.vitorias.has("aberto"), "sem vitória")
	j.free()
	d.free()


func test_inelegivel_nao_corre() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var c := Carreira.new(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	verificar(c.disputar("ff_ate_120", uid, 1).has("erro"), "forte barrado")
	verificar(c.disputar("licenciado", uid, 1).has("erro"), "sem licença barrado")
	verificar(c.disputar("aberto", 999, 1).has("erro"), "carro inexistente")
	igual(j.dias, 0, "nenhuma corrida contada")
	j.free()
	d.free()


func test_adversario_com_pecas_e_pneu_de_chuva() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	j.licencas.append("b")
	var c := Carreira.new(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	var r := c.disputar("licenciado", uid, 1)
	igual(r["classificacao"][0], "adv0_forte", "turbo e pneu de chuva vencem na chuva")
	igual(r["premio"], 5, "prêmio de 2º")
	j.free()
	d.free()


func test_escalacao_por_equipes() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var c := Carreira.new(d, j)
	var g1 := c.escalacao("aberto", 7)
	igual(g1.size(), 1, "uma vaga por adversário")
	igual(g1[0]["equipe"]["id"], "eq_azul", "prova sem licença: equipe do nível N1 primeiro")
	igual(c.escalacao("aberto", 7), g1, "mesma semente, mesmo grid")
	igual(c.escalacao("licenciado", 7)[0]["equipe"]["id"], "eq_verde", "licença b: nível N2")
	var segundos := 0
	for s in 400:
		if c.escalacao("aberto", s)[0]["segundo"]:
			segundos += 1
	verificar(segundos > 90 and segundos < 150, "segundo piloto em ~30%% das corridas (%d/400)" % segundos)
	# O segundo piloto corre com menos consistência; o nome sai da escalação.
	var s2 := 0
	while not c.escalacao("aberto", s2)[0]["segundo"]:
		s2 += 1
	igual(c.nome_piloto("aberto", "adv0_fraco", s2), "Azul Dois", "nome do segundo piloto")
	igual(c.nome_piloto("aberto", "adv0_fraco"), Carreira.sobrenome_fixo("aberto", 0), "sem semente: nome fixo")
	j.free()
	d.free()


func test_campeonato_por_pontos() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var c := Carreira.new(d, j)
	var ev := {"nome": "Copa — etapa 1", "premios": [500, 250, 100]}
	igual(Campeonatos.pontos(ev, 1), 10, "1º: 10 pontos")
	igual(Campeonatos.pontos(ev, 2), 5, "2º: proporcional ao prêmio")
	igual(Campeonatos.pontos(ev, 4), 0, "fora dos prêmios: 0")
	igual(Campeonatos.serie(ev), "Copa", "série pelo nome")
	# Série de uma prova só não é campeonato.
	igual(Campeonatos.registrar(c, "aberto", ["jogador", "adv0_fraco"], 1), {}, "prova única: sem campeonato")
	igual(Campeonatos.registrar(c, "serie_2", ["jogador", "adv0_fraco"], 1), {}, "fora da vez não conta")
	var r1: Dictionary = Campeonatos.registrar(c, "serie_1", ["adv0_fraco", "jogador"], 1)
	igual(r1["pontos"], 5, "2º na etapa 1")
	verificar(not r1["final"], "temporada continua")
	var saldo: int = j.economia.saldo
	var r2: Dictionary = Campeonatos.registrar(c, "serie_2", ["jogador", "adv0_fraco"], 2)
	verificar(r2["final"], "última etapa fecha a temporada")
	# 15 pts do jogador; o rival pontua pela equipe de cada corrida.
	igual(int(r2["classificacao_final"][0][1]) >= 15, true, "líder com ao menos 15 pts")
	if r2["campeao"]:
		igual(j.economia.saldo, saldo + 300, "bônus de campeão pago")
		igual(j.titulos.get("Copa Teste", 0), 1, "título registrado")
	verificar(not j.campeonatos.has("Copa Teste"), "temporada recomeça")
	j.free()
	d.free()


func test_historia_escolhe_cena_por_trigger_flags_e_condicao() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var h := Historia.new(d, j)
	igual(h.cena_para("GAME_START"), {}, "sem personagem, sem história")
	j.personagem = "ana"
	var c := h.cena_para("GAME_START")
	igual(c.get("id"), "boas_vindas", "abertura")
	igual(h.cena_para("CORRIDA_FIM", {"posicao": 1}), {}, "exige a flag da abertura")
	var prox := h.concluir(c)
	igual(prox.get("id"), "segue", "cena encadeada")
	verificar(j.flags.has("COMECOU"), "flag gravada")
	igual(h.cena_para("GAME_START"), {}, "uma vez só")
	igual(h.cena_para("CORRIDA_FIM", {"posicao": 2}), {}, "condição de posição")
	igual(h.cena_para("CORRIDA_FIM", {"posicao": 1}).get("id"), "vitoria", "vitória")
	h.concluir(h.cena_para("SEM_DINHEIRO"))
	igual(h.cena_para("SEM_DINHEIRO").get("id"), "sempre", "repetível")
	j.free()
	d.free()
