class_name IdleAnuncios
extends Node
## Anúncios do The Fastfather (docs/idle/plano.md, AdMob): vídeo premiado e
## intersticial ao subir de liga. No Android com o plugin do AdMob
## (addons/AdmobPlugin, instalado pelo CI só no APK do idle) os anúncios são de
## verdade; sem ele (editor, web, testes) o vídeo "passa" na hora e o
## intersticial não aparece: o jogo funciona igual, só sem anúncio.
## Vídeo que não carrega ou falha ao abrir paga a recompensa igual (a queixa
## mais comum do gênero é o vídeo que trava e não paga); só quem fecha o vídeo
## antes do fim fica sem ela.
## Ids de teste do Google até o usuário mandar os dele (data/idle/idle.json,
## "admob": is_real e os ids reais).

const ADMOB := "res://addons/AdmobPlugin/Admob.gd"

## Intervalo mínimo entre intersticiais (s), de data/idle/idle.json.
var intersticial_min_s := 90.0
var config := {}  # data/idle/idle.json → "admob"
var _ultimo_intersticial := -INF
var _admob: Node
var _pronto := false
var _premiado_carregado := false
var _intersticial_carregado := false
var _ao_ganhar := Callable()
var _ganhou := false


func _ready() -> void:
	if not OS.has_feature("android") or not ResourceLoader.exists(ADMOB):
		return
	_admob = load(ADMOB).new()
	_admob.is_real = bool(config.get("is_real", false))
	_admob.android_real_rewarded_id = String(config.get("premiado_id", ""))
	_admob.android_real_interstitial_id = String(config.get("intersticial_id", ""))
	add_child(_admob)
	_admob.initialization_completed.connect(func(_s):
		_pronto = true
		_carregar())
	_admob.rewarded_ad_loaded.connect(func(_i, _r): _premiado_carregado = true)
	_admob.rewarded_ad_failed_to_load.connect(func(_i, _e): _premiado_carregado = false)
	_admob.rewarded_ad_user_earned_reward.connect(func(_i, _r): _ganhou = true)
	_admob.rewarded_ad_dismissed_full_screen_content.connect(func(_i): _fim_premiado())
	_admob.rewarded_ad_failed_to_show_full_screen_content.connect(func(_i, _e):
		_ganhou = true
		_fim_premiado())
	_admob.interstitial_ad_loaded.connect(func(_i, _r): _intersticial_carregado = true)
	_admob.interstitial_ad_failed_to_load.connect(func(_i, _e): _intersticial_carregado = false)
	_admob.interstitial_ad_dismissed_full_screen_content.connect(func(_i):
		Preferencias.aplicar()
		_admob.load_interstitial_ad())
	_admob.initialize()


func _carregar() -> void:
	if not _premiado_carregado:
		_admob.load_rewarded_ad()
	if not _intersticial_carregado:
		_admob.load_interstitial_ad()


## O vídeo premiado: `ao_ganhar` roda se a pessoa assistiu até o fim ou se o
## vídeo não pôde aparecer (sem AdMob, sem vídeo carregado, falha ao abrir).
func premiado(ao_ganhar: Callable) -> void:
	if _admob == null or not _premiado_carregado:
		if _admob != null and _pronto:
			_admob.load_rewarded_ad()
		ao_ganhar.call()
		return
	_ao_ganhar = ao_ganhar
	_ganhou = false
	_premiado_carregado = false
	_mudo()
	_admob.show_rewarded_ad()


## O som do jogo para enquanto o anúncio toca (docs/idle/sonorizacao.md) e volta
## no fechamento (Preferencias.aplicar devolve as chaves do jogador).
func _mudo() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)


func _fim_premiado() -> void:
	Preferencias.aplicar()
	if _ganhou and _ao_ganhar.is_valid():
		_ao_ganhar.call()
	_ao_ganhar = Callable()
	_ganhou = false
	if _pronto:
		_admob.load_rewarded_ad()


## Intersticial (só ao subir de liga), respeitando o intervalo mínimo.
func intersticial() -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _ultimo_intersticial < intersticial_min_s:
		return
	if _admob == null or not _intersticial_carregado:
		if _admob != null and _pronto:
			_admob.load_interstitial_ad()
		return
	_ultimo_intersticial = agora
	_intersticial_carregado = false
	_mudo()
	_admob.show_interstitial_ad()
