extends "res://tests/base_teste.gd"

const JogadorScript := preload("res://autoload/jogador.gd")


func _jogador(d: Node) -> Node:
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000)
	return j


func test_estados_e_treino_da_licenca() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	j.treinos = {}
	var l := Licencas.new(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	igual(l.estado("a", 0.0), Licencas.LOCKED, "a sem b: bloqueada")
	igual(l.estado("b", 0.0), Licencas.AVAILABLE, "b disponível")
	igual(l.iniciar_treino("b", 100.0), "", "treino começa")
	var dur := l.treino_s("b")
	verificar(dur > 0.0, "treino tem duração")
	igual(l.estado("b", 100.0 + dur * 0.5), Licencas.TRAINING, "no meio do treino")
	perto(l.restante("b", 100.0 + dur * 0.5), dur * 0.5, 0.01, "tempo restante")
	igual(l.estado("b", 100.0 + dur + 1.0), Licencas.READY, "treino feito")
	igual(l.atualizar(100.0 + dur + 1.0), ["b"], "treino feito: licença concedida sozinha")
	igual(l.estado("b", 100.0 + dur + 2.0), Licencas.COMPLETE, "concedida")
	igual(Licencas.id_novo("B"), "CLUB", "id antigo migra")
	igual(Licencas.teste_novo("a2"), "sport2", "teste antigo migra")
	igual(Licencas.teste_novo("ic_ultimo_credito"), "ic_ultimo_credito", "contrato fica")
	j.free()
	d.free()


func test_desejos_voltam_do_save() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	j.desejos = ["forte"]
	var estado: Dictionary = JSON.parse_string(JSON.stringify(Save.serializar(j)))
	estado["usados_vendidos"] = {"0:fraco": true}  # save antigo: os usados saíram, a chave é ignorada
	var k := _jogador(d)
	igual(Save.desserializar(estado, k, d), "", "load")
	igual(k.desejos, ["forte"], "desejos voltam do save")
	j.free()
	k.free()
	d.free()
