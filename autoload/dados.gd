extends Node
## Carrega todo o balanceamento de res://data/*.json uma vez, em memória.
## CLAUDE.md: "não invente balanceamento" — este autoload é o único ponto de leitura
## desses arquivos. docs/dreadwick_biblia_oficial.md #17.7.

const DATA_DIR := "res://data/"

var _cache: Dictionary = {}


func _ready() -> void:
	_carregar_tudo()


func _carregar_tudo() -> void:
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_error("Dados: não consegui abrir %s" % DATA_DIR)
		return
	dir.list_dir_begin()
	var nome := dir.get_next()
	while nome != "":
		if nome.ends_with(".json"):
			var chave := nome.trim_suffix(".json")
			_cache[chave] = _carregar_json(DATA_DIR + nome)
		nome = dir.get_next()
	dir.list_dir_end()


func _carregar_json(caminho: String) -> Variant:
	var file := FileAccess.open(caminho, FileAccess.READ)
	if file == null:
		push_error("Dados: falha ao abrir %s" % caminho)
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null:
		push_error("Dados: %s não é JSON válido" % caminho)
	return parsed


## Acesso genérico por nome de arquivo, sem extensão (ex: get_dados("moeda")).
func get_dados(chave: String) -> Variant:
	if not _cache.has(chave):
		push_error("Dados: chave '%s' não carregada — existe data/%s.json?" % [chave, chave])
	return _cache.get(chave)


func tempo() -> Dictionary:
	return get_dados("tempo")


func necessidades() -> Dictionary:
	return get_dados("necessidades")


func moeda() -> Dictionary:
	return get_dados("moeda")


func pesca() -> Dictionary:
	return get_dados("pesca")


func confianca() -> Dictionary:
	return get_dados("confianca")


func insanidade() -> Dictionary:
	return get_dados("insanidade")
