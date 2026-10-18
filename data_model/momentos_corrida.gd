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
