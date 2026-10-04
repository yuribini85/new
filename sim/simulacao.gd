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
## Retorna {"classificacao", "carros", "amostras", "comprimento", "duracao"}.
## com_amostras = false (offline) guarda só a amostra final; o resultado é o mesmo.
static func correr(pista: Pista, participantes: Array, voltas: int, params: Dictionary, semente: int,
		com_amostras: bool = true) -> Dictionary:
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

	# Estado quente em arrays: o laço roda dezenas de milhares de vezes por
	# corrida e o offline resolve muitas corridas de uma vez.
	var total := carros.size()
	var s_arr := PackedFloat64Array()
	var v_arr := PackedFloat64Array()
	var acel_arr := PackedFloat64Array()
	var pot_arr := PackedFloat64Array()
	var massa_arr := PackedFloat64Array()
	for c in carros:
		s_arr.append(c["s"])
		v_arr.append(0.0)
		acel_arr.append(c["acel_tracao"])
		pot_arr.append(c["potencia_w"])
		massa_arr.append(c["massa"])
	var envs := []
	for c in carros:
		envs.append(c["envelopes"])
	# Índices dos carros ainda correndo, mantidos em ordem de corrida.
	var ativos: Array[int] = []
	for k in total:
		ativos.append(k)

	var amostras := []
	var proxima_amostra := 0.0
	var t := 0.0
	var tempo_max := float(params["tempo_max_s"])
	var amostra_dt := float(params["amostra_dt_s"])

	while t < tempo_max and not ativos.is_empty():
		if t >= proxima_amostra:
			if com_amostras:
				amostras.append(_amostra(t, carros, s_arr))
			proxima_amostra += amostra_dt

		# Ordem de corrida antes do passo: o da frente resolve primeiro. A
		# ordem muda pouco entre passos, então inserção é quase linear.
		for k in range(1, ativos.size()):
			var j := k
			while j > 0 and s_arr[ativos[j - 1]] < s_arr[ativos[j]]:
				var tmp := ativos[j - 1]
				ativos[j - 1] = ativos[j]
				ativos[j] = tmp
				j -= 1

		var frente := -1
		var terminaram := false
		for idx in ativos:
			var s_antes := s_arr[idx]
			var volta_atual := floori(s_antes / comprimento)
			var volta := clampi(volta_atual, 0, voltas - 1)
			var i := int(fposmod(s_antes, comprimento) / passo) % n
			var env: PackedFloat64Array = envs[idx][volta]
			var limite := minf(env[i], env[(i + 1) % n])
			var v := v_arr[idx]
			var acel := acel_arr[idx]
			if v > 0.0:
				acel = minf(acel, pot_arr[idx] / (massa_arr[idx] * v))
			var v_novo := minf(v + acel * dt, limite)
			var s_novo := s_antes + (v + v_novo) * 0.5 * dt

			if frente >= 0 and s_novo > s_arr[frente] - dmin:
				if not _pode_passar(carros[idx], zonas[i], volta, v_novo, v_arr[frente], rng):
					s_novo = maxf(s_antes, s_arr[frente] - dmin)
					v_novo = minf(v_novo, v_arr[frente])

			s_arr[idx] = s_novo
			v_arr[idx] = v_novo
			if floori(s_novo / comprimento) > volta_atual:
				_registrar_passagem(carros[idx], s_antes, s_novo, t, dt, comprimento, voltas)
				terminaram = terminaram or carros[idx]["terminou"]
			frente = idx
		if terminaram:
			ativos = ativos.filter(func(k): return not carros[k]["terminou"])
		t += dt

	for k in total:
		carros[k]["s"] = s_arr[k]
		carros[k]["v"] = v_arr[k]
	amostras.append(_amostra(t, carros, s_arr))
	return {
		"classificacao": _classificar(carros),
		"carros": _resumo(carros),
		"amostras": amostras,
		"comprimento": comprimento,
		"duracao": t,
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
	# O ponto de menor limite nunca é rebaixado pela frenagem; partindo dele,
	# uma única volta para trás basta.
	var inicio := 0
	for i in n:
		if env[i] < env[inicio]:
			inicio = i
	for k in range(n - 1, 0, -1):
		var i := (inicio + k) % n
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


static func _amostra(t: float, carros: Array, s_arr: PackedFloat64Array) -> Dictionary:
	var s := {}
	for k in carros.size():
		s[carros[k]["id"]] = s_arr[k]
	return {"t": t, "s": s}


## Quem terminou, por tempo; quem não terminou (tempo_max), pela distância.
static func _classificar(carros: Array) -> Array:
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
