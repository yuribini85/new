class_name MomentosCorrida
extends RefCounted
## Momentos de decisão na corrida (decisão 117): com o carro do jogador colado
## num rival, a tela oferece duas escolhas por alguns segundos. Cada escolha vira
## uma ordem (Simulacao: janela de tempo com fator de ritmo e agressividade) que
## entra no piloto da corrida em andamento (Fila.ordenar) e a corrida é refeita
## dali em diante; sem escolha, nada muda. Os números ficam em
## data/simulacao.json, "momentos" (calibrados por tools/calibrar_momentos.gd:
## uma corrida bem decidida vale mais ou menos uma peça).

const ATAQUE := "ataque"
const DEFESA := "defesa"


## O momento no instante t do resultado (amostras da corrida), ou {}:
## {"tipo": ATAQUE|DEFESA, "rival": id, "distancia": m}. Ataque com alguém
## logo à frente; defesa com alguém logo atrás (e ninguém à frente para atacar).
static func detectar(resultado: Dictionary, t: float, p: Dictionary) -> Dictionary:
	if t < float(p["inicio_s"]) or t > float(resultado["duracao"]) - float(p["fim_s"]):
		return {}
	var amostras: Array = resultado.get("amostras", [])
	if amostras.size() < 2:
		return {}
	var s := _distancias(amostras, t)
	if not s.has("jogador"):
		return {}
	var meu: float = s["jogador"]
	var meta := float(resultado["comprimento"]) * int(resultado["voltas"])
	if meu >= meta:
		return {}
	var frente := ""
	var d_frente := INF
	var tras := ""
	var d_tras := INF
	for id in s:
		if id == "jogador" or float(s[id]) >= meta:
			continue
		var d: float = float(s[id]) - meu
		if d > 0.0 and d < d_frente:
			frente = id
			d_frente = d
		elif d <= 0.0 and -d < d_tras:
			tras = id
			d_tras = -d
	var gap := float(p["distancia_m"])
	if frente != "" and d_frente <= gap:
		return {"tipo": ATAQUE, "rival": frente, "distancia": d_frente}
	if tras != "" and d_tras <= gap:
		return {"tipo": DEFESA, "rival": tras, "distancia": d_tras}
	return {}


## As duas escolhas do tipo, na ordem da tela: [[id, opção], ...].
static func escolhas(tipo: String, p: Dictionary) -> Array:
	var r := []
	for id in p["opcoes"]:
		if String(p["opcoes"][id]["tipo"]) == tipo:
			r.append([id, p["opcoes"][id]])
	return r


## A ordem da escolha `id` feita no instante t.
static func ordem(id: String, t: float, p: Dictionary) -> Dictionary:
	var o: Dictionary = p["opcoes"][id]
	var de := t + float(o["atraso_s"])
	return {"escolha": id, "de": de, "ate": de + float(o["dura_s"]), "ritmo": float(o["ritmo"]),
			"agressividade": float(o.get("agressividade", -1.0))}


## Folga depois do fim da ordem para conferir o duelo (técnico: o carro que
## passou no último instante da ordem já aparece na frente).
const CONFERE_S := 1.0


## O que cada escolha faz com o duelo (Fila.prever dá as corridas refeitas):
## {id: {"vence": bool, "t": s, "como": "passou"|"segurou"}}. vence: no fim da
## ordem o duelo com o rival termina diferente da corrida sem ordem. t: o
## instante a mostrar na tela; "passou" quando o jogador troca de lugar com o
## rival na corrida refeita (t é a ultrapassagem), "segurou" quando quem
## trocaria é a corrida sem ordem (t é quando o rival passaria). -1 sem vencer.
static func avaliar(base: Dictionary, m: Dictionary, ordens: Dictionary, refeitas: Dictionary) -> Dictionary:
	var r := {}
	var rival: String = m["rival"]
	for id in ordens:
		var o: Dictionary = ordens[id]
		var fim := float(o["ate"]) + CONFERE_S
		var res: Dictionary = refeitas[id]
		var vence := frente(res, rival, fim) != frente(base, rival, fim)
		var t := -1.0
		var como := ""
		if vence:
			# Antes de a ordem valer as duas corridas são iguais: procura dali.
			t = _troca(res, rival, float(o["de"]), fim)
			como = "passou" if t >= 0.0 and frente(res, rival, fim) else "segurou"
			if como == "segurou":
				t = _troca(base, rival, float(o["de"]), fim)
			if t < 0.0:
				t = fim
		r[id] = {"vence": vence, "t": t, "como": como}
	return r


## Alguma das escolhas muda o duelo (só aí o momento aparece).
static func importa(avaliacao: Dictionary) -> bool:
	for id in avaliacao:
		if avaliacao[id]["vence"]:
			return true
	return false


## O jogador está à frente do rival no instante t.
static func frente(resultado: Dictionary, rival: String, t: float) -> bool:
	var s := _distancias(resultado["amostras"], minf(t, float(resultado["duracao"])))
	return float(s.get("jogador", 0.0)) > float(s.get(rival, 0.0))


## Primeiro instante em [de, ate] em que jogador e rival trocam de lugar (de
## meio em meio segundo, refinado), ou -1.
static func _troca(resultado: Dictionary, rival: String, de: float, ate: float) -> float:
	var antes := frente(resultado, rival, de)
	var t := de
	while t < ate:
		var prox := minf(t + 0.5, ate)
		if frente(resultado, rival, prox) != antes:
			var a := t
			var b := prox
			for i in 6:
				var meio := (a + b) * 0.5
				if frente(resultado, rival, meio) != antes:
					b = meio
				else:
					a = meio
			return b
		t = prox
	return -1.0


## Distância de cada carro no instante t (interpolada entre amostras).
static func _distancias(amostras: Array, t: float) -> Dictionary:
	var lo := 0
	var hi := amostras.size() - 1
	if t <= float(amostras[0]["t"]):
		return amostras[0]["s"]
	if t >= float(amostras[hi]["t"]):
		return amostras[hi]["s"]
	while hi - lo > 1:
		var m := (lo + hi) / 2
		if float(amostras[m]["t"]) <= t:
			lo = m
		else:
			hi = m
	var a: Dictionary = amostras[lo]
	var b: Dictionary = amostras[hi]
	var f := (t - float(a["t"])) / maxf(float(b["t"]) - float(a["t"]), 1e-6)
	var r := {}
	for id in a["s"]:
		r[id] = lerpf(float(a["s"][id]), float(b["s"].get(id, a["s"][id])), f)
	return r
