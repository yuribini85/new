class_name Historia
extends RefCounted
## História como camada de dados (decisão 32): cenas de data/dialogos.json
## (gerado de tools/historia/cenas.txt) disparadas por triggers do jogo. Uma cena
## vale para o trigger quando o personagem jogável bate, as flags exigidas estão
## no jogador, as proibidas não, a condição do contexto bate e, se é de uma vez
## só, ainda não foi vista. A primeira que vale, na ordem do arquivo, é mostrada.
## Sem personagem (saves de antes da história), nada dispara.
##
## Triggers: GAME_START, ABA:<GARAGEM|LOJA|OFICINA|EVENTOS|CORRIDA|LICENCAS|EQUIPE>,
## EVENTO_SELECIONADO, CAMPEONATO_SELECIONADO, CORRIDA_INICIO, CORRIDA_FIM
## (contexto posicao), CORRIDA_CONTRA:<piloto>, EVENTO_BLOQUEADO, LICENCA_EXIGIDA,
## LICENCA_DISPONIVEL:<id>, LICENCA_TREINO_INICIO, LICENCA_PRONTA,
## LICENCA_CONCEDIDA:<id>, COMPRA_CARRO, PECA_COMPRADA, DEMANDA_CONCLUIDA (a peça
## da demanda do prólogo comprada), GARAGEM_DOIS_CARROS,
## CAMPEONATO_VENCIDO, SEM_DINHEIRO, POTENCIA_ACIMA, LICENCA_EM_TREINO e os do
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
	if c.get("personagem") != null and c["personagem"] != jogador.personagem:
		return false
	if c.get("uma_vez", true) and jogador.dialogos_vistos.has(c["id"]):
		return false
	if not c.get("requer", []).all(func(f): return jogador.flags.has(f)):
		return false
	if c.get("proibe", []).any(func(f): return jogador.flags.has(f)):
		return false
	var cond: Dictionary = c.get("condicao", {})
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
## {premio}, {posicao}, {peca}, {demanda}): o estado do jogo e o contexto do trigger
## (evento = id da prova, posicao, peca, carro). As falas mostram o que o
## jogador vê na tela, nunca um número inventado.
func variaveis(ctx: Dictionary = {}) -> Dictionary:
	var v := {"saldo": Aba.dinheiro(jogador.economia.saldo) + " G"}
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
			v["premio"] = Aba.dinheiro(int(ev["premios"][0])) + " G"
	if ctx.has("posicao"):
		v["posicao"] = "%dº" % int(ctx["posicao"])
	# A peça da primeira demanda do prólogo (historia.json → adrian.peca_demanda).
	var demanda := String(dados.historia().get("adrian", {}).get("peca_demanda", ""))
	if dados.existe("pecas", demanda):
		v["demanda"] = String(dados.peca(demanda)["nome"])
	for k in ["peca", "carro"]:
		if ctx.has(k):
			v[k] = String(ctx[k])
	return v


## Cena terminada: marca como vista e grava as flags. Retorna a próxima ({} se não há).
func concluir(c: Dictionary) -> Dictionary:
	jogador.dialogos_vistos[c["id"]] = true
	for f in c.get("flags", []):
		jogador.flags[f] = true
	if c.get("proxima") != null and dados.existe("dialogos", c["proxima"]):
		return dados.item("dialogos", c["proxima"])
	return {}


func personagem(id: String) -> Dictionary:
	return dados.item("personagens", id) if dados.existe("personagens", id) else {}
