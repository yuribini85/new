extends "res://tests/base_teste.gd"

const JogadorScript := preload("res://autoload/jogador.gd")


func _jogador(d: Node) -> Node:
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000)
	return j


func test_licenca_concedida_com_todos_os_testes_em_bronze_ou_melhor() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var l := Licencas.new(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	var r1 := l.fazer_teste("b", "b1", uid, 1)
	igual(r1["grau"], "ouro", "b1 (tempo %.2f)" % r1.get("tempo", -1.0))
	igual(r1["licenca_concedida"], false, "falta b2")
	var r2 := l.fazer_teste("b", "b2", uid, 1)
	igual(r2["grau"], "bronze", "b2 (tempo %.2f)" % r2.get("tempo", -1.0))
	igual(r2["licenca_concedida"], true, "b concedida")
	igual(j.licencas, ["b"], "licenças")
	igual(j.dias, 0, "teste não conta dia")
	j.free()
	d.free()


func test_requisito_restricao_e_reprovacao() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var l := Licencas.new(d, j)
	var forte: int = j.concessionaria.comprar_carro(d.carro("forte"))
	verificar(l.fazer_teste("a", "a1", forte, 1).has("erro"), "a exige b")
	verificar(l.fazer_teste("b", "b1", forte, 1).has("erro"), "b1 só FF")
	j.licencas.append("b")
	var r := l.fazer_teste("a", "a1", forte, 1)
	igual(r["grau"], "", "tempo impossível reprova")
	igual(r["licenca_concedida"], false, "a não concedida")
	verificar(not j.graus_licenca.has("a1"), "reprovação não registra grau")
	j.free()
	d.free()


func test_melhor_grau_e_mantido() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var l := Licencas.new(d, j)
	j.graus_licenca["b2"] = "ouro"
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	l.fazer_teste("b", "b2", uid, 1)
	igual(j.graus_licenca["b2"], "ouro", "bronze não rebaixa ouro")
	j.free()
	d.free()


func test_estoque_de_usados_por_faixa_de_dias() -> void:
	var d := dados_fixture()
	var regras: Dictionary = d.economia()
	var carros: Array = d.lista("carros")
	igual(Usados.estoque(carros, 5, regras, {}).map(func(o): return o["carro_id"]), ["fraco"], "dia 5")
	igual(Usados.estoque(carros, 15, regras, {}).size(), 2, "dia 15")
	igual(Usados.estoque(carros, 31, regras, {}), [], "dia 31")
	d.free()


func test_quilometragem_fixa_no_periodo_e_preco_com_desconto() -> void:
	var d := dados_fixture()
	var regras: Dictionary = d.economia()
	var carros: Array = d.lista("carros")
	var a: Dictionary = Usados.estoque(carros, 14, regras, {})[0]
	var b: Dictionary = Usados.estoque(carros, 20, regras, {})[0]
	igual(a, b, "mesmo período (dias 14-20)")
	verificar(a["km"] >= 10000 and a["km"] <= 90000, "km na faixa: %d" % a["km"])
	igual(a["preco"], int(floor(400 * maxf(1.0 - a["km"] * 0.00001, 0.3))), "preço")
	d.free()


func test_comprar_usado_tira_do_estoque_no_periodo() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var regras: Dictionary = d.economia()
	var oferta: Dictionary = Usados.estoque(d.lista("carros"), 5, regras, j.usados_vendidos)[0]
	var saldo: int = j.economia.saldo
	var uid: int = j.concessionaria.comprar_usado(oferta, d.carro(oferta["carro_id"]), j.usados_vendidos)
	verificar(uid > 0, "compra")
	igual(j.economia.saldo, saldo - oferta["preco"], "débito")
	igual(j.garagem.carro(uid).km, oferta["km"], "km do carro")
	igual(Usados.estoque(d.lista("carros"), 5, regras, j.usados_vendidos), [], "saiu do estoque")
	igual(j.concessionaria.comprar_usado(oferta, d.carro(oferta["carro_id"]), j.usados_vendidos), -1, "não compra duas vezes")
	igual(Usados.estoque(d.lista("carros"), 7, regras, j.usados_vendidos).size(), 1, "volta no período seguinte")
	j.free()
	d.free()
