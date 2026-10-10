extends "res://tests/base_teste.gd"


func test_fixtures_carregam_sem_erros_nem_pendencias() -> void:
	var d := dados_fixture()
	igual(d.erros(), [], "erros")
	igual(d.pendencias(), [], "pendências")
	igual(d.lista("carros").size(), 2, "carros")
	igual(d.carro("forte")["tracao"], "FR", "tração")
	perto(d.pista("oval").comprimento, 1000.0 + 200.0 * PI, 1e-3, "pista")
	d.free()


func test_data_real_carrega_sem_erros_nem_pendencias() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	igual(d.erros(), [], "erros em data/")
	igual(d.pendencias(), [], "pendências em data/")
	verificar(d.lista("carros").size() >= 17, "carros importados do GT2")
	d.free()

func test_referencias_invalidas_sao_erro() -> void:
	var d := dados_fixture()
	d._listas["carros"]["x"] = {"id": "x", "fabricante": "nenhuma", "tracao": "AWD"}
	d._objetos["economia"]["pneu_de_fabrica"] = "nenhum"
	d._erros.clear()
	d._listas["eventos"]["y"] = {"id": "y", "pista": "nenhuma", "condicao": "neve",
		"restricoes": {"cor": "azul"}, "adversarios": [{"carro": "fraco", "piloto": "ninguem"}]}
	d._validar_referencias()
	igual(d.erros().size(), 7, "erros: %s" % [d.erros()])
	d.free()
