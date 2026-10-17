class_name Selo
extends RefCounted
## Selo do save e do código do progresso (pedido do usuário, 2026-10-17:
## proteção contra cópia e adulteração): HMAC-SHA256 com a chave do jogo.
## Save editado à mão (giros, compras) deixa de bater com o selo; o jogo
## carrega o progresso, mas tira as compras pagas (a loja do aparelho devolve as
## legítimas ao conectar). Código do progresso com selo errado não carrega.
##
## A chave do build de loja vem de res://chave_selo.txt, gravado pelo CI a partir
## do segredo SELO_CHAVE (fora do Git); sem ele, a chave de desenvolvimento.
## Quem extrai o pacote acha a chave: o selo barra a edição casual, não um
## ataque dedicado (para isso, validação em servidor).

const ARQUIVO_CHAVE := "res://chave_selo.txt"
const CHAVE_DEV := "cw-dev-selo-2026"

static var _chave := PackedByteArray()


static func _chave_bytes() -> PackedByteArray:
	if _chave.is_empty():
		var texto := CHAVE_DEV
		if FileAccess.file_exists(ARQUIVO_CHAVE):
			var lida := FileAccess.get_file_as_string(ARQUIVO_CHAVE).strip_edges()
			if lida != "":
				texto = lida
		_chave = texto.to_utf8_buffer()
	return _chave


## Selo (32 hex) dos bytes.
static func de(bytes: PackedByteArray) -> String:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, _chave_bytes(), bytes).hex_encode().substr(0, 32)


static func confere(bytes: PackedByteArray, selo: String) -> bool:
	return selo.length() == 32 and de(bytes) == selo
