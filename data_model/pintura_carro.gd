class_name PinturaCarro
extends RefCounted
## Pintura personalizada (Oficina → PINTURA, pedido do usuário): a cor da
## carroceria, livre na paleta (arte/carros/cores.json), e um padrão de faixas
## com a cor da faixa e a do filete. Fica no carro (Carro.cor, Carro.faixas) e
## aparece onde o modelo 3D aparece. Preço: data/equipe.json → pintura (fator
## sobre o prêmio de referência da maior licença; null = a definir, vale 0).

## [id, nome] dos padrões, na ordem da tela (o índice é o do shader carro_faixas).
const PADROES := [["", "Sem faixas"], ["dupla", "Dupla central"], ["larga", "Larga central"],
		["lateral", "Lateral"], ["dois_tons", "Dois tons"], ["tripla", "Tripla fina"], ["assimetrica", "Assimétrica"],
		["capo", "Capô"], ["diagonal", "Diagonal"], ["chevron", "Chevron"], ["xadrez", "Xadrez"],
		["degrade", "Degradê"], ["ziguezague", "Zigue-zague"], ["serrilha", "Serrilha"], ["circulo", "Círculo"],
		["tres_tons", "Três tons"]]

## A paleta da pintura é a de fábrica mais saturada (pedido do usuário): mesmas
## famílias e o mesmo brilho relativo, tons mais vivos. Cinzas, brancos, preto
## e creme (pouca saturação) ficam como estão.
const SATURACAO_MIN := 0.2
const SATURACAO_GANHO := 0.45  # fração do que falta até 1
const SATURACAO_TETO := 0.97
const BRILHO_GANHO := 1.15


static func indice_padrao(id: String) -> int:
	for i in PADROES.size():
		if PADROES[i][0] == id:
			return i
	return 0


static func nome_padrao(id: String) -> String:
	return String(PADROES[indice_padrao(id)][1])


## Cores da paleta da pintura: [{chave, nome, cor}].
static func cores() -> Array:
	var l := []
	for k in Cores._ler()["paleta"]:
		l.append({"chave": k, "nome": Cores.nome(k), "cor": saturada(Cores.cor(k))})
	return l


static func saturada(c: Color) -> Color:
	if c.s < SATURACAO_MIN:
		return c
	return Color.from_hsv(c.h, minf(SATURACAO_TETO, c.s + (1.0 - c.s) * SATURACAO_GANHO), minf(1.0, c.v * BRILHO_GANHO))


## Pintura de um carro de equipe rival (decisão 60): um desenho sorteado por
## `semente` (fixo por prova e vaga), nas cores da equipe (faixa e filete).
static func da_equipe(equipe: Dictionary, semente: String) -> Dictionary:
	var cores: Dictionary = equipe.get("cores", {})
	if cores.is_empty():
		return {}
	var k := 1 + posmod(semente.hash(), PADROES.size() - 1)
	return {"padrao": PADROES[k][0], "faixa": String(cores.get("faixa", "#ffffff")),
			"filete": String(cores.get("filete", "#1a1a1a"))}


static func cfg(dados: Node) -> Dictionary:
	return dados.equipe().get("pintura", {})


## Preço de mudar a cor e/ou as faixas ("" ou -1 = a definir: vale 0).
static func preco(dados: Node, jogador: Node, muda_cor: bool, muda_faixas: bool) -> int:
	var niveis := GestaoEquipe.ordem(dados)
	var k := GestaoEquipe.maior_licenca(dados, jogador)
	var ref := GestaoEquipe.premio_referencia(dados, niveis[k]) if k >= 0 else 0
	var total := 0.0
	if muda_cor and cfg(dados).get("fator_cor") != null:
		total += ref * float(cfg(dados)["fator_cor"])
	if muda_faixas and cfg(dados).get("fator_faixas") != null:
		total += ref * float(cfg(dados)["fator_faixas"])
	return roundi(total)


## O preço ainda não foi definido pelo usuário (os fatores estão null).
static func preco_definido(dados: Node) -> bool:
	return cfg(dados).get("fator_cor") != null and cfg(dados).get("fator_faixas") != null


## Aplica a pintura no carro (cor "#rrggbb", faixas {padrao, faixa, filete}).
## "" ou o motivo.
static func aplicar(dados: Node, jogador: Node, carro: Carro, cor: String, faixas: Dictionary) -> String:
	var muda_cor := cor != carro.cor and not (carro.cor == "" and Color(cor) == Cores.fabrica(carro.id))
	var muda_faixas := faixas != carro.faixas
	if not muda_cor and not muda_faixas:
		return "nada mudou"
	if not jogador.economia.debitar(preco(dados, jogador, muda_cor, muda_faixas)):
		return "saldo insuficiente"
	carro.cor = cor
	carro.faixas = {} if String(faixas.get("padrao", "")) == "" else faixas.duplicate()
	return ""
