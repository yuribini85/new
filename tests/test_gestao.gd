extends "res://tests/base_teste.gd"
## Gestão da equipe (GestaoEquipe): patrocínio com renda por hora (também
## offline, com o teto de ausência), bônus por condição, desmanche em crédito
## de peças e as melhorias da sede. Fixtures sintéticas (equipe.json,
## patrocinadores.json): prêmio de referência da licença "b" = 10.

const JogadorScript := preload("res://autoload/jogador.gd")


func _novo(d: Node) -> Node:
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	EquipeJogador.criar(j)
	j.licencas = ["b"]
	return j


func test_ofertas_vem_da_licenca_do_jogador() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	verificar(GestaoEquipe.aberta(d, j), "gestão aberta com a equipe criada")
	var ids: Array = GestaoEquipe.ofertas(d, j).map(func(p): return p["id"])
	igual(ids.size(), 2, "ofertas: as do arquivo (2)")
	verificar(not "p_a1" in ids, "patrocinador de licença acima da do jogador não oferece")
	j.free()
	d.free()


func test_patrocinio_rende_por_hora_com_teto_e_acaba() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	var saldo0: int = j.economia.saldo
	igual(GestaoEquipe.assinar(d, j, "p_b1", 0.0), "", "assina")
	igual(GestaoEquipe.assinar(d, j, "p_b2", 0.0), "sem vaga para outro contrato", "uma vaga só")
	# 1 giro por hora (10 × 0,1); três horas com o app aberto (de hora em hora).
	var r := {"ganho": 0}
	for h in [1.0, 2.0, 3.0]:
		r = GestaoEquipe.acumular(d, j, h * 3600.0)
	igual(int(r["ganho"]), 1, "uma hora por vez")
	igual(j.economia.saldo, saldo0 + 3, "renda no caixa")
	# Ausência de 5 h com teto de 1 h (fixture: teto_offline_s 3600): só 1 h conta.
	r = GestaoEquipe.acumular(d, j, 8.0 * 3600.0)
	igual(int(r["ganho"]), 1, "ausência limitada ao teto")
	# O contrato dura 10 h: acaba e sai da lista.
	r = GestaoEquipe.acumular(d, j, 10.0 * 3600.0)
	igual(r["encerrados"], ["Patrocinador B1"], "contrato encerrado")
	igual(GestaoEquipe.contratos(j).size(), 0, "sem contratos depois do fim")
	j.free()
	d.free()


func test_bonus_so_quando_a_condicao_e_cumprida() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	GestaoEquipe.assinar(d, j, "p_b1", 0.0)  # pódio, bônus 5
	var ev: Dictionary = d.evento("licenciado")
	igual(GestaoEquipe.bonus_corrida(d, j, ev, 4, false).size(), 0, "4º não é pódio")
	var saldo0: int = j.economia.saldo
	var pagos := GestaoEquipe.bonus_corrida(d, j, ev, 2, false)
	igual(pagos.size(), 1, "pódio paga")
	igual(j.economia.saldo, saldo0 + 5, "bônus de 5 no caixa")
	j.free()
	d.free()


func test_sede_melhora_vagas_e_renda() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	j.economia.creditar(1000)
	igual(GestaoEquipe.preco_melhoria(d, j, "marketing"), 10, "nível 1: 10 × 1 × 1")
	igual(GestaoEquipe.comprar_melhoria(d, j, "marketing"), "", "compra marketing 1")
	igual(GestaoEquipe.preco_melhoria(d, j, "marketing"), 20, "nível 2 custa o dobro")
	igual(GestaoEquipe.comprar_melhoria(d, j, "escritorio"), "", "compra escritório")
	igual(GestaoEquipe.comprar_melhoria(d, j, "escritorio"), "nível máximo", "escritório só tem 1 nível")
	igual(GestaoEquipe.vagas(d, j), 2, "escritório abre a segunda vaga")
	igual(GestaoEquipe.renda_hora(d, j, GestaoEquipe.patrocinador(d, "p_b1")), 2, "marketing +50%: 1 → 1,5 → 2")
	j.free()
	d.free()


func test_desmanche_vira_pecas_que_pagam_a_blindagem() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	j.economia.creditar(5000)
	var a: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	var b: int = j.concessionaria.comprar_carro(d.carro("forte"))
	var carro: Carro = j.garagem.carro(b)
	carro.pecas_possuidas.append("turbo")  # comprada por 200
	# fator 0,5 × (revenda 900 × 0,5 + peças 200) = 325
	igual(GestaoEquipe.pecas_do_carro(d, j, carro), 325, "a carcaça e as peças compradas viram peças")
	igual(GestaoEquipe.desmontar(d, j, b), 325, "desmonta")
	verificar(j.garagem.carro(b) == null, "o carro sai da garagem")
	igual(j.economia.credito_pecas, 325, "peças no estoque")
	igual(GestaoEquipe.desmontar(d, j, a), -1, "o único carro não se desmonta")
	var saldo0: int = j.economia.saldo
	verificar(j.economia.debitar_peca(150), "peça comum de 150")
	igual(j.economia.saldo, saldo0 - 150, "peça comum se paga em giros")
	igual(j.economia.credito_pecas, 325, "e não gasta peças")
	verificar(j.economia.debitar_peca(150, true), "blindagem de 150 peças")
	igual(j.economia.credito_pecas, 175, "a blindagem gasta peças")
	igual(j.economia.saldo, saldo0 - 150, "e não giros")
	verificar(not j.economia.debitar_peca(500, true), "sem peças bastantes, não compra")
	j.free()
	d.free()


func test_estado_da_equipe_volta_do_save() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	GestaoEquipe.assinar(d, j, "p_b1", 100.0)
	j.economia.credito_pecas = 42
	j.equipe["sede"] = {"marketing": 1}
	var s := Save.serializar(j)
	var k: Node = JogadorScript.new()
	k.novo_jogo(d.economia(), d.pneu)
	igual(Save.desserializar(JSON.parse_string(JSON.stringify(s)), k, d), "", "load")
	igual(GestaoEquipe.contratos(k).size(), 1, "contrato volta do save")
	igual(k.economia.credito_pecas, 42, "crédito de peças volta do save")
	igual(GestaoEquipe.nivel(k, "marketing"), 1, "nível da sede volta do save")
	j.free()
	k.free()
	d.free()


func test_treino_sobe_ritmo_ate_o_teto() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	j.economia.creditar(1000)
	# Fixture: passo 0,05, teto 1,1 na licença "b", base 1,0; nível n leva n h e custa 5 × n.
	perto(GestaoEquipe.ritmo(d, j, 1.0), 1.0, 1e-6, "sem treino, a base")
	igual(GestaoEquipe.preco_treino(d, j), 5, "nível 1 custa 5")
	igual(GestaoEquipe.treinar(d, j, 1.0, 0.0), "", "começa o treino")
	igual(GestaoEquipe.treinar(d, j, 1.0, 0.0), "já está treinando", "um treino por vez")
	verificar(not GestaoEquipe.concluir_treino(j, 1800.0), "meia hora: ainda treinando")
	verificar(GestaoEquipe.concluir_treino(j, 3600.0), "uma hora: concluído")
	perto(GestaoEquipe.ritmo(d, j, 1.0), 1.05, 1e-6, "nível 1: +0,05")
	GestaoEquipe.treinar(d, j, 1.0, 3600.0)
	GestaoEquipe.concluir_treino(j, 3600.0 * 3.0)
	perto(GestaoEquipe.ritmo(d, j, 1.0), 1.1, 1e-6, "nível 2: no teto")
	verificar(not GestaoEquipe.pode_treinar(d, j, 1.0), "no teto não treina mais")
	j.equipe["treino"]["nivel"] = 5
	perto(GestaoEquipe.ritmo(d, j, 1.0), 1.1, 1e-6, "acima do teto: limitado")
	var base := float(d.piloto(d.carreira()["piloto_jogador"])["ritmo"])
	var p := EquipeJogador.piloto_do_jogador(d, j)
	perto(float(p["ritmo"]), GestaoEquipe.ritmo(d, j, base), 1e-6, "o piloto da corrida usa o treino")
	perto(float(EquipeJogador.piloto_corrida(d, j)["ritmo"]), base, 1e-6, "o segundo piloto não herda o treino")
	j.free()
	d.free()


## Decisão 69: uma vaga de corrida e duas de arena; cada candidato tem o tipo;
## as de arena abrem com o tutorial da arena.
func test_pilotos_de_corrida_e_de_arena() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	j.flags.erase(EquipeJogador.FLAG)
	igual(EquipeJogador.contratar(d, j, "livre_1"), "a equipe ainda não contrata", "antes da equipe existir")
	EquipeJogador.criar(j)
	igual(EquipeJogador.contratar(d, j, "ninguem"), "candidato desconhecido", "só candidatos")
	verificar(EquipeJogador.contratar(d, j, "livre_3", "corrida") != "", "piloto de arena não corre")
	igual(EquipeJogador.contratar(d, j, "livre_1", "corrida"), "", "piloto de corrida")
	igual(EquipeJogador.contratar(d, j, "livre_2", "corrida"), "", "troca o de corrida")
	igual(EquipeJogador.nome_jogador(d, j), "Livre Dois", "quem corre")
	verificar(EquipeJogador.contratar(d, j, "livre_3", "arena1") != "", "arena fechada antes do tutorial")
	j.flags[EquipeJogador.FLAG_ARENA] = true
	verificar(EquipeJogador.contratar(d, j, "livre_1", "arena1") != "", "piloto de corrida não vai à arena")
	igual(EquipeJogador.contratar(d, j, "livre_3", "arena1"), "", "arena 1")
	verificar(EquipeJogador.contratar(d, j, "livre_3", "arena2") != "", "o mesmo piloto em duas vagas, não")
	igual(EquipeJogador.contratar(d, j, "livre_4", "arena2"), "", "arena 2")
	igual(EquipeJogador.nome_segundo(d, j), "Livre Quatro", "a dupla")
	var texto := JSON.stringify(Save.serializar(j))
	var k := _novo(d)
	igual(Save.desserializar(JSON.parse_string(texto), k, d), "", "load")
	igual(k.pilotos, j.pilotos, "pilotos no save")
	j.free()
	k.free()
	d.free()


func test_pintura_muda_cor_e_faixas_e_volta_do_save() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	j.economia.creditar(1000)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	var c: Carro = j.garagem.carro(uid)
	var fx := {"padrao": "dupla", "faixa": "#ffffff", "filete": "#c8202a"}
	# Fixture sem preço definido (equipe.json sem "pintura"): vale 0.
	igual(PinturaCarro.preco(d, j, true, true), 0, "preço a definir vale 0")
	igual(PinturaCarro.aplicar(d, j, c, c.cor, c.faixas), "nada mudou", "sem mudança não aplica")
	igual(PinturaCarro.aplicar(d, j, c, "#1f3f8f", fx), "", "pinta")
	igual(c.cor, "#1f3f8f", "cor nova")
	igual(c.faixas, fx, "faixas novas")
	igual(PinturaCarro.aplicar(d, j, c, "#1f3f8f", {"padrao": ""}), "", "tira as faixas")
	igual(c.faixas, {}, "sem faixas")
	PinturaCarro.aplicar(d, j, c, "#1f3f8f", fx)
	j.ultima_loja = "brace_yard_works"
	var s := Save.serializar(j)
	var k: Node = JogadorScript.new()
	k.novo_jogo(d.economia(), d.pneu)
	igual(Save.desserializar(JSON.parse_string(JSON.stringify(s)), k, d), "", "load")
	igual(k.garagem.carro(uid).faixas, fx, "faixas voltam do save")
	igual(k.ultima_loja, "brace_yard_works", "a última loja aberta volta do save")
	igual(PinturaCarro.indice_padrao("lateral"), 3, "índice do padrão é o do shader")
	igual(PinturaCarro.indice_padrao("tigrado"), 0, "desenho removido vira sem faixas")
	igual(PinturaCarro.nome_padrao("circulo"), "Círculo", "círculo sem 'de número'")
	var cinza := Color("#9aa0a6")
	igual(PinturaCarro.saturada(cinza), cinza, "cinza fica como está")
	var verm := Color("#b3261e")
	verificar(PinturaCarro.saturada(verm).s > verm.s and is_equal_approx(PinturaCarro.saturada(verm).h, verm.h),
			"cor mais saturada no mesmo matiz")
	j.free()
	k.free()
	d.free()
