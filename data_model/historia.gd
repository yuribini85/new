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
## EVENTO_SELECIONADO, CAMPEONATO_SELECIONADO, CORRIDA_INICIO, CORRIDA_FIM
## (contexto posicao), CORRIDA_CONTRA:<piloto>, EVENTO_BLOQUEADO, LICENCA_EXIGIDA,
## LICENCA_DISPONIVEL:<id>, LICENCA_TREINO_INICIO, LICENCA_PRONTA,
## LICENCA_CONCEDIDA:<id>, COMPRA_CARRO, PECA_COMPRADA, DEMANDA_CONCLUIDA (a peça
## da demanda do prólogo comprada), GARAGEM_DOIS_CARROS,
## CAMPEONATO_VENCIDO, SEM_DINHEIRO, POTENCIA_ACIMA, LICENCA_EM_TREINO,
## COMPRA_CARRO_CARA, CAIXA_BAIXO, COLECAO (contexto quantidade),
## GARAGEM_AMPLIADA e os do
## prólogo (ULTIMA_CORRIDA_ADRIAN, RADIO_ULTIMA_CORRIDA, ACIDENTE, POS_ACIDENTE).
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


## Primeira cena que vale para o trigger ({} se nenhuma).
func cena_para(trigger: String, ctx: Dictionary = {}) -> Dictionary:
	if not ativa() or trigger in ["ENCADEADA", "LEMBRETE"]:
		return {}
	for c in dados.lista("dialogos"):
		if c["trigger"] == trigger and vale(c, ctx):
			return c
	return {}


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
	return true


## Pede a cena do trigger. true se uma cena foi pedida (quem chamou pode
## esperar por ela, como a inscrição que vira tutorial).
func disparar(trigger: String, ctx: Dictionary = {}) -> bool:
	var c := cena_para(trigger, ctx)
	if c.is_empty():
		return false
	var com_ctx := c.duplicate()
	com_ctx["_ctx"] = ctx
	cena.emit(com_ctx)
	return true


## Variáveis das falas ({saldo}, {carro}, {evento}, {serie}, {pista}, {voltas},
## {premio}, {posicao}, {peca}, {demanda}, {piloto}): o estado do jogo e o contexto do trigger
## (evento = id da prova, posicao, peca, carro). As falas mostram o que o
## jogador vê na tela, nunca um número inventado.
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
	for k in ["peca", "carro"]:
		if ctx.has(k):
			v[k] = String(ctx[k])
	return v


## Cena terminada: marca como vista e grava as flags. Retorna a próxima ({} se não há).
func concluir(c: Dictionary) -> Dictionary:
	jogador.dialogos_vistos[c["id"]] = true
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
