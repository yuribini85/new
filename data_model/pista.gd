class_name Pista
extends RefCounted
## Pista como lista ordenada de trechos tipados (docs/plano_mvp.md, seção 3).
## A simulação lê só tipo, comprimento, raio e zona de ultrapassagem. A
## geometria (para a visualização) é derivada dos mesmos trechos: reta avança,
## trecho com raio_m > 0 é um arco para o `sentido` ("esquerda", padrão, ou
## "direita"). Assim o traçado nunca contradiz a simulação.

const TIPOS := [
	"reta", "curva_lenta", "curva_media", "curva_rapida",
	"frenagem", "aceleracao", "entrada_box", "saida_box",
]
## Trechos de box ficam fora da volta: o primeiro build não tem parada.
const FORA_DA_VOLTA := ["entrada_box", "saida_box"]

var id: String
var funcao: String
var trechos: Array = []
## Distância acumulada no início de cada trecho de `trechos`.
var inicios: PackedFloat64Array = []
var comprimento: float = 0.0
## Posição (m) e rumo (rad) no início de cada trecho; a volta começa em (0,0) rumo 0.
var _pos_inicio: Array = []
var _rumo_inicio: PackedFloat64Array = []
var _pos_final: Vector2
var _rumo_final: float


func _init(dados_pista: Dictionary) -> void:
	id = dados_pista["id"]
	funcao = dados_pista.get("funcao", "")
	for t in dados_pista["trechos"]:
		if t["tipo"] in FORA_DA_VOLTA:
			continue
		trechos.append(t)
		inicios.append(comprimento)
		comprimento += float(t["comprimento_m"])
	var pos := Vector2.ZERO
	var rumo := 0.0
	for t in trechos:
		_pos_inicio.append(pos)
		_rumo_inicio.append(rumo)
		var fim := _avancar(t, pos, rumo, float(t["comprimento_m"]))
		pos = fim[0]
		rumo = fim[1]
	_pos_final = pos
	_rumo_final = rumo


## Lista de problemas da definição; vazia se a pista é válida.
static func validar(dados_pista: Dictionary) -> Array:
	var erros := []
	var trechos_volta := 0
	for i in dados_pista.get("trechos", []).size():
		var t: Dictionary = dados_pista["trechos"][i]
		if not t.get("tipo") in TIPOS:
			erros.append("trecho %d: tipo inválido '%s'" % [i, t.get("tipo")])
			continue
		if float(t.get("comprimento_m", 0)) <= 0:
			erros.append("trecho %d: comprimento_m deve ser positivo" % i)
		if t["tipo"].begins_with("curva") and float(t.get("raio_m", 0)) <= 0:
			erros.append("trecho %d: curva sem raio_m positivo" % i)
		if not t.get("sentido", "esquerda") in ["esquerda", "direita"]:
			erros.append("trecho %d: sentido inválido '%s'" % [i, t.get("sentido")])
		if not t["tipo"] in FORA_DA_VOLTA:
			trechos_volta += 1
	if trechos_volta == 0:
		erros.append("pista sem trechos na volta")
	return erros


## Índice do trecho na distância s (qualquer volta, inclusive s negativo do grid).
func indice_em(s: float) -> int:
	return inicios.bsearch(fposmod(s, comprimento), false) - 1


func trecho_em(s: float) -> Dictionary:
	return trechos[indice_em(s)]


## Posição em metros no plano da pista, para qualquer s (voltas e grid).
func posicao_em(s: float) -> Vector2:
	var i := indice_em(s)
	return _avancar(trechos[i], _pos_inicio[i], _rumo_inicio[i], fposmod(s, comprimento) - inicios[i])[0]


## Rumo em radianos (0 = +x, anti-horário) na distância s.
func rumo_em(s: float) -> float:
	var i := indice_em(s)
	return _avancar(trechos[i], _pos_inicio[i], _rumo_inicio[i], fposmod(s, comprimento) - inicios[i])[1]


## Distância em metros entre o fim da volta e a largada. Acima de ~1 m o
## traçado não fecha e a pista precisa de ajuste nos comprimentos ou raios.
func erro_fechamento() -> float:
	return _pos_final.length()


## Diferença de rumo ao fechar a volta, em rad (0 quando a volta fecha alinhada).
func erro_rumo() -> float:
	return absf(angle_difference(0.0, _rumo_final))


## Polilinha da volta a cada `passo` metros.
func pontos(passo: float = 2.0) -> PackedVector2Array:
	var r := PackedVector2Array()
	var n := maxi(int(ceil(comprimento / passo)), 1)
	for k in n + 1:
		r.append(posicao_em(comprimento * k / n) if k < n else posicao_em(0.0))
	return r


static func _avancar(t: Dictionary, pos: Vector2, rumo: float, d: float) -> Array:
	var raio := float(t.get("raio_m", 0.0))
	if raio <= 0.0:
		return [pos + Vector2.from_angle(rumo) * d, rumo]
	var lado := -1.0 if t.get("sentido", "esquerda") == "direita" else 1.0
	var giro := lado * d / raio
	# Centro do arco à esquerda (ou direita) do rumo atual.
	var centro := pos + Vector2.from_angle(rumo + lado * PI / 2.0) * raio
	var de_centro := pos - centro
	return [centro + de_centro.rotated(giro), rumo + giro]
