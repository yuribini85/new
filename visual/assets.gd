class_name Assets
extends RefCounted
## Carregador central de arte (documento de implementação, seção 30):
## get_asset(id, variante) devolve a textura da entidade, ou null quando o
## arquivo ainda não existe; quem chama mostra o placeholder (iniciais na cor do
## personagem, nome da equipe em texto). A arte nova entra só pondo o arquivo no
## caminho que os dados já indicam, sem mexer nas telas.
##
## Variantes: "retrato" (personagens.json, campo `retrato`; piloto: um retrato
## genérico), "corpo" (corpo inteiro do diálogo: <pasta do retrato>/corpo/
## <nome>.webp; com id "<personagem>@<pose>", <nome>_<pose>.webp), "logo" (equipe, campo `logo`), "ui" (arte/ui/<id>.png), "cenario"
## (fundo das cenas: arte/cenarios/<id>.webp) e "ilustracao" (quadro de um momento
## da história: arte/cenas/<id>.webp); os ids estão em data/historia.json.

static var _cache := {}


static func get_asset(id: String, variante: String) -> Texture2D:
	var chave := variante + ":" + id
	if not _cache.has(chave):
		_cache[chave] = _carregar(caminho(id, variante))
	return _cache[chave]


## Decisão 72: todo piloto (rival, candidato, mercado) usa um dos retratos
## genéricos (arte/pilotos/genericos/generico_NN.png, corpo em genericos/corpo/),
## sempre o mesmo para o mesmo piloto. A ordem é a dos dados (candidatos, depois
## as equipes), então os quatro pilotos de uma equipe nunca repetem rosto.
const GENERICOS := 12
static var _ordem_pilotos := {}


static func retrato_generico(id: String) -> String:
	var dados: Node = _dados()
	if _ordem_pilotos.is_empty() and dados != null:
		for c in EquipeJogador.candidatos(dados):
			_ordem_pilotos[String(c["id"])] = _ordem_pilotos.size()
		for e in dados.lista("equipes"):
			for p in e.get("pilotos", []):
				if not _ordem_pilotos.has(String(p["id"])):
					_ordem_pilotos[String(p["id"])] = _ordem_pilotos.size()
	var i := int(_ordem_pilotos.get(id, absi(hash(id))))
	return "res://arte/pilotos/genericos/generico_%02d.png" % (1 + i % GENERICOS)


## Caminho que os dados indicam ("" se a entidade não tem um).
static func caminho(id: String, variante: String) -> String:
	var dados: Node = _dados()
	match variante:
		"corpo":
			var pose := id.get_slice("@", 1) if "@" in id else ""
			var r := caminho(id.get_slice("@", 0), "retrato")
			return "" if r == "" else r.get_base_dir().path_join("corpo").path_join(
					r.get_file().get_basename() + ("_" + pose if pose != "" else "") + ".webp")
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
						return retrato_generico(id)
			# Segundo piloto e candidatos (carreira.json → equipe_jogador).
			if not EquipeJogador.piloto(dados, id).is_empty():
				return retrato_generico(id)
		"logo":
			if dados != null and dados.existe("equipes", id):
				return String(dados.item("equipes", id).get("logo", ""))
	return ""


## Limpa o cache (arte trocada com o jogo aberto, testes).
static func limpar() -> void:
	_cache = {}
	_ordem_pilotos = {}


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
