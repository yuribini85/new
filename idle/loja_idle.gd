class_name LojaIdle
extends Node
## Compras do The Fastfather (sugestão 16 aprovada, 2026-10-28): a ponte com a
## cobrança do Google Play, no mesmo formato da LojaPlay do Chrome & Wreckage
## (singleton GodotGooglePlayBilling: startConnection, querySkuDetails,
## purchase, queryPurchases, acknowledgePurchase). Sem o plugin (editor, web,
## testes) `disponivel` é falso e a tela mostra o pacote sem o botão de compra.
## Compra confirmada, ou já feita na conta (reinstalação), sai em `concedido`.

signal concedido(sku: String)

const SINGLETON := "GodotGooglePlayBilling"
const ESTADO_COMPRADO := 1

var skus: PackedStringArray = []
var precos := {}  # sku -> texto do preço da loja ("R$ 19,90")
var conectado := false
var _plugin: Object


func disponivel() -> bool:
	return _plugin != null and conectado


func _ready() -> void:
	if skus.is_empty() or not Engine.has_singleton(SINGLETON):
		return
	_plugin = Engine.get_singleton(SINGLETON)
	_plugin.connect("connected", _conectou)
	_plugin.connect("disconnected", func(): conectado = false)
	_plugin.connect("sku_details_query_completed", func(detalhes: Array):
		for d in detalhes:
			precos[String(d.get("sku", ""))] = String(d.get("price", "")))
	_plugin.connect("purchases_updated", _compras)
	_plugin.connect("query_purchases_response", func(r: Dictionary):
		if int(r.get("status", -1)) == OK:
			_compras(r.get("purchases", [])))
	_plugin.call("startConnection")


func _conectou() -> void:
	conectado = true
	_plugin.call("querySkuDetails", skus, "inapp")
	_plugin.call("queryPurchases", "inapp")


func comprar(sku: String) -> void:
	if disponivel():
		_plugin.call("purchase", sku)


func _compras(compras: Array) -> void:
	for c in compras:
		if int(c.get("purchase_state", 0)) != ESTADO_COMPRADO:
			continue
		for s in c.get("skus", [c.get("sku", "")]):
			if String(s) in skus:
				concedido.emit(String(s))
		if not bool(c.get("is_acknowledged", false)):
			_plugin.call("acknowledgePurchase", String(c.get("purchase_token", "")))
