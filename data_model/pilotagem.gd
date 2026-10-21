class_name Pilotagem
extends RefCounted
## Pilotagem por toques (decisão 127, teste com pessoas de 2026-10-21): com a
## corrida na tela, o jogador conduz nos pontos que decidem uma volta. Sem
## toque, o piloto contratado dirige (a corrida de sempre). Cada toque vira uma
## ordem da Simulacao (janela de tempo com ritmo, aceleração ou agressividade)
## gravada na fila: a corrida continua determinística e termina igual com o
## jogo fechado. Os números ficam em data/simulacao.json, "pilotagem".
##
## - Frenagem: tocar quando o carro chega ao ponto de frenagem da curva. Na hora
##   certa a curva sai mais rápida; cedo perde tempo; tarde escapa da linha.
## - Saída: estar segurando quando o carro sai da curva acelera melhor; soltar
##   antes do fim da saída perde tração.
## - Largada: tocar quando as luzes do semáforo apagam (a espera depois da
##   terceira luz varia por corrida). Na hora, o carro arranca melhor; antes,
##   queima a largada; tarde, larga atrasado.
## - Vácuo: colado num rival, segurar enche a barra do vácuo; soltar com ela
##   cheia é a ultrapassagem (a ordem do ataque); segurar demais perde o vácuo.
##   Depois recarrega.

const PERFEITA := "perfeita"
const BOA := "boa"
const CEDO := "cedo"
const TARDE := "tarde"
const LIMPA := "limpa"
const SOLTOU := "soltou"
const LARGADA_PERFEITA := "largada_perfeita"
const LARGADA_BOA := "largada_boa"
const QUEIMOU := "queimou"
const ATRASADA := "atrasada"
const VACUO := "vacuo"
const PERDEU_VACUO := "perdeu_vacuo"

## Texto de cada nota na tela (língua do jogador).
const TEXTOS := {PERFEITA: "FREADA PERFEITA", BOA: "BOA FREADA", CEDO: "FREOU CEDO", TARDE: "FREOU TARDE",
		LIMPA: "SAÍDA LIMPA", SOLTOU: "PERDEU TRAÇÃO", LARGADA_PERFEITA: "LARGADA PERFEITA",
		LARGADA_BOA: "BOA LARGADA", QUEIMOU: "QUEIMOU A LARGADA", ATRASADA: "LARGOU ATRASADO",
		VACUO: "PASSOU NO VÁCUO", PERDEU_VACUO: "PERDEU O VÁCUO"}


static func params(dados: Node) -> Dictionary:
	return dados.simulacao().get("pilotagem", {})


static func ativa(dados: Node) -> bool:
	return bool(params(dados).get("ativa", false))


## Nota da frenagem pelo atraso do toque em relação ao ponto de frenagem
## (negativo: tocou antes).
static func nota_frenagem(atraso_s: float, p: Dictionary) -> String:
	var f: Dictionary = p["frenagem"]
	if absf(atraso_s) <= float(f["perfeita_s"]):
		return PERFEITA
	if absf(atraso_s) <= float(f["boa_s"]):
		return BOA
	return CEDO if atraso_s < 0.0 else TARDE


## A ordem da frenagem: do toque até o carro sair da curva, o ritmo da nota.
## Freada boa ou perfeita tocada antes do ponto de frenagem (t_ponto) vale a
## partir do ponto: o valor da nota não muda com o lugar do toque na faixa.
static func ordem_frenagem(nota: String, t_toque: float, t_saida: float, p: Dictionary, t_ponto := -INF) -> Dictionary:
	var de := maxf(t_toque, t_ponto) if nota in [PERFEITA, BOA] else t_toque
	return {"de": de, "ate": maxf(t_saida, de + 0.1), "ritmo": float(p["frenagem"]["ritmo"][nota]),
			"origem": "frenagem"}


## A ordem da saída de curva: a aceleração da nota por `dura_s` a partir de t.
## Soltar no meio: a ordem de SOLTOU vale do instante em que soltou até o fim da
## saída, por cima da LIMPA (as duas multiplicam: o resultado é o fator de SOLTOU).
static func ordem_saida(nota: String, t: float, ate: float, p: Dictionary) -> Dictionary:
	var s: Dictionary = p["saida"]
	var acel := float(s["acel"][nota])
	if nota == SOLTOU:
		acel /= float(s["acel"][LIMPA])
	return {"de": t, "ate": maxf(ate, t + 0.1), "acel": acel, "origem": "saida"}


## Segundos de saída de curva (a janela em que segurar conta).
static func dura_saida(p: Dictionary) -> float:
	return float(p["saida"]["dura_s"])


## A ordem do ataque: mais agressividade e um pouco mais de ritmo por um tempo.
static func ordem_ataque(t: float, p: Dictionary) -> Dictionary:
	var a: Dictionary = p["ataque"]
	return {"de": t, "ate": t + float(a["dura_s"]), "ritmo": float(a["ritmo"]),
			"agressividade": float(a["agressividade"]), "origem": "ataque"}


## O vácuo aparece: alguém à frente a até `distancia_m` e o último ataque
## (passagem no vácuo) já recarregou.
static func pode_atacar(distancia_frente_m: float, t: float, ultimo_ataque: float, p: Dictionary) -> bool:
	var a: Dictionary = p["ataque"]
	return distancia_frente_m <= float(a["distancia_m"]) and t - ultimo_ataque >= float(a["recarga_s"])


## Fração da recarga do ataque (0 acabou de atacar, 1 pronto).
static func recarga(t: float, ultimo_ataque: float, p: Dictionary) -> float:
	return clampf((t - ultimo_ataque) / float(p["ataque"]["recarga_s"]), 0.0, 1.0)


## A curva tem frenagem que vale tocar: o carro freia ao menos `frenagem_min_m`
## antes da entrada.
static func tem_frenagem(curva: Dictionary, comprimento: float, p: Dictionary) -> bool:
	return fposmod(float(curva["inicio"]) - float(curva["frenagem"]), comprimento) >= float(p["frenagem"]["minimo_m"])


## Nota da largada pelo tempo de reação ao apagar das luzes (negativo: tocou
## com as luzes acesas). "" depois da janela: o toque não conta.
static func nota_largada(reacao_s: float, p: Dictionary) -> String:
	var l: Dictionary = p["largada"]
	if reacao_s < 0.0:
		return QUEIMOU
	if reacao_s <= float(l["perfeita_s"]):
		return LARGADA_PERFEITA
	if reacao_s <= float(l["boa_s"]):
		return LARGADA_BOA
	return ATRASADA if reacao_s <= float(l["janela_s"]) else ""


## A ordem da largada: vale do apagar das luzes (t = 0 da corrida; a corrida ao
## vivo espera o toque, ver Fila.pilotar) por `dura_s`, com a aceleração da
## nota; na largada boa ou perfeita o piloto também briga pela posição
## (agressividade) e pode passar antes da primeira zona de ultrapassagem.
static func ordem_largada(nota: String, p: Dictionary) -> Dictionary:
	var l: Dictionary = p["largada"]
	var o := {"de": 0.0, "ate": float(l["dura_s"]), "acel": float(l["acel"][nota]), "origem": "largada"}
	if nota in [LARGADA_PERFEITA, LARGADA_BOA]:
		o["agressividade"] = float(l["agressividade"])
		o["livre"] = true
	return o


## Quanto as três luzes ficam acesas antes de apagar (s), sorteado pela
## semente da corrida: a mesma corrida apaga sempre no mesmo instante.
static func espera_largada(semente: int, p: Dictionary) -> float:
	var e: Array = p["largada"]["espera_s"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("largada:%d" % semente)
	return rng.randf_range(float(e[0]), float(e[1]))


## Barra do vácuo pelo tempo segurando (s de tela): 0..1 enchendo, 1 cheia
## (soltar agora passa) até `janela_s` depois; além disso perdeu o vácuo.
static func nota_vacuo(segurou_s: float, p: Dictionary) -> String:
	var v: Dictionary = p["vacuo"]
	if segurou_s < float(v["carga_s"]):
		return ""
	return VACUO if segurou_s <= float(v["carga_s"]) + float(v["janela_s"]) else PERDEU_VACUO
