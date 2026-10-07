class_name Cores
extends RefCounted
## Cores de fábrica de cada modelo (arte/carros/cores.json, tools/gerar_cores.py).
## Como no GT2: carro novo, o jogador escolhe na compra; usado vem numa cor do
## modelo; rivais variam entre as cores do modelo. Sem pintura livre depois.

const ARQUIVO := "res://arte/carros/cores.json"

static var _dados := {}


static func _ler() -> Dictionary:
	if _dados.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO)) \
				if FileAccess.file_exists(ARQUIVO) else null
		_dados = d if d is Dictionary else {"paleta": {}, "modelos": {}}
	return _dados


## Chaves das cores do modelo, a de fábrica primeiro; vazio se o modelo não tem.
static func chaves(id: String) -> Array:
	return _ler()["modelos"].get(id, [])


static func cor(chave: String) -> Color:
	return Color(String(_ler()["paleta"].get(chave, {}).get("cor", "#ffffff")))


static func nome(chave: String) -> String:
	return String(_ler()["paleta"].get(chave, {}).get("nome", chave))


static func lista(id: String) -> Array:
	return chaves(id).map(func(k): return cor(k))


## Cor de fábrica do modelo (a primeira); sem lista, a cor do carro em código.
static func fabrica(id: String) -> Color:
	var c := chaves(id)
	return cor(c[0]) if not c.is_empty() else CarroBloco.cor_do_id(id)


## Cor do carro da garagem: a escolhida na compra ou a de fábrica.
static func do_carro(carro: Carro) -> Color:
	return Color(carro.cor) if carro.cor != "" else fabrica(carro.id)


## Uma das cores do modelo, escolhida por `semente` (rival, usado do dia).
static func sortear(id: String, semente: String) -> Color:
	var c := chaves(id)
	return cor(c[posmod(semente.hash(), c.size())]) if not c.is_empty() else CarroBloco.cor_do_id(id)
