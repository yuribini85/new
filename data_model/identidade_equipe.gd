class_name IdentidadeEquipe
extends RefCounted
## Identidade da equipe do jogador (pacote de identidades das equipes): o nome,
## livre (padrão: o da campanha, "Wreckage Motorsport"), e o logo, uma das dez
## opções de data/emblemas.json, independentes um do outro. Fica no jogador
## (Jogador.identidade, no save) e vale para todos os carros dele: a pintura de
## cada carro só escolhe onde o logo vai (PinturaCarro, locais_logo).

const NOME_MAX := 28
const ARQUIVO := "res://data/emblemas.json"

static var _cache := {}


static func _ler() -> Dictionary:
	if _cache.is_empty() and FileAccess.file_exists(ARQUIVO):
		var d = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
		_cache = d if d is Dictionary else {}
	return _cache


## As opções de logo do jogador: [{id, nome, arquivo}].
static func opcoes() -> Array:
	return _ler().get("jogador", [])


static func arquivo_logo(id: String) -> String:
	for o in opcoes():
		if o["id"] == id:
			return String(o["arquivo"])
	return ""


## Nome da equipe: o escolhido ou o padrão da campanha.
static func nome(dados: Node, jogador: Node) -> String:
	var n := String(jogador.identidade.get("nome", "")).strip_edges()
	return n if n != "" else nome_padrao(dados, jogador)


static func nome_padrao(dados: Node, jogador: Node) -> String:
	var troca: Dictionary = dados.historia().get(String(jogador.personagem), {}).get("equipe", {})
	return String(troca.get("nome", "Wreckage Motorsport"))


## Id do logo escolhido ("" = nenhum ainda).
static func logo(jogador: Node) -> String:
	return String(jogador.identidade.get("logo", ""))


## Grava nome e logo (nome vazio volta ao padrão; corta no tamanho máximo).
static func definir(jogador: Node, novo_nome: String, logo_id: String) -> void:
	var n := novo_nome.strip_edges().left(NOME_MAX)
	jogador.identidade = {}
	if n != "":
		jogador.identidade["nome"] = n
	if logo_id != "" and arquivo_logo(logo_id) != "":
		jogador.identidade["logo"] = logo_id
