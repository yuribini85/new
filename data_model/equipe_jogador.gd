class_name EquipeJogador
extends RefCounted
## Second Driver Motorsport (fases 8 e 9 do documento de implementação): a
## equipe do jogador nasce na cena SCN_K01 (flag SECOND_DRIVER_CREATED). Criar
## não reseta dinheiro, carros nem licenças; só muda o contexto (aba Equipe).
## A equipe é a de equipes.json com "jogador": true; nome e pilotos vêm de lá.
##
## Gestão leve (decisão 38, carreira.json → equipe_jogador): caixa único (o
## saldo do jogador); a cada corrida entra o patrocínio e saem o staff e o
## salário do segundo piloto. Valores null são pendentes do playtest e valem 0.
## Segundo piloto: contratado entre `contrataveis` depois da cena que libera
## (flag DRIVER_HIRE_UNLOCKED); corre a mesma prova que a Elena como
## companheiro, com o carro da garagem escolhido na aba Equipe, e o piloto do
## jogador com a perda de consistência de segundo piloto (decisão 36).

const FLAG := "SECOND_DRIVER_CREATED"
const FLAG_CONTRATAR := "DRIVER_HIRE_UNLOCKED"
## Id do companheiro na corrida (ao lado de "jogador").
const ID := "companheiro"


static func criada(jogador: Node) -> bool:
	return jogador.flags.has(FLAG)


static func criar(jogador: Node) -> void:
	jogador.flags[FLAG] = true


## Dados da equipe do jogador ({} antes de criada ou sem equipe nos dados).
static func dados_equipe(dados: Node, jogador: Node) -> Dictionary:
	if not criada(jogador):
		return {}
	for e in dados.lista("equipes"):
		if e.get("jogador", false):
			return e
	return {}


static func config(dados: Node) -> Dictionary:
	return dados.carreira().get("equipe_jogador", {})


## Valor da gestão em Cr (0 enquanto pendente do playtest).
static func valor(dados: Node, chave: String) -> int:
	var v = config(dados).get(chave)
	return 0 if v == null else int(v)


static func definido(dados: Node, chave: String) -> bool:
	return config(dados).get(chave) != null


static func pode_contratar(jogador: Node) -> bool:
	return criada(jogador) and jogador.flags.has(FLAG_CONTRATAR) and jogador.segundo_piloto == ""


## Contrata um piloto de `contrataveis`. "" ou o motivo.
static func contratar(dados: Node, jogador: Node, piloto_id: String) -> String:
	if not pode_contratar(jogador):
		return "contratação indisponível"
	if piloto(dados, piloto_id).is_empty():
		return "piloto %s não está disponível" % piloto_id
	if not jogador.economia.debitar(valor(dados, "contratacao_segundo_piloto")):
		return "saldo insuficiente"
	jogador.segundo_piloto = piloto_id
	return ""


static func piloto(dados: Node, piloto_id: String) -> Dictionary:
	for p in config(dados).get("contrataveis", []):
		if p["id"] == piloto_id:
			return p
	return {}


## Nome do segundo piloto contratado ("" se não há).
static func nome_segundo(dados: Node, jogador: Node) -> String:
	return String(piloto(dados, jogador.segundo_piloto).get("nome", ""))


## Carro do companheiro para esta prova (-1 se ele não corre): piloto
## contratado, carro escolhido na garagem, diferente do da Elena e elegível.
static func companheiro_para(dados: Node, jogador: Node, evento_id: String, uid: int) -> int:
	if not criada(jogador) or jogador.segundo_piloto == "":
		return -1
	var cu: int = jogador.carro_companheiro
	var carro: Carro = jogador.garagem.carro(cu)
	if carro == null or cu == uid:
		return -1
	var ev: Dictionary = dados.evento(evento_id)
	if ev.is_empty() or not Elegibilidade.motivos(carro, ev["restricoes"], jogador.licencas).is_empty():
		return -1
	return cu


## Piloto do companheiro: o do jogador com a perda de consistência do segundo piloto.
static func piloto_corrida(dados: Node) -> Dictionary:
	var p: Dictionary = dados.piloto(dados.carreira()["piloto_jogador"]).duplicate()
	var perda := float(dados.carreira().get("segundo_piloto", {}).get("perda_consistencia", 0.0))
	p["consistencia"] = float(p["consistencia"]) * (1.0 - perda)
	return p


## Folha de uma corrida: {patrocinio, staff, salario, saldo} (saldo = líquido).
static func folha(dados: Node, jogador: Node) -> Dictionary:
	if not criada(jogador):
		return {}
	var f := {
		"patrocinio": valor(dados, "patrocinio"),
		"staff": valor(dados, "custo_staff"),
		"salario": valor(dados, "salario_segundo_piloto") if jogador.segundo_piloto != "" else 0,
	}
	f["saldo"] = f["patrocinio"] - f["staff"] - f["salario"]
	return f


## Aplica a folha depois de uma corrida. O caixa não fica negativo: o que
## faltar não é cobrado (gestão leve, sem dívida). Retorna a folha aplicada.
static func cobrar_corrida(dados: Node, jogador: Node) -> Dictionary:
	var f := folha(dados, jogador)
	if f.is_empty():
		return {}
	jogador.economia.creditar(int(f["patrocinio"]))
	var custo: int = mini(int(f["staff"]) + int(f["salario"]), jogador.economia.saldo)
	jogador.economia.debitar(custo)
	f["cobrado"] = custo
	return f
