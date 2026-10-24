extends "res://tests/base_teste.gd"
## Gestão da equipe (GestaoEquipe): patrocínio com renda por hora (também
## offline, com o teto de ausência) e renovação sozinha, bônus por condição e
## o Escritório da sede. Fixtures sintéticas (equipe.json, patrocinadores.json):
## prêmio de referência da licença "b" = 10.

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


func test_patrocinio_rende_todas_as_horas_e_acaba() -> void:
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
	# Decisão 104: a ausência conta inteira dentro do contrato (5 h fora: 5 giros).
	r = GestaoEquipe.acumular(d, j, 8.0 * 3600.0)
	igual(int(r["ganho"]), 5, "ausência paga inteira")
	# O contrato dura 10 h (fixture, sem a base: duracao_h): acaba e sai da
	# lista; o que passa do fim não paga.
	r = GestaoEquipe.acumular(d, j, 14.0 * 3600.0)
	igual(int(r["ganho"]), 2, "só até o fim do contrato")
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


func test_bonus_pela_dificuldade_da_condicao() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	var p := GestaoEquipe.patrocinador(d, "p_b1")  # pódio, bônus 5
	igual(GestaoEquipe.bonus(d, j, p), 5, "sem bonus_condicao: multiplicador 1")
	d.equipe()["patrocinio"]["bonus_condicao"] = {"podio": 2.0}
	igual(GestaoEquipe.bonus(d, j, p), 10, "pódio × 2")
	igual(GestaoEquipe.chave_condicao({"tipo": "licenca", "valor": "PRO"}), "licenca:PRO", "chave com a licença")
	j.free()
	d.free()


## Decisão 124: sem escolha entre ofertas; a vaga livre assina sozinha a
## primeira (a que mais paga por hora) e renova quando o contrato acaba.
func test_patrocinio_assina_e_renova_sozinho() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	var primeira: String = GestaoEquipe.ofertas(d, j)[0]["nome"]
	igual(GestaoEquipe.renovar(d, j, 0.0), [primeira], "assina a primeira oferta")
	igual(GestaoEquipe.contratos(j).size(), 1, "um contrato")
	igual(GestaoEquipe.renovar(d, j, 0.0), [], "sem vaga, não assina outro")
	GestaoEquipe.acumular(d, j, 20.0 * 3600.0)
	igual(GestaoEquipe.contratos(j).size(), 0, "o contrato acabou")
	igual(GestaoEquipe.renovar(d, j, 20.0 * 3600.0).size(), 1, "renova sozinho")
	perto(float(GestaoEquipe.contratos(j)[0]["inicio"]), 20.0 * 3600.0, 1e-6, "o novo começa agora")
	j.free()
	d.free()


func test_sede_so_escritorio_abre_vaga() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	j.economia.creditar(1000)
	igual(d.equipe()["sede"].size(), 1, "só o Escritório")
	igual(GestaoEquipe.preco_melhoria(d, j, "escritorio"), 10, "nível 1: 10 × 1 × 1")
	igual(GestaoEquipe.comprar_melhoria(d, j, "escritorio"), "", "compra escritório")
	igual(GestaoEquipe.comprar_melhoria(d, j, "escritorio"), "nível máximo", "escritório só tem 1 nível")
	igual(GestaoEquipe.vagas(d, j), 2, "escritório abre a segunda vaga")
	igual(GestaoEquipe.renovar(d, j, 0.0).size(), 2, "as duas vagas assinam")
	igual(GestaoEquipe.renda_hora(d, j, GestaoEquipe.patrocinador(d, "p_b1")), 1, "renda sem multiplicador da sede")
	j.free()
	d.free()


## Decisão 124: a blindagem se paga em giros, pelo preço dela (antes, peças e
## giros valiam o mesmo).
func test_blindagem_em_giros() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	j.economia.creditar(5000)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	var chapa := {"id": "fraco_blindagem_1", "nome": "Chapa", "categoria": Blindagem.CATEGORIA, "nivel": 1, "preco": 150,
			"efeitos": [{"atributo": "peso", "op": "mult", "valor": 1.05}]}
	var saldo0: int = j.economia.saldo
	igual(j.concessionaria.comprar_peca(j.garagem.carro(uid), chapa), "", "compra a blindagem")
	igual(j.economia.saldo, saldo0 - 150, "paga em giros")
	j.economia.saldo = 0
	chapa = chapa.merged({"id": "fraco_blindagem_2"}, true)
	igual(j.concessionaria.comprar_peca(j.garagem.carro(uid), chapa), "saldo insuficiente", "sem giros, não compra")
	j.free()
	d.free()


func test_estado_da_equipe_volta_do_save() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	GestaoEquipe.assinar(d, j, "p_b1", 100.0)
	j.equipe["sede"] = {"escritorio": 1}
	j.equipe["treino_livre_1"] = {"nivel": 1, "inicio": 0.0, "fim": 3600.0}  # treino pago de save antigo
	j.equipe["embalo_livre_1"] = true
	var s := Save.serializar(j)
	s["credito_pecas"] = 42  # save antigo: as peças saíram, o campo é ignorado
	var k: Node = JogadorScript.new()
	k.novo_jogo(d.economia(), d.pneu)
	igual(Save.desserializar(JSON.parse_string(JSON.stringify(s)), k, d), "", "load")
	igual(GestaoEquipe.contratos(k).size(), 1, "contrato volta do save")
	igual(GestaoEquipe.nivel(k, "escritorio"), 1, "nível da sede volta do save")
	EquipeJogador.migrar(d, k)
	igual(GestaoEquipe.nivel_treino(k, "livre_1"), 2, "o treino pago em andamento entra como nível")
	verificar(not k.equipe.has("embalo_livre_1"), "o embalo sai")
	j.free()
	k.free()
	d.free()


## Nível de ritmo: passo por nível até o teto da licença (decisão 124: sobe só
## com a experiência).
func test_nivel_sobe_ritmo_ate_o_teto() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	# Fixture: passo 0,05, teto 1,1 na licença "b", base 1,0.
	perto(GestaoEquipe.ritmo(d, j, 1.0), 1.0, 1e-6, "sem nível, a base")
	verificar(GestaoEquipe.pode_subir(d, j, 1.0), "abaixo do teto sobe")
	j.equipe["treino"] = {"nivel": 1}
	perto(GestaoEquipe.ritmo(d, j, 1.0), 1.05, 1e-6, "nível 1: +0,05")
	j.equipe["treino"]["nivel"] = 2
	perto(GestaoEquipe.ritmo(d, j, 1.0), 1.1, 1e-6, "nível 2: no teto")
	verificar(not GestaoEquipe.pode_subir(d, j, 1.0), "no teto não sobe mais")
	j.equipe["treino"]["nivel"] = 5
	perto(GestaoEquipe.ritmo(d, j, 1.0), 1.1, 1e-6, "acima do teto: limitado")
	var base := float(d.piloto(d.carreira()["piloto_jogador"])["ritmo"])
	var p := EquipeJogador.piloto_do_jogador(d, j)
	perto(float(p["ritmo"]), GestaoEquipe.ritmo(d, j, base), 1e-6, "o piloto da corrida usa o nível")
	perto(float(EquipeJogador.piloto_corrida(d, j)["ritmo"]), base, 1e-6, "o segundo piloto não herda o nível")
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


## Decisão 70: cada piloto tem atributos pelo traço e o próprio nível, que
## sobe com as provas (experiência, decisão 71).
func test_atributos_e_experiencia_por_piloto() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	j.economia.creditar(1000)
	d.equipe()["treino"]["xp_por_nivel"] = 2
	var base: Dictionary = d.piloto(d.carreira()["piloto_jogador"])
	var a1 := EquipeJogador.atributos(d, j, "livre_1")
	var a2 := EquipeJogador.atributos(d, j, "livre_2")
	perto(float(a1["consistencia"]), float(base["consistencia"]), 1e-6, "Constante: a consistência do piloto-base")
	verificar(float(a2["consistencia"]) < float(a1["consistencia"]), "Promessa: mais crua")
	igual(EquipeJogador.contratar(d, j, "livre_1", "corrida"), "", "contrata")
	igual(EquipeJogador.apos_prova(d, j, ["corrida"], false), [], "uma prova: ainda não")
	igual(EquipeJogador.apos_prova(d, j, ["corrida"], false), ["livre_1"], "duas provas: sobe")
	igual(GestaoEquipe.nivel_treino(j, "livre_1"), 1, "nível 1")
	igual(GestaoEquipe.nivel_treino(j, "livre_2"), 0, "o nível é de um piloto só")
	verificar(float(EquipeJogador.piloto_do_jogador(d, j)["ritmo"]) > float(base["ritmo"]), "quem corre usa o nível dele")
	d.equipe()["treino"].erase("xp_por_nivel")
	j.free()
	d.free()


## Decisão 70: a corrida inscrita guarda o piloto de então (subir de nível
## depois não muda a prova programada).
func test_piloto_guardado_na_inscricao() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	j.economia.creditar(1000)
	EquipeJogador.contratar(d, j, "livre_1", "corrida")
	var c := Carreira.new(d, j)
	var f := Fila.new(c, j, 3600.0)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	igual(f.iniciar("aberto", uid, 1, 0.0), "", "inscrição")
	var antes: Dictionary = f.corrida_atual(1.0)["resultado"]["carros"]["jogador"]
	j.equipe["treino_livre_1"] = {"nivel": 2}  # subiu depois
	var depois: Dictionary = f.corrida_atual(1.0)["resultado"]["carros"]["jogador"]
	igual(depois["tempo_total"], antes["tempo_total"], "a corrida inscrita não muda")
	j.free()
	d.free()


## Decisão 71: o mercado mostra a oferta do período; vencer uma equipe do Grid
## põe os pilotos dela no mercado; experiência por prova.
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


func test_mercado_e_experiencia() -> void:
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
	j.free()
	d.free()


## Decisão 104: a capacidade de renda offline (a duração do contrato) começa
## em 2 h e cada título de série soma 1 h (dados reais, equipe.json).
func test_capacidade_offline_cresce_com_os_titulos() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.licencas = ["CLUB", "SPORT", "NATIONAL"]
	igual(GestaoEquipe.teto_offline(d, j), 2.0 * 3600.0, "sem título: 2 h (licença não soma)")
	j.titulos = {"Copa A": 1, "Copa B": 3}
	igual(GestaoEquipe.teto_offline(d, j), 4.0 * 3600.0, "dois títulos de série: 4 h")
	LojaReal.conceder(d, j, "turno_noite")
	igual(GestaoEquipe.teto_offline(d, j), 10.0 * 3600.0, "Turno da Noite: +6 h, soma com os títulos")
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


## Pedido do usuário: com a corrida em andamento, o piloto de corrida não muda.
func test_nao_troca_piloto_durante_a_corrida() -> void:
	var d: Node = DadosScript.new()
	d.carregar(d.DATA_DIR)
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	EquipeJogador.criar(j)
	var ofertas: Array = EquipeJogador.oferta(d, j, "corrida", Time.get_unix_time_from_system())
	verificar(ofertas.size() >= 2, "há candidatos de corrida")
	igual(EquipeJogador.contratar(d, j, String(ofertas[0]["id"]), "corrida"), "", "contrata sem corrida")
	j.fila = {"evento_id": "x", "uid": 1, "restantes": 1, "inicio": 0.0, "semente": 1}
	verificar(EquipeJogador.contratar(d, j, String(ofertas[1]["id"]), "corrida") != "", "com corrida em andamento, não troca")
	igual(EquipeJogador.piloto_vaga(j, "corrida"), String(ofertas[0]["id"]), "o piloto continua o mesmo")
	j.fila = {}
	igual(EquipeJogador.contratar(d, j, String(ofertas[1]["id"]), "corrida"), "", "depois da corrida, troca")
	j.free()
	d.free()


## Luvas (decisão do usuário, 2026-10-17): o primeiro piloto sai de graça; os
## seguintes pagam uma vez, mais pelo melhor; sem giros, não contrata.
func test_luvas_da_contratacao() -> void:
	var d: Node = DadosScript.new()
	d.carregar(d.DATA_DIR)
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	EquipeJogador.criar(j)
	var ofertas: Array = EquipeJogador.oferta(d, j, "corrida", Time.get_unix_time_from_system())
	igual(EquipeJogador.luvas(d, j, String(ofertas[0]["id"])), 0, "o primeiro sai de graça")
	var saldo0: int = j.economia.saldo
	igual(EquipeJogador.contratar(d, j, String(ofertas[0]["id"]), "corrida"), "", "contrata o primeiro")
	igual(j.economia.saldo, saldo0, "sem débito no primeiro")
	var custo := EquipeJogador.luvas(d, j, String(ofertas[1]["id"]))
	verificar(custo > 0, "o segundo paga luvas")
	j.economia.saldo = custo - 1
	verificar(EquipeJogador.contratar(d, j, String(ofertas[1]["id"]), "corrida") != "", "sem giros, não contrata")
	j.economia.saldo = custo
	igual(EquipeJogador.contratar(d, j, String(ofertas[1]["id"]), "corrida"), "", "com giros, contrata")
	igual(j.economia.saldo, 0, "pagou as luvas uma vez")
	j.free()
	d.free()


func test_loja_real_compra_liga_a_flag() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	d.monetizacao()["loja"] = {"produtos": [{"id": "pack_premium", "sku": "pack_premium", "flag": "PACK_PREMIUM",
			"nome": "Pack Elite", "descricao": ""}]}
	verificar(not LojaReal.comprado(d, j, "pack_premium"), "começa sem o pack")
	igual(LojaReal.comprar(d, j, "pack_premium"), LojaReal.SEM_LOJA, "sem a loja do aparelho, não cobra")
	verificar(not EquipeJogador.tem_pack_premium(j), "pedir não concede")
	igual(LojaReal.conceder(d, j, "pack_premium"), "", "a loja confirma")
	verificar(EquipeJogador.tem_pack_premium(j), "a confirmação liga o pack")
	igual(LojaReal.comprar(d, j, "pack_premium"), "já comprado", "não compra duas vezes")
	igual(LojaReal.conceder(d, j, "nada"), "produto desconhecido", "produto que não existe")
	j.free()
	d.free()


## Decisão 107: os avisos do aparelho saem do estado (contrato que acaba,
## treino de licença); o que falta menos de um minuto não vira aviso.
func test_notificacoes_planejadas() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	GestaoEquipe.assinar(d, j, "p_b1", 0.0)
	var n := Notificacoes.planejar(d, j, 3600.0)
	var ids: Array = n.map(func(x): return x["id"])
	verificar("contrato_p_b1" in ids, "contrato vira aviso")
	var c: Dictionary = n[ids.find("contrato_p_b1")]
	perto(float(c["em_s"]), 9.0 * 3600.0, 1.0, "no fim do contrato (10 h, assinado em 0)")
	igual(Notificacoes.planejar(d, j, 10.0 * 3600.0 - 30.0).filter(func(x): return x["id"] == "contrato_p_b1").size(), 0,
			"menos de um minuto: sem aviso")
	j.free()
	d.free()


## Decisão 109: meta do dia sorteada pela data entre as tarefas possíveis;
## cumprida, coleta uma vez; no dia seguinte, tudo de novo (dados reais).
func test_meta_do_dia() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.licencas = ["CLUB"]
	var agora := 1_800_000_000.0
	var est := MetaDia.estado(d, j, agora)
	igual(est["tarefas"].size(), 3, "três tarefas")
	for id in est["tarefas"]:
		verificar(not String(MetaDia.tarefa(d, id)["tipo"]) in ["arena", "patrocinio"], "só o que dá para fazer")
	var id: String = est["tarefas"][0]
	var t := MetaDia.tarefa(d, id)
	igual(MetaDia.coletar(d, j, id, agora), 0, "sem cumprir não paga")
	MetaDia.registrar(j, String(t["tipo"]), int(t["quantidade"]), agora)
	var saldo0: int = j.economia.saldo
	var v := MetaDia.coletar(d, j, id, agora)
	verificar(v > 0, "cumprida paga")
	igual(j.economia.saldo, saldo0 + v, "no caixa")
	igual(MetaDia.coletar(d, j, id, agora), 0, "uma vez só")
	var amanha := MetaDia.estado(d, j, agora + 86400.0)
	igual(amanha["coletadas"].size(), 0, "dia novo: nada coletado")
	igual(MetaDia.progresso(d, j, String(amanha["tarefas"][0]), agora + 86400.0)[0], 0, "dia novo: contagem zerada")
	j.free()
	d.free()


## Decisão 130 (E4): caixa de pintura na primeira vitória de prova da licença
## mínima ou com o carro mais fraco do grid; abre na hora um item trancado e,
## sem nada a liberar, vira giros. Fixture: licença mínima "b", exclusivos
## turbina, metálico e serifa.
func test_caixa_de_pintura() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	var fraco := Carro.new(d.carro("fraco"))
	var forte := Carro.new(d.carro("forte"))
	forte.instalar(d.peca("turbo"))  # o mesmo carro do rival da "licenciado"
	verificar(CaixaPintura.ganha(d, j, d.evento("licenciado"), forte, true), "primeira vitória na licença: caixa")
	verificar(not CaixaPintura.ganha(d, j, d.evento("licenciado"), forte, false), "repetida, com carro forte: nada")
	verificar(not CaixaPintura.ganha(d, j, d.evento("aberto"), fraco, true), "prova aberta com o mesmo carro do rival: nada")
	var aberto_forte: Dictionary = d.evento("serie_1")
	verificar(not CaixaPintura.ganha(d, j, aberto_forte, forte, true), "carro mais forte que o rival: nada")
	verificar(CaixaPintura.ganha(d, j, d.evento("licenciado"), Carro.new(d.carro("fraco")), false),
			"repetida, mas com o carro mais fraco do grid: caixa")
	verificar(not CaixaPintura.liberado(d, j, "rodas", "turbina"), "aro exclusivo trancado")
	verificar(CaixaPintura.liberado(d, j, "rodas", "cinco"), "aro comum livre")
	var n := CaixaPintura.trancados(d, j).size()
	var item := CaixaPintura.abrir(d, j, d.evento("licenciado"), 7)
	verificar(item.has("id") and CaixaPintura.liberado(d, j, String(item["tipo"]), String(item["id"])), "o item sai liberado")
	igual(CaixaPintura.trancados(d, j).size(), n - 1, "um a menos para sair")
	for k in n:
		CaixaPintura.abrir(d, j, d.evento("licenciado"), k)
	var antes: int = j.economia.saldo
	var giros := CaixaPintura.abrir(d, j, d.evento("licenciado"), 1)
	verificar(giros.has("giros") and int(giros["giros"]) > 0 and j.economia.saldo == antes + int(giros["giros"]),
			"nada mais a liberar: um prêmio de 1º da licença em giros")
	j.free()
	d.free()


## Decisão 130 (E6): o piloto de corrida sobe pelo recorde pessoal de volta
## (corrida sem recorde não conta); com o treinador, cada recorde vale fator_xp.
func test_evolucao_pelo_recorde_de_volta() -> void:
	var d := dados_fixture()
	var j := _novo(d)
	j.economia.creditar(1000)
	d.equipe()["treino"]["xp_por_nivel"] = 3
	d.equipe()["treino"]["recordes_por_nivel"] = 2
	d.equipe()["treinador"] = {"preco_premios": 1, "fator_xp": 2, "duracao_h": 24}
	igual(EquipeJogador.contratar(d, j, "livre_1", "corrida"), "", "contrata")
	igual(EquipeJogador.apos_prova(d, j, ["corrida"], false, false), [], "sem recorde: nada")
	igual(EquipeJogador.xp(j, "livre_1"), 0, "sem recorde não soma")
	igual(EquipeJogador.apos_prova(d, j, ["corrida"], false, true), [], "um recorde: ainda não")
	igual(EquipeJogador.apos_prova(d, j, ["corrida"], false, true), ["livre_1"], "dois recordes: sobe")
	igual(EquipeJogador.apos_prova(d, j, ["corrida"], false, true, true), ["livre_1"], "com o treinador, um recorde basta")
	var saldo: int = j.economia.saldo
	var preco := GestaoEquipe.preco_treinador(d, j)
	verificar(preco > 0, "o contrato custa um prêmio de 1º da licença")
	igual(GestaoEquipe.contratar_treinador(d, j, 1000.0), "", "contrata")
	igual(j.economia.saldo, saldo - preco, "paga na hora")
	verificar(GestaoEquipe.contratar_treinador(d, j, 2000.0) != "", "já contratado: não paga de novo")
	verificar(GestaoEquipe.treinador_ativo(j, 1000.0 + 23.0 * 3600.0), "contratado por 24 h")
	verificar(not GestaoEquipe.treinador_ativo(j, 1000.0 + 25.0 * 3600.0), "depois, não")
	d.equipe()["treino"].erase("xp_por_nivel")
	d.equipe()["treino"].erase("recordes_por_nivel")
	d.equipe().erase("treinador")
	j.free()
	d.free()
