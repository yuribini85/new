extends "res://tests/base_teste.gd"

const JogadorScript := preload("res://autoload/jogador.gd")


func _jogador(d: Node) -> Node:
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	# Treinos já feitos (decisão 33): estes testes cobrem a avaliação.
	j.treinos = {"a": -1.0e12, "b": -1.0e12}
	return j


func test_contrato_de_fabrica_nao_cumpre_e_peca_cumpre() -> void:
	var d := dados_fixture()
	var c: Dictionary = d.item("contratos", "c_teste")
	var fabrica := Contratos.avaliar(d, c, {"pecas": []})
	igual(fabrica["grau"], "", "de fábrica empata com o rival: não vence")
	var turbo := Contratos.avaliar(d, c, {"pecas": ["turbo"]})
	igual(turbo["grau"], "prata", "turbo: vence com uma peça, mas é de motor")
	verificar(turbo["provas"][0]["folga"] > 0.0, "folga positiva")
	verificar(turbo["provas"][0].has("diagnostico"), "diagnóstico de curvas e retas")
	var alivio := Contratos.avaliar(d, c, {"pecas": ["alivio"]})
	igual(alivio["grau"], "ouro", "alívio de peso: vence sem peça de motor")
	igual(Contratos.avaliar(d, c, {"pecas": ["alivio"]}), alivio, "mesma montagem, mesmo resultado")
	var duas := Contratos.avaliar(d, c, {"pecas": ["turbo", "alivio"]})
	verificar(not duas["graus"]["prata"].is_empty(), "duas peças: falta a condição da prata")
	igual(duas["custo"], 300, "custo pelo preço de tabela")
	d.free()


func test_contrato_concede_licenca_e_guarda_montagem() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var ct := Contratos.new(d, j)
	verificar(ct.enviar("c_teste", {"pecas": ["alivio"]}).has("erro"), "licença a exige a b")
	j.licencas.append("b")
	var r := ct.enviar("c_teste", {"pecas": []})
	verificar(not r["licenca_concedida"] and not "a" in j.licencas, "reprovado não concede")
	r = ct.enviar("c_teste", {"pecas": ["turbo"]})
	verificar(r["licenca_concedida"] and "a" in j.licencas, "bronze ou melhor concede a licença")
	igual(j.graus_licenca["c_teste"], "prata", "grau guardado")
	ct.enviar("c_teste", {"pecas": []})
	igual(j.graus_licenca["c_teste"], "prata", "reprovação não rebaixa")
	igual(j.montagens["c_teste"]["pecas"], [], "última montagem enviada")
	var estado: Dictionary = JSON.parse_string(JSON.stringify(Save.serializar(j)))
	var k := _jogador(d)
	igual(Save.desserializar(estado, k, d), "", "load")
	igual(k.montagens, j.montagens, "montagens voltam do save")
	j.free()
	k.free()
	d.free()


func test_peca_de_outro_carro_fica_fora_da_montagem() -> void:
	var d := dados_fixture()
	var c: Dictionary = d.item("contratos", "c_teste").duplicate(true)
	c["pecas_escola"] = ["alivio"]
	igual(Contratos.avaliar(d, c, {"pecas": ["turbo"]})["n_pecas"], 0, "turbo fora da lista da escola")
	d.free()
