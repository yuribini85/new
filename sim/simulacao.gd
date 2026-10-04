class_name Simulacao
extends RefCounted
## Resolve uma corrida sem renderizar nada (docs/plano_mvp.md, seção 3).
##
## Modelo quase estático: para cada carro e cada volta existe um envelope de
## velocidade — limite de curva sqrt(aderência·g·raio), velocidade máxima e
## frenagem antecipada — e o carro acelera até ele limitado por potência e
## tração. Ultrapassagem só em trechos marcados; fora deles o carro de trás
## respeita a distância mínima (cortesia). A visualização só lê `amostras`.

const G := 9.81
const CV_PARA_W := 735.5
const KMH_PARA_MS := 1.0 / 3.6

## Chaves obrigatórias em data/simulacao.json.
const PARAMS := [
	"passo_m", "dt_s", "amostra_dt_s", "tempo_max_s",
	"distancia_minima_m", "sigma_ruido", "fator_tracao",
]


## participantes: em ordem de grid, cada um
##   {"id": String, "atributos": Carro.atributos_efetivos(), "piloto": {ritmo, consistencia, agressividade}}
## Retorna {"classificacao", "carros", "amostras", "comprimento"}.
static func correr(pista: Pista, participantes: Array, voltas: int, params: Dictionary, semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var comprimento := pista.comprimento
	var n := maxi(int(ceil(comprimento / float(params["passo_m"]))), 1)
	var passo := comprimento / n
	var dt := float(params["dt_s"])
	var dmin := float(params["distancia_minima_m"])

	# Geometria discretizada: raio (0 = sem limite de curva) e zona de ultrapassagem.
	var raios := PackedFloat64Array()
	var zonas := PackedInt32Array()
	raios.resize(n)
	zonas.resize(n)
	for i in n:
		var idx := pista.indice_em((i + 0.5) * passo)
		var t: Dictionary = pista.trechos[idx]
		raios[i] = float(t.get("raio_m", 0.0))
		zonas[i] = idx if t.get("ultrapassagem", false) else -1

	var carros := []
	for g in participantes.size():
		var p: Dictionary = participantes[g]
		var a: Dictionary = p["atributos"]
		var piloto: Dictionary = p["piloto"]
		var mu := float(a["aderencia"])
		var c := {
			"id": p["id"],
			"agressividade": float(piloto["agressividade"]),
			"potencia_w": float(a["potencia"]) * CV_PARA_W,
			"massa": float(a["peso"]),
			"acel_tracao": mu * G * float(params["fator_tracao"][a["tracao"]]),
			"s": -g * dmin,
			"v": 0.0,
			"envelopes": [],
			"voltas": [],
			"ultima_passagem": 0.0,
			"terminou": false,
			"tempo_total": 0.0,
			"rolagens": {},
		}
		for volta in voltas:
			var ruido := absf(rng.randfn(0.0, float(params["sigma_ruido"])))
			var fator := maxf(float(piloto["ritmo"]) * (1.0 - ruido * (1.0 - float(piloto["consistencia"]))), 0.01)
			c["envelopes"].append(_envelope(raios, passo, mu, float(a["freio"]),
					float(a["velocidade_max"]) * KMH_PARA_MS, fator))
		carros.append(c)

	var amostras := []
	var proxima_amostra := 0.0
	var t := 0.0
	var tempo_max := float(params["tempo_max_s"])
	var distancia_final := voltas * comprimento

	while t < tempo_max:
		var ativos := carros.filter(func(c): return not c["terminou"])
		if ativos.is_empty():
			break
		if t >= proxima_amostra:
			amostras.append(_amostra(t, carros))
			proxima_amostra += float(params["amostra_dt_s"])

		# Ordem de corrida antes do passo: o da frente resolve primeiro.
		ativos.sort_custom(func(x, y): return x["s"] > y["s"])
		var frente: Dictionary = {}
		for c in ativos:
			var s_antes: float = c["s"]
			var volta := clampi(floori(s_antes / comprimento), 0, voltas - 1)
			var i := int(fposmod(s_antes, comprimento) / passo) % n
			var env: PackedFloat64Array = c["envelopes"][volta]
			var limite := minf(env[i], env[(i + 1) % n])
			var v: float = c["v"]
			var acel: float = c["acel_tracao"]
			if v > 0.0:
				acel = minf(acel, c["potencia_w"] / (c["massa"] * v))
			var v_novo := minf(v + acel * dt, limite)
			var s_novo := s_antes + (v + v_novo) * 0.5 * dt

			if not frente.is_empty() and s_novo > frente["s"] - dmin:
				if not _pode_passar(c, zonas[i], volta, v_novo, frente["v"], rng):
					s_novo = maxf(s_antes, frente["s"] - dmin)
					v_novo = minf(v_novo, frente["v"])

			c["s"] = s_novo
			c["v"] = v_novo
			_registrar_passagem(c, s_antes, s_novo, t, dt, comprimento, voltas)
			frente = c
		t += dt

	amostras.append(_amostra(t, carros))
	return {
		"classificacao": _classificar(carros, distancia_final),
		"carros": _resumo(carros),
		"amostras": amostras,
		"comprimento": comprimento,
	}


## Velocidade máxima em cada ponto considerando a frenagem para os pontos à
## frente. A pista é fechada, então a passada para trás dá duas voltas.
static func _envelope(raios: PackedFloat64Array, passo: float, mu: float, freio: float,
		v_max: float, fator: float) -> PackedFloat64Array:
	var n := raios.size()
	var env := PackedFloat64Array()
	env.resize(n)
	for i in n:
		var lim := v_max
		if raios[i] > 0.0:
			lim = minf(lim, sqrt(mu * G * raios[i]))
		env[i] = lim * fator
	var desacel := freio * mu * G * fator
	for k in range(2 * n - 1, -1, -1):
		var i := k % n
		env[i] = minf(env[i], sqrt(env[(i + 1) % n] ** 2 + 2.0 * desacel * passo))
	return env


## Na entrada de cada zona, uma vez por volta, a agressividade decide se o
## piloto tenta a ultrapassagem. Só passa se estiver mais rápido.
static func _pode_passar(c: Dictionary, zona: int, volta: int, v: float, v_frente: float,
		rng: RandomNumberGenerator) -> bool:
	if zona < 0:
		return false
	var chave := "%d:%d" % [volta, zona]
	if not c["rolagens"].has(chave):
		c["rolagens"][chave] = rng.randf() < c["agressividade"]
	return c["rolagens"][chave] and v > v_frente


static func _registrar_passagem(c: Dictionary, s_antes: float, s_novo: float, t: float,
		dt: float, comprimento: float, voltas: int) -> void:
	var k := floori(s_novo / comprimento)
	if k < 1 or k <= floori(s_antes / comprimento):
		return
	var cruzamento := t + dt * (k * comprimento - s_antes) / (s_novo - s_antes)
	c["voltas"].append(cruzamento - c["ultima_passagem"])
	c["ultima_passagem"] = cruzamento
	if k >= voltas:
		c["terminou"] = true
		c["tempo_total"] = cruzamento


static func _amostra(t: float, carros: Array) -> Dictionary:
	var s := {}
	for c in carros:
		s[c["id"]] = c["s"]
	return {"t": t, "s": s}


## Quem terminou, por tempo; quem não terminou (tempo_max), pela distância.
static func _classificar(carros: Array, distancia_final: float) -> Array:
	var ordem := carros.duplicate()
	ordem.sort_custom(func(x, y):
		if x["terminou"] != y["terminou"]:
			return x["terminou"]
		if x["terminou"]:
			return x["tempo_total"] < y["tempo_total"]
		return x["s"] > y["s"])
	return ordem.map(func(c): return c["id"])


static func _resumo(carros: Array) -> Dictionary:
	var r := {}
	for c in carros:
		r[c["id"]] = {
			"terminou": c["terminou"],
			"tempo_total": c["tempo_total"],
			"voltas": c["voltas"],
		}
	return r
