extends "res://tests/base_teste.gd"
## Chrome Racing Team (docs/idle/plano.md): regras do jogo idle.


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
