extends Node
## Carrega o balanceamento de res://data/*.json uma vez, em memória, e confere
## o formato. É o único ponto de leitura desses arquivos.
## CLAUDE.md: nenhum número é inventado — o que falta aparece em pendencias().

const DATA_DIR := "res://data/"
const CarroScript := preload("res://data_model/carro.gd")
const PistaScript := preload("res://data_model/pista.gd")
const SimulacaoScript := preload("res://sim/simulacao.gd")

## arquivo -> campos obrigatórios de cada item da lista.
const ESQUEMAS := {
	"fabricantes": ["id", "nome", "escola"],
	"carros": [
		"id", "fabricante", "arquetipo_ref", "categoria", "tracao",
		"potencia", "peso", "aderencia", "freio", "velocidade_max", "preco", "ano",
	],
	"pecas": ["id", "categoria", "efeitos", "preco"],
	"pneus": ["id", "aderencia", "preco"],
	"pistas": ["id", "funcao", "trechos"],
	"pilotos_ia": ["id", "ritmo", "consistencia", "agressividade"],
}

## arquivo -> chaves obrigatórias do objeto.
const OBJETOS := {
	"simulacao": SimulacaoScript.PARAMS,
	"economia": ["saldo_inicial", "fracao_revenda", "pneu_de_fabrica"],
}

var _listas: Dictionary = {}  # arquivo -> {id -> item}
var _objetos: Dictionary = {}  # arquivo -> objeto
var _pendencias: Array = []
var _erros: Array = []


func _ready() -> void:
	carregar(DATA_DIR)
	for e in _erros:
		push_error("Dados: " + e)
	for p in _pendencias:
		push_warning("Dados pendente: " + p)


func carregar(dir: String) -> void:
	_listas.clear()
	_pendencias.clear()
	_erros.clear()
	for arquivo in ESQUEMAS:
		_listas[arquivo] = {}
		var lista = _ler_json(dir + arquivo + ".json")
		if not lista is Array:
			_erros.append("%s.json deve ser uma lista" % arquivo)
			continue
		if lista.is_empty():
			_pendencias.append("%s.json vazio" % arquivo)
		for item in lista:
			_validar_item(arquivo, item)
			_listas[arquivo][str(item.get("id"))] = item
	for arquivo in OBJETOS:
		_objetos[arquivo] = {}
		var obj = _ler_json(dir + arquivo + ".json")
		if not obj is Dictionary:
			_erros.append("%s.json deve ser um objeto" % arquivo)
			continue
		_objetos[arquivo] = obj
		for chave in OBJETOS[arquivo]:
			if not obj.has(chave):
				_erros.append("%s.json sem chave %s" % [arquivo, chave])
			elif obj[chave] == null:
				_pendencias.append("%s.json: %s" % [arquivo, chave])
	_validar_referencias()


func _ler_json(caminho: String) -> Variant:
	if not FileAccess.file_exists(caminho):
		_erros.append("arquivo ausente: " + caminho)
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if parsed == null:
		_erros.append("%s não é JSON válido" % caminho)
	return parsed


func _validar_item(arquivo: String, item: Variant) -> void:
	if not item is Dictionary:
		_erros.append("%s.json: item não é objeto" % arquivo)
		return
	for campo in ESQUEMAS[arquivo]:
		if not item.has(campo):
			_erros.append("%s.json: '%s' sem campo %s" % [arquivo, item.get("id"), campo])
		elif item[campo] == null:
			_pendencias.append("%s.json: '%s'.%s" % [arquivo, item.get("id"), campo])
	if arquivo == "pistas" and item.has("trechos"):
		for e in PistaScript.validar(item):
			_erros.append("pistas.json: '%s' %s" % [item.get("id"), e])


## Ids citados em um arquivo precisam existir no arquivo de destino.
func _validar_referencias() -> void:
	for c in _listas["carros"].values():
		if c.get("fabricante") != null and not _listas["fabricantes"].has(str(c["fabricante"])):
			_erros.append("carros.json: '%s' cita fabricante inexistente %s" % [c["id"], c["fabricante"]])
		if c.get("tracao") != null and not c["tracao"] in CarroScript.TRACOES:
			_erros.append("carros.json: '%s' tração inválida %s" % [c["id"], c["tracao"]])
	for p in _listas["pecas"].values():
		for e in p.get("efeitos", []):
			if not e.get("atributo") in CarroScript.ATRIBUTOS or not e.get("op") in CarroScript.OPS:
				_erros.append("pecas.json: '%s' efeito inválido %s" % [p["id"], e])
	var pneu_fabrica = _objetos.get("economia", {}).get("pneu_de_fabrica")
	if pneu_fabrica != null and not _listas["pneus"].has(str(pneu_fabrica)):
		_erros.append("economia.json: pneu_de_fabrica inexistente %s" % pneu_fabrica)


## Valores que ainda precisam vir do estudo do GT2 ou de playtest.
func pendencias() -> Array:
	return _pendencias


## Problemas de formato. Devem ser corrigidos no JSON, não no código.
func erros() -> Array:
	return _erros


func lista(arquivo: String) -> Array:
	return _listas[arquivo].values()


func item(arquivo: String, id: String) -> Dictionary:
	if not _listas[arquivo].has(id):
		push_error("Dados: '%s' não existe em %s.json" % [id, arquivo])
		return {}
	return _listas[arquivo][id]


func carro(id: String) -> Dictionary:
	return item("carros", id)


func peca(id: String) -> Dictionary:
	return item("pecas", id)


func pneu(id: String) -> Dictionary:
	return item("pneus", id)


func piloto(id: String) -> Dictionary:
	return item("pilotos_ia", id)


func pista(id: String) -> Pista:
	return PistaScript.new(item("pistas", id))


func simulacao() -> Dictionary:
	return _objetos["simulacao"]


func economia() -> Dictionary:
	return _objetos["economia"]
