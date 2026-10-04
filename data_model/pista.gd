class_name Pista
extends RefCounted
## Pista como lista ordenada de trechos tipados (docs/plano_mvp.md, seção 3).
## A simulação lê só tipo, comprimento, raio e zona de ultrapassagem; a
## geometria (pontos_trajetoria) é usada apenas pela visualização.

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


func _init(dados_pista: Dictionary) -> void:
	id = dados_pista["id"]
	funcao = dados_pista.get("funcao", "")
	for t in dados_pista["trechos"]:
		if t["tipo"] in FORA_DA_VOLTA:
			continue
		trechos.append(t)
		inicios.append(comprimento)
		comprimento += float(t["comprimento_m"])


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
