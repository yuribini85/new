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


func test_desmanche_vira_credito_que_paga_pecas_primeiro() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	j.economia.creditar(5000)
	var a: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	var b: int = j.concessionaria.comprar_carro(d.carro("forte"))
	var carro: Carro = j.garagem.carro(b)
	carro.pecas_possuidas.append("turbo")  # comprada por 200
	igual(GestaoEquipe.credito_desmanche(d, j, carro), 100, "metade das peças compradas")
	igual(GestaoEquipe.desmontar(d, j, b), 100, "desmonta")
	verificar(j.garagem.carro(b) == null, "o carro sai da garagem")
	igual(j.economia.credito_pecas, 100, "crédito de peças")
	igual(GestaoEquipe.desmontar(d, j, a), -1, "o único carro não se desmonta")
	var saldo0: int = j.economia.saldo
	verificar(j.economia.debitar_peca(150), "peça de 150")
	igual(j.economia.credito_pecas, 0, "o crédito paga primeiro")
	igual(j.economia.saldo, saldo0 - 50, "o caixa paga o resto")
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
