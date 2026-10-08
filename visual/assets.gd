class_name Assets
extends RefCounted
## Carregador central de arte (documento de implementação, seção 30):
## get_asset(id, variante) devolve a textura da entidade, ou null quando o
## arquivo ainda não existe; quem chama mostra o placeholder (iniciais na cor do
## personagem, nome da equipe em texto). A arte nova entra só pondo o arquivo no
## caminho que os dados já indicam, sem mexer nas telas.
##
## Variantes: "retrato" (personagens.json ou piloto de equipes.json, campo
## `retrato`), "corpo" (corpo inteiro do diálogo: <pasta do retrato>/corpo/
## <nome>.webp), "logo" (equipe, campo `logo`), "ui" (arte/ui/<id>.png), "cenario"
## (fundo das cenas: arte/cenarios/<id>.webp) e "ilustracao" (quadro de um momento
## da história: arte/cenas/<id>.webp); os ids estão em data/historia.json.

static var _cache := {}


static func get_asset(id: String, variante: String) -> Texture2D:
	var chave := variante + ":" + id
	if not _cache.has(chave):
		_cache[chave] = _carregar(caminho(id, variante))
	return _cache[chave]


## Caminho que os dados indicam ("" se a entidade não tem um).
static func caminho(id: String, variante: String) -> String:
	var dados: Node = _dados()
	match variante:
		"corpo":
			var r := caminho(id, "retrato")
			return "" if r == "" else r.get_base_dir().path_join("corpo").path_join(r.get_file().get_basename() + ".webp")
		"ui":
			return "res://arte/ui/%s.png" % id
		"cenario":
			return "res://arte/cenarios/%s.webp" % id
		"ilustracao":
			return "res://arte/cenas/%s.webp" % id
		"retrato":
			if dados == null:
				return ""
			if dados.existe("personagens", id):
				return String(dados.item("personagens", id).get("retrato", ""))
			for e in dados.lista("equipes"):
				for p in e.get("pilotos", []):
					if p["id"] == id:
						return String(p.get("retrato", ""))
		"logo":
			if dados != null and dados.existe("equipes", id):
				return String(dados.item("equipes", id).get("logo", ""))
	return ""


## Limpa o cache (arte trocada com o jogo aberto, testes).
static func limpar() -> void:
	_cache = {}


static func _carregar(arquivo: String) -> Texture2D:
	if arquivo == "":
		return null
	if ResourceLoader.exists(arquivo):
		return load(arquivo) as Texture2D
	# Arquivo novo ainda não importado pelo editor: lê a imagem direto.
	if FileAccess.file_exists(arquivo):
		var img := Image.load_from_file(arquivo)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


static func _dados() -> Node:
	var arvore := Engine.get_main_loop() as SceneTree
	return arvore.root.get_node_or_null("Dados") if arvore != null else null
