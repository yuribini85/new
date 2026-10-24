class_name NuvemPlay
extends Node
## Progresso na nuvem do Google Play (pedido do usuário, 2026-10-17): o código
## do progresso (SaveManager.codigo, ~2 KB) vai para os jogos salvos do Play
## Games a cada ida para o segundo plano, e as Configurações oferecem baixar
## de volta (outro aparelho, jogo reinstalado).
##
## Ponte com o plugin GodotPlayGameServices (singleton do export Android). Os
## nomes da API dele ficam nas constantes abaixo, para conferir quando o plugin
## entrar no export; método que não existir deixa a nuvem indisponível em vez
## de quebrar. O Principal cria este nó só quando o singleton existe.

signal baixado(codigo: String)
signal erro(texto: String)

const SINGLETON := "GodotPlayGameServices"
const ARQUIVO := "progresso"
const M_INICIAR := "initialize"
const M_SALVAR := "saveGame"  # (nome, descrição, bytes, tempo jogado ms, progresso)
const M_CARREGAR := "loadGame"  # (nome, criar se não existir)
const S_SALVO := "gameSaved"
const S_CARREGADO := "gameLoaded"

## A ponte ativa (null fora do Android ou sem o plugin).
static var ativa: NuvemPlay

var _plugin: Object


func _ready() -> void:
	if not Engine.has_singleton(SINGLETON):
		return
	var p := Engine.get_singleton(SINGLETON)
	for m in [M_SALVAR, M_CARREGAR]:
		if not p.has_method(m):
			push_warning("NuvemPlay: o plugin não tem %s; nuvem desligada" % m)
			return
	_plugin = p
	if p.has_method(M_INICIAR):
		p.call(M_INICIAR)
	if p.has_signal(S_SALVO):
		p.connect(S_SALVO, func(ok, _nome, _desc):
			if not ok:
				erro.emit("não foi possível salvar na nuvem"))
	if p.has_signal(S_CARREGADO):
		p.connect(S_CARREGADO, _carregou)
	ativa = self


func _exit_tree() -> void:
	if ativa == self:
		ativa = null


func disponivel() -> bool:
	return _plugin != null


## Envia o código do progresso (texto) para a nuvem.
func enviar(codigo: String, descricao: String, jogado_ms: int) -> void:
	if _plugin != null:
		_plugin.call(M_SALVAR, ARQUIVO, descricao, codigo.to_utf8_buffer(), jogado_ms, 0)


## Pede o progresso da nuvem; chega em `baixado`.
func baixar() -> void:
	if _plugin != null:
		_plugin.call(M_CARREGAR, ARQUIVO, false)


## O plugin entrega o jogo salvo como JSON com o conteúdo em bytes.
func _carregou(snapshot) -> void:
	var dados: Variant = JSON.parse_string(snapshot) if snapshot is String else snapshot
	if not dados is Dictionary or not dados.has("content"):
		erro.emit("não há progresso na nuvem")
		return
	var conteudo: Variant = dados["content"]
	var texto := PackedByteArray(conteudo).get_string_from_utf8() if conteudo is Array else String(conteudo)
	baixado.emit(texto)
