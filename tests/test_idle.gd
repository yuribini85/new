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
