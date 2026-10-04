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
