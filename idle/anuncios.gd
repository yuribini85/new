class_name IdleAnuncios
extends Node
## Anúncios do Chrome Racing Team (docs/idle/plano.md, AdMob). Sem o plugin do
## AdMob (editor, web, testes) o vídeo "passa" na hora e o intersticial não
## aparece: o jogo funciona igual, só sem anúncio.

## Intervalo mínimo entre intersticiais (s), de data/idle/idle.json.
var intersticial_min_s := 90.0
var _ultimo_intersticial := -INF


## O vídeo premiado: `ao_ganhar` roda só se a pessoa assistiu até o fim.
func premiado(ao_ganhar: Callable) -> void:
	ao_ganhar.call()


## Intersticial entre corridas, respeitando o intervalo mínimo.
func intersticial() -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _ultimo_intersticial < intersticial_min_s:
		return
	_ultimo_intersticial = agora
