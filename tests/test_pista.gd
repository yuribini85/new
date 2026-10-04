extends "res://tests/base_teste.gd"


func test_box_fica_fora_da_volta_e_indice_da_volta_completa() -> void:
	var d := dados_fixture()
	var p: Pista = d.pista("oval")
	perto(p.comprimento, 1000.0 + 200.0 * PI, 1e-3, "comprimento sem box")
	igual(p.trecho_em(0.0)["tipo"], "reta", "início")
	igual(p.trecho_em(550.0)["tipo"], "curva_media", "primeira curva")
	igual(p.indice_em(p.comprimento + 10.0), 0, "segunda volta")
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


func test_geometria_fecha_e_segue_os_trechos() -> void:
	var d := dados_fixture()
	for id in ["oval", "circulo", "sem_ultrapassagem", "oito_direita"]:
		var p: Pista = d.pista(id)
		verificar(p.erro_fechamento() < 0.01, "%s não fecha: %.4f m" % [id, p.erro_fechamento()])
		verificar(p.erro_rumo() < 1e-4, "%s rumo final: %.6f" % [id, p.erro_rumo()])
	var oval: Pista = d.pista("oval")
	verificar(oval.posicao_em(250.0).distance_to(Vector2(250, 0)) < 1e-6, "meio da reta")
	verificar(oval.posicao_em(500.0 + 100.0 * PI).distance_to(Vector2(500, 200)) < 1e-3, "fim da curva à esquerda")
	perto(oval.rumo_em(500.0 + 100.0 * PI), PI, 1e-6, "rumo após a curva")
	var direita: Pista = d.pista("oito_direita")
	verificar(direita.posicao_em(100.0 + 125.6637061).y < 0.0, "curva à direita vai para -y")
	verificar(Pista.validar({"trechos": [{"tipo": "reta", "comprimento_m": 1, "sentido": "cima"}]}).size() == 1, "sentido inválido")
	d.free()
