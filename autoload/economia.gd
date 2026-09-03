extends Node
## Dinheiro e estoques. docs/dreadwick_biblia_oficial.md #8 (economia e recursos).
## Moeda britânica pré-decimal: tudo guardado internamente em pence (#8.5: "usar pence
## como unidade monetária interna"), convertido para libras/xelins/pence só na exibição.

signal dinheiro_mudou(pence: int)
signal estoque_mudou(recurso: String, valor: float)

var dinheiro_pence: int = 0

## #8.4: querosene em litros, Kit em unidades, peixes em kg (comuns e mutantes
## compartilham o mesmo estoque, "salvo futuro compartimento especial"). Materiais e
## peças-chave ficam de fora por enquanto — nenhuma receita/upgrade os consome ainda
## (a bíblia lista "número final de níveis por ramo de upgrade" como pendência, #20).
var estoques: Dictionary = {
	"querosene_litros": 0.0,
	"kit_sobrevivencia": 0.0,
	"peixes_kg": 0.0,
}


func libras_xelins_pence() -> Dictionary:
	var cfg := Dados.moeda()
	var pence_por_xelim: int = cfg["pence_por_xelim"]
	var xelins_por_libra: int = cfg["xelins_por_libra"]
	var total_xelins := dinheiro_pence / pence_por_xelim
	var pence := dinheiro_pence % pence_por_xelim
	var libras := total_xelins / xelins_por_libra
	var xelins := total_xelins % xelins_por_libra
	return {"libras": libras, "xelins": xelins, "pence": pence}


func tem_dinheiro(pence: int) -> bool:
	return dinheiro_pence >= pence


func debitar_dinheiro(pence: int) -> void:
	dinheiro_pence = maxi(0, dinheiro_pence - pence)
	dinheiro_mudou.emit(dinheiro_pence)


func creditar_dinheiro(pence: int) -> void:
	if pence <= 0:
		return
	dinheiro_pence += pence
	dinheiro_mudou.emit(dinheiro_pence)


func tem_estoque(recurso: String, quantidade: float) -> bool:
	return estoques.get(recurso, 0.0) >= quantidade


func debitar_estoque(recurso: String, quantidade: float) -> void:
	if quantidade <= 0.0 or not estoques.has(recurso):
		return
	estoques[recurso] = maxf(0.0, estoques[recurso] - quantidade)
	estoque_mudou.emit(recurso, estoques[recurso])


func creditar_estoque(recurso: String, quantidade: float) -> void:
	if quantidade <= 0.0 or not estoques.has(recurso):
		return
	estoques[recurso] += quantidade
	estoque_mudou.emit(recurso, estoques[recurso])


func get_save_data() -> Dictionary:
	return {
		"dinheiro_pence": dinheiro_pence,
		"estoques": estoques,
	}


func restaurar(salvo: Dictionary) -> void:
	if salvo.is_empty():
		return
	dinheiro_pence = salvo.get("dinheiro_pence", 0)
	var e: Dictionary = salvo.get("estoques", {})
	for k in estoques:
		estoques[k] = e.get(k, estoques[k])
