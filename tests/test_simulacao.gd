extends "res://tests/base_teste.gd"


func _participante(d: Node, id: String, carro_id: String, piloto: String, condicao := "seco", pneus := ["seco"]) -> Dictionary:
	var c := Carro.new(d.carro(carro_id))
	for p in pneus:
		c.adicionar_pneu(d.pneu(p))
	return {"id": id, "atributos": c.atributos_efetivos(condicao), "piloto": d.piloto(piloto)}


func _correr(d: Node, pista: String, participantes: Array, voltas: int, semente := 1) -> Dictionary:
	return Simulacao.correr(d.pista(pista), participantes, voltas, d.simulacao(), semente)


func test_volta_lancada_no_circulo_bate_com_a_fisica() -> void:
	var d := dados_fixture()
	var r := _correr(d, "circulo", [_participante(d, "a", "forte", "perfeito")], 3)
	var esperado := 2.0 * PI * 40.0 / sqrt(1.0 * Simulacao.G * 40.0)
	var voltas: Array = r["carros"]["a"]["voltas"]
	igual(voltas.size(), 3, "voltas registradas")
	perto(voltas[1], esperado, 0.05, "volta 2")
	perto(voltas[2], esperado, 0.05, "volta 3")
	verificar(voltas[0] > voltas[1], "volta 1 parte parado")
	d.free()


func test_ritmo_do_piloto_escala_a_volta() -> void:
	var d := dados_fixture()
	var piloto := {"ritmo": 0.9, "consistencia": 1.0, "agressividade": 0.0}
	var r := Simulacao.correr(d.pista("circulo"),
			[{"id": "a", "atributos": _participante(d, "a", "forte", "perfeito")["atributos"], "piloto": piloto}],
			2, d.simulacao(), 1)
	perto(r["carros"]["a"]["voltas"][1], 2.0 * PI * 40.0 / (sqrt(Simulacao.G * 40.0) * 0.9), 0.05, "volta a 90%")
	d.free()


func test_mesma_semente_mesmo_resultado() -> void:
	var d := dados_fixture()
	var ps := [_participante(d, "a", "forte", "erratico"), _participante(d, "b", "fraco", "erratico")]
	var r1 := _correr(d, "oval", ps, 3, 42)
	var r2 := _correr(d, "oval", ps, 3, 42)
	var r3 := _correr(d, "oval", ps, 3, 7)
	igual(r1["carros"], r2["carros"], "determinismo")
	verificar(r1["carros"]["a"]["tempo_total"] != r3["carros"]["a"]["tempo_total"], "semente diferente muda o ruído")
	d.free()


func test_carro_mais_potente_vence() -> void:
	var d := dados_fixture()
	var r := _correr(d, "oval", [_participante(d, "fraco", "fraco", "perfeito"), _participante(d, "forte", "forte", "perfeito")], 5)
	igual(r["classificacao"], ["forte", "fraco"], "classificação")
	d.free()


func test_sem_zona_de_ultrapassagem_ninguem_passa() -> void:
	var d := dados_fixture()
	var r := _correr(d, "sem_ultrapassagem", [_participante(d, "fraco", "fraco", "perfeito"), _participante(d, "forte", "forte", "perfeito")], 5)
	igual(r["classificacao"], ["fraco", "forte"], "classificação mantém o grid")
	var dmin: float = d.simulacao()["distancia_minima_m"]
	var final: float = 5 * r["comprimento"]
	for a in r["amostras"]:
		if a["s"]["fraco"] >= final:
			break  # quem terminou deixa de ser obstáculo
		verificar(a["s"]["forte"] <= a["s"]["fraco"] - dmin + 1e-6, "forte encostou em t=%.1f" % a["t"])
	d.free()


func test_agressividade_decide_a_ultrapassagem_na_zona() -> void:
	var d := dados_fixture()
	var agressivo := _correr(d, "oval", [_participante(d, "fraco", "fraco", "timido"), _participante(d, "forte", "forte", "perfeito")], 5)
	igual(agressivo["classificacao"], ["forte", "fraco"], "agressivo passa")
	var timido := _correr(d, "oval", [_participante(d, "fraco", "fraco", "timido"), _participante(d, "forte", "forte", "timido")], 5)
	igual(timido["classificacao"], ["fraco", "forte"], "tímido não passa")
	d.free()


func test_pneu_de_chuva_vence_na_chuva() -> void:
	var d := dados_fixture()
	var r := _correr(d, "oval", [
		_participante(d, "so_seco", "forte", "perfeito", "chuva", ["seco"]),
		_participante(d, "com_chuva", "forte", "perfeito", "chuva", ["seco", "chuva"]),
	], 5)
	igual(r["classificacao"], ["com_chuva", "so_seco"], "classificação na chuva")
	d.free()


func test_sem_amostras_da_o_mesmo_resultado() -> void:
	var d := dados_fixture()
	var ps := [_participante(d, "a", "forte", "erratico"), _participante(d, "b", "fraco", "erratico")]
	var com := _correr(d, "oval", ps, 3, 9)
	var sem := Simulacao.correr(d.pista("oval"), ps, 3, d.simulacao(), 9, false)
	igual(sem["carros"], com["carros"], "mesmo resultado")
	igual(sem["duracao"], com["duracao"], "mesma duração")
	igual(sem["amostras"].size(), 1, "só a amostra final")
	d.free()


func test_arrasto_limita_a_velocidade_pela_potencia() -> void:
	var d := dados_fixture()
	var pista := Pista.new({"id": "longa", "trechos": [
		{"tipo": "reta", "comprimento_m": 4000},
		{"tipo": "curva_rapida", "comprimento_m": 500.0 * PI, "raio_m": 500},
		{"tipo": "reta", "comprimento_m": 4000},
		{"tipo": "curva_rapida", "comprimento_m": 500.0 * PI, "raio_m": 500},
	]})
	var c := Carro.new(d.carro("forte"))
	c.base = c.base.duplicate()
	c.base.erase("velocidade_max")
	c.adicionar_pneu(d.pneu("seco"))
	var params: Dictionary = d.simulacao().duplicate()
	params["cda_m2"] = 0.6
	params["densidade_ar_kg_m3"] = 1.2
	var r := Simulacao.correr(pista, [{"id": "a", "atributos": c.atributos_efetivos("seco"), "piloto": d.piloto("perfeito")}],
			1, params, 1)
	var a: Array = r["amostras"]
	var vmax := 0.0
	for i in range(1, a.size()):
		vmax = maxf(vmax, (a[i]["s"]["a"] - a[i - 1]["s"]["a"]) / (a[i]["t"] - a[i - 1]["t"]))
	var teorica := pow(300.0 * Simulacao.CV_PARA_W / (0.5 * 1.2 * 0.6), 1.0 / 3.0)
	verificar(vmax < teorica * 1.001, "não passa da velocidade terminal: %.1f > %.1f m/s" % [vmax, teorica])
	verificar(vmax > teorica * 0.95, "chega perto da terminal numa reta de 4 km: %.1f de %.1f m/s" % [vmax, teorica])
	d.free()


func test_forca_por_marcha_nao_passa_do_cambio_ideal_e_para_no_corte() -> void:
	var a := {"potencia": 100.0, "curva_rpm": PackedFloat64Array([1000, 4000, 7000]),
			"curva_nm": PackedFloat64Array([80, 120, 90]), "corte": 7000.0,
			"relacoes": PackedFloat64Array([3.0, 1.5, 1.0]), "final": 4.0, "raio_roda": 0.3}
	var f := Simulacao.forca_por_velocidade(a)
	verificar(f.size() > 10, "tabela preenchida")
	var pico_w := 0.0
	for i in 3:
		pico_w = maxf(pico_w, a["curva_nm"][i] * a["curva_rpm"][i] * TAU / 60.0)
	for k in range(1, f.size()):
		verificar(f[k] <= pico_w / (k * Simulacao.PASSO_FORCA) + 1e-6, "força ≤ P/v em %d" % k)
	# Última marcha no corte: 7000 rpm × raio ÷ (1,0 × 4,0) ≈ 55 m/s.
	var v_corte := 7000.0 * TAU / 60.0 * 0.3 / 4.0
	igual(f[int(v_corte / Simulacao.PASSO_FORCA) + 2], 0.0, "sem força depois do corte")
	verificar(f[int(v_corte / Simulacao.PASSO_FORCA) - 2] > 0.0, "força antes do corte")
