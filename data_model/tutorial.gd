class_name Tutorial
extends RefCounted
## O tutorial como camada à parte da história (decisão 119, pedido dos
## testadores): o ensino são as cenas marcadas `tutorial` (cenas.txt
## tutorial=sim), as falas do "sistema" (a voz do tutorial, que na tela leva o
## rótulo TUTORIAL) e as ações que mostram ou abrem algo no jogo (destaques,
## telas). PULAR TUTORIAL, com um toque, tira todo o ensino de uma vez e libera
## as telas que o tutorial apresentaria; a história (falas dos personagens,
## Grid, licenças, arena) segue igual.

const FLAG_PULADO := "TUTORIAL_PULADO"
## Cor do que é tutorial (rótulo, faixa e botão): fora da paleta da história,
## que usa o ocre e a cor de cada personagem.
const COR := Color(0.36, 0.78, 0.95)
## Flags que as telas leem para se mostrar e que só o tutorial daria.
const FLAGS_LIBERADAS := ["GARAGE_TUTORIAL_SEEN", "LICENSE_SYSTEM_UNLOCKED", "ACELERAR_LIBERADO"]


static func pulado(jogador: Node) -> bool:
	return jogador.flags.has(FLAG_PULADO)


## Ação que ensina: mostra ou abre algo do jogo.
static func acao_de_ensino(nome: String) -> bool:
	return nome.begins_with("HIGHLIGHT_") or nome.begins_with("OPEN_") or nome == "RETURN_TO_GARAGE"


## A cena tem algo de tutorial (o botão PULAR TUTORIAL aparece nela).
static func ensina(c: Dictionary) -> bool:
	if c.is_empty():
		return false
	if c.get("tutorial", false):
		return true
	for f in c.get("falas", []):
		if f.has("acao") and acao_de_ensino(String(f["acao"])):
			return true
		if String(f.get("quem", "")) == "sistema":
			return true
	return false


## A cena sem o ensino: sem as falas do sistema e as ações que ensinam; numa
## cena só de tutorial, sem fala nenhuma. As outras ações (desbloqueios, nome,
## cenário) ficam: a cena ainda vale (flags, próxima) mesmo sem nada a mostrar.
static func sem_ensino(c: Dictionary) -> Dictionary:
	var r := c.duplicate()
	var so_tutorial: bool = c.get("tutorial", false)
	r["falas"] = Array(c.get("falas", [])).filter(func(f):
		if f.has("acao"):
			return not acao_de_ensino(String(f["acao"]))
		return not so_tutorial and String(f.get("quem", "")) != "sistema")
	return r


## Há o que mostrar (alguma fala).
static func tem_fala(c: Dictionary) -> bool:
	return Array(c.get("falas", [])).any(func(f): return not f.has("acao"))


## Um toque: daqui em diante sem ensino, com as telas liberadas (a equipe
## existe; Lojas, Corridas, Carreira e Oficina à mostra; o ACELERAR e as
## licenças). A Arena continua abrindo com os 3 carros (regra do jogo).
static func pular(jogador: Node) -> void:
	jogador.flags[FLAG_PULADO] = true
	for f in FLAGS_LIBERADAS:
		jogador.flags[f] = true
	EquipeJogador.criar(jogador)
