class_name Relevo
extends RefCounted
## Relevo da pista de terra (pedido do usuário, 2026-10-22: "ondulações e rampas
## fortes para dar adrenalina"). Só visual: a simulação continua em uma dimensão
## e decide o tempo; a tela levanta a pista e os carros por cima dela. Na saída
## de uma rampa o carro voa (balística a partir da velocidade que a simulação
## deu), e cai de volta no chão.
##
## Dados (data/pistas.json → relevo):
##   ondulacoes: [[de_m, ate_m, amplitude_m, onda_m], ...]  costelas de terra
##   rampas:     [[em_m, altura_m, subida_m, descida_m], ...]  o topo em em_m

const G := 9.8

var _ondulacoes: Array = []
var _rampas: Array = []
var _comprimento := 1.0


static func de(pista: Pista) -> Relevo:
	var r := Relevo.new()
	r._comprimento = maxf(pista.comprimento, 1.0)
	r._ondulacoes = pista.relevo.get("ondulacoes", [])
	r._rampas = pista.relevo.get("rampas", [])
	return r


func vazio() -> bool:
	return _ondulacoes.is_empty() and _rampas.is_empty()


## Altura do chão da pista em s (m).
func altura(s: float) -> float:
	var x := fposmod(s, _comprimento)
	var h := 0.0
	for o in _ondulacoes:
		if x >= float(o[0]) and x <= float(o[1]):
			# costelas: meia senoide ao quadrado, suaves nas pontas da faixa
			var borda := minf(x - float(o[0]), float(o[1]) - x)
			var entra := clampf(borda / maxf(float(o[3]), 0.1), 0.0, 1.0)
			h += float(o[2]) * pow(sin(PI * (x - float(o[0])) / float(o[3])), 2.0) * entra
	for r in _rampas:
		var d := x - float(r[0])
		if d <= 0.0 and d > -float(r[2]):
			# subida que fica mais íngreme até o topo (a boca da rampa lança o carro)
			h += float(r[1]) * pow((d + float(r[2])) / float(r[2]), 1.6)
		elif d > 0.0 and d < float(r[3]):
			h += float(r[1]) * (1.0 - smoothstep(0.0, float(r[3]), d))
	return h


## Inclinação do chão em s (m de altura por m andado).
func inclinacao(s: float) -> float:
	return (altura(s + 0.5) - altura(s - 0.5))


## A rampa cujo topo o carro cruzou entre s0 e s1 ([] se nenhuma): [em, altura, subida, descida].
func rampa_cruzada(s0: float, s1: float) -> Array:
	if s1 <= s0:
		return []
	for r in _rampas:
		var em := float(r[0])
		var k := floorf((s1 - em) / _comprimento)
		var topo := em + k * _comprimento
		if topo > s0 and topo <= s1:
			return r
	return []


## Velocidade vertical (m/s) com que o carro sai do topo da rampa a v (m/s):
## a inclinação da boca da rampa.
func saida(rampa: Array, v: float) -> float:
	return v * 1.6 * float(rampa[1]) / maxf(float(rampa[2]), 0.1)
