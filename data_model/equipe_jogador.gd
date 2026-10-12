class_name EquipeJogador
extends RefCounted
## Second Driver Motorsport (fases 8 e 9 do documento de implementação): a
## equipe do jogador nasce na cena SCN_K01 (flag SECOND_DRIVER_CREATED). Criar
## não reseta dinheiro, carros nem licenças; só muda o contexto (aba Equipe).
## A equipe é a de equipes.json com "jogador": true; nome e pilotos vêm de lá.
##
## Gestão leve (decisão 38, carreira.json → equipe_jogador): caixa único (o
## saldo do jogador); a cada corrida entra o patrocínio e sai o staff. Valores
## null são pendentes do playtest e valem 0.
## Segundo piloto (`segundo_piloto` nos dados): sem contrato nem salário; entra
## na equipe na cena que libera (flag DRIVER_HIRE_UNLOCKED) e só aparece na
## prova, com o carro da garagem escolhido na aba Equipe e o piloto do jogador
## com a perda de consistência de segundo piloto (decisão 36). Os ganhos são
## da equipe: vale quem chegar na frente e os dois pontuam no campeonato.

const FLAG := "SECOND_DRIVER_CREATED"
const FLAG_CONTRATAR := "DRIVER_HIRE_UNLOCKED"
## Decisão 69: o jogador administra; quem pilota é contratado. Vagas de piloto:
## uma de corrida e duas de arena (jogador.pilotos). Os de arena abrem com o
## tutorial da arena (3 carros na garagem).
const VAGAS_PILOTO := ["corrida", "arena1", "arena2"]
const NOMES_VAGA := {"corrida": "PILOTO DE CORRIDA", "arena1": "PILOTO DE ARENA 1", "arena2": "PILOTO DE ARENA 2"}
const FLAG_ARENA := "ARENA_PILOTS_UNLOCKED"
## Id do companheiro na corrida (ao lado de "jogador").
const ID := "companheiro"


static func criada(jogador: Node) -> bool:
	return jogador.flags.has(FLAG)


static func criar(jogador: Node) -> void:
	jogador.flags[FLAG] = true


## Dados da equipe do jogador ({} antes de criada ou sem equipe nos dados). A
## campanha pode trocar nome e logo (historia.json → <personagem>.equipe; logo
## "" = o nome em texto).
static func dados_equipe(dados: Node, jogador: Node) -> Dictionary:
	if not criada(jogador):
		return {}
	for e in dados.lista("equipes"):
		if e.get("jogador", false):
			var troca: Dictionary = dados.historia().get(String(jogador.personagem), {}).get("equipe", {})
			var r: Dictionary = e.duplicate()
			r.merge(troca, true)
			# A identidade escolhida pelo jogador (nome e logo, independentes).
			if String(jogador.identidade.get("nome", "")) != "":
				r["nome"] = IdentidadeEquipe.nome(dados, jogador)
			if IdentidadeEquipe.logo(jogador) != "":
				r["logo"] = IdentidadeEquipe.arquivo_logo(IdentidadeEquipe.logo(jogador))
				r["subtitulo"] = true  # o emblema não traz o nome
			return r
	return {}


static func config(dados: Node) -> Dictionary:
	return dados.carreira().get("equipe_jogador", {})


## Valor da gestão em G (0 enquanto pendente do playtest).
static func valor(dados: Node, chave: String) -> int:
	var v = config(dados).get(chave)
	return 0 if v == null else int(v)


static func definido(dados: Node, chave: String) -> bool:
	return config(dados).get(chave) != null


## Segundo piloto entra na equipe (ação da cena que libera). Sem custo.
static func liberar_segundo(dados: Node, jogador: Node) -> void:
	jogador.flags[FLAG_CONTRATAR] = true
	if criada(jogador) and jogador.segundo_piloto == "":
		jogador.segundo_piloto = String(config(dados).get("segundo_piloto", {}).get("id", ""))


static func piloto(dados: Node, piloto_id: String) -> Dictionary:
	if piloto_id == "":
		return {}
	for c in candidatos(dados):
		if c.get("id") == piloto_id:
			return c
	var p: Dictionary = config(dados).get("segundo_piloto", {})
	return p if p.get("id") == piloto_id else {}


## Candidatos a segundo piloto (decisão 56): {id, nome, retrato, traco, frase}.
static func candidatos(dados: Node) -> Array:
	return config(dados).get("candidatos", [])


## Traço do candidato: {nome, treina}.
static func traco(dados: Node, piloto_id: String) -> Dictionary:
	return config(dados).get("tracos", {}).get(String(piloto(dados, piloto_id).get("traco", "")), {})


## Tipo do candidato: "corrida" ou "arena" (carreira.json → candidatos).
static func tipo(dados: Node, piloto_id: String) -> String:
	return String(piloto(dados, piloto_id).get("tipo", "corrida"))


## Piloto contratado na vaga ("" = vaga vazia).
static func piloto_vaga(jogador: Node, vaga: String) -> String:
	var p: Dictionary = jogador.pilotos
	if vaga == "corrida":
		return String(p.get("corrida", ""))
	var a: Array = p.get("arena", ["", ""])
	return String(a[0 if vaga == "arena1" else 1]) if a.size() == 2 else ""


static func vaga_do_piloto(jogador: Node, piloto_id: String) -> String:
	for v in VAGAS_PILOTO:
		if piloto_id != "" and piloto_vaga(jogador, v) == piloto_id:
			return v
	return ""


## As vagas de arena só abrem com o tutorial da arena (3 carros).
static func vaga_aberta(jogador: Node, vaga: String) -> bool:
	return criada(jogador) and (vaga == "corrida" or jogador.flags.has(FLAG_ARENA))


## Contrata o candidato para a vaga (o tipo tem de bater). "" ou o motivo.
static func contratar(dados: Node, jogador: Node, piloto_id: String, vaga := "corrida") -> String:
	if not vaga in VAGAS_PILOTO:
		return "vaga desconhecida"
	if not vaga_aberta(jogador, vaga):
		return "a equipe ainda não contrata" if not criada(jogador) else "os pilotos de arena chegam com a arena"
	if not candidatos(dados).any(func(c): return c.get("id") == piloto_id):
		return "candidato desconhecido"
	var quer := "corrida" if vaga == "corrida" else "arena"
	if tipo(dados, piloto_id) != quer:
		return "%s é piloto de %s" % [String(piloto(dados, piloto_id).get("nome", piloto_id)), tipo(dados, piloto_id)]
	var em := vaga_do_piloto(jogador, piloto_id)
	if em != "" and em != vaga:
		return "já está na equipe"
	var p: Dictionary = jogador.pilotos.duplicate(true)
	if vaga == "corrida":
		p["corrida"] = piloto_id
	else:
		var a: Array = p.get("arena", ["", ""])
		if a.size() != 2:
			a = ["", ""]
		a[0 if vaga == "arena1" else 1] = piloto_id
		p["arena"] = a
	jogador.pilotos = p
	return ""


## Save antigo: o segundo piloto vai para a vaga do tipo dele; quem já viu a
## arena ou passou da International mantém o que tinha.
static func migrar(dados: Node, jogador: Node) -> void:
	if jogador.flags.has("ARENA_INTRO"):
		jogador.flags[FLAG_ARENA] = true
	if exige_piloto(jogador) and jogador.flags.has("INTERNATIONAL_COMPLETE"):
		jogador.flags["GESTAO_LIBERADA"] = true
	if not jogador.pilotos.is_empty():
		return
	jogador.pilotos = {"corrida": "", "arena": ["", ""]}
	var s := String(jogador.segundo_piloto)
	if s != "" and not piloto(dados, s).is_empty():
		if tipo(dados, s) == "corrida":
			jogador.pilotos["corrida"] = s
		else:
			jogador.pilotos["arena"] = [s, ""]


## Na campanha do dono a equipe precisa do piloto de corrida para correr.
static func exige_piloto(jogador: Node) -> bool:
	return String(jogador.personagem) == "dono"


## Nome de quem pilota nas corridas: o piloto de corrida contratado; sem ele, o
## personagem da história (Adrian, Elena) ou "Você" em jogo sem história.
static func nome_jogador(dados: Node, jogador: Node) -> String:
	var contratado := piloto_vaga(jogador, "corrida")
	if contratado != "":
		return String(piloto(dados, contratado).get("nome", contratado))
	if exige_piloto(jogador):
		return "Sem piloto"
	var id := Prologo.piloto(dados, jogador)
	if id == "":
		id = String(jogador.personagem)
	if id != "" and dados.existe("personagens", id):
		return String(dados.item("personagens", id)["nome"])
	return "Você"


## Nome do piloto de arena da vaga ("" se vazia).
static func nome_arena(dados: Node, jogador: Node, vaga: String) -> String:
	var id := piloto_vaga(jogador, vaga)
	return String(piloto(dados, id).get("nome", id)) if id != "" else ""


## Nome do segundo piloto da dupla da arena ("" se ainda não há).
static func nome_segundo(dados: Node, jogador: Node) -> String:
	return nome_arena(dados, jogador, "arena2")


## Carro do companheiro para esta prova (-1 se ele não corre): piloto
## na equipe, carro escolhido na garagem, diferente do da Elena e elegível.
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


## Piloto do jogador nas corridas: o de carreira.json com o treino da equipe
## (GestaoEquipe: ritmo até o teto da licença).
static func piloto_do_jogador(dados: Node, jogador: Node) -> Dictionary:
	var p: Dictionary = dados.piloto(dados.carreira()["piloto_jogador"]).duplicate()
	if jogador != null:
		p["ritmo"] = GestaoEquipe.ritmo(dados, jogador, float(p["ritmo"]))
	return p


## Piloto do companheiro: o do jogador com a perda de consistência do segundo
## piloto; o treino é do piloto principal, salvo o traço que treina junto
## (Promessa).
static func piloto_corrida(dados: Node, jogador: Node = null) -> Dictionary:
	var treina: bool = jogador != null and bool(traco(dados, piloto_vaga(jogador, "arena2")).get("treina", false))
	var p: Dictionary = piloto_do_jogador(dados, jogador if treina else null)
	var perda := float(dados.carreira().get("segundo_piloto", {}).get("perda_consistencia", 0.0))
	p["consistencia"] = float(p["consistencia"]) * (1.0 - perda)
	return p


## Folha de uma corrida: {patrocinio, staff, saldo} (saldo = líquido).
static func folha(dados: Node, jogador: Node) -> Dictionary:
	if not criada(jogador):
		return {}
	var f := {
		"patrocinio": valor(dados, "patrocinio"),
		"staff": valor(dados, "custo_staff"),
	}
	f["saldo"] = f["patrocinio"] - f["staff"]
	return f


## Aplica a folha depois de uma corrida. O caixa não fica negativo: o que
## faltar não é cobrado (gestão leve, sem dívida). Retorna a folha aplicada.
static func cobrar_corrida(dados: Node, jogador: Node) -> Dictionary:
	var f := folha(dados, jogador)
	if f.is_empty():
		return {}
	jogador.economia.creditar(int(f["patrocinio"]))
	var custo: int = mini(int(f["staff"]), jogador.economia.saldo)
	jogador.economia.debitar(custo)
	f["cobrado"] = custo
	return f
