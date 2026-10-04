extends "res://tests/base_teste.gd"

const JogadorScript := preload("res://autoload/jogador.gd")


func _jogador(d: Node) -> Node:
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	return j


func test_comprar_carro_debita_e_entrega_com_pneu_de_fabrica() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	verificar(uid > 0, "compra")
	igual(j.economia.saldo, 600, "saldo 1000 - 400")
	var c: Carro = j.garagem.carro(uid)
	igual(c.atributos_efetivos("seco")["pneu"], "seco", "pneu de fábrica")
	j.free()
	d.free()


func test_sem_saldo_nao_compra_nada() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	j.concessionaria.comprar_carro(d.carro("fraco"))
	igual(j.concessionaria.comprar_carro(d.carro("forte")), -1, "forte custa 900 com 600")
	igual(j.economia.saldo, 600, "saldo intacto")
	igual(j.garagem.lista().size(), 1, "garagem")
	j.free()
	d.free()


func test_dois_do_mesmo_modelo_tem_uids_distintos() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var a: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	var b: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	verificar(a != b and b > 0, "uids %d %d" % [a, b])
	j.free()
	d.free()


func test_vender_paga_fracao_do_preco_de_tabela() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	j.concessionaria.comprar_peca(j.garagem.carro(uid), d.peca("turbo"))
	igual(j.economia.saldo, 400, "1000 - 400 - 200")
	igual(j.concessionaria.vender_carro(uid), 200, "400 * 0.5, peças não somam")
	igual(j.economia.saldo, 600, "saldo após venda")
	igual(j.garagem.carro(uid), null, "saiu da garagem")
	igual(j.concessionaria.vender_carro(uid), 0, "vender de novo")
	j.free()
	d.free()


func test_peca_possuida_reinstala_sem_cobrar() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	j.economia.creditar(1000)
	var c: Carro = j.garagem.carro(j.concessionaria.comprar_carro(d.carro("forte")))
	igual(j.concessionaria.comprar_peca(c, d.peca("turbo")), "", "turbo")
	igual(j.concessionaria.comprar_peca(c, d.peca("motor_fr")), "", "motor_fr")
	igual(j.economia.saldo, 600, "2000 - 900 - 200 - 300")
	igual(j.concessionaria.comprar_peca(c, d.peca("turbo")), "", "volta ao turbo")
	igual(j.economia.saldo, 600, "reinstalar é grátis")
	igual(c.pecas["motor"]["id"], "turbo", "instalada")
	j.free()
	d.free()


func test_peca_incompativel_ou_sem_saldo_nao_cobra() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var c: Carro = j.garagem.carro(j.concessionaria.comprar_carro(d.carro("fraco")))
	verificar(j.concessionaria.comprar_peca(c, d.peca("motor_fr")) != "", "FF recusa motor_fr")
	igual(j.economia.saldo, 600, "nada cobrado")
	j.economia.debitar(550)
	igual(j.concessionaria.comprar_peca(c, d.peca("turbo")), "saldo insuficiente", "sem saldo")
	verificar(not c.pecas.has("motor"), "não instalou")
	j.free()
	d.free()


func test_pneu_de_chuva_comprado_uma_vez() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var c: Carro = j.garagem.carro(j.concessionaria.comprar_carro(d.carro("fraco")))
	igual(j.concessionaria.comprar_pneu(c, d.pneu("chuva")), "", "compra")
	igual(j.economia.saldo, 520, "600 - 80")
	igual(j.concessionaria.comprar_pneu(c, d.pneu("chuva")), "pneu já possuído", "repetido")
	igual(c.atributos_efetivos("chuva")["pneu"], "chuva", "usado na chuva")
	j.free()
	d.free()
