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
	# Decisão 74: faltando peças, os giros completam a blindagem.
	var saldo1: int = j.economia.saldo
	verificar(j.economia.debitar_peca(500, true), "175 peças + 325 giros")
	igual(j.economia.credito_pecas, 0, "as peças primeiro")
	igual(j.economia.saldo, saldo1 - 325, "os giros completam")
	verificar(not j.economia.debitar_peca(j.economia.saldo + 1, true), "sem peças nem giros bastantes, não compra")
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
	# Aro das rodas: vai com a pintura, não custa, volta do save; save antigo
	# (sem "roda") fica com o padrão.
	igual(Rodas.desenho_de(k.garagem.carro(uid).faixas), Rodas.PADRAO, "save sem roda: aro padrão")
	igual(PinturaCarro.aplicar(d, j, c, "#1f3f8f", fx.merged({"roda": "turbina"})), "", "troca só o aro")
	igual(String(c.faixas["roda"]), "turbina", "aro gravado")
	igual(PinturaCarro.normalizar({"roda": Rodas.PADRAO}), {}, "aro padrão não vai para o save")
	igual(PinturaCarro.normalizar({"roda": "inexistente"}), {}, "aro desconhecido vira o padrão")
	var s2 := Save.serializar(j)
	var k2: Node = JogadorScript.new()
	k2.novo_jogo(d.economia(), d.pneu)
	igual(Save.desserializar(JSON.parse_string(JSON.stringify(s2)), k2, d), "", "load com aro")
	igual(Rodas.desenho_de(k2.garagem.carro(uid).faixas), "turbina", "aro volta do save")
	k2.free()
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


## Decisão 70: cada piloto tem atributos pelo traço e o próprio treino, como
## energia: gasta ao começar, enche até o fim, e o nível entra quando enche.
func test_atributos_e_energia_por_piloto() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	j.economia.creditar(1000)
	var base: Dictionary = d.piloto(d.carreira()["piloto_jogador"])
	var a1 := EquipeJogador.atributos(d, j, "livre_1")
	var a2 := EquipeJogador.atributos(d, j, "livre_2")
	perto(float(a1["consistencia"]), float(base["consistencia"]), 1e-6, "Constante: a consistência do piloto-base")
	verificar(float(a2["consistencia"]) < float(a1["consistencia"]), "Promessa: mais crua")
	igual(EquipeJogador.contratar(d, j, "livre_1", "corrida"), "", "contrata")
	perto(GestaoEquipe.energia(j, "livre_1", 0.0), 1.0, 1e-6, "descansado")
	igual(GestaoEquipe.treinar(d, j, float(base["ritmo"]), 0.0, "livre_1"), "", "treina")
	perto(GestaoEquipe.energia(j, "livre_1", 0.0), 0.0, 1e-6, "treinar gasta a energia")
	verificar(GestaoEquipe.energia(j, "livre_1", 1800.0) > 0.4, "volta enchendo")
	perto(GestaoEquipe.nivel_treino(j, "livre_2"), 0, 1e-6, "o treino é de um piloto só")
	verificar(GestaoEquipe.concluir_treino(j, 3600.0), "enche: o nível entra")
	perto(GestaoEquipe.energia(j, "livre_1", 3600.0), 1.0, 1e-6, "energia cheia")
	verificar(float(EquipeJogador.piloto_do_jogador(d, j)["ritmo"]) > float(base["ritmo"]), "quem corre usa o treino dele")
	j.free()
	d.free()


## Decisão 70: cansado perde consistência; a corrida inscrita guarda o piloto
## de então (descansar depois não muda a prova programada).
func test_cansaco_e_piloto_guardado_na_inscricao() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	j.economia.creditar(1000)
	d.equipe()["treino"]["cansaco"] = 0.2
	EquipeJogador.contratar(d, j, "livre_1", "corrida")
	var descansado := float(EquipeJogador.atributos(d, j, "livre_1", 0.0)["consistencia"])
	GestaoEquipe.treinar(d, j, 1.0, 0.0, "livre_1")
	var cansado := float(EquipeJogador.atributos(d, j, "livre_1", 0.0)["consistencia"])
	perto(cansado, descansado * 0.8, 1e-6, "energia zero: −20% de consistência")
	var c := Carreira.new(d, j)
	var f := Fila.new(c, j, 3600.0)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	igual(f.iniciar("aberto", uid, 1, 0.0), "", "inscrição")
	var antes: Dictionary = f.corrida_atual(1.0)["resultado"]["carros"]["jogador"]
	GestaoEquipe.concluir_treino(j, 999999.0)  # descansou
	var depois: Dictionary = f.corrida_atual(1.0)["resultado"]["carros"]["jogador"]
	igual(depois["tempo_total"], antes["tempo_total"], "a corrida inscrita não muda")
	j.free()
	d.free()


## Decisão 71: o mercado mostra a oferta do período; vencer uma equipe do Grid
## põe os pilotos dela no mercado; experiência por prova e embalo.
## Pack premium e variação por piloto (pedido do usuário, 2026-10-16). Dados reais.
func test_pack_premium_e_variacao_por_piloto() -> void:
	var d: Node = DadosScript.new()
	d.carregar(d.DATA_DIR)
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	EquipeJogador.criar(j)
	var agora := Time.get_unix_time_from_system()
	verificar(not EquipeJogador.oferta(d, j, "corrida", agora).any(func(c): return bool(c.get("premium", false))),
			"sem o pack, nenhum premium no mercado")
	igual(EquipeJogador.premium_do_tipo(d, "corrida").size(), 1, "1 premium de corrida")
	igual(EquipeJogador.premium_do_tipo(d, "arena").size(), 2, "2 premium de arena")
	var pr: Dictionary = EquipeJogador.premium_do_tipo(d, "corrida")[0]
	var at := EquipeJogador.atributos(d, j, String(pr["id"]))
	perto(float(at["ritmo"]), EquipeJogador.ritmo_premium(d), 1e-6, "premium: ritmo medido")
	perto(float(at["consistencia"]), 1.0, 1e-6, "premium: consistência 100%")
	perto(float(at["agressividade"]), 1.0, 1e-6, "premium: agressividade 100%")
	j.flags[EquipeJogador.FLAG_PACK_PREMIUM] = true
	for t in ["corrida", "arena"]:
		var of := EquipeJogador.oferta(d, j, t, agora)
		for c in EquipeJogador.premium_do_tipo(d, t):
			verificar(of.any(func(x): return x["id"] == c["id"]), "%s sempre no mercado com o pack" % c["id"])
	igual(EquipeJogador.contratar(d, j, String(pr["id"]), "corrida"), "", "contrata o premium")
	# Variação: dois candidatos do mesmo traço com atributos diferentes, fixos.
	var mesmos: Array = EquipeJogador.candidatos(d).filter(func(c): return c.get("traco") == "constante")
	var a1 := EquipeJogador.atributos(d, null, String(mesmos[0]["id"]))
	var a2 := EquipeJogador.atributos(d, null, String(mesmos[1]["id"]))
	verificar(a1 != a2, "mesmo traço, atributos diferentes")
	igual(EquipeJogador.atributos(d, null, String(mesmos[0]["id"])), a1, "a variação é fixa")
	j.free()
	d.free()


func test_mercado_experiencia_e_embalo() -> void:
	var d: Node = load("res://autoload/dados.gd").new()
	d.carregar("res://data/")
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	EquipeJogador.criar(j)
	j.flags["GESTAO_LIBERADA"] = true
	var por_tipo := int(EquipeJogador.cfg_mercado(d)["por_tipo"])
	igual(EquipeJogador.oferta(d, j, "corrida", 0.0).size(), por_tipo, "a oferta do período")
	var antes := EquipeJogador.pool(d, j, "arena").size()
	var primeira: Dictionary = TheGrid.equipes(d)[0]
	TheGrid.registrar(d, j, [String(primeira["id"])])
	verificar(EquipeJogador.pool(d, j, "arena").size() + EquipeJogador.pool(d, j, "corrida").size() > antes + por_tipo,
			"os pilotos da equipe vencida entram no mercado")
	var do_grid: Dictionary = EquipeJogador.pool(d, j, "corrida").filter(func(c): return c.has("equipe")).front() \
			if EquipeJogador.pool(d, j, "corrida").any(func(c): return c.has("equipe")) else EquipeJogador.pool(d, j, "arena").filter(func(c): return c.has("equipe")).front()
	verificar(do_grid.has("equipe"), "piloto do Grid com a equipe de origem")
	# Os do Grid servem às duas vagas, qualquer que seja o traço.
	for pe in primeira.get("pilotos", []):
		for t in ["corrida", "arena"]:
			verificar(EquipeJogador.pool(d, j, t).any(func(c): return c["id"] == pe["id"]), "%s no mercado de %s" % [pe["id"], t])
	# Experiência: a cada xp_por_nivel provas, um nível (abaixo do teto).
	j.licencas = ["CLUB", "SPORT", "NATIONAL", "INTERNATIONAL"]
	var c0: String = EquipeJogador.oferta(d, j, "corrida", Time.get_unix_time_from_system())[0]["id"]
	igual(EquipeJogador.contratar(d, j, c0, "corrida"), "", "contrata do mercado")
	var n := int(GestaoEquipe.cfg_treino(d)["xp_por_nivel"])
	for k in n:
		EquipeJogador.apos_prova(d, j, ["corrida"], true)
	igual(GestaoEquipe.nivel_treino(j, c0), 1, "subiu um nível com a experiência")
	verificar(EquipeJogador.em_embalo(j, c0), "vitórias seguidas: embalo")
	var dur := GestaoEquipe.duracao_treino(d, j, c0)
	j.equipe.erase("embalo_" + c0)
	verificar(dur < GestaoEquipe.duracao_treino(d, j, c0), "embalo: treino mais curto")
	j.free()
	d.free()


## Decisão 85: o patrocínio rende com o app fechado até 2 h na primeira
## licença e +1 h por licença a mais (dados reais, equipe.json).
func test_teto_offline_do_patrocinio_cresce_com_as_licencas() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.licencas = ["CLUB"]
	igual(GestaoEquipe.teto_offline(d, j), 2.0 * 3600.0, "Club: 2 h")
	j.licencas = ["CLUB", "SPORT", "NATIONAL"]
	igual(GestaoEquipe.teto_offline(d, j), 4.0 * 3600.0, "três licenças: 4 h")
	verificar(not GestaoEquipe.patrocinio_aberto(d, j), "sem equipe, sem patrocínio")
	j.personagem = "dono"
	EquipeJogador.criar(j)
	verificar(not GestaoEquipe.patrocinio_aberto(d, j), "dono: espera a cena do patrocínio")
	j.flags[GestaoEquipe.FLAG_PATROCINIO] = true
	verificar(GestaoEquipe.patrocinio_aberto(d, j), "liberado depois da corrida com a Club")
	verificar(not GestaoEquipe.aberta(d, j), "caixa e sede seguem fechados até a International")
	j.free()
	d.free()


## Decisão 85: a garagem do dono começa vazia; o carro da Mara chega na
## National com a peça mais forte de cada categoria.
func test_dono_comeca_sem_carro_e_ganha_o_da_mara_na_national() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var j: Node = JogadorScript.new()
	igual(Prologo.iniciar(d, j, "dono"), "", "começa")
	igual(j.garagem.lista().size(), 0, "garagem vazia")
	igual(j.economia.saldo, int(d.economia()["saldo_inicial"]), "saldo inicial da economia")
	igual(Prologo.ao_conceder(d, j, "CLUB"), "", "a Club não traz o carro")
	var nome := Prologo.ao_conceder(d, j, "NATIONAL")
	verificar(nome != "", "a National traz o carro da Mara (%s)" % nome)
	var c: Carro = j.garagem.lista()[0]
	verificar(c.pecas.size() >= 5, "preparado: %d categorias com peça" % c.pecas.size())
	j.free()
	d.free()


## Combustível e prêmio na repetição (decisões do usuário, 2026-10-17). Dados reais.
func test_combustivel_e_repeticao() -> void:
	var d: Node = DadosScript.new()
	d.carregar(d.DATA_DIR)
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	var r := Combustivel.regras(d)
	verificar(not r.is_empty(), "regras do combustível nos dados")
	var tanque := int(r["tanque"])
	var passo := float(r["renova_s"])
	var t0 := 1_000_000.0
	verificar(Combustivel.vale(d, j), "sem história, o combustível vale")
	igual(Combustivel.quantidade(d, j, t0), tanque, "começa cheio")
	for i in tanque:
		verificar(Combustivel.gastar(d, j, t0), "gasta %d" % (i + 1))
	igual(Combustivel.quantidade(d, j, t0), 0, "vazio")
	verificar(not Combustivel.pode(d, j, t0) and not Combustivel.gastar(d, j, t0), "vazio não larga")
	igual(Combustivel.quantidade(d, j, t0 + passo * 1.5), 1, "renova 1 por período")
	perto(Combustivel.proxima_s(d, j, t0 + passo * 1.5), passo * 0.5, 1e-6, "próxima no meio do período")
	verificar(Combustivel.gastar(d, j, t0 + passo * 1.5), "gasta o renovado")
	igual(Combustivel.quantidade(d, j, t0 + passo * 2.0), 1, "fração do período guardada ao gastar")
	igual(Combustivel.quantidade(d, j, t0 - 3600.0), 0, "relógio voltando não dá combustível")
	igual(Combustivel.quantidade(d, j, t0 + passo * 100.0), tanque, "não passa do tanque")
	Combustivel.encher(j)
	igual(Combustivel.quantidade(d, j, t0), tanque, "vídeo enche o tanque")
	# Repetição: só prova vencida com licença; cai e volta no período seguinte.
	var c := Carreira.new(d, j)
	j.carreira = c
	var ev := ""
	for e in d.lista("eventos"):
		if String(e["restricoes"].get("licenca", "")) != "" and not e["premios"].is_empty():
			ev = e["id"]
			break
	var livre := ""
	for e in d.lista("eventos"):
		if String(e["restricoes"].get("licenca", "")) == "" and not e["premios"].is_empty():
			livre = e["id"]
			break
	perto(c.fator_repeticao(ev, t0), 1.0, 1e-9, "não vencida paga inteiro")
	j.vitorias[ev] = 1
	j.vitorias[livre] = 1
	var fatores: Array = d.carreira()["repeticao"]["fatores"]
	for k in fatores.size() + 1:
		perto(c.fator_repeticao(ev, t0), float(fatores[mini(k, fatores.size() - 1)]), 1e-9, "repetição %d" % (k + 1))
		c._contar_repeticao(ev, t0)
	perto(c.fator_repeticao(livre, t0), 1.0, 1e-9, "prova sem licença fica fora")
	perto(c.fator_repeticao(ev, t0 + c.repeticao_volta_em(t0) + 1.0), float(fatores[0]), 1e-9, "período novo recomeça")
	j.free()
	d.free()
