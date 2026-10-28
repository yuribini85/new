extends "res://tests/base_teste.gd"
## The Fastfather (docs/idle/plano.md): regras do jogo idle.


func _cfg() -> Dictionary:
	return {"dinheiro_inicial": 0, "renda_base": 2.0, "offline_max_h": 1.0, "grid": 10, "premio_p1": 100,
		"expoente_custo_liga": 1.0, "carro_do_jogador": 1.0,
		"piloto": {"ritmo": 1.0, "consistencia": 1.0, "agressividade": 0.1},
		"rivais": {"ritmo": 1.0, "consistencia": 1.0, "agressividade": 0.3},
		"melhorias": [
			{"id": "motor", "efeito": "potencia", "do_carro": true, "por_nivel": 0.1, "base": 10, "crescimento": 2.0, "max": 3},
			{"id": "patrocinio", "efeito": "renda", "por_nivel": 1.0, "base": 5, "crescimento": 1.5, "max": 10}],
		"ligas": [{"nome": "A", "pista": "oval", "voltas": 1, "potencia": 100, "multiplicador": 1},
			{"nome": "B", "pista": "oval", "voltas": 1, "potencia": 150, "multiplicador": 10}]}


func test_custo_compra_e_maximo() -> void:
	var e := IdleEstado.new(_cfg())
	igual(e.custo("motor"), 10.0, "nível 0: base")
	verificar(not e.comprar("motor"), "sem dinheiro, não compra")
	e.dinheiro = 100.0
	verificar(e.comprar("motor") and e.comprar("motor"), "compra")
	igual([e.nivel("motor"), e.dinheiro, e.custo("motor")], [2, 70.0, 40.0], "custo dobra a cada nível")
	e.comprar("motor")
	verificar(e.no_maximo("motor") and not e.comprar("motor"), "no máximo não compra mais")


func test_premio_renda_e_offline() -> void:
	var e := IdleEstado.new(_cfg())
	igual([e.premio(1), e.premio(10)], [100.0, 10.0], "P1 inteiro, P10 um décimo")
	igual(e.renda_s(), 2.0, "renda base")
	e.dinheiro = 5.0
	e.comprar("patrocinio")
	igual(e.renda_s(), 3.0, "patrocínio soma")
	e.salvo_em = 1000.0
	igual(e.ganho_offline(1000.0 + 600.0), 1800.0, "10 min fechado")
	igual(e.ganho_offline(1000.0 + 99999.0), 3.0 * 3600.0, "até offline_max_h")
	igual(e.ganho_offline(500.0), 0.0, "relógio para trás não rende")


func test_vitoria_libera_liga_e_carro_novo_zera_o_carro() -> void:
	var e := IdleEstado.new(_cfg())
	e.dinheiro = 1000.0
	e.comprar("motor")
	e.comprar("patrocinio")
	verificar(not e.pode_subir(), "sem vitória, não sobe")
	e.concluir(3)
	verificar(not e.pode_subir(), "3º não sobe")
	e.concluir(1)
	verificar(e.subir_liga(), "venceu: sobe")
	igual([e.liga, e.nivel("motor"), e.nivel("patrocinio")], [1, 0, 1], "carro novo: motor zera; patrocínio fica")
	igual(e.premio(1), 1000.0, "prêmio no tamanho da liga")
	igual(e.custo("motor"), 100.0, "custo no tamanho da liga")
	e.concluir(1)
	verificar(not e.subir_liga(), "última liga")


func test_save_ida_e_volta() -> void:
	var e := IdleEstado.new(_cfg())
	e.dinheiro = 123.0
	e.niveis["motor"] = 2
	e.liga = 1
	e.venceu = true
	var f := IdleEstado.new(_cfg())
	f.de_save(JSON.parse_string(JSON.stringify(e.para_save())))
	igual(f.para_save(), e.para_save(), "volta igual")


func test_corrida_com_a_frota_real() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var e := IdleEstado.new()
	var ps := e.participantes(d)
	igual(ps.size(), int(e.cfg["grid"]), "grid cheio")
	igual(ps[-1]["id"], "jogador", "você larga em último")
	var r := e.correr(d, 1, false)
	verificar(IdleEstado.posicao(r) >= 1 and IdleEstado.posicao(r) <= ps.size(), "posição")
	# Melhorar o carro e o piloto não piora a corrida (mesma semente).
	var forte := e.correr(d, 1, false, {"motor": 20, "pneus": 15, "ultrapassagem": 15, "vacuo": 10})
	verificar(IdleEstado.posicao(forte) <= IdleEstado.posicao(r), "melhorias ajudam")
	d.free()


func test_rivais_saem_do_carro_da_equipe() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var cfg := _cfg()
	cfg["rivais"]["espalhar"] = 0.2
	cfg["rivais"]["aderencia_por_forca"] = 0.5
	cfg["ligas"][0]["forca_rivais"] = 1.5  # forca da liga vale sobre a da pista
	var e := IdleEstado.new(cfg)
	verificar(is_equal_approx(e.fator_rival(0), 1.8) and is_equal_approx(e.fator_rival(8), 1.2),
			"do mais forte ao mais fraco, vezes forca_rivais")
	var base: Dictionary = e.carro_base(d)
	var a: Dictionary = e.participantes(d)[0]["atributos"]
	var b := IdleEstado._atributos(d, base)
	verificar(is_equal_approx(a["potencia"], b["potencia"] * 1.8) and is_equal_approx(a["aderencia"], b["aderencia"] * 1.4)
			and a["peso"] == b["peso"], "ficha do rival = carro da equipe escalado")
	var ps := e.participantes(d)
	verificar(ps[0]["carro"] != base["id"], "o modelo na tela é outro carro da frota")
	d.free()


func _cfg_mods() -> Dictionary:
	var c := _cfg()
	c.erase("ligas")
	c["modalidades"] = [
		{"id": "a", "nome": "A", "ligas": [{"nome": "A1", "pista": "oval", "voltas": 1, "potencia": 100, "multiplicador": 1},
			{"nome": "A2", "pista": "oval", "voltas": 1, "potencia": 150, "multiplicador": 10}]},
		{"id": "b", "nome": "B", "libera": {"modalidade": "a", "liga": 1},
			"ligas": [{"nome": "B1", "pista": "oval", "voltas": 1, "potencia": 100, "multiplicador": 4}]}]
	c["pilotos"] = {"base": {"ritmo": 1.0, "consistencia": 0.9, "agressividade": 0.5}, "ritmo_por_nivel": 0.01,
		"nivel_max": 3, "contrato_gratis_h": 4, "contratos_video_dia": 2,
		"perfis": {"agressivo": {"agressividade": 0.1, "consistencia": -0.05}}}
	return c


func test_modalidades_liberam_e_rendem_juntas() -> void:
	var e := IdleEstado.new(_cfg_mods())
	igual(e.liberadas(), ["a"], "só a primeira")
	verificar(not e.trocar_modalidade("b"), "B fechada")
	e.dinheiro = 1000.0
	e.comprar("patrocinio")
	e.concluir(1)
	e.subir_liga()
	igual(e.liberadas(), ["a", "b"], "A na liga 2 abre B")
	igual(e.renda_s(), 30.0 + 8.0, "A: (2 + 1) × 10; B: 2 × 4")
	verificar(e.trocar_modalidade("b"), "troca")
	igual([e.liga, e.nivel("patrocinio"), e.custo("motor")], [0, 0, 40.0], "B tem liga e níveis próprios")


func test_contratos_e_fusao() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var e := IdleEstado.new(_cfg_mods())
	verificar(e.contrato_gratis_pronto(1000.0), "o primeiro é na hora")
	var p1 := e.usar_contrato_gratis(d, 1000.0)
	igual([p1["nivel"], e.piloto_escalado()["uid"]], [1, p1["uid"]], "nível 1 e já escalado")
	verificar(not e.contrato_gratis_pronto(1000.0 + 3600.0), "o próximo espera 4 h")
	verificar(e.contrato_gratis_pronto(1000.0 + 4 * 3600.0), "depois de 4 h")
	var p2 := e.usar_contrato_video(d, "2026-10-24", 7)
	e.usar_contrato_video(d, "2026-10-24", 8)
	igual(e.contratos_video_restantes("2026-10-24"), 0, "dois vídeos por dia")
	igual(e.contratos_video_restantes("2026-10-25"), 2, "no dia seguinte voltam")
	verificar(e.fundir(int(p1["uid"]), int(p2["uid"])), "dois do nível 1 fundem")
	igual([e.pilotos.size(), int(e.piloto(int(p1["uid"]))["nivel"])], [2, 2], "um sai, o outro sobe")
	verificar(not e.fundir(int(p1["uid"]), int(e.pilotos[1]["uid"])), "níveis diferentes não fundem")
	var a := e.atributos_piloto(d, e.piloto_escalado())
	verificar(is_equal_approx(float(a["ritmo"]), 1.01), "nível 2: +1% de ritmo")
	d.free()


func test_save_antigo_vira_a_primeira_modalidade() -> void:
	var e := IdleEstado.new(_cfg_mods())
	e.de_save({"dinheiro": 50.0, "liga": 1, "venceu": true, "niveis": {"motor": 2}, "corridas": 9})
	igual([e.modalidade, e.liga, e.venceu, e.nivel("motor"), e.corridas], ["a", 1, true, 2, 9], "migrou")
	verificar(e.liberada("b"), "e a segunda já abre")


func test_arena_com_a_simulacao_do_chrome_wreckage() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var e := IdleEstado.new()
	e.mods["arena"] = {"liga": 0, "venceu": false, "niveis": e.niveis.duplicate(), "corridas": 0}
	e.modalidade = "arena"
	verificar(e.e_arena(), "a modalidade arena")
	var r := e.correr(d, 3, false)
	igual(Array(r["classificacao"]).size(), int(e.cfg["grid"]), "dez carros na luta")
	verificar(IdleEstado.posicao(r) >= 1, "posição pela ordem de quem ficou de pé")
	d.free()


func test_metas_do_dia() -> void:
	var c := _cfg()
	c["meta_dia"] = {"por_dia": 2, "recompensa_min": 10, "tarefas": [
		{"id": "correr", "tipo": "corridas", "quantidade": 2, "texto": "Corra %d corridas"},
		{"id": "vencer", "tipo": "vitorias", "quantidade": 1, "texto": "Vença %d corridas"}]}
	var e := IdleEstado.new(c)
	var hoje := 1.8e9
	var est := e.metas_do_dia(hoje)
	igual(Array(est["tarefas"]).size(), 2, "duas metas sorteadas")
	e.registrar_meta("corridas", 1, hoje)
	verificar(not e.meta_pronta("correr", hoje) and e.coletar_meta("correr", hoje) == 0.0, "incompleta não paga")
	e.registrar_meta("corridas", 1, hoje)
	igual(e.progresso_meta("correr", hoje), [2, 2], "progresso")
	igual(e.metas_prontas(hoje), 1, "uma pronta")
	var antes := e.dinheiro
	igual(e.coletar_meta("correr", hoje), e.renda_s() * 600.0, "paga 10 min da renda")
	igual(e.dinheiro - antes, e.renda_s() * 600.0, "o dinheiro entra")
	igual(e.coletar_meta("correr", hoje), 0.0, "não paga duas vezes")
	var s := IdleEstado.new(c)
	s.de_save(JSON.parse_string(JSON.stringify(e.para_save())))
	igual([s.progresso_meta("correr", hoje), s.meta_pronta("correr", hoje)], [[2, 2], false], "save guarda as metas")
	igual(s.progresso_meta("correr", hoje + 86400.0), [0, 2], "dia novo zera")
	# As ações do jogo contam: a vitória conta corrida e vitória.
	e.concluir(1)
	igual(e.progresso_meta("vencer", hoje if MetaDia.dia(hoje) == MetaDia.dia(Time.get_unix_time_from_system()) else
			Time.get_unix_time_from_system())[0], 1, "vitória conta")


func test_avisos_com_o_app_fechado() -> void:
	var e := IdleEstado.new(_cfg())
	e.contrato_em = 1000.0 + 3600.0
	var avisos := IdleAvisos.planejar(e, 1000.0)
	igual(avisos.map(func(a): return [a["id"], a["em_s"]]), [["teto", 3600.0], ["contrato", 3600.0]],
			"teto da renda e contrato grátis")
	e.contrato_em = 0.0
	igual(IdleAvisos.planejar(e, 1000.0).map(func(a): return a["id"]), ["teto"], "contrato já pronto: sem aviso")


func test_video_sem_anuncio_paga_igual() -> void:
	var a := IdleAnuncios.new()
	var pago := [false]
	a.premiado(func(): pago[0] = true)
	verificar(pago[0], "sem vídeo para mostrar, a recompensa sai")
	a.free()


func test_escada_de_desbloqueios() -> void:
	var c := _cfg_mods()
	c["desbloqueio_inicial"] = ["melhoria:motor"]
	c["desbloqueios"] = [
		{"id": "inicio", "quando": {}, "libera": []},
		{"id": "pneus", "quando": {"corridas": 2}, "libera": ["melhoria:pneus"]},
		{"id": "tv", "quando": {"corridas": 3}, "custo": 50, "libera": ["camera_tv"]},
		{"id": "vit", "quando": {"vitoria": true}, "libera": ["aba:pilotos"]}]
	var e := IdleEstado.new(c)
	verificar(e.tem("melhoria:motor") and not e.tem("melhoria:pneus") and not e.tem("camera_tv"), "começa só com o motor")
	igual(String(e.proxima_conversa().get("id", "")), "inicio", "primeira conversa")
	e.oferecer("inicio")
	verificar(e.proxima_conversa().is_empty(), "pneus só com 2 corridas")
	e.corridas = 3
	igual(String(e.proxima_conversa()["id"]), "pneus", "na ordem da lista")
	e.oferecer("pneus")
	verificar(e.tem("melhoria:pneus"), "de graça abre na conversa")
	e.oferecer("tv")
	verificar(not e.tem("camera_tv") and e.ofertas_abertas().size() == 1, "com custo vira oferta")
	e.dinheiro = 10.0
	verificar(not e.comprar_desbloqueio("tv"), "sem dinheiro não compra")
	e.dinheiro = 60.0
	verificar(e.comprar_desbloqueio("tv") and e.tem("camera_tv") and e.dinheiro == 10.0, "compra a oferta")
	verificar(e.proxima_conversa().is_empty(), "vitória ainda não veio")
	e.venceu = true
	igual(String(e.proxima_conversa()["id"]), "vit", "primeira vitória")
	var s := IdleEstado.new(c)
	s.de_save(JSON.parse_string(JSON.stringify(e.para_save())))
	verificar(s.tem("camera_tv") and s.tem("melhoria:pneus") and "inicio" in s.oferecidos, "save guarda a escada")
	# Save de antes da escada: o que a equipe já alcançou vem aberto.
	var velho := e.para_save()
	velho.erase("desbloqueados")
	velho.erase("oferecidos")
	var m := IdleEstado.new(c)
	m.de_save(JSON.parse_string(JSON.stringify(velho)))
	verificar(m.tem("camera_tv") and m.tem("aba:pilotos"), "save antigo abre o alcançado")
	verificar(IdleEstado.new(_cfg()).tem("cameras"), "sem escada na configuração, tudo aberto")


## A passagem sem sorteio (Simulacao: piloto.regular): a mesma equipe chega no
## mesmo lugar em qualquer corrida, e a melhor chegada da liga fica guardada.
func test_mesma_equipe_mesma_chegada_e_melhor_posicao() -> void:
	var dados: Node = Engine.get_main_loop().root.get_node("Dados")
	var e := IdleEstado.new()
	e.usar_contrato_gratis(dados, 0.0)
	e.niveis["ultrapassagem"] = 4
	var pos := IdleEstado.posicao(e.correr(dados, 11, false))
	for s in [22, 33, 44]:
		igual(IdleEstado.posicao(e.correr(dados, s, false)), pos, "mesma chegada com a semente %d" % s)
	igual(e.melhor_posicao(), 0, "sem corrida, sem melhor")
	e.concluir(6)
	e.concluir(8)
	igual(e.melhor_posicao(), 6, "a melhor chegada fica")
	e.concluir(1)
	e.subir_liga()
	igual(e.melhor_posicao(), 0, "liga nova zera a melhor")


## A renda por segundo só corre depois que o patrocínio entra na escada.
func test_renda_so_com_o_patrocinio() -> void:
	var c := _cfg_mods()
	c["renda_base"] = 5.0
	c["desbloqueio_inicial"] = ["melhoria:motor"]
	c["desbloqueios"] = [{"id": "patrocinio", "quando": {}, "libera": ["renda"]}]
	var e := IdleEstado.new(c)
	igual(e.renda_s(), 0.0, "antes do patrocínio, nada por segundo")
	e.oferecer("patrocinio")
	verificar(e.renda_s() > 0.0, "com o patrocínio, a renda base corre")


## Compra em quantidade (+10 e MÁX. do complexo): só compra se pagar tudo, e o
## MÁX. leva o que o dinheiro paga sem passar do máximo.
func test_compra_em_quantidade() -> void:
	var c := _cfg()
	c["melhorias"][0]["max"] = 40
	c["melhorias"][0]["crescimento"] = 1.15
	var e := IdleEstado.new(c)
	e.dinheiro = 0.0
	var dez := e.custo_varios("motor", 10)
	verificar(dez > e.custo("motor") * 10.0, "dez níveis custam mais que dez vezes o primeiro")
	igual(e.comprar_varios("motor", 10), 0, "sem dinheiro não compra")
	e.dinheiro = dez
	igual(e.comprar_varios("motor", 10), 10, "compra os dez")
	igual(e.nivel("motor"), 10, "nível 10")
	verificar(absf(e.dinheiro) < 0.001, "gastou exatamente o custo dos dez")
	e.dinheiro = 1.0e12
	var n := e.niveis_pagaveis("motor")
	igual(n, int(e.melhoria("motor")["max"]) - 10, "MÁX. para no máximo")
	verificar(not is_finite(e.custo_varios("motor", n + 1)), "passar do máximo não tem preço")


## Carro de época: carroceria pintada e quatro rodas no eixo, com o centro na
## altura do raio (chão em y = 0), como os carros gerados.
func test_carro_de_epoca() -> void:
	for modelo in CarroEpoca.MODELOS:
		var carro := CarroEpoca.construir(modelo, Color.DARK_RED)
		verificar(carro != null, "%s existe" % modelo)
		var corpo := carro.get_node("Carroceria") as MeshInstance3D
		verificar(int(corpo.mesh.get_meta("pintura", -1)) >= 0, "%s: a lataria tem a superfície pintada" % modelo)
		var rodas := carro.get_children().filter(func(n): return n.has_meta("lado"))
		igual(rodas.size(), 4, "%s: quatro rodas" % modelo)
		for r in rodas:
			perto((r as Node3D).position.y, float(r.get_meta("raio")), 0.001, "%s: roda apoiada no chão" % modelo)
		perto(corpo.get_aabb().position.y, 0.0, 0.5, "%s: carroceria perto do chão" % modelo)
		var caixa := corpo.get_aabb()
		verificar(caixa.size.z > 3.5 and caixa.size.z < 5.8 and caixa.size.y > 1.2 and caixa.size.y < 1.9,
				"%s: tamanho de carro de verdade" % modelo)
		carro.free()
	verificar(CarroEpoca.construir("nao_existe", Color.RED) == null, "modelo desconhecido não monta")


## Garagem: um carro por divisão; sem ele a divisão não corre; comprado uma
## vez, fica no save; save antigo de quem já correu vem com o carro.
func test_garagem_um_carro_por_divisao() -> void:
	var c := _cfg_mods()
	c["garagem"] = [{"id": "cupe", "nome": "Cupê", "ano": 1928, "modelo": "cupe_1928", "modalidade": "a", "preco": 525}]
	var e := IdleEstado.new(c)
	e.dinheiro = 600.0
	verificar(not e.pode_correr(), "divisão com carro na garagem pede o carro")
	verificar(e.carro_da_modalidade("b").is_empty(), "divisão sem carro na lista não pede nada")
	verificar(e.comprar_carro("cupe"), "compra com dinheiro")
	perto(e.dinheiro, 75.0, 0.001, "paga o preço")
	verificar(e.pode_correr() and not e.comprar_carro("cupe"), "comprado uma vez")
	var e2 := IdleEstado.new(c)
	e2.de_save(JSON.parse_string(JSON.stringify(e.para_save())))
	verificar(e2.tem_carro("cupe"), "o carro fica no save")
	var antigo := e.para_save()
	antigo.erase("garagem")
	antigo["corridas"] = 3
	antigo["mods"]["a"]["corridas"] = 3
	var e3 := IdleEstado.new(c)
	e3.de_save(antigo)
	verificar(e3.tem_carro("cupe"), "save de antes da garagem: quem já correu tem o carro")
	var pobre := IdleEstado.new(c)
	pobre.dinheiro = 100.0
	verificar(not pobre.comprar_carro("cupe"), "sem dinheiro não compra")


## Ferro-velho (The Fastfather, SEQUÊNCIA 2): o primeiro carro sai por 1/3 do
## preço e fica velho até a primeira vitória; divisão fechada vira silhueta;
## a cena da vitória passa na frente da fila de conversas; os dados reais
## dão o mesmo troco de antes (US$ 100).
func test_ferro_velho() -> void:
	var c := _cfg_mods()
	c["garagem"] = [{"id": "cupe", "nome": "Cupê", "ano": 1928, "modelo": "cupe_1928", "modalidade": "a", "preco": 525,
			"ferro_velho": {"preco": 175}},
		{"id": "cupe2", "nome": "Cupê 2", "ano": 1940, "modelo": "cupe_1940", "modalidade": "b", "preco": 12000}]
	var e := IdleEstado.new(c)
	e.dinheiro = 275.0
	perto(e.preco_carro(e.carro_garagem("cupe")), 175.0, 0.001, "preço de sucata")
	verificar(not e.carro_bloqueado(e.carro_garagem("cupe")), "a divisão de largada está aberta")
	verificar(e.carro_bloqueado(e.carro_garagem("cupe2")), "divisão fechada: silhueta")
	verificar(e.comprar_carro("cupe") and e.ferro_velho, "comprado, sai do ferro-velho")
	perto(e.dinheiro, 100.0, 0.001, "sobra o troco")
	var pe := GaragemIdle.pintura(e, e.carro_garagem("cupe"))
	verificar(float(pe[1].get("ferrugem", 0.0)) > 0.0 and int(pe[1].get("numero", -1)) == PinturaEpoca.NUMERO_JOGADOR,
			"enferrujado, com o 13 à mão")
	var e2 := IdleEstado.new(c)
	e2.de_save(JSON.parse_string(JSON.stringify(e.para_save())))
	verificar(e2.ferro_velho, "o ferro-velho fica no save")
	e.ferro_velho = false
	verificar(float(GaragemIdle.pintura(e, e.carro_garagem("cupe"))[1].get("ferrugem", 0.0)) == 0.0, "pintado: sem ferrugem")
	var real := IdleEstado.new()
	var primeiro: Dictionary = real.carros_garagem()[0]
	perto(real.dinheiro - real.preco_carro(primeiro), 100.0, 0.001, "jogo de verdade: US$ 100 de troco")
	perto(real.preco_carro(primeiro) * 3.0, float(primeiro["preco"]), 0.001, "1/3 do preço")
	# A cena da vitória passa na frente da fila.
	c["desbloqueios"] = [{"id": "x", "quando": {"corridas": 9}, "quem": {}}, {"id": "v", "avulsa": true,
			"quando": {"vitoria": true}, "cena": "vitoria", "quem": {}}]
	var e3 := IdleEstado.new(c)
	e3._m()["venceu"] = true
	igual(String(e3.proxima_conversa().get("id", "")), "v", "avulsa não espera a fila")
	verificar(not CenaQuadrinho.carregar("loja").is_empty(), "as cenas estão em cenas.json")


## Rinha das Famílias (pedido do usuário, 2026-10-27): roda ao lado da corrida,
## nunca no lugar dela; abre com a 2ª liga dos Bairros; quem corre é o
## sobrinho (os rapazes não mexem na corrida); a luta paga sem contar corrida
## e devolve a modalidade como estava.
func test_rinha_em_paralelo() -> void:
	var dados: Node = Engine.get_main_loop().root.get_node("Dados")
	var e := IdleEstado.new()
	verificar(not e.rinha_aberta(), "fechada no começo")
	e.liga = 1
	verificar(e.rinha_aberta(), "abre na 2ª liga dos Bairros")
	verificar(not e.trocar_modalidade(e.id_rinha()), "a corrida não vai para a Rinha")
	var antes := IdleEstado.posicao(e.correr(dados, 5, false))
	e.usar_contrato_gratis(dados, 0.0)
	e.pilotos[0]["nivel"] = 6
	igual(IdleEstado.posicao(e.correr(dados, 5, false)), antes, "rapaz não muda a corrida do sobrinho")
	var mod := e.modalidade
	var corridas := e.corridas
	var r := e.lutar_rinha(dados, 3, false)
	verificar(not r.is_empty() and r.has("classificacao"), "a luta sai inteira")
	var dinheiro := e.dinheiro
	var p := e.pagar_rinha(IdleEstado.posicao(r))
	perto(e.dinheiro, dinheiro + p, 0.001, "o prêmio entra")
	verificar(p > 0.0, "paga pela posição")
	igual(e.modalidade, mod, "a corrida continua onde estava")
	igual(e.corridas, corridas, "luta não conta como corrida")
	igual(e.liga_rinha(), 1, "a liga acompanha a corrida mais alta")


## Pinturas de época: só cor única, filete lateral, capô ou teto; a cor do
## rival sai da paleta da família e nunca é a do jogador; número de 1 a 99;
## mesma equipe, mesma cor; o jogador leva o 13.
func test_pinturas_de_epoca() -> void:
	igual(PinturaEpoca.familia("compactos", 0), "bairro", "1ª divisão: garagem de bairro")
	igual(PinturaEpoca.familia("terra", 2), "stock", "Stock Cars")
	igual(PinturaEpoca.familia("gt", 6), "familias", "ligas de cima: Copa das Famílias")
	igual(PinturaEpoca.familia("arena", 0), "", "arena fora")
	for fam in PinturaEpoca.FAMILIAS:
		var eu: Array = PinturaEpoca.do_jogador(fam)
		igual(int(eu[1]["numero"]), 7, "%s: o sobrinho é o 7" % fam)
		var paleta: Array = PinturaEpoca.FAMILIAS[fam]["cores"]
		for k in 30:
			var r: Array = PinturaEpoca.do_rival(fam, "equipe%d" % k, "s%d" % k)
			var f: Dictionary = r[1]
			verificar(String(f.get("padrao", "")) in PinturaEpoca.PADROES_EPOCA, "%s: padrão de época" % fam)
			verificar(paleta.any(func(c): return Color(String(c)).is_equal_approx(r[0])), "%s: cor da paleta" % fam)
			verificar(not PinturaEpoca._perto(r[0], eu[0]), "%s: rival não usa a cor do jogador" % fam)
			if f.has("numero"):
				verificar(int(f["numero"]) >= 1 and int(f["numero"]) <= 99, "%s: número de 1 a 99" % fam)
		var a: Array = PinturaEpoca.do_rival(fam, "mesma", "corrida1")
		var b: Array = PinturaEpoca.do_rival(fam, "mesma", "corrida2")
		verificar((a[0] as Color).is_equal_approx(b[0]), "%s: mesma equipe, mesma cor" % fam)


## Marcos por melhoria (análise de engajamento, 2026-10-28): o efeito das
## melhorias listadas dobra a cada nível-marco; as outras não mudam.
func test_marcos_dobram_a_renda() -> void:
	var c := _cfg()
	c["marcos"] = {"niveis": [10, 25], "multiplicador": 2.0, "efeitos": ["renda"]}
	var e := IdleEstado.new(c)
	var renda: Dictionary = {}
	var outra: Dictionary = {}
	for m in c["melhorias"]:
		if String(m["efeito"]) == "renda" and renda.is_empty():
			renda = m
		elif String(m["efeito"]) != "renda" and outra.is_empty():
			outra = m
	verificar(not renda.is_empty() and not outra.is_empty(), "a config de teste tem as duas")
	perto(e.multiplicador_marcos(renda, 9), 1.0, 0.001, "antes do marco: x1")
	perto(e.multiplicador_marcos(renda, 10), 2.0, 0.001, "no 10: x2")
	perto(e.multiplicador_marcos(renda, 30), 4.0, 0.001, "depois do 25: x4")
	perto(e.multiplicador_marcos(outra, 30), 1.0, 0.001, "fora da lista: sem multiplicar")
	igual(e.proximo_marco(12), Vector2i(10, 25), "entre o 10 e o 25")
	igual(e.proximo_marco(30).y, 0, "depois do último, não há próximo")


## Combustível adulterado: usos por dia, o bônus vale até a hora marcada e
## soma tempo se usado de novo.
func test_combustivel_por_dia() -> void:
	var c := _cfg()
	c["combustivel"] = {"usos_dia": 2, "potencia": 0.2, "duracao_s": 600}
	var e := IdleEstado.new(c)
	igual(e.combustivel_restantes("2026-01-01"), 2, "dois por dia")
	verificar(e.usar_combustivel(1000.0, "2026-01-01"), "primeiro uso")
	verificar(e.combustivel_ativo(1500.0) and not e.combustivel_ativo(1700.0), "vale 600 s")
	verificar(e.usar_combustivel(1100.0, "2026-01-01"), "segundo uso soma ao que resta")
	verificar(e.combustivel_ativo(2100.0), "1000 + 600 + 600")
	verificar(not e.usar_combustivel(1200.0, "2026-01-01"), "acabou o do dia")
	igual(e.combustivel_restantes("2026-01-02"), 2, "o dia seguinte volta a dois")
