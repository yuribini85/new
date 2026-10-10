class_name Concessionaria
extends RefCounted
## Compra e venda de carros novos, peças e pneus. Preços e regras de revenda
## vêm de data/ (carros, pecas, pneus, economia).

const OK := ""

var economia: Economia
var garagem: Garagem
## data/economia.json
var regras: Dictionary
## Função id -> pneu (Dados.pneu), para o pneu de fábrica.
var _pneu_por_id: Callable


func _init(economia_: Economia, garagem_: Garagem, regras_: Dictionary, pneu_por_id: Callable) -> void:
	economia = economia_
	garagem = garagem_
	regras = regras_
	_pneu_por_id = pneu_por_id


## Compra um carro novo; ele chega com o pneu de fábrica. Retorna o uid ou -1.
## `cor`: pintura escolhida (hex); vazia = a de fábrica do modelo.
func comprar_carro(dados_carro: Dictionary, cor := "") -> int:
	if garagem.cheia() or not economia.debitar(int(dados_carro["preco"])):
		return -1
	var carro := Carro.new(dados_carro)
	carro.cor = cor
	carro.adicionar_pneu(_pneu_por_id.call(regras["pneu_de_fabrica"]))
	return garagem.adicionar(carro)


## Compra uma oferta de Usados.estoque(). `vendidos` recebe a chave da oferta
## para ela sumir do estoque no resto do período. Retorna o uid ou -1.
func comprar_usado(oferta: Dictionary, dados_carro: Dictionary, vendidos: Dictionary, cor := "") -> int:
	if vendidos.has(oferta["chave"]) or garagem.cheia() or not economia.debitar(int(oferta["preco"])):
		return -1
	vendidos[oferta["chave"]] = true
	var carro := Carro.new(dados_carro)
	carro.cor = cor
	carro.adicionar_pneu(_pneu_por_id.call(regras["pneu_de_fabrica"]))
	return garagem.adicionar(carro)


## Vende pelo preço de tabela vezes a fração de revenda. Peças não somam.
## O último carro da garagem não pode ser vendido: sem carro e sem saldo para
## outro, a carreira trava. Retorna o valor creditado ou 0.
func vender_carro(uid: int) -> int:
	if not pode_vender(uid):
		return 0
	var carro := garagem.remover(uid)
	if carro == null:
		return 0
	var valor := int(floor(float(carro.base["preco"]) * float(regras["fracao_revenda"])))
	economia.creditar(valor)
	return valor


func pode_vender(uid: int) -> bool:
	return garagem.carro(uid) != null and garagem.lista().size() > 1


## Compra (ou reinstala, se já possuída) e instala a peça. Retorna OK ou o motivo.
func comprar_peca(carro: Carro, peca: Dictionary) -> String:
	var motivo := carro.motivo_recusa(peca)
	if motivo != OK:
		return motivo
	if not peca["id"] in carro.pecas_possuidas:
		if not economia.debitar(int(peca["preco"])):
			return "saldo insuficiente"
		carro.pecas_possuidas.append(peca["id"])
	carro.instalar(peca)
	return OK


func comprar_pneu(carro: Carro, pneu: Dictionary) -> String:
	for p in carro.pneus:
		if p["id"] == pneu["id"]:
			return "pneu já possuído"
	if not economia.debitar(int(pneu["preco"])):
		return "saldo insuficiente"
	carro.adicionar_pneu(pneu)
	return OK
