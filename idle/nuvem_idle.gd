class_name NuvemIdle
extends Node
## Save na nuvem do The Fastfather (jogos salvos do Google Play Games; análise
## de retenção, 2026-10-28: perder o progresso é a queixa mais dura do gênero).
## No Android com o plugin (addons/GodotPlayGameServices, instalado pelo CI só
## no APK e só com o game_id de data/idle/idle.json "play_games") o jogo salva
## na conta Google do jogador ao sair e de tempos em tempos; sem ele (editor,
## web, testes) nada acontece: o save do aparelho segue igual.
## Ao abrir, lê o da nuvem: se for mais adiantado que o do aparelho, avisa
## (`achou`), e a tela decide: aparelho sem progresso carrega direto; com
## progresso, pergunta.

signal achou(save: Dictionary)

const PLUGIN := "GodotPlayGameServices"
const PASTA := "res://addons/GodotPlayGameServices/scripts/"
const ARQUIVO := "fastfather"

var config := {}  # data/idle/idle.json → "play_games"
var conectado := false
var _assinatura: Node
var _snapshots: Node
var _progresso_local := 0
var _ultimo_envio := -INF


func disponivel() -> bool:
	return OS.has_feature("android") and Engine.has_singleton(PLUGIN) \
			and String(config.get("game_id", "")) != "" and has_node("/root/" + PLUGIN)


## Liga o plugin e lê o save da nuvem; `progresso_local` é o do aparelho.
func iniciar(progresso_local: int) -> void:
	_progresso_local = progresso_local
	if not disponivel():
		return
	get_node("/root/" + PLUGIN).initialize()
	_assinatura = load(PASTA + "sign_in/sign_in_client.gd").new()
	_snapshots = load(PASTA + "snapshots/snapshots_client.gd").new()
	add_child(_assinatura)
	add_child(_snapshots)
	_assinatura.user_authenticated.connect(_autenticado)
	_snapshots.game_loaded.connect(_carregou)
	_assinatura.is_authenticated()


## O botão das configurações, para quem não entrou na conta ao abrir.
func entrar() -> void:
	if _assinatura != null:
		_assinatura.sign_in()


func _autenticado(sim: bool) -> void:
	conectado = sim
	if sim:
		_snapshots.load_game(ARQUIVO, false)


func _carregou(snapshot) -> void:
	if snapshot == null or snapshot.content.is_empty():
		return
	var s = JSON.parse_string(snapshot.content.get_string_from_utf8())
	if s is Dictionary and IdleEstado.progresso_de(s) > _progresso_local:
		achou.emit(s)


## Envia o save; `forcar` ignora o intervalo (ao sair do app).
func enviar(estado: IdleEstado, forcar := false) -> void:
	if not conectado or _snapshots == null:
		return
	var agora := Time.get_ticks_msec() / 1000.0
	if not forcar and agora - _ultimo_envio < float(config.get("salvar_a_cada_s", 300.0)):
		return
	_ultimo_envio = agora
	var p := estado.progresso()
	_progresso_local = maxi(_progresso_local, p)
	_snapshots.save_game(ARQUIVO, "The Fastfather", JSON.stringify(estado.para_save()).to_utf8_buffer(), 0, p)
