class_name ArteCarro
extends RefCounted
## Sprites dos carros (docs/arte_carros.md): um de cima e um isométrico por
## modelo, em res://arte/carros/<id>_topo.png e <id>_iso.png. Enquanto não há
## arte final, os arquivos são os provisórios de tools/gerar_sprites.gd.

const PASTA := "res://arte/carros/"
## Escala dos sprites (px por metro), a mesma do gerador e da especificação.
const PX_POR_M := 40.0

static var _cache := {}


## Textura da vista ("topo" ou "iso") do modelo; null se o arquivo não existe.
static func textura(id: String, vista: String) -> Texture2D:
	var chave := "%s_%s" % [id, vista]
	if not _cache.has(chave):
		var caminho := PASTA + chave + ".png"
		_cache[chave] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _cache[chave]
