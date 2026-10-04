extends "res://tests/base_teste.gd"


func test_box_fica_fora_da_volta_e_indice_da_volta_completa() -> void:
	var d := dados_fixture()
	var p: Pista = d.pista("oval")
	igual(p.comprimento, 1600.0, "comprimento sem box")
	igual(p.trecho_em(0.0)["tipo"], "reta", "início")
	igual(p.trecho_em(550.0)["tipo"], "curva_media", "primeira curva")
	igual(p.indice_em(1610.0), 0, "segunda volta")
	igual(p.indice_em(-10.0), 3, "grid atrás da linha")
	d.free()


func test_validacao() -> void:
	var erros := Pista.validar({"trechos": [
		{"tipo": "chicane", "comprimento_m": 10},
		{"tipo": "curva_lenta", "comprimento_m": 10},
		{"tipo": "reta", "comprimento_m": 0},
	]})
	igual(erros.size(), 3, "erros: %s" % [erros])
	igual(Pista.validar({"trechos": [{"tipo": "entrada_box", "comprimento_m": 10}]}).size(), 1, "só box")
