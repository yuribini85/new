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


func test_estoque_de_usados_por_janela_de_dias() -> void:
	var d := dados_fixture()
	var carros: Array = d.lista("carros")
	igual(Usados.estoque(carros, 5, {}), [{"carro_id": "fraco", "preco": 150, "chave": "0:fraco", "fim": 9}], "dia 5")
	igual(Usados.estoque(carros, 15, {}).map(func(o): return [o["carro_id"], o["preco"]]),
			[["fraco", 140], ["forte", 400]], "dia 15: duas ofertas, da mais barata para a mais cara")
	igual(Usados.estoque(carros, 31, {}), [], "dia 31")
	d.free()


func test_comprar_usado_tira_do_estoque_na_janela() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var oferta: Dictionary = Usados.estoque(d.lista("carros"), 5, j.usados_vendidos)[0]
	var saldo: int = j.economia.saldo
	var uid: int = j.concessionaria.comprar_usado(oferta, d.carro(oferta["carro_id"]), j.usados_vendidos)
	verificar(uid > 0, "compra")
	igual(j.economia.saldo, saldo - 150, "débito pelo preço da janela")
	igual(Usados.estoque(d.lista("carros"), 5, j.usados_vendidos), [], "saiu do estoque")
	igual(j.concessionaria.comprar_usado(oferta, d.carro(oferta["carro_id"]), j.usados_vendidos), -1, "não compra duas vezes")
	igual(Usados.estoque(d.lista("carros"), 10, j.usados_vendidos).filter(func(o): return o["carro_id"] == "fraco").size(),
			1, "volta na janela seguinte")
	j.free()
	d.free()


func test_agenda_e_proxima_oferta_dos_usados() -> void:
	var d := dados_fixture()
	var carros: Array = d.lista("carros")
	var ag := Usados.agenda(carros, 0, 30)
	igual(ag.map(func(o): return [o["carro_id"], o["inicio"]]), [["fraco", 10], ["forte", 10]], "abrem no dia 10, mais barato primeiro")
	igual(Usados.agenda(carros, 0, 9), [], "nada abre antes do dia 10")
	igual(Usados.proxima(d.carro("forte"), 3, {})["inicio"], 10, "forte: próxima janela no dia 10")
	igual(Usados.proxima(d.carro("fraco"), 3, {})["inicio"], 0, "fraco: à venda agora")
	igual(Usados.proxima(d.carro("fraco"), 3, {"0:fraco": true})["inicio"], 10, "comprado nesta janela: a próxima")
	igual(Usados.proxima(d.carro("forte"), 21, {}), {}, "forte não volta depois do dia 20")
	var j := _jogador(d)
	j.desejos = ["forte"]
	var estado: Dictionary = JSON.parse_string(JSON.stringify(Save.serializar(j)))
	var k := _jogador(d)
	igual(Save.desserializar(estado, k, d), "", "load")
	igual(k.desejos, ["forte"], "desejos voltam do save")
	j.free()
	k.free()
	d.free()
