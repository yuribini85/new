class_name EquipeJogador
extends RefCounted
## Second Driver Motorsport (fase 8 do documento de implementação): a equipe do
## jogador nasce na cena SCN_K01 (flag SECOND_DRIVER_CREATED). Criar não reseta
## dinheiro, carros nem licenças; só muda o contexto (aba Equipe aparece).
## A equipe é a de equipes.json com "jogador": true; nome e pilotos vêm de lá.
## Finanças leves e segundo piloto ficam para a fase 9.

const FLAG := "SECOND_DRIVER_CREATED"


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
