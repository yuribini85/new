class_name VagasGaragem
extends RefCounted
## Vagas da garagem (decisão 43, data/garagem.json): começa com
## capacidade_inicial; cada ampliação multiplica as vagas por fator_vagas. A
## 1ª custa a soma dos prêmios de 1º lugar das provas da licença
## licenca_do_preco × fator_preco_base; cada uma seguinte, × fator_preco a
## anterior. Sem o arquivo (dados de teste), garagem sem limite.


## 0 = sem limite.
static func capacidade(dados: Node, ampliacoes: int) -> int:
	var g: Dictionary = dados.garagem()
	if g.is_empty():
		return 0
	return int(g["capacidade_inicial"]) * int(pow(float(g["fator_vagas"]), ampliacoes))


## Preço da próxima ampliação (depois de `ampliacoes` feitas). 0 = indisponível.
static func preco(dados: Node, ampliacoes: int) -> int:
	var g: Dictionary = dados.garagem()
	if g.is_empty():
		return 0
	var soma := 0
	for e in dados.lista("eventos"):
		if e.get("restricoes", {}).get("licenca", "") == g["licenca_do_preco"] and not e.get("premios", []).is_empty():
			soma += int(e["premios"][0])
	return int(soma * float(g["fator_preco_base"]) * pow(float(g["fator_preco"]), ampliacoes))


## Compra a próxima ampliação. "" ou o motivo.
static func ampliar(dados: Node, jogador: Node) -> String:
	var p := preco(dados, jogador.ampliacoes_garagem)
	if p <= 0:
		return "a garagem não amplia"
	if not jogador.economia.debitar(p):
		return "saldo insuficiente"
	jogador.ampliacoes_garagem += 1
	jogador.garagem.vagas = capacidade(dados, jogador.ampliacoes_garagem)
	return ""
