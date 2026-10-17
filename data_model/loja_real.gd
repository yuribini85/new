class_name LojaReal
extends RefCounted
## Loja de dinheiro real (decisão 101): compras únicas e permanentes
## (monetizacao.json → loja.produtos), cada uma liga uma flag no save. O preço
## e a cobrança são da loja do aparelho (sku), pela ponte LojaPlay (decisão
## 110, Google Play); sem ela, comprar e restaurar respondem que ainda não há
## loja. `conceder` é o que a ponte chama ao confirmar a compra (e o modo de teste).

## A ponte com a loja do aparelho (o Principal cria quando o plugin existe).
static var ponte: LojaPlay

const SEM_LOJA := "a loja do aparelho entra na versão final"


static func produtos(dados: Node) -> Array:
	return dados.monetizacao().get("loja", {}).get("produtos", [])


static func produto(dados: Node, id: String) -> Dictionary:
	for p in produtos(dados):
		if String(p["id"]) == id:
			return p
	return {}


static func comprado(dados: Node, jogador: Node, id: String) -> bool:
	var p := produto(dados, id)
	return not p.is_empty() and jogador.flags.has(String(p["flag"]))


static func conceder(dados: Node, jogador: Node, id: String) -> String:
	var p := produto(dados, id)
	if p.is_empty():
		return "produto desconhecido"
	jogador.flags[String(p["flag"])] = true
	return ""


## Tira do jogo as compras que a conta da loja não possui (LojaPlay.possuidos).
## Devolve os ids retirados.
static func conferir(dados: Node, jogador: Node, possuidos: Array) -> Array:
	var tirados := []
	for p in produtos(dados):
		if jogador.flags.has(String(p["flag"])) and not String(p["id"]) in possuidos:
			jogador.flags.erase(String(p["flag"]))
			tirados.append(String(p["id"]))
	return tirados


## Horas de renda offline que as compras somam (produto com "horas_offline").
static func horas_offline(dados: Node, jogador: Node) -> float:
	var h := 0.0
	for p in produtos(dados):
		if p.has("horas_offline") and jogador.flags.has(String(p["flag"])):
			h += float(p["horas_offline"])
	return h


## A plataforma tem loja do aparelho (não na Web) e a ponte está conectada.
static func disponivel() -> bool:
	return not OS.has_feature("web") and ponte != null and is_instance_valid(ponte) and ponte.conectado


## Preço como a loja do aparelho mostra; sem ela, o preço-base em dólar
## (monetizacao.json → preco_usd, decisão 106); "" sem nenhum dos dois.
static func preco(dados: Node, id: String) -> String:
	var p := produto(dados, id)
	if p.is_empty():
		return ""
	if disponivel() and ponte.precos.has(String(p.get("sku", id))):
		return String(ponte.precos[String(p.get("sku", id))])
	if p.get("preco_usd") == null:
		return ""
	return ("US$ %.2f" % float(p["preco_usd"])).replace(".", ",")


## Pede a compra; "" quando a loja aceitou o pedido (a confirmação chega por
## `conceder`), ou o motivo.
static func comprar(dados: Node, jogador: Node, id: String) -> String:
	if produto(dados, id).is_empty():
		return "produto desconhecido"
	if comprado(dados, jogador, id):
		return "já comprado"
	if not disponivel():
		return SEM_LOJA
	ponte.comprar(String(produto(dados, id).get("sku", id)))
	return ""


static func restaurar(_dados: Node, _jogador: Node) -> String:
	if not disponivel():
		return SEM_LOJA
	ponte.restaurar()
	return ""
