class_name Historia
extends RefCounted
## História como camada de dados (decisão 32): cenas de data/dialogos.json
## (gerado de tools/historia/cenas.txt) disparadas por triggers do jogo. Uma cena
## vale para o trigger quando o personagem jogável bate (um ou uma lista), as flags exigidas estão
## no jogador, as proibidas não, a condição do contexto bate e, se é de uma vez
## só, ainda não foi vista. A primeira que vale, na ordem do arquivo, é mostrada.
## Sem personagem (saves de antes da história), nada dispara.
##
## Triggers: GAME_START, ABA:<GARAGEM|LOJA|OFICINA|EVENTOS|CORRIDA|LICENCAS|EQUIPE>, EVOLUCAO (janela
## de compra de uma categoria da Evolução, na Garagem),
## EVENTO_SELECIONADO, CAMPEONATO_SELECIONADO, CORRIDA_INICIO, CORRIDA_EM_CURSO (corrida já
## andando, aba Corrida aberta), CORRIDA_FIM
## (contexto posicao), CORRIDA_CONTRA:<piloto>, EVENTO_BLOQUEADO, LICENCA_EXIGIDA,
## LICENCA_DISPONIVEL:<id>, LICENCA_TREINO_INICIO,
## LICENCA_CONCEDIDA:<id>, COMPRA_CARRO, PECA_COMPRADA, DEMANDA_CONCLUIDA (a peça
## da demanda do prólogo comprada), GARAGEM_DOIS_CARROS,
## CAMPEONATO_VENCIDO, SEM_DINHEIRO, POTENCIA_ACIMA, LICENCA_EM_TREINO,
## COMPRA_CARRO_CARA, CAIXA_BAIXO, COLECAO (contexto quantidade),
## VITORIA_LICENCA:<id> e VITORIA (quantidade; ver disparar_fim),
## ARENA_INSCRICAO, ARENA_FIM, ARENA_VITORIA, ARENA_PERDA,
## GARAGEM_AMPLIADA, GARAGEM_ABERTA (janela Garagem), PINTURA e PINTURA_APLICADA,
## LOJA:<workshop>, BLINDAGEM (janela da blindagem) e BLINDAGEM_COMPRADA,
## GRID_SUBIU (contexto equipe, posicao_grid), GRID_TOPO, SEM_PECAS, NOME_DEFINIDO
## (o nome do administrador dado na abertura).
## ENCADEADA: só vem pela "proxima" de outra cena; LEMBRETE: só pelo "lembrete"
## de outra (a interface mostra se o jogador demorar e a cena ainda valer).

## Uma cena pedida: a interface (principal.gd) mostra.
signal cena(c: Dictionary)

var dados: Node
var jogador: Node


func _init(dados_: Node, jogador_: Node) -> void:
	dados = dados_
	jogador = jogador_


func ativa() -> bool:
	return String(jogador.personagem) != ""


## Primeira cena que vale para o trigger ({} se nenhuma). Comentários de
## contexto (repetíveis e reativos) do mesmo trigger se revezam: vale o da vez
## entre os que valem agora, para a mesma fala não voltar sempre.
## `reativas`: false deixa de fora os comentários (o fim de corrida dá a vez
## aos marcos antes deles).
func cena_para(trigger: String, ctx: Dictionary = {}, reativas := true) -> Dictionary:
	if not ativa() or trigger in ["ENCADEADA", "LEMBRETE"]:
		return {}
	var rodizio := []
	for c in dados.lista("dialogos"):
		if c["trigger"] != trigger or not vale(c, ctx):
			continue
		if not _comentario(c):
			if rodizio.is_empty():
				return c
			continue
		if reativas:
			rodizio.append(c)
	if rodizio.is_empty():
		return {}
	# O visto há mais tempo (nunca visto primeiro; empate: a ordem do arquivo).
	var melhor: Dictionary = rodizio[0]
	for c in rodizio:
		if _visto_em(c) < _visto_em(melhor):
			melhor = c
	return melhor


## Corrida (jogador.dias) em que o comentário foi visto pela última vez; -1 nunca.
func _visto_em(c: Dictionary) -> int:
	var v = jogador.dialogos_vistos.get(c["id"], -1)
	return int(v) if v is int or v is float else -1


static func _comentario(c: Dictionary) -> bool:
	return c.get("reativa", false) and not c.get("uma_vez", true)


func vale(c: Dictionary, ctx: Dictionary = {}) -> bool:
	var quem = c.get("personagem")
	if quem != null and not (jogador.personagem in quem if quem is Array else quem == jogador.personagem):
		return false
	if c.get("reativa", false) and jogador.dias - jogador.ultima_reativa < intervalo_reativas():
		return false
	if c.get("uma_vez", true) and jogador.dialogos_vistos.has(c["id"]):
		return false
	if not c.get("requer", []).all(func(f): return jogador.flags.has(f)):
		return false
	if c.get("proibe", []).any(func(f): return jogador.flags.has(f)):
		return false
	var cond: Dictionary = c.get("condicao", {})
	if cond.has("quantidade_min") and int(ctx.get("quantidade", -1)) < int(cond["quantidade_min"]):
		return false
	if cond.has("posicao") and int(ctx.get("posicao", -1)) != int(cond["posicao"]):
		return false
	if cond.has("posicao_min") and int(ctx.get("posicao", -1)) < int(cond["posicao_min"]):
		return false
	if cond.has("posicao_max") and (not ctx.has("posicao") or int(ctx["posicao"]) > int(cond["posicao_max"])):
		return false
	# demanda_paga:1 — o caixa já paga a peça que a Mara pede (o tutorial da
	# Oficina não manda comprar o que não dá).
	if cond.has("demanda_paga") and not demanda_paga():
		return false
	return true


func demanda_paga() -> bool:
	var d := Prologo.demanda(dados, jogador)  # já sem as peças que o carro tem
	return dados.existe("pecas", d) and jogador.economia.pode_pagar_peca(int(dados.peca(d)["preco"]), false)


## Pede a cena do trigger. true se uma cena foi pedida (quem chamou pode
## esperar por ela, como a inscrição que vira tutorial).
func disparar(trigger: String, ctx: Dictionary = {}) -> bool:
	return _pedir(cena_para(trigger, ctx), ctx)


func _pedir(c: Dictionary, ctx: Dictionary) -> bool:
	if c.is_empty():
		return false
	var com_ctx := c.duplicate()
	com_ctx["_ctx"] = ctx
	cena.emit(com_ctx)
	return true


## The Grid: uma equipe ficou para trás (`e` = a equipe de equipes.json);
## no topo, a fala do topo.
func disparar_grid(e: Dictionary, dados_: Node) -> bool:
	if e.is_empty():
		return false
	var pos: int = TheGrid.posicao(dados_, jogador)
	var ctx := {"equipe": String(e["nome"]), "posicao_grid": pos, "posicao": pos}
	if pos == 1 and disparar("GRID_TOPO", ctx):
		return true
	return disparar("GRID_SUBIU", ctx)


## Fim de corrida: a conversa da chegada (CORRIDA_FIM) ou, sem ela, numa
## vitória inédita, um marco: a primeira vitória numa licença
## (VITORIA_LICENCA:<id>) ou o total de provas vencidas (VITORIA, contexto
## quantidade). Uma conversa só. `antes`: as vitórias antes desta corrida.
func disparar_fim(posicao: int, evento_id: String, antes: Dictionary) -> bool:
	var ctx := {"posicao": posicao, "evento": evento_id}
	if _pedir(cena_para("CORRIDA_FIM", ctx, false), ctx):
		return true
	if posicao == 1 and not antes.has(evento_id) and dados.existe("eventos", evento_id):
		var lic := String(dados.evento(evento_id)["restricoes"].get("licenca", ""))
		var mesma := func(e) -> bool:
			return dados.existe("eventos", e) and String(dados.evento(e)["restricoes"].get("licenca", "")) == lic
		if lic != "" and not antes.keys().any(mesma):
			if disparar("VITORIA_LICENCA:" + lic, ctx):
				return true
		var q := ctx.duplicate()
		q["quantidade"] = jogador.vitorias.size()
		if disparar("VITORIA", q):
			return true
	# Sem cena nem marco: um comentário de contexto (no máximo um a cada
	# reativa_intervalo_corridas corridas), para a Mara não sumir entre os marcos.
	return disparar("CORRIDA_FIM", ctx)


## Variáveis das falas ({saldo}, {carro}, {evento}, {serie}, {pista}, {voltas},
## {premio}, {posicao}, {peca}, {demanda}, {piloto}, {admin}): o estado do jogo e o contexto do trigger
## (evento = id da prova, posicao, peca, carro). As falas mostram o que o
## jogador vê na tela, nunca um número inventado.
## Flexão de gênero nas falas: "{g:contratado|contratada}" vira a forma do
## gênero do piloto de corrida contratado ({piloto}); sem ele, a masculina.
## Fica antes de `format` (as chaves com ":" não são variáveis).
func flexionar(texto: String) -> String:
	if not "{g:" in texto:
		return texto
	var id := EquipeJogador.piloto_vaga(jogador, "corrida")
	var g := EquipeJogador.genero(dados, id) if id != "" else "m"
	var re := RegEx.create_from_string("\\{g:([^|}]*)\\|([^}]*)\\}")
	var saida := texto
	for m in re.search_all(texto):
		saida = saida.replace(m.get_string(0), m.get_string(2) if g == "f" else m.get_string(1))
	return saida


func variaveis(ctx: Dictionary = {}) -> Dictionary:
	var v := {"saldo": Aba.dinheiro(jogador.economia.saldo) + " giros"}
	var c: Carro = jogador.garagem.carro(jogador.carro_ativo) if jogador.garagem != null else null
	if c != null:
		v["carro"] = String(c.base["nome"])
	var ev_id := String(ctx.get("evento", ""))
	if ev_id == "" and not jogador.fila.is_empty():
		ev_id = String(jogador.fila.get("evento_id", ""))
	if ev_id != "" and dados.existe("eventos", ev_id):
		var ev: Dictionary = dados.evento(ev_id)
		v["evento"] = String(ev["nome"])
		v["serie"] = Campeonatos.serie(ev)
		v["pista"] = Aba.nome_pista(String(ev["pista"]))
		v["voltas"] = str(int(ev["voltas"]))
		if not ev.get("premios", []).is_empty():
			v["premio"] = Aba.dinheiro(int(ev["premios"][0])) + " giros"
	if ctx.has("posicao"):
		v["posicao"] = "%dº" % int(ctx["posicao"])
	# A peça da primeira demanda do prólogo (historia.json → <personagem>.peca_demanda).
	var demanda := Prologo.demanda(dados, jogador)
	if dados.existe("pecas", demanda):
		v["demanda"] = String(dados.peca(demanda)["nome"])
	v["piloto"] = EquipeJogador.nome_jogador(dados, jogador)
	v["admin"] = String(jogador.nome_admin) if String(jogador.nome_admin) != "" else "chefe"
	for k in ["peca", "carro", "equipe"]:
		if ctx.has(k):
			v[k] = String(ctx[k])
	if ctx.has("posicao_grid"):
		v["posicao_grid"] = "#%d" % int(ctx["posicao_grid"])
	return v


## Save fechado no meio de uma cena (decisão 90): as flags só são gravadas no
## fim da cena, e as que destravam telas viriam de gatilhos que não se repetem.
## Aqui elas saem do estado real (carro, piloto, licenças). Devolve o passo da
## chegada que ficou para trás: "nome" (pedir o nome), "nome_definido" (o nome
## foi dado, falta a conversa seguinte), "grid" (a apresentação do Grid) ou "".
func recuperar() -> String:
	if String(jogador.personagem) != "dono":
		return ""
	var f: Dictionary = jogador.flags
	if jogador.garagem != null and not jogador.garagem.lista().is_empty() and not f.has("FIRST_CAR"):
		f["FIRST_CAR"] = true
		EquipeJogador.criar(jogador)
	if EquipeJogador.piloto_vaga(jogador, "corrida") != "":
		f["PILOT_HIRED"] = true
	if "CLUB" in jogador.licencas:
		f["CLUB_COMPLETE"] = true
	if "INTERNATIONAL" in jogador.licencas:
		f["INTERNATIONAL_COMPLETE"] = true
		f["GESTAO_LIBERADA"] = true
	if f.has("FIRST_TUNE_DONE"):
		f["GARAGE_TUTORIAL_SEEN"] = true
	if jogador.dialogos_vistos.has("CW_P01") and not f.has("ADMIN_NAMED"):
		return "nome" if String(jogador.nome_admin) == "" else "nome_definido"
	# Decisão 96: o Grid vem depois da primeira corrida.
	if f.has("ADMIN_NAMED") and f.has("FIRST_RACE_DONE") and not f.has("GRID_INTRO"):
		return "grid"
	return ""


## Abre uma cena pelo id (a que ficou para trás em recuperar); false se ela não vale.
func abrir(id: String) -> bool:
	if not dados.existe("dialogos", id):
		return false
	var c: Dictionary = dados.item("dialogos", id)
	if jogador.dialogos_vistos.has(id) and not c.get("repetivel", false):
		return false
	cena.emit(c)
	return true


## Cena terminada: marca como vista e grava as flags. Retorna a próxima ({} se não há).
func concluir(c: Dictionary) -> Dictionary:
	# Comentário de contexto: guarda a corrida em que foi visto (o rodízio).
	jogador.dialogos_vistos[c["id"]] = jogador.dias if _comentario(c) else true
	if c.get("reativa", false):
		jogador.ultima_reativa = jogador.dias
	for f in c.get("flags", []):
		jogador.flags[f] = true
	if c.get("proxima") != null and dados.existe("dialogos", c["proxima"]):
		return dados.item("dialogos", c["proxima"])
	return {}


## Modelos diferentes na garagem (a coleção, como na Carreira).
func colecao() -> int:
	var ids := {}
	for c in jogador.garagem.lista():
		ids[c.id] = true
	return ids.size()


## Compra de carro cara: o preço passa do percentil `carro_caro_percentil`
## dos preços do catálogo (historia.json).
func carro_caro(preco: int) -> bool:
	var precos := []
	for c in dados.lista("carros"):
		precos.append(int(c.get("preco", 0)))
	if precos.is_empty():
		return false
	precos.sort()
	var p := clampf(float(dados.historia().get("carro_caro_percentil", 1.0)), 0.0, 1.0)
	return preco > int(precos[mini(int(p * precos.size()), precos.size() - 1)])


## Caixa baixo (critério do usuário): o saldo não paga nem a peça mais barata
## que o carro em uso ainda não tem.
func caixa_baixo() -> bool:
	var c: Carro = jogador.garagem.carro(jogador.carro_ativo) if jogador.garagem != null else null
	if c == null:
		return false
	var mais_barata := -1
	for p in dados.lista("pecas"):
		var permitidos: Array = p.get("carros_permitidos", [])
		if p["id"] in c.pecas_possuidas or (not permitidos.is_empty() and not c.id in permitidos):
			continue
		if mais_barata < 0 or int(p["preco"]) < mais_barata:
			mais_barata = int(p["preco"])
	return mais_barata > 0 and not jogador.economia.pode_pagar(mais_barata)


## Corridas entre dois comentários de contexto (cenas reativa=sim).
func intervalo_reativas() -> int:
	return int(dados.historia().get("reativa_intervalo_corridas", 3))


func personagem(id: String) -> Dictionary:
	return dados.item("personagens", id) if dados.existe("personagens", id) else {}
