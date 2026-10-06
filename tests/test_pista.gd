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


const Importador := preload("res://tools/importar_kit_pista.gd")


func test_kit_segue_o_manifesto() -> void:
	var itens: Array = JSON.parse_string(FileAccess.get_file_as_string("res://arte/pistas/kit_manifesto.json"))
	verificar(itens.size() > 0, "manifesto vazio")
	for it in itens:
		var t := MontadorPista.kit(String(it["nome"]))
		verificar(t != null, "kit sem %s" % it["nome"])
		if t != null:
			igual(Vector2i(t.get_width(), t.get_height()), Vector2i(int(it["largura_px"]), int(it["altura_px"])),
					"tamanho de %s" % it["nome"])


func test_importador_tira_magenta_e_refaz_emenda() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1))
	img.fill_rect(Rect2i(16, 16, 32, 32), Color(0.2, 0.4, 0.2))
	verificar(Importador._tirar_magenta(img), "magenta não detectado")
	perto(img.get_pixel(0, 0).a, 0.0, 1e-3, "fundo transparente")
	perto(img.get_pixel(32, 32).a, 1.0, 1e-3, "objeto opaco")
	var verde := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	verde.fill(Color(0.2, 0.4, 0.2))
	verificar(not Importador._tirar_magenta(verde), "sem magenta não mexe")
	var tex := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	tex.fill(Color(0.3, 0.3, 0.3))
	tex.fill_rect(Rect2i(0, 0, 64, 4), Color(0.9, 0.9, 0.9))
	verificar(Importador._emenda(tex) > 0.06, "emenda ruim detectada")
	verificar(Importador._emenda(Importador._repetivel(tex)) < 0.02, "repetível emenda")
