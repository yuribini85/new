class_name Pilotagem
extends RefCounted
## Pilotagem por toques (decisão 127, teste com pessoas de 2026-10-21): com a
## corrida na tela, o jogador conduz nos pontos que decidem uma volta. Sem
## toque, o piloto contratado dirige (a corrida de sempre). Cada toque vira uma
## ordem da Simulacao (janela de tempo com ritmo, aceleração ou agressividade)
## gravada na fila: a corrida continua determinística e termina igual com o
## jogo fechado. Os números ficam em data/simulacao.json, "pilotagem".
##
## Revisão da corrida (decisão 131): três gestos.
## - Segurar na curva: encostar o dedo quando o carro chega ao ponto de
##   frenagem (a freada: na hora certa a curva sai mais rápida; cedo perde
##   tempo; tarde escapa da linha) e soltar na saída da curva (a aceleração:
##   na hora, saída limpa; antes, perde tração; depois, acelera tarde).
## - Largada: tocar quando as luzes do semáforo apagam (a espera depois da
##   terceira luz varia por corrida). Na hora, o carro arranca melhor; antes,
##   queima a largada; tarde, larga atrasado.
## - Deslizar: colado no carro da frente, a seta mostra o lado livre;
##   deslizar o dedo para ele é a passagem no vácuo (a ordem do ataque). Com
##   um rival colado atrás, ele mostra para que lado vai sair; deslizar para
##   esse lado fecha a porta (ele não passa por um tempo). Lado errado ou
##   demorar não vale. Depois recarrega.
## - Modo do pneu (provas longas, a partir de `forcar.minimo_voltas`): um modo
##   que fica valendo, aplicado a cada volta. ATAQUE anda mais na volta e gasta
##   um pneu guardado; sem pneu guardado, o pneu cansa nas `voltas_cansado`
##   seguintes. POUPAR anda menos e guarda um pneu (até `voltas_cansado`).
##   NORMAL não muda nada. (Decisão do usuário 2026-10-22: "pneu que cansa".)

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
const ACELEROU_TARDE := "acelerou_tarde"
const VACUO := "vacuo"
const PORTA_FECHADA := "porta_fechada"
const LADO_ERRADO := "lado_errado"
const FORCOU := "forcou"
const POUPOU := "poupou"

## Texto de cada nota na tela (língua do jogador).
const TEXTOS := {PERFEITA: "FREADA PERFEITA", BOA: "BOA FREADA", CEDO: "FREOU CEDO", TARDE: "FREOU TARDE",
		LIMPA: "SAÍDA LIMPA", SOLTOU: "PERDEU TRAÇÃO", ACELEROU_TARDE: "ACELEROU TARDE",
		LARGADA_PERFEITA: "LARGADA PERFEITA",
		LARGADA_BOA: "BOA LARGADA", QUEIMOU: "QUEIMOU A LARGADA", ATRASADA: "LARGOU ATRASADO",
		VACUO: "PASSOU NO VÁCUO", PORTA_FECHADA: "PORTA FECHADA!",
		LADO_ERRADO: "LADO ERRADO", FORCOU: "FORÇANDO", POUPOU: "POUPANDO PNEUS"}
## Modo do pneu nas provas longas (o texto é o do botão).
const ATAQUE := "ATAQUE"
const NORMAL := "NORMAL"
const POUPAR := "POUPAR"
const MODOS := [NORMAL, ATAQUE, POUPAR]


static func params(dados: Node) -> Dictionary:
	return dados.simulacao().get("pilotagem", {})


## Os parâmetros da pilotagem nesta prova. Ajuda para quem trava (decisão 130,
## E5): com `travado.derrotas` derrotas seguidas numa prova ainda não vencida,
## a faixa da freada boa cresce `ajuda.fator_boa` até a vitória, sem aviso. O
## valor de cada nota não muda.
static func para_prova(dados: Node, jogador: Node, evento_id: String) -> Dictionary:
	var p: Dictionary = params(dados).duplicate(true)
	var minimo := int(dados.carreira().get("travado", {}).get("derrotas", 0))
	var derrotas := int(jogador.historico.get(evento_id, {}).get("derrotas", 0))
	if p.has("ajuda") and minimo > 0 and derrotas >= minimo and not jogador.vitorias.has(evento_id):
		p["frenagem"]["boa_s"] = float(p["frenagem"]["boa_s"]) * float(p["ajuda"]["fator_boa"])
	return p


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


## A ordem da saída de curva: a aceleração da nota de `t` até `ate`.
static func ordem_saida(nota: String, t: float, ate: float, p: Dictionary) -> Dictionary:
	var acel := float(p["saida"]["acel"][nota])
	return {"de": t, "ate": maxf(ate, t + 0.1), "acel": acel, "origem": "saida"}


## Nota da saída pelo instante em que o dedo soltou, em relação à saída da
## curva (s de tela; negativo = antes): até a faixa da freada boa, limpa;
## antes, perdeu tração; depois, acelerou tarde.
static func nota_saida(atraso_s: float, p: Dictionary) -> String:
	var j := float(p["frenagem"]["boa_s"])
	if atraso_s < -j:
		return SOLTOU
	return LIMPA if atraso_s <= j else ACELEROU_TARDE


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


## A defesa aparece: um rival a até `distancia_m` atrás e a última defesa já
## recarregou.
static func pode_defender(distancia_tras_m: float, t: float, ultima_defesa: float, p: Dictionary) -> bool:
	var d: Dictionary = p.get("defesa", {})
	return not d.is_empty() and distancia_tras_m <= float(d["distancia_m"]) \
			and t - ultima_defesa >= float(d["recarga_s"])


## O lado (-1 esquerda, 1 direita) para onde o rival de trás sai, sorteado pela
## semente e pelo instante: a mesma corrida mostra sempre o mesmo lado.
static func lado_defesa(semente: int, t: float) -> int:
	return -1 if hash("defesa:%d:%d" % [semente, roundi(t * 10.0)]) % 2 == 0 else 1


## Nota do deslize: para o lado certo, dentro de `defesa.janela_s` (s de tela),
## vale `acerto` (PORTA_FECHADA na defesa, VACUO na passagem); do outro lado,
## lado errado. "" depois da janela (não conta).
static func nota_deslize(lado_dedo: int, lado_certo: int, demorou_s: float, p: Dictionary,
		acerto := PORTA_FECHADA) -> String:
	if demorou_s > float(p["defesa"]["janela_s"]):
		return ""
	return acerto if lado_dedo == lado_certo else LADO_ERRADO


## A ordem da porta fechada: enquanto vale, o carro de trás não passa.
static func ordem_defesa(t: float, p: Dictionary) -> Dictionary:
	return {"de": t, "ate": t + float(p["defesa"]["dura_s"]), "defesa": true, "origem": "defesa"}


## A prova tem FORÇAR / POUPAR PNEUS (voltas suficientes).
static func pode_forcar(voltas: int, p: Dictionary) -> bool:
	return p.has("forcar") and voltas >= int(p["forcar"]["minimo_voltas"])


## As ordens do ATAQUE de `t` até o fim da volta (`fim_volta`, s da corrida) e,
## sem pneu guardado, o pneu cansado nas `voltas_cansado` seguintes (cada uma
## com `volta_s` de duração).
static func ordens_forcar(t: float, fim_volta: float, volta_s: float, guardado: bool, p: Dictionary) -> Array:
	var f: Dictionary = p["forcar"]
	var r := [{"de": t, "ate": fim_volta, "ritmo": float(f["ritmo"]["forcar"]), "origem": "forcar"}]
	if not guardado:
		r.append({"de": fim_volta, "ate": fim_volta + volta_s * float(f["voltas_cansado"]),
				"ritmo": float(f["ritmo"]["cansado"]), "origem": "cansado"})
	return r


## A ordem do POUPAR: anda menos de `t` até o fim da volta.
static func ordem_poupar(t: float, fim_volta: float, p: Dictionary) -> Dictionary:
	return {"de": t, "ate": fim_volta, "ritmo": float(p["forcar"]["ritmo"]["poupar"]), "origem": "poupar"}


## A volta no modo `modo`: [ordens, pneus guardados depois]. ATAQUE gasta um
## pneu guardado (sem nenhum, cansa); POUPAR guarda um, até `voltas_cansado`.
static func ordens_modo(modo: String, t: float, fim_volta: float, volta_s: float, guardados: int,
		p: Dictionary) -> Array:
	match modo:
		ATAQUE:
			return [ordens_forcar(t, fim_volta, volta_s, guardados > 0, p), maxi(guardados - 1, 0)]
		POUPAR:
			return [[ordem_poupar(t, fim_volta, p)],
					mini(guardados + 1, int(p["forcar"]["voltas_cansado"]))]
	return [[], guardados]
