class_name LojaReal
extends RefCounted
## Loja de dinheiro real (decisão 101): compras únicas e permanentes
## (monetizacao.json → loja.produtos), cada uma liga uma flag no save. O preço
## e a cobrança são da loja do aparelho (sku); enquanto o plugin dela não entra
## (depois do MVP), comprar e restaurar respondem que ainda não há loja.
## `conceder` é o que o plugin chama ao confirmar a compra (e o modo de teste).

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


## A plataforma tem loja do aparelho (não na Web) e o plugin dela está ativo.
static func disponivel() -> bool:
	return not OS.has_feature("web") and _plugin() != null


## Preço como a loja do aparelho mostra ("" sem loja: a tela não inventa preço).
static func preco(_dados: Node, _id: String) -> String:
	return ""


## Pede a compra; "" quando a loja aceitou o pedido (a confirmação chega por
## `conceder`), ou o motivo.
static func comprar(dados: Node, jogador: Node, id: String) -> String:
	if produto(dados, id).is_empty():
		return "produto desconhecido"
	if comprado(dados, jogador, id):
		return "já comprado"
	if not disponivel():
		return SEM_LOJA
	return SEM_LOJA


static func restaurar(_dados: Node, _jogador: Node) -> String:
	if not disponivel():
		return SEM_LOJA
	return SEM_LOJA


static func _plugin() -> Object:
	return null
