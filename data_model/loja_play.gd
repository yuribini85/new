class_name LojaPlay
extends Node
## Ponte com a cobrança do Google Play (decisão 110): o plugin oficial
## GodotGooglePlayBilling (singleton do export Android; API startConnection,
## querySkuDetails, purchase, queryPurchases, acknowledgePurchase e os sinais
## connected, sku_details_query_completed, purchases_updated,
## query_purchases_response, purchase_error). O Principal cria este nó só
## quando o singleton existe; sem ele, LojaReal responde que a loja chega na
## versão final. Compra confirmada sai em `concedido(id do produto)`, que o
## Principal entrega a LojaReal.conceder; restaurar consulta as compras feitas.

signal concedido(id: String)
## Consulta das compras da conta concluída: os ids que ela possui. O Principal
## tira as compras marcadas no jogo que a conta não tem (save copiado ou editado).
signal possuidos(ids: Array)
signal erro(texto: String)

const SINGLETON := "GodotGooglePlayBilling"
const ESTADO_COMPRADO := 1

var conectado := false
var precos := {}  # sku -> texto do preço da loja ("R$ 49,90")
var _plugin: Object
var _skus := {}  # sku -> id do produto


func _init(dados: Node) -> void:
	for p in LojaReal.produtos(dados):
		_skus[String(p.get("sku", p["id"]))] = String(p["id"])


func _ready() -> void:
	if not Engine.has_singleton(SINGLETON):
		return
	_plugin = Engine.get_singleton(SINGLETON)
	_plugin.connect("connected", _conectou)
	_plugin.connect("disconnected", func(): conectado = false)
	_plugin.connect("sku_details_query_completed", _detalhes)
	_plugin.connect("purchases_updated", _compras)
	_plugin.connect("query_purchases_response", _consulta)
	_plugin.connect("purchase_error", func(_c, msg): erro.emit(String(msg)))
	_plugin.call("startConnection")


func _conectou() -> void:
	conectado = true
	_plugin.call("querySkuDetails", PackedStringArray(_skus.keys()), "inapp")
	_plugin.call("queryPurchases", "inapp")


func _detalhes(detalhes: Array) -> void:
	for d in detalhes:
		precos[String(d.get("sku", ""))] = String(d.get("price", ""))


func comprar(sku: String) -> void:
	if conectado:
		_plugin.call("purchase", sku)


func restaurar() -> void:
	if conectado:
		_plugin.call("queryPurchases", "inapp")


func _consulta(r: Dictionary) -> void:
	if int(r.get("status", -1)) != OK:
		return
	var compras: Array = r.get("purchases", [])
	_compras(compras)
	var ids := []
	for c in compras:
		if int(c.get("purchase_state", 0)) == ESTADO_COMPRADO:
			for s in c.get("skus", [c.get("sku", "")]):
				if _skus.has(String(s)):
					ids.append(String(_skus[String(s)]))
	possuidos.emit(ids)


func _compras(compras: Array) -> void:
	for c in compras:
		if int(c.get("purchase_state", 0)) != ESTADO_COMPRADO:
			continue
		var skus: Array = c.get("skus", [c.get("sku", "")])
		for s in skus:
			if _skus.has(String(s)):
				concedido.emit(String(_skus[String(s)]))
		if not bool(c.get("is_acknowledged", false)):
			_plugin.call("acknowledgePurchase", String(c.get("purchase_token", "")))
