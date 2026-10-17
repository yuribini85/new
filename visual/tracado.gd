class_name Tracado
extends RefCounted
## Traçado de corrida (só visual): a linha que os carros seguem em vez do
## centro da pista. Aberto antes da curva, tangência na zebra de dentro,
## aberto de novo na saída, como num carro de corrida de verdade.
##
## Sai da curvatura do traçado: a média local (janela curta) puxa para dentro;
## a curva que vem aí ou acabou de passar (média larga maior que a local)
## puxa para fora. No meio da curva, por dentro; antes e depois, por fora. Em
## sequência de curvas (chicane, S) as duas se compensam sozinhas.
## Lateral > 0 é à esquerda do sentido da pista (mesmo sinal da Pista).

const PASSO_M := 2.0
const SIGMA_CURTA_M := 24.0
const SIGMA_LARGA_M := 55.0
const GANHO_DENTRO := 150.0
const GANHO_FORA := 400.0
## Até onde o centro do carro vai: borda do asfalto menos meio carro; na
## tangência, as rodas de dentro sobem na zebra.
const ABERTO_M := 5.0
const TANGENCIA_M := 5.6

static var _cache := {}

var _linha := PackedFloat32Array()
var _curta := PackedFloat32Array()
var _comprimento := 1.0


static func de(pista: Pista) -> Tracado:
	if not _cache.has(pista.id):
		var t := Tracado.new()
		t._calcular(pista)
		_cache[pista.id] = t
	return _cache[pista.id]


func _calcular(pista: Pista) -> void:
	_comprimento = pista.comprimento
	var n := maxi(int(ceil(_comprimento / PASSO_M)), 1)
	var k := PackedFloat32Array()
	k.resize(n)
	for i in n:
		var t: Dictionary = pista.trecho_em(i * PASSO_M)
		var r := float(t.get("raio_m", 0.0))
		k[i] = (1.0 if t.get("sentido", "esquerda") == "esquerda" else -1.0) / r if r > 0.0 else 0.0
	_curta = _media(k, SIGMA_CURTA_M)
	var larga := _media(k, SIGMA_LARGA_M)
	_linha.resize(n)
	for i in n:
		var v := tanh(GANHO_DENTRO * _curta[i] - GANHO_FORA * (larga[i] - _curta[i]))
		_linha[i] = v * (TANGENCIA_M if signf(v) == signf(_curta[i]) and absf(_curta[i]) > 0.002 else ABERTO_M)


## Média com peso gaussiano, circular (a volta fecha).
static func _media(k: PackedFloat32Array, sigma: float) -> PackedFloat32Array:
	var n := k.size()
	var raio := mini(int(ceil(sigma * 3.0 / PASSO_M)), n / 2)
	var pesos := PackedFloat32Array()
	var soma := 0.0
	for j in range(-raio, raio + 1):
		var w := exp(-pow(j * PASSO_M, 2.0) / (2.0 * sigma * sigma))
		pesos.append(w)
		soma += w
	var r := PackedFloat32Array()
	r.resize(n)
	for i in n:
		var acc := 0.0
		for j in range(-raio, raio + 1):
			acc += k[posmod(i + j, n)] * pesos[j + raio]
		r[i] = acc / soma
	return r


func _amostra(arr: PackedFloat32Array, s: float) -> float:
	var f := fposmod(s, _comprimento) / PASSO_M
	var i := int(f)
	var n := arr.size()
	return lerpf(arr[i % n], arr[(i + 1) % n], f - i)


## Deslocamento lateral do traçado ideal em s (m, + = esquerda).
func lateral(s: float) -> float:
	return _amostra(_linha, s)


## Curvatura média local em s (1/m, + = curva para a esquerda).
func curvatura(s: float) -> float:
	return _amostra(_curta, s)
