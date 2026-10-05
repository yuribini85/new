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
	igual(a["posicoes"].size(), Mecanico.AMOSTRAS, "amostras")
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
