extends "res://tests/base_teste.gd"

const JogadorScript := preload("res://autoload/jogador.gd")


func _jogador(d: Node) -> Node:
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000)
	return j


func test_restricoes() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var fraco: Carro = j.garagem.carro(j.concessionaria.comprar_carro(d.carro("fraco")))
	var forte: Carro = j.garagem.carro(j.concessionaria.comprar_carro(d.carro("forte")))
	var r: Dictionary = d.evento("ff_ate_120")["restricoes"]
	igual(Elegibilidade.motivos(fraco, r, []), [], "fraco entra")
	igual(Elegibilidade.motivos(forte, r, []).size(), 2, "forte: tração e potência")
	j.concessionaria.comprar_peca(fraco, d.peca("turbo"))
	igual(Elegibilidade.motivos(fraco, r, []).size(), 1, "turbo passa de 120 cv")
	igual(Elegibilidade.motivos(fraco, {"ano_min": 1991}, []).size(), 1, "ano_min")
	igual(Elegibilidade.motivos(fraco, {"licenca": "b"}, []).size(), 1, "sem licença")
	igual(Elegibilidade.motivos(fraco, {"licenca": "b"}, ["b"]), [], "com licença")
	# Copas de marca: lista de modelos e versão de corrida (rua × corrida).
	igual(Elegibilidade.motivos(fraco, {"carros": ["fraco"], "corrida": false}, []), [], "modelo da copa, de rua")
	igual(Elegibilidade.motivos(forte, {"carros": ["fraco"]}, []).size(), 1, "modelo fora da copa")
	igual(Elegibilidade.motivos(fraco, {"corrida": true}, []).size(), 1, "de rua não entra na copa corrida")
	fraco.pecas["corrida"] = {"id": "kit", "categoria": "corrida", "preco": 0, "efeitos": []}
	igual(Elegibilidade.motivos(fraco, {"corrida": true}, []), [], "com kit entra na copa corrida")
	igual(Elegibilidade.motivos(fraco, {"corrida": false}, []).size(), 1, "com kit sai da copa de rua")
	j.free()
	d.free()


func test_vitoria_paga_premio_e_carro_premio_so_na_primeira() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var c := Carreira.new(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	var saldo: int = j.economia.saldo
	var r1 := c.disputar("aberto", uid, 1)
	igual(r1["posicao"], 1, "forte vence fraco")
	igual(j.economia.saldo, saldo + 500, "prêmio de 1º")
	verificar(r1["carro_premio_uid"] > 0, "carro-prêmio entregue")
	igual(j.garagem.carro(r1["carro_premio_uid"]).id, "forte", "modelo do prêmio")
	var r2 := c.disputar("aberto", uid, 2)
	igual(r2["carro_premio_uid"], -1, "segunda vitória sem carro")
	igual(j.vitorias["aberto"], 2, "vitórias")
	igual(j.dias, 2, "cada corrida é um dia")
	igual(j.garagem.lista().size(), 2, "garagem")
	j.free()
	d.free()


func test_jogador_larga_em_ultimo() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var c := Carreira.new(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	var saldo: int = j.economia.saldo
	var r := c.disputar("aberto", uid, 1)
	igual(r["classificacao"], ["adv0_fraco", "jogador"], "carro igual não passa")
	igual(j.economia.saldo, saldo + 100, "prêmio de 2º")
	verificar(not j.vitorias.has("aberto"), "sem vitória")
	j.free()
	d.free()


func test_inelegivel_nao_corre() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var c := Carreira.new(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	verificar(c.disputar("ff_ate_120", uid, 1).has("erro"), "forte barrado")
	verificar(c.disputar("licenciado", uid, 1).has("erro"), "sem licença barrado")
	verificar(c.disputar("aberto", 999, 1).has("erro"), "carro inexistente")
	igual(j.dias, 0, "nenhuma corrida contada")
	j.free()
	d.free()


func test_adversario_com_pecas_e_pneu_de_chuva() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	j.licencas.append("b")
	var c := Carreira.new(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	var r := c.disputar("licenciado", uid, 1)
	igual(r["classificacao"][0], "adv0_forte", "turbo e pneu de chuva vencem na chuva")
	igual(r["premio"], 5, "prêmio de 2º")
	j.free()
	d.free()


func test_escalacao_por_equipes() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var c := Carreira.new(d, j)
	var g1 := c.escalacao("aberto", 7)
	igual(g1.size(), 1, "uma vaga por adversário")
	igual(g1[0]["equipe"]["id"], "eq_azul", "prova sem licença: equipe do nível N1 primeiro")
	igual(c.escalacao("aberto", 7), g1, "mesma semente, mesmo grid")
	igual(c.escalacao("licenciado", 7)[0]["equipe"]["id"], "eq_verde", "licença b: nível N2")
	var segundos := 0
	for s in 400:
		if c.escalacao("aberto", s)[0]["segundo"]:
			segundos += 1
	verificar(segundos > 90 and segundos < 150, "segundo piloto em ~30%% das corridas (%d/400)" % segundos)
	# O segundo piloto corre com menos consistência; o nome sai da escalação.
	var s2 := 0
	while not c.escalacao("aberto", s2)[0]["segundo"]:
		s2 += 1
	igual(c.nome_piloto("aberto", "adv0_fraco", s2), "Azul Dois", "nome do segundo piloto")
	# Perfil da equipe (fixture: Azul cautelosa, 0,25) e perda do segundo piloto.
	var base := {"ritmo": 1.0, "consistencia": 1.0, "agressividade": 1.0}
	var vaga: Dictionary = c.escalacao("aberto", s2)[0]
	var p := c.piloto_na_vaga(base, vaga)
	perto(float(p["agressividade"]), 0.25, 1e-6, "equipe cautelosa tenta passar menos")
	verificar(float(p["consistencia"]) < 1.0, "segundo piloto com menos consistência")
	perto(float(base["agressividade"]), 1.0, 1e-6, "a base não muda")
	igual(c.nome_piloto("aberto", "adv0_fraco"), Carreira.sobrenome_fixo("aberto", 0), "sem semente: nome fixo")
	j.free()
	d.free()


## Decisão 88: o rival de traço agressivo (pelo perfil, como no mercado) corre
## com menos consistência; o cauteloso não. Dados reais.
func test_traco_do_rival_pelo_perfil() -> void:
	var d: Node = DadosScript.new()
	d.carregar(d.DATA_DIR)
	var j: Node = JogadorScript.new()
	var c := Carreira.new(d, j)
	var base := {"ritmo": 1.0, "consistencia": 1.0, "agressividade": 1.0}
	var eq := {"id": "x", "nome": "X", "perfil": "equilibrado"}
	var agr := c.piloto_na_vaga(base, {"equipe": eq, "piloto": {"id": "a", "nome": "A", "perfil": "agressivo"}, "segundo": false})
	var cau := c.piloto_na_vaga(base, {"equipe": eq, "piloto": {"id": "b", "nome": "B", "perfil": "cauteloso"}, "segundo": false})
	var perda := float(d.carreira()["segundo_piloto"]["perda_consistencia"])
	# Cada piloto tem a sua variação (EquipeJogador.variar): dentro da faixa.
	var faixa: float = EquipeJogador.faixas_variacao(d, 1.0)["consistencia"]
	perto(float(agr["consistencia"]), 1.0 - perda, faixa + 1e-6, "agressivo: menos consistência")
	perto(float(cau["consistencia"]), 1.0, faixa + 1e-6, "cauteloso: consistência inteira")
	verificar(float(agr["consistencia"]) < float(cau["consistencia"]), "o agressivo segue menos consistente")
	var de_novo := c.piloto_na_vaga(base, {"equipe": eq, "piloto": {"id": "a", "nome": "A", "perfil": "agressivo"}, "segundo": false})
	igual(de_novo, agr, "a variação é fixa por piloto")
	j.free()
	d.free()


func test_campeonato_por_pontos() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var c := Carreira.new(d, j)
	var ev := {"nome": "Copa — etapa 1", "premios": [500, 250, 100]}
	igual(Campeonatos.pontos(ev, 1), 10, "1º: 10 pontos")
	igual(Campeonatos.pontos(ev, 2), 5, "2º: proporcional ao prêmio")
	igual(Campeonatos.pontos(ev, 4), 0, "fora dos prêmios: 0")
	igual(Campeonatos.serie(ev), "Copa", "série pelo nome")
	# Série de uma prova só não é campeonato.
	igual(Campeonatos.registrar(c, "aberto", ["jogador", "adv0_fraco"], 1), {}, "prova única: sem campeonato")
	igual(Campeonatos.registrar(c, "serie_2", ["jogador", "adv0_fraco"], 1), {}, "fora da vez não conta")
	var r1: Dictionary = Campeonatos.registrar(c, "serie_1", ["adv0_fraco", "jogador"], 1)
	igual(r1["pontos"], 5, "2º na etapa 1")
	verificar(not r1["final"], "temporada continua")
	var saldo: int = j.economia.saldo
	var r2: Dictionary = Campeonatos.registrar(c, "serie_2", ["jogador", "adv0_fraco"], 2)
	verificar(r2["final"], "última etapa fecha a temporada")
	# 15 pts do jogador; o rival pontua pela equipe de cada corrida.
	igual(int(r2["classificacao_final"][0][1]) >= 15, true, "líder com ao menos 15 pts")
	if r2["campeao"]:
		igual(j.economia.saldo, saldo + 300, "bônus de campeão pago")
		igual(j.titulos.get("Copa Teste", 0), 1, "título registrado")
	verificar(not j.campeonatos.has("Copa Teste"), "temporada recomeça")
	j.free()
	d.free()


func test_historia_escolhe_cena_por_trigger_flags_e_condicao() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var h := Historia.new(d, j)
	igual(h.cena_para("GAME_START"), {}, "sem personagem, sem história")
	j.personagem = "ana"
	var c := h.cena_para("GAME_START")
	igual(c.get("id"), "boas_vindas", "abertura")
	igual(h.cena_para("CORRIDA_FIM", {"posicao": 1}), {}, "exige a flag da abertura")
	var prox := h.concluir(c)
	igual(prox.get("id"), "segue", "cena encadeada")
	verificar(j.flags.has("COMECOU"), "flag gravada")
	igual(h.cena_para("GAME_START"), {}, "uma vez só")
	igual(h.cena_para("CORRIDA_FIM", {"posicao": 2}), {}, "condição de posição")
	igual(h.cena_para("CORRIDA_FIM", {"posicao": 1}).get("id"), "vitoria", "vitória")
	h.concluir(h.cena_para("SEM_DINHEIRO"))
	igual(h.cena_para("SEM_DINHEIRO").get("id"), "sempre", "repetível")
	j.free()
	d.free()


## Chrome & Wreckage: o dono da oficina começa sem carro e sem licença, com o
## saldo inicial; quem corre é o piloto contratado. Cenas valem para
## listas de personagens, comentários de contexto respeitam o intervalo em
## corridas e a condição de quantidade.
func test_campanha_do_dono_e_comentarios() -> void:
	var d := dados_fixture()
	var j: Node = JogadorScript.new()
	igual(Prologo.iniciar(d, j), "", "começa como dono")
	igual(j.personagem, "dono", "personagem")
	igual(j.licencas, [], "sem licença")
	igual(j.garagem.lista().size(), 0, "garagem vazia")
	igual(j.economia.saldo, int(d.economia()["saldo_inicial"]), "saldo inicial da economia")
	igual(Prologo.demanda(d, j), "turbo", "peça da demanda")
	j.carro_ativo = j.concessionaria.comprar_carro(d.carro("fraco"))
	# Decisão 69: o dono administra; quem corre é o piloto de corrida contratado.
	igual(EquipeJogador.nome_jogador(d, j), "Sem piloto", "sem piloto contratado")
	EquipeJogador.criar(j)
	igual(EquipeJogador.contratar(d, j, "livre_1", "corrida"), "", "contrata o piloto de corrida")
	igual(EquipeJogador.nome_jogador(d, j), "Livre Um", "o contratado corre")
	var h := Historia.new(d, j)
	j.historia = h
	j.flags["DUPLA"] = true
	igual(h.cena_para("SEM_DINHEIRO").get("id"), "dupla", "cena com lista de personagens")
	j.personagem = "outro"
	igual(h.cena_para("SEM_DINHEIRO").get("id"), "sempre", "fora da lista, a próxima")
	j.personagem = "dono"
	j.dias = 10
	h.concluir(h.cena_para("CAIXA_BAIXO"))
	igual(j.ultima_reativa, 10, "comentário marca a corrida")
	igual(h.cena_para("CAIXA_BAIXO"), {}, "não repete antes do intervalo")
	j.dias = 13
	igual(h.cena_para("CAIXA_BAIXO").get("id"), "comentario", "volta depois de 3 corridas")
	igual(h.cena_para("COLECAO", {"quantidade": 1}), {}, "coleção abaixo do marco")
	igual(h.cena_para("COLECAO", {"quantidade": 2}).get("id"), "colecao", "marco da coleção")
	igual(h.colecao(), 1, "um modelo na garagem")
	j.economia.saldo = 0
	verificar(h.caixa_baixo(), "sem dinheiro para a peça mais barata")
	j.economia.saldo = 1000000
	verificar(not h.caixa_baixo(), "com dinheiro")
	var precos: Array = d.lista("carros").map(func(c): return int(c["preco"]))
	verificar(h.carro_caro(precos.max() + 1) and not h.carro_caro(precos.min()), "carro caro pelo percentil")
	igual(int(Save.serializar(j).get("ultima_reativa", -1)), 10, "intervalo vai para o save")
	EquipeJogador.criar(j)
	igual(EquipeJogador.dados_equipe(d, j).get("nome"), "Oficina", "nome da equipe da campanha")
	j.free()
	d.free()


## Cenas reais: o jogo novo é a campanha do dono (a única).
## Quem fala na campanha da Wreckage: a Mara, o piloto, o sistema e o pessoal da
## oficina, das lojas, da Vector Academy e da arena (pedido do usuário).
const ELENCO_WRECKAGE := ["mara", "piloto_casa", "sistema", "examinador", "manobrista", "mecanico_arena",
		"organizadora", "pintor", "vendedor_charge_folio", "vendedor_relay_room", "vendedora_brace_yard",
		"vendedora_return_chapter", "vendedora_shared_grid", "vendedor_spare_penny"]


func test_cenas_reais_da_campanha_do_dono() -> void:
	var d: Node = DadosScript.new()
	d.carregar(d.DATA_DIR)
	if d.historia().is_empty():
		d.free()
		return
	igual(Prologo.campanha(d), "dono", "jogo novo é Chrome & Wreckage")
	var j: Node = JogadorScript.new()
	igual(Prologo.iniciar(d, j), "", "começa")
	var h := Historia.new(d, j)
	j.historia = h
	igual(h.cena_para("GAME_START").get("id"), "CW_P01", "abertura da Mara")
	# Decisão 73: a chegada termina pedindo o nome. Decisão 96 (a 85 com o Grid
	# depois da primeira corrida): carro → piloto → corrida → Grid → corrida → peça →
	# corrida → licença → corrida → patrocínio → arena.
	var p01: Dictionary = h.cena_para("GAME_START")
	igual(String(p01["falas"][-1].get("acao", "")), "PEDIR_NOME", "a chegada pede o nome")
	igual(h.concluir(p01), {}, "sem nome, a cena não segue sozinha")
	j.nome_admin = "Ana"
	var p01b: Dictionary = h.cena_para("NOME_DEFINIDO")
	igual(p01b.get("id"), "CW_P01B", "o nome dado")
	igual(h.variaveis().get("admin"), "Ana", "a Mara usa o nome")
	# Gênero do piloto de corrida nas falas: masculina sem piloto.
	igual(h.flexionar("{g:contratado|contratada}."), "contratado.", "sem piloto: masculina")
	var antes = j.pilotos
	j.pilotos = {"corrida": "noor_haddad", "arena": ["", ""]}
	igual(EquipeJogador.genero(d, "noor_haddad"), "f", "Noor é pilota")
	igual(h.flexionar("{piloto} está {g:contratado|contratada}."), "{piloto} está contratada.", "pilota: feminina")
	igual(EquipeJogador.palavra_piloto(d, "noor_haddad"), "pilota", "pilota")
	j.pilotos = antes
	igual(h.concluir(p01b).get("id"), "CW_C00", "primeiro, comprar o carro")
	igual(j.garagem.lista().size(), 0, "a garagem começa vazia")
	igual(h.cena_para("COMPRA_CARRO").get("id"), "CW_C01B", "comprado o carro")
	j.flags["FIRST_CAR"] = true
	igual(h.cena_para("ABA:EQUIPE").get("id"), "CW_P03C", "na Equipe, a Mara pede o piloto")
	verificar(String(h.cena_para("PILOTO_CONTRATADO")["falas"][-1].get("acao", "")) == "HIGHLIGHT_NAV_EVENTOS",
			"contratado, vai para a primeira prova")
	j.flags["PILOT_HIRED"] = true
	igual(h.cena_para("CORRIDA_FIM", {"posicao": 1}).get("id"), "CW_P06", "fim da primeira prova")
	var grid: Dictionary = h.concluir(h.cena_para("CORRIDA_FIM", {"posicao": 1}))
	igual(grid.get("id"), "CW_GR00", "depois da primeira prova, o The Grid")
	igual(h.concluir(grid), {}, "e não abre a Oficina")
	# Da segunda prova em diante, só com o caixa pagando a peça (pedido do usuário).
	var carro := Carro.new(d.lista("carros")[0])
	j.carro_ativo = j.garagem.adicionar(carro)
	j.economia.saldo = 0
	verificar(String(h.cena_para("CORRIDA_FIM", {"posicao": 3}).get("id", "")) != "CW_P06D", "sem caixa, a peça espera")
	j.economia.saldo = 1000000
	var p06d: Dictionary = h.cena_para("CORRIDA_FIM", {"posicao": 3})
	igual(p06d.get("id"), "CW_P06D", "segunda prova com caixa")
	igual(h.concluir(p06d).get("id"), "CW_P02", "e segue para aprimorar o carro")
	j.flags["FIRST_TUNE_DONE"] = true
	igual(h.cena_para("CORRIDA_FIM", {"posicao": 3}).get("id"), "CW_P06C", "segunda prova: a licença")
	j.flags["SECOND_RACE_DONE"] = true
	var r10: Dictionary = h.cena_para("LICENCA_CONCEDIDA:CLUB")
	igual(r10.get("id"), "CW_R10", "licença renovada")
	h.concluir(r10)
	igual(h.cena_para("CORRIDA_FIM", {"posicao": 2}).get("id"), "CW_S00", "corrida com a Club: o patrocínio")
	verificar(h.cena_para("GARAGEM_TRES_CARROS").is_empty(), "a arena espera o patrocínio")
	j.flags["PATROCINIO_INTRO"] = true
	igual(h.cena_para("GARAGEM_TRES_CARROS").get("id"), "CW_P07", "depois, a arena")
	var sem: Dictionary = h.cena_para("SEM_DINHEIRO")
	igual(sem["falas"][0]["quem"], "mara", "sem dinheiro: Mara")
	for c in d.lista("dialogos"):
		if String(c["id"]).begins_with("CW_"):
			for f in c["falas"]:
				verificar(f.get("quem", "mara") in ELENCO_WRECKAGE, "%s: só o elenco da Wreckage" % c["id"])
	j.free()
	d.free()


func test_equipe_folha_e_companheiro() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var c := Carreira.new(d, j)
	j.carreira = c
	j.fila_ctrl = Fila.new(c, j, 3600.0)
	igual(EquipeJogador.folha(d, j), {}, "sem equipe, sem folha")
	EquipeJogador.criar(j)
	igual(EquipeJogador.nome_segundo(d, j), "", "sem segundo piloto antes da cena")
	var saldo: int = j.economia.saldo
	EquipeJogador.liberar_segundo(d, j)
	igual(j.economia.saldo, saldo, "segundo piloto sem contrato")
	j.flags[EquipeJogador.FLAG_ARENA] = true
	igual(EquipeJogador.contratar(d, j, "livre_3", "arena1"), "", "piloto de arena 1")
	igual(EquipeJogador.contratar(d, j, "livre_4", "arena2"), "", "piloto de arena 2")
	igual(EquipeJogador.nome_segundo(d, j), "Livre Quatro", "nome do segundo da dupla")
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	igual(EquipeJogador.companheiro_para(d, j, "aberto", uid), -1, "sem carro escolhido não corre")
	var uid2: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	j.carro_companheiro = uid
	igual(EquipeJogador.companheiro_para(d, j, "aberto", uid), -1, "mesmo carro do piloto não corre")
	j.carro_companheiro = uid2
	igual(EquipeJogador.companheiro_para(d, j, "aberto", uid), uid2, "companheiro com o outro carro")
	# Decisão 68: nas corridas só corre um piloto da equipe.
	igual(j.fila_ctrl.iniciar("aberto", uid, 1, 0.0), "", "corrida")
	verificar(not j.fila.has("companheiro"), "o segundo piloto não corre")
	j.fila["companheiro"] = {"uid": uid2}  # (a pontuação de equipe ainda aceita dois, como em saves antigos)
	var corrida: Dictionary = j.fila_ctrl._preparar(j.fila, false)
	var cl: Array = corrida["resultado"]["classificacao"]
	verificar(EquipeJogador.ID in cl, "companheiro na classificação")
	saldo = j.economia.saldo
	var r := c.aplicar(corrida)
	igual(r["posicao"], mini(cl.find("jogador"), cl.find(EquipeJogador.ID)) + 1, "posição da equipe = a melhor")
	var premio: int = r["premio"]
	igual(r["folha"]["saldo"], 50 - 70, "folha: patrocínio − staff, sem salário")
	igual(j.economia.saldo, saldo + premio + 50 - 70, "prêmio e folha no caixa único")
	verificar(c.rotulo_participante("aberto", EquipeJogador.ID, uid).begins_with("Livre Quatro"), "rótulo do companheiro")
	# Sem dinheiro para a folha: cobra só o que há, sem saldo negativo.
	j.economia.saldo = 10
	var f := EquipeJogador.cobrar_corrida(d, j)
	igual(f["cobrado"], 60, "cobra até o caixa (10 + 50 de patrocínio)")
	igual(j.economia.saldo, 0, "caixa não fica negativo")
	j.free()
	d.free()


func test_cenarios_de_teste_montam() -> void:
	var d := dados_fixture()
	for c in Cenarios.LISTA:
		var j: Node = JogadorScript.new()
		igual(Cenarios.montar(d, j, c["id"]), "", "cenário %s monta" % c["id"])
		match c["id"]:
			"dono_inicio":
				igual(j.personagem, "dono", "dono_inicio: dono")
			"dono_arena":
				verificar(j.garagem.lista().size() >= 2, "arena: 2+ carros")
		j.free()
	var j2: Node = JogadorScript.new()
	igual(Cenarios.montar(d, j2, "nenhum"), "cenário nenhum não existe", "cenário inválido")
	j2.free()
	d.free()


## Decisão 90: save fechado no meio de uma cena; as flags que destravam telas
## voltam do estado real e o passo da chegada que faltou é retomado.
func test_historia_recupera_cena_interrompida() -> void:
	var d: Node = DadosScript.new()
	d.carregar(d.DATA_DIR)
	if d.historia().is_empty():
		d.free()
		return
	var j: Node = JogadorScript.new()
	Prologo.iniciar(d, j)
	var h := Historia.new(d, j)
	j.historia = h
	igual(h.recuperar(), "", "jogo novo: nada a recuperar")
	j.dialogos_vistos["CW_P01"] = true  # fechou no pedido do nome
	igual(h.recuperar(), "nome", "pede o nome de novo")
	j.nome_admin = "Ana"
	igual(h.recuperar(), "nome_definido", "nome dado, falta a conversa")
	j.flags["ADMIN_NAMED"] = true
	igual(h.recuperar(), "", "antes da primeira corrida, o Grid ainda não")
	j.flags["FIRST_RACE_DONE"] = true
	igual(h.recuperar(), "grid", "falta a apresentação do Grid")
	j.flags["GRID_INTRO"] = true
	j.economia.creditar(100000)
	j.concessionaria.comprar_carro(d.lista("carros")[0])  # fechou na cena do carro
	j.licencas.append("CLUB")
	j.licencas.append("INTERNATIONAL")
	igual(h.recuperar(), "", "nada da chegada")
	verificar(j.flags.has("FIRST_CAR") and EquipeJogador.criada(j), "a equipe nasce com o carro")
	verificar(j.flags.has("CLUB_COMPLETE"), "Club pela licença")
	verificar(j.flags.has("GESTAO_LIBERADA"), "Caixa e Sede pela International")
	j.free()
	d.free()


## O desafio de arena do Grid nunca leva o último carro: com a vaga de corrida
## vazia, um carro fica de fora assim mesmo.
func test_arena_do_grid_nao_zera_a_garagem() -> void:
	var d: Node = DadosScript.new()
	d.carregar(d.DATA_DIR)
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(100000)
	for i in 2:
		j.concessionaria.comprar_carro(d.lista("carros")[i])
	igual(GridDesafio.carros_arena(j).size(), 1, "dois carros, sem escalação: só um vai à arena")
	j.free()
	d.free()


## Decisão 96: os comentários do dia a dia se revezam (o visto há mais tempo
## primeiro) e o fim de corrida dá a vez ao marco antes deles.
func test_comentarios_se_revezam_e_marcos_vem_antes() -> void:
	var d: Node = DadosScript.new()
	d.carregar(d.DATA_DIR)
	var j: Node = JogadorScript.new()
	Prologo.iniciar(d, j)
	var h := Historia.new(d, j)
	j.historia = h
	for f in ["GRID_INTRO", "FIRST_RACE_DONE", "FIRST_WIN", "FIRST_LOSS_TALK", "GARAGE_TUTORIAL_SEEN", "ARENA_DEMO_SEEN"]:
		j.flags[f] = true
	var vistos := {}
	for k in 4:
		j.dias = 10 + k * 5  # fora do intervalo entre comentários
		var c := h.cena_para("CORRIDA_FIM", {"posicao": 1})
		verificar(not c.is_empty() and String(c["id"]).begins_with("CW_D"), "um comentário de vitória")
		vistos[c["id"]] = true
		h.concluir(c)
	igual(vistos.size(), 4, "quatro vitórias, quatro falas diferentes")
	j.dias = 100
	var podio := h.cena_para("CORRIDA_FIM", {"posicao": 2})
	verificar(String(podio.get("id", "")) in ["CW_D05", "CW_D06", "CW_D07"], "pódio tem fala própria")
	igual(h.cena_para("CORRIDA_FIM", {"posicao": 2}, false), {}, "sem os comentários, nada no fim comum")
	j.free()
	d.free()


## Decisão 119: PULAR TUTORIAL tira o ensino (cenas tutorial, falas do sistema,
## destaques) e mantém a história; as telas ficam liberadas.
func test_pular_tutorial_tira_o_ensino_e_mantem_a_historia() -> void:
	var d: Node = DadosScript.new()
	d.carregar(d.DATA_DIR)
	if d.historia().is_empty():
		d.free()
		return
	var j: Node = JogadorScript.new()
	Prologo.iniciar(d, j)
	var cenas := {}
	for c in d.lista("dialogos"):
		cenas[c["id"]] = c
	verificar(Tutorial.ensina(cenas["CW_P02"]), "o tour da Oficina ensina")
	verificar(not Tutorial.tem_fala(Tutorial.sem_ensino(cenas["CW_P02"])), "cena só de tutorial: nada a mostrar")
	var c01b := Tutorial.sem_ensino(cenas["CW_C01B"])
	verificar(Tutorial.tem_fala(c01b), "cena de história continua")
	verificar(c01b["falas"].all(func(f): return String(f.get("quem", "")) != "sistema"), "sem a voz do tutorial")
	verificar(c01b["falas"].all(func(f): return not Tutorial.acao_de_ensino(String(f.get("acao", "")))), "sem destaques")
	verificar(c01b["falas"].any(func(f): return f.get("acao", "") == "UNLOCK_TEAM_TAB"), "o desbloqueio fica")
	verificar(not Tutorial.ensina(cenas["CW_GR06"]), "cena do Grid não é tutorial")
	verificar(not Tutorial.pulado(j), "começa com tutorial")
	Tutorial.pular(j)
	verificar(Tutorial.pulado(j), "pulado")
	verificar(EquipeJogador.criada(j), "a equipe existe")
	verificar(j.flags.has("ACELERAR_LIBERADO") and j.flags.has("LICENSE_SYSTEM_UNLOCKED"), "ACELERAR e licenças liberados")
	j.free()
	d.free()


## Decisão 123: série que atravessava licenças vira uma por licença; a Elite
## ganha a Série Resistência, da prova mais curta para a mais longa.
func test_series_por_licenca_e_elite() -> void:
	var d: Node = DadosScript.new()
	d.carregar(d.DATA_DIR)
	for ev in d.lista("eventos"):
		var etapas := Campeonatos.etapas(d, Campeonatos.serie(ev))
		if etapas.is_empty():
			continue
		var lic := String(ev["restricoes"].get("licenca", ""))
		verificar(etapas.all(func(e): return String(e["restricoes"].get("licenca", "")) == lic),
				"%s: todas as etapas na mesma licença" % Campeonatos.serie(ev))
	var elite := Campeonatos.etapas(d, Campeonatos.SERIE_ELITE)
	igual(elite.size(), d.lista("eventos").filter(func(e): return e["restricoes"].get("licenca", "") == "ELITE").size(),
			"todas as provas da Elite na série")
	verificar(int(elite[0]["voltas"]) <= int(elite[-1]["voltas"]), "da mais curta para a mais longa")
	d.free()
