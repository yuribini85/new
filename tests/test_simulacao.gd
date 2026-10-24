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


func test_largada_lancada_tira_a_arrancada_da_volta_1() -> void:
	var d := dados_fixture()
	var v := sqrt(1.0 * Simulacao.G * 40.0)
	var r := Simulacao.correr(d.pista("circulo"), [_participante(d, "a", "forte", "perfeito")], 2, d.simulacao(), 1,
			true, v)
	var voltas: Array = r["carros"]["a"]["voltas"]
	perto(voltas[0], voltas[1], 0.05, "volta 1 lançada igual à volta 2")
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
	# A velocidade máxima da ficha da garagem é a mesma terminal do modelo.
	var ficha := Simulacao.velocidade_maxima_kmh(c.atributos_efetivos("seco"), params)
	verificar(absf(ficha * Simulacao.KMH_PARA_MS - teorica) < 0.5, "ficha: %.1f de %.1f m/s" % [ficha * Simulacao.KMH_PARA_MS, teorica])
	var com_teto := c.atributos_efetivos("seco")
	com_teto["velocidade_max"] = 150.0
	igual(Simulacao.velocidade_maxima_kmh(com_teto, params), 150.0, "o teto do carro limita a ficha")
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


func test_tracao_pelo_peso_no_eixo_motriz() -> void:
	var p := {"fator_tracao": {"FF": 0.6, "FR": 0.5, "MR": 0.55, "RR": 0.6, "4WD": 1.0}}
	perto(Simulacao.fator_tracao({"tracao": "FR"}, p), 0.5, 1e-9, "sem peso_dianteiro: fator fixo")
	perto(Simulacao.fator_tracao({"tracao": "FF", "peso_dianteiro": 0.62}, p), 0.62, 1e-9, "FF: peso na frente")
	perto(Simulacao.fator_tracao({"tracao": "MR", "peso_dianteiro": 0.39}, p), 0.61, 1e-9, "MR: peso atrás")
	perto(Simulacao.fator_tracao({"tracao": "4WD", "peso_dianteiro": 0.55}, p), 1.0, 1e-9, "4WD: todo o peso")


func test_diagnostico_separa_trafego_de_potencial() -> void:
	var d := dados_fixture()
	# Sem zona de ultrapassagem, o forte larga atrás do fraco e fica preso.
	var r := Simulacao.correr(d.pista("sem_ultrapassagem"),
			[_participante(d, "fraco", "fraco", "perfeito"), _participante(d, "forte", "forte", "perfeito")],
			2, d.simulacao(), 1)
	var dmin := float(d.simulacao()["distancia_minima_m"])
	verificar(Diagnostico.colado(r, "forte", dmin) > 1.0, "forte preso atrás do fraco")
	igual(Diagnostico.colado(r, "fraco", dmin), 0.0, "o da frente nunca está colado")
	var ev := {"pista": "oval", "voltas": 1}
	var p := Diagnostico.potencial(d, ev, _participante(d, "a", "fraco", "perfeito")["atributos"],
			_participante(d, "b", "forte", "perfeito")["atributos"])
	verificar(p["meu"] > p["rival"], "sozinho, o fraco é mais lento")
	perto(p["curvas"] + p["retas"], p["meu"] - p["rival"], 0.3, "curvas + retas ≈ diferença total")
	d.free()


func test_tatica_curvas_frenagem_e_proxima() -> void:
	var d := dados_fixture()
	var pista: Pista = d.pista("oval")
	var c := Carro.new(d.carro("forte"))
	c.adicionar_pneu(d.pneu("seco"))
	var a := c.atributos_efetivos("seco")
	var lista := Tatica.curvas(pista, a, d.simulacao(), ["Norte"])
	igual(lista.size(), 2, "duas curvas no oval")
	igual(lista[0]["nome"], "Norte", "nome de curvas.json")
	igual(lista[1]["nome"], "Curva 2", "sem nome: número")
	perto(lista[0]["inicio"], 500.0, 0.01, "curva 1 começa no fim da reta")
	verificar(lista[0]["frenagem"] > 0.0 and lista[0]["frenagem"] < 500.0, "frenagem na reta antes da curva")
	perto(lista[0]["v_kmh"], sqrt(float(a["aderencia"]) * Simulacao.G * 100.0) * 3.6, 1.0, "velocidade de curva = limite do raio")
	var p := Tatica.proxima(lista, 0.0, pista.comprimento)
	igual(p["estado"], "frear", "na reta: frear adiante")
	perto(p["distancia"], lista[0]["frenagem"], 0.01, "distância até a frenagem")
	igual(Tatica.proxima(lista, 600.0, pista.comprimento)["estado"], "na_curva", "dentro da curva")
	igual(Tatica.proxima(lista, lista[0]["frenagem"] + 1.0, pista.comprimento)["estado"], "freando", "entre frenagem e curva")
	d.free()


## Decisão 90: a resistência resolvida aos poucos (entre quadros) dá o mesmo
## resultado, bit a bit, que de uma vez.
func test_aos_poucos_igual_a_de_uma_vez() -> void:
	var d := dados_fixture()
	var ps := [_participante(d, "a", "forte", "erratico"), _participante(d, "b", "fraco", "timido"),
			_participante(d, "c", "forte", "perfeito")]
	for com_amostras in [true, false]:
		var inteira := Simulacao.correr(d.pista("oval"), ps, 30, d.simulacao(), 99, com_amostras)
		var a := Simulacao.iniciar(d.pista("oval"), ps, 30, d.simulacao(), 99, com_amostras)
		var fatias := 0
		while not a.avancar(0.0):  # a menor fatia possível
			fatias += 1
			verificar(a.resultado().is_empty(), "sem resultado antes do fim")
		verificar(fatias > 10, "orçamento zero devolve antes do fim (%d fatias)" % fatias)
		verificar(a.pronto() and a.avancar(0.0), "terminada continua terminada")
		igual(a.resultado(), inteira, "mesmo resultado (amostras: %s)" % com_amostras)
	d.free()


func test_fatia_respeita_o_orcamento() -> void:
	var d := dados_fixture()
	var ps := [_participante(d, "a", "forte", "erratico"), _participante(d, "b", "fraco", "erratico")]
	var a := Simulacao.iniciar(d.pista("oval"), ps, 60, d.simulacao(), 5)
	var pior := 0
	var fatias := 0
	while true:
		var t0 := Time.get_ticks_usec()
		var pronto := a.avancar(2.0)
		pior = maxi(pior, Time.get_ticks_usec() - t0)
		fatias += 1
		if pronto:
			break
	verificar(fatias > 1, "corrida longa em mais de uma fatia")
	# Folga para um envelope ou alguns passos além do prazo (e máquina lenta).
	verificar(pior < 2000 + 15000, "fatia de 2 ms passou de 17 ms (%d us)" % pior)
	d.free()


## Decisão 130 (largada): a ordem "livre" deixa passar fora das zonas de
## ultrapassagem enquanto vale (a largada sai em fila); sem ela, ninguém passa.
func test_ordem_livre_passa_fora_da_zona() -> void:
	var d := dados_fixture()
	var a := _participante(d, "a", "fraco", "perfeito")
	var b := _participante(d, "b", "fraco", "perfeito")
	for livre in [false, true]:
		var b2: Dictionary = b.duplicate(true)
		b2["piloto"] = b["piloto"].duplicate()
		b2["piloto"]["ordens"] = [{"de": 0.0, "ate": 5.0, "acel": 1.3, "agressividade": 1.0, "livre": livre}]
		var r := _correr(d, "sem_ultrapassagem", [a, b2], 2)
		igual(r["classificacao"], ["b", "a"] if livre else ["a", "b"], "livre=%s" % livre)
	d.free()


## Defesa (Pilotagem): enquanto a porta fechada do carro da frente vale, o de
## trás não passa, nem com a ordem livre.
func test_porta_fechada_segura_o_de_tras() -> void:
	var d := dados_fixture()
	var a := _participante(d, "a", "fraco", "perfeito")
	var b := _participante(d, "b", "fraco", "perfeito")
	b["piloto"] = b["piloto"].duplicate()
	b["piloto"]["ordens"] = [{"de": 0.0, "ate": 5.0, "acel": 1.3, "agressividade": 1.0, "livre": true}]
	for defende in [false, true]:
		var a2: Dictionary = a.duplicate(true)
		a2["piloto"] = a["piloto"].duplicate()
		a2["piloto"]["ordens"] = [{"de": 0.0, "ate": 6.0, "defesa": true}] if defende else []
		var r := _correr(d, "sem_ultrapassagem", [a2, b], 2)
		igual(r["classificacao"], ["a", "b"] if defende else ["b", "a"], "defesa=%s" % defende)
	var p := {"defesa": {"distancia_m": 20.0, "recarga_s": 45.0, "janela_s": 1.5, "dura_s": 3.0}}
	igual(Pilotagem.nota_deslize(1, 1, 0.5, p), Pilotagem.PORTA_FECHADA, "lado certo")
	igual(Pilotagem.nota_deslize(-1, 1, 0.5, p), Pilotagem.LADO_ERRADO, "lado errado")
	igual(Pilotagem.nota_deslize(1, 1, 2.0, p), "", "tarde demais")
	verificar(Pilotagem.pode_defender(10.0, 50.0, 0.0, p) and not Pilotagem.pode_defender(10.0, 30.0, 0.0, p),
			"recarga")
	verificar(not Pilotagem.pode_defender(30.0, 50.0, 0.0, p), "longe demais")
	igual(Pilotagem.lado_defesa(7, 12.3), Pilotagem.lado_defesa(7, 12.3), "o mesmo lado na mesma corrida")
	d.free()


## FORÇAR / POUPAR PNEUS (decisão do usuário 2026-10-22, "pneu que cansa"):
## forçar anda mais até o fim da volta e cansa nas seguintes; com o pneu
## guardado (poupou antes), não cansa.
func test_forcar_cansa_o_pneu_e_poupar_guarda() -> void:
	var p := {"forcar": {"minimo_voltas": 30, "voltas_cansado": 2,
			"ritmo": {"forcar": 1.02, "poupar": 0.98, "cansado": 0.97}}}
	verificar(Pilotagem.pode_forcar(30, p) and not Pilotagem.pode_forcar(29, p), "só nas provas longas")
	verificar(not Pilotagem.pode_forcar(99, {}), "sem os dados, não aparece")
	var cansa := Pilotagem.ordens_forcar(10.0, 70.0, 60.0, false, p)
	igual(cansa.size(), 2, "forçar sem pneu guardado cansa")
	perto(float(cansa[0]["ate"]), 70.0, 1e-6, "forçar até o fim da volta")
	perto(float(cansa[1]["de"]), 70.0, 1e-6, "cansado depois")
	perto(float(cansa[1]["ate"]), 190.0, 1e-6, "por duas voltas")
	igual(Pilotagem.ordens_forcar(10.0, 70.0, 60.0, true, p).size(), 1, "com o pneu guardado, não cansa")
	perto(float(Pilotagem.ordem_poupar(10.0, 70.0, p)["ritmo"]), 0.98, 1e-6, "poupar anda menos")
	# Decisão 131: o modo que fica valendo. POUPAR guarda um pneu (até
	# voltas_cansado); ATAQUE gasta um (sem nenhum, cansa); NORMAL não muda nada.
	var r := Pilotagem.ordens_modo(Pilotagem.POUPAR, 0.0, 60.0, 60.0, 2, p)
	igual([r[0].size(), r[1]], [1, 2], "poupar com o pneu cheio não passa de voltas_cansado")
	r = Pilotagem.ordens_modo(Pilotagem.ATAQUE, 0.0, 60.0, 60.0, 1, p)
	igual([r[0].size(), r[1]], [1, 0], "ataque com pneu guardado não cansa")
	r = Pilotagem.ordens_modo(Pilotagem.ATAQUE, 0.0, 60.0, 60.0, 0, p)
	igual([r[0].size(), r[1]], [2, 0], "ataque sem pneu guardado cansa")
	igual(Pilotagem.ordens_modo(Pilotagem.NORMAL, 0.0, 60.0, 60.0, 1, p), [[], 1], "normal não muda nada")
	# Decisão 131 C4: a volta limpa dá ritmo até o fim da volta seguinte; sem o
	# bloco nos dados, nada.
	igual(Pilotagem.ordem_sequencia(0.0, 60.0, p), {}, "sem sequencia nos dados: sem bônus")
	p["sequencia"] = {"ritmo": 1.002}
	var vl := Pilotagem.ordem_sequencia(5.0, 60.0, p)
	igual([vl["de"], vl["ate"], vl["origem"]], [5.0, 60.0, "sequencia"], "a volta seguinte inteira")
	perto(float(vl["ritmo"]), 1.002, 1e-9, "ritmo da sequência")


## Decisão 117: a ordem de um momento de decisão só mexe na corrida a partir de
## "de"; antes, as amostras são as mesmas; mais ritmo, menos tempo.
func test_ordem_so_vale_depois_de_comecar() -> void:
	var d := dados_fixture()
	var a := _participante(d, "a", "forte", "erratico")
	var b := _participante(d, "b", "forte", "erratico")
	var sem := _correr(d, "oval", [a, b], 4, 11)
	var b2: Dictionary = b.duplicate(true)
	b2["piloto"] = b["piloto"].duplicate()
	b2["piloto"]["ordens"] = [{"de": 20.0, "ate": 60.0, "ritmo": 1.05, "agressividade": 1.0}]
	var com := _correr(d, "oval", [a, b2], 4, 11)
	var iguais := true
	var depois_muda := false
	for k in mini(sem["amostras"].size(), com["amostras"].size()):
		var x: Dictionary = sem["amostras"][k]
		if float(x["t"]) < 20.0:
			iguais = iguais and x["s"] == com["amostras"][k]["s"]
		elif x["s"]["b"] != com["amostras"][k]["s"]["b"]:
			depois_muda = true
	verificar(iguais, "antes da ordem, a mesma corrida")
	verificar(depois_muda, "depois dela, o carro anda diferente")
	verificar(float(com["carros"]["b"]["tempo_total"]) < float(sem["carros"]["b"]["tempo_total"]), "mais ritmo, menos tempo")
	d.free()


## Chrome Racing Team: o vácuo do piloto (fração) faz o carro de trás andar
## mais colado no da frente; sem ele (0, o Chrome & Wreckage), nada muda.
func test_vacuo_opcional_do_piloto() -> void:
	var d := dados_fixture()
	var a := _participante(d, "a", "forte", "erratico")
	var b := _participante(d, "b", "forte", "erratico")
	var sem := _correr(d, "oval", [a, b], 4, 11)
	var b0: Dictionary = b.duplicate(true)
	b0["piloto"]["vacuo"] = 0.0
	igual(_correr(d, "oval", [a, b0], 4, 11)["amostras"], sem["amostras"], "vácuo 0: a mesma corrida")
	var b2: Dictionary = b.duplicate(true)
	b2["piloto"]["vacuo"] = 0.05
	var com := _correr(d, "oval", [a, b2], 4, 11)
	verificar(float(com["carros"]["b"]["tempo_total"]) < float(sem["carros"]["b"]["tempo_total"]), "com vácuo, menos tempo")
	d.free()


## Pilotagem por toques (decisão 127): a ordem dada no meio da corrida que
## anda junto com a tela, numa cópia, dá o mesmo resultado que a corrida
## refeita do zero com a ordem desde o começo.
func test_ordem_no_meio_igual_a_refazer_do_zero() -> void:
	var d := dados_fixture()
	var a := _participante(d, "a", "forte", "erratico")
	var b := _participante(d, "b", "forte", "erratico")
	var ordens := [{"de": 20.0, "ate": 30.0, "ritmo": 1.04, "acel": 1.1},
			{"de": 25.0, "ate": 40.0, "ritmo": 0.97, "agressividade": 1.0}]
	var b2: Dictionary = b.duplicate(true)
	b2["piloto"] = b["piloto"].duplicate()
	b2["piloto"]["ordens"] = ordens
	var do_zero := _correr(d, "oval", [a, b2], 4, 11)
	var vivo := Simulacao.iniciar(d.pista("oval"), [a, b], 4, d.simulacao(), 11)
	verificar(vivo.avancar_ate(20.0) and not vivo.pronto(), "para no instante pedido")
	var dada: Dictionary = vivo.ordenar("b", ordens[0])
	perto(float(dada["de"]), 20.0, 0.051, "a ordem vale a partir de agora")
	var copia := vivo.clonar()
	copia.avancar_ate(25.0)
	copia.ordenar("b", ordens[1])
	copia.avancar(INF)
	vivo.avancar(INF)
	var r := copia.resultado()
	igual(r["classificacao"], do_zero["classificacao"], "mesma classificação")
	perto(float(r["carros"]["b"]["tempo_total"]), float(do_zero["carros"]["b"]["tempo_total"]), 1e-9, "mesmo tempo")
	igual(r["amostras"].size(), do_zero["amostras"].size(), "mesmas amostras")
	igual(r["amostras"].back()["s"], do_zero["amostras"].back()["s"], "mesma chegada")
	# A original termina sozinha (a cópia não mexe nela).
	verificar(vivo.pronto(), "a original segue depois da cópia")
	d.free()


## Ordens sobrepostas somam: duas de ritmo 1.03 valem como uma de 1.03².
func test_ordens_sobrepostas_somam() -> void:
	var d := dados_fixture()
	var b := _participante(d, "b", "forte", "perfeito")
	var duas: Dictionary = b.duplicate(true)
	duas["piloto"] = b["piloto"].duplicate()
	duas["piloto"]["ordens"] = [{"de": 5.0, "ate": 50.0, "ritmo": 1.03}, {"de": 5.0, "ate": 50.0, "ritmo": 1.03}]
	var uma: Dictionary = b.duplicate(true)
	uma["piloto"] = b["piloto"].duplicate()
	uma["piloto"]["ordens"] = [{"de": 5.0, "ate": 50.0, "ritmo": 1.03 * 1.03}]
	perto(float(_correr(d, "oval", [duas], 3, 5)["carros"]["b"]["tempo_total"]),
			float(_correr(d, "oval", [uma], 3, 5)["carros"]["b"]["tempo_total"]), 1e-6, "efeito somado")
	d.free()


## Momentos de decisão: a escolha "vence" quando muda o duelo no fim da ordem,
## e o instante mostrado é o da ultrapassagem (ataque).
func test_momento_avaliar_duelo() -> void:
	var base := {"duracao": 60.0, "amostras": [
		{"t": 0.0, "s": {"jogador": 0.0, "r": 10.0}},
		{"t": 60.0, "s": {"jogador": 600.0, "r": 610.0}}]}
	var passa := {"duracao": 60.0, "amostras": [
		{"t": 0.0, "s": {"jogador": 0.0, "r": 10.0}},
		{"t": 10.0, "s": {"jogador": 100.0, "r": 110.0}},
		{"t": 20.0, "s": {"jogador": 220.0, "r": 210.0}},
		{"t": 60.0, "s": {"jogador": 620.0, "r": 610.0}}]}
	var m := {"tipo": MomentosCorrida.ATAQUE, "rival": "r", "distancia": 10.0}
	var ordens := {"atacar": {"de": 10.0, "ate": 20.0}, "esperar": {"de": 30.0, "ate": 40.0}}
	var av := MomentosCorrida.avaliar(base, m, ordens, {"atacar": passa, "esperar": base})
	verificar(av["atacar"]["vence"], "atacar passou")
	verificar(not av["esperar"]["vence"], "esperar não mudou nada")
	perto(float(av["atacar"]["t"]), 15.0, 0.1, "o instante da ultrapassagem")
	verificar(MomentosCorrida.importa(av), "o momento importa")
	verificar(not MomentosCorrida.importa(MomentosCorrida.avaliar(base, m, ordens, {"atacar": base, "esperar": base})),
			"sem mudança, o momento não aparece")


## Rádio da Mara: com dica_acerto 1 aponta sempre a escolha que vence; com 0,
## a outra; o sorteio é fixo pela semente e pelo instante.
func test_momento_dica_do_radio() -> void:
	var av := {"atacar": {"vence": false}, "esperar": {"vence": true}}
	igual(MomentosCorrida.dica(av, {"dica_acerto": 1.0}, 7, 30.0), "esperar", "acerta sempre")
	igual(MomentosCorrida.dica(av, {"dica_acerto": 0.0}, 7, 30.0), "atacar", "erra sempre")
	var meio := {"dica_acerto": 0.5}
	igual(MomentosCorrida.dica(av, meio, 7, 30.0), MomentosCorrida.dica(av, meio, 7, 30.0), "mesmo sorteio")


## Oval inclinado (decisão 130, fase D): na curva inclinada o limite é o da
## física da pista inclinada, v² = g r (mu + tg) / (1 - mu tg); plana, sqrt(mu g r).
func test_curva_inclinada_deixa_passar_mais_rapido() -> void:
	var raios := PackedFloat64Array([200.0, 200.0])
	var plana := Simulacao._envelope(raios, 1.0, 1.0, 1.0, INF, 1.0)
	var tg := tan(deg_to_rad(24.0))
	var bancos := PackedFloat64Array([tg, tg])
	var inclinada := Simulacao._envelope(raios, 1.0, 1.0, 1.0, INF, 1.0, bancos)
	perto(plana[0], sqrt(Simulacao.G * 200.0), 1e-6, "plana")
	perto(inclinada[0], sqrt(Simulacao.G * 200.0 * (1.0 + tg) / (1.0 - tg)), 1e-6, "inclinada")
	var d := dados_fixture()
	verificar(Simulacao.bancos(d.pista("oval"), 10, 1.0).is_empty(), "pista plana sem tabela de inclinação")
	d.free()
