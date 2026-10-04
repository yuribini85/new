extends "res://tests/base_teste.gd"


func test_fixtures_carregam_sem_erros_nem_pendencias() -> void:
	var d := dados_fixture()
	igual(d.erros(), [], "erros")
	igual(d.pendencias(), [], "pendências")
	igual(d.lista("carros").size(), 2, "carros")
	igual(d.carro("forte")["tracao"], "FR", "tração")
	igual(d.pista("oval").comprimento, 1600.0, "pista")
	d.free()


func test_data_real_tem_formato_valido_e_lista_pendencias() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	igual(d.erros(), [], "erros em data/")
	verificar("carros.json vazio" in d.pendencias(), "carros vazio deveria ser pendência")
	verificar("simulacao.json: sigma_ruido" in d.pendencias(), "sigma_ruido deveria ser pendência")
	verificar("economia.json: saldo_inicial" in d.pendencias(), "saldo_inicial deveria ser pendência")
	verificar("carreira.json: teto_offline_s" in d.pendencias(), "teto_offline_s deveria ser pendência")
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
