extends Node
## Módulo 2 — Dados. Carrega todo o balanceamento de res://data/*.json uma vez,
## em memória. CLAUDE.md: "Todo número vem de data/. Se faltar algum, pergunte
## em vez de estimar" — este autoload é o único ponto de leitura desses arquivos.

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


## Acesso genérico por nome de arquivo, sem extensão (ex: get_dados("economia")).
func get_dados(chave: String) -> Variant:
	if not _cache.has(chave):
		push_error("Dados: chave '%s' não carregada — existe data/%s.json?" % [chave, chave])
	return _cache.get(chave)


func economia() -> Dictionary:
	return get_dados("economia")


func ciclo() -> Dictionary:
	return get_dados("ciclo")


func ato1() -> Dictionary:
	return get_dados("ato1")


func vila_lotes() -> Dictionary:
	return get_dados("vila_lotes")


func expedicoes() -> Variant:
	return get_dados("expedicoes")


func mina() -> Variant:
	return get_dados("mina")


func orfaos() -> Dictionary:
	return get_dados("orfaos")


func cicatrizes() -> Dictionary:
	return get_dados("cicatrizes")


func floresta() -> Dictionary:
	return get_dados("floresta")


## Junta ato1.json (ordem de desbloqueio) com vila_lotes.json (posição/tamanho no mapa)
## num catálogo único por id. O módulo de Mapa consome isso para instanciar Edificio.
func catalogo_edificios_ato1() -> Dictionary:
	var catalogo: Dictionary = {}
	var lotes_por_id: Dictionary = {}
	for lote in vila_lotes().get("lots", []):
		lotes_por_id[lote["id"]] = lote

	for definicao in ato1().get("ordem", []):
		var id: String = definicao["id"]
		var lote: Dictionary = lotes_por_id.get(id, {})
		if lote.is_empty():
			push_warning("Dados: '%s' está em ato1.json mas não em vila_lotes.json" % id)
			continue
		catalogo[id] = {
			"id": id,
			"nome": lote.get("name", id),
			"zona": lote.get("zone", ""),
			"celula": Vector2i(lote["cell"][0], lote["cell"][1]),
			"footprint": Vector2i(lote["footprint"][0], lote["footprint"][1]),
			"custo_n1": definicao.get("custo_n1", 0),
			"produz": definicao.get("produz", ""),
			"destrava": definicao.get("destrava", ""),
			"capacidade": definicao.get("capacidade", ""),
			"funcao": definicao.get("funcao", ""),
		}
	return catalogo


## Os 30 lotes inteiros do mapa (docs/the_way_back_biblia.html #04b: "todos os
## lotes existem desde o primeiro minuto, visíveis como silhueta escura de
## ruína"), mesmo os que ainda não têm custo/produção definidos em ato1.json —
## esses ficam com disponivel=false: aparecem como ruína decorativa, mas nunca
## constroem até um ato futuro trazer os dados deles.
func catalogo_lotes_todos() -> Dictionary:
	var ato1_por_id: Dictionary = {}
	for definicao in ato1().get("ordem", []):
		ato1_por_id[definicao["id"]] = definicao

	var catalogo: Dictionary = {}
	for lote in vila_lotes().get("lots", []):
		var id: String = lote["id"]
		var definicao: Dictionary = ato1_por_id.get(id, {})
		catalogo[id] = {
			"id": id,
			"nome": lote.get("name", id),
			"zona": lote.get("zone", ""),
			"celula": Vector2i(lote["cell"][0], lote["cell"][1]),
			"footprint": Vector2i(lote["footprint"][0], lote["footprint"][1]),
			"custo_n1": definicao.get("custo_n1", 0),
			"produz": definicao.get("produz", ""),
			"destrava": definicao.get("destrava", ""),
			"capacidade": definicao.get("capacidade", ""),
			"funcao": definicao.get("funcao", ""),
			"disponivel": not definicao.is_empty(),
		}
	return catalogo
