extends RefCounted
## Asserções mínimas compartilhadas pelos testes.

const FIXTURES := "res://tests/fixtures/"
const DadosScript := preload("res://autoload/dados.gd")

var falhas: Array = []


func verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		falhas.append(mensagem)


func igual(obtido: Variant, esperado: Variant, mensagem: String) -> void:
	if obtido != esperado:
		falhas.append("%s: esperado %s, obtido %s" % [mensagem, esperado, obtido])


func perto(obtido: float, esperado: float, tolerancia: float, mensagem: String) -> void:
	if absf(obtido - esperado) > tolerancia:
		falhas.append("%s: esperado %.4f ± %.4f, obtido %.4f" % [mensagem, esperado, tolerancia, obtido])


## Dados carregados das fixtures. Chamador libera com .free().
func dados_fixture() -> Node:
	var d: Node = DadosScript.new()
	d.carregar(FIXTURES)
	return d
