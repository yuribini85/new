class_name Simulacao
extends RefCounted
## Resolve uma corrida sem renderizar nada (docs/plano_mvp.md, seção 3).
##
## Modelo quase estático: para cada carro e cada volta existe um envelope de
## velocidade — limite de curva sqrt(aderência·g·raio), velocidade máxima e
## frenagem antecipada — e o carro acelera até ele limitado pela força na roda (torque na melhor marcha) e
## tração. Ultrapassagem só em trechos marcados; fora deles o carro de trás
## respeita a distância mínima (cortesia). A visualização só lê `amostras`.

const G := 9.81
const CV_PARA_W := 735.5
const KMH_PARA_MS := 1.0 / 3.6

## Chaves obrigatórias em data/simulacao.json. Opcionais: "cda_m2" e
## "densidade_ar_kg_m3" ligam o arrasto aerodinâmico (velocidade máxima passa a
## surgir da potência); sem elas, só o teto `velocidade_max` do carro limita.
const PARAMS := [
	"passo_m", "dt_s", "amostra_dt_s", "tempo_max_s",
	"distancia_minima_m", "sigma_ruido", "fator_tracao",
]


## participantes: em ordem de grid, cada um
##   {"id": String, "atributos": Carro.atributos_efetivos(), "piloto": {ritmo, consistencia, agressividade}}
## Retorna {"classificacao", "carros", "amostras", "comprimento", "duracao"}.
## com_amostras = false (offline) guarda só a amostra final; o resultado é o mesmo.
## v_inicial_ms > 0: largada lançada (o grid já parte nessa velocidade).
## Tudo de uma vez: testes, ferramentas e o offline. Na tela, `iniciar`.
static func correr(pista: Pista, participantes: Array, voltas: int, params: Dictionary, semente: int,
		com_amostras: bool = true, v_inicial_ms: float = 0.0) -> Dictionary:
	var a := iniciar(pista, participantes, voltas, params, semente, com_amostras, v_inicial_ms)
	a.avancar(INF)
	return a.resultado()


## A mesma corrida resolvida aos poucos (decisão 90: uma prova de resistência
## leva segundos e travava a tela). `avancar(orcamento_ms)` roda até gastar o
## orçamento e diz se terminou; `resultado()` é igual, bit a bit, ao de
## `correr` com os mesmos argumentos (o fatiamento não muda a conta).
static func iniciar(pista: Pista, participantes: Array, voltas: int, params: Dictionary, semente: int,
		com_amostras: bool = true, v_inicial_ms: float = 0.0) -> Andamento:
	return Andamento.new(pista, participantes, voltas, params, semente, com_amostras, v_inicial_ms)


## Estado de uma corrida em resolução. Primeiro os envelopes (um por carro e
## volta), depois os passos de tempo; o orçamento é conferido entre eles.
class Andamento:
	extends RefCounted

	## Passos de tempo entre leituras do relógio (ler a cada passo custa).
	const PASSOS_POR_CONFERENCIA := 16

	var _rng := RandomNumberGenerator.new()
	var _comprimento: float
	var _n: int
	var _passo: float
	var _dt: float
	var _k_arrasto: float
	var _dmin: float
	var _voltas: int
	var _com_amostras: bool
	var _raios := PackedFloat64Array()
	var _zonas := PackedInt32Array()
	var _carros := []
	## Envelopes ainda por calcular, um por carro e volta, na ordem dos carros:
	## [carro, aderência, freio, teto, fator].
	var _por_calcular := []
	var _calculados := 0
	var _s_arr := PackedFloat64Array()
	var _v_arr := PackedFloat64Array()
	var _acel_arr := PackedFloat64Array()
	var _pot_arr := PackedFloat64Array()
	var _massa_arr := PackedFloat64Array()
	var _forcas := []  # força motriz por faixa de velocidade (vazio: potência/v)
	var _lim_arr := PackedFloat64Array()  # limite de velocidade de cada carro neste passo
	var _envs := []
	var _ativos: Array[int] = []
	var _amostras := []
	var _proxima_amostra := 0.0
	var _t := 0.0
	var _tempo_max: float
	var _amostra_dt: float
	var _pronto := false
	var _resultado: Dictionary = {}

	func _init(pista: Pista, participantes: Array, voltas: int, params: Dictionary, semente: int,
			com_amostras: bool, v_inicial_ms: float) -> void:
		_rng.seed = semente
		_voltas = voltas
		_com_amostras = com_amostras
		_comprimento = pista.comprimento
		_n = maxi(int(ceil(_comprimento / float(params["passo_m"]))), 1)
		_passo = _comprimento / _n
		_dt = float(params["dt_s"])
		_k_arrasto = 0.5 * float(params.get("densidade_ar_kg_m3", 0.0)) * float(params.get("cda_m2", 0.0))
		_dmin = float(params["distancia_minima_m"])
		_tempo_max = float(params["tempo_max_s"])
		_amostra_dt = float(params["amostra_dt_s"])

		# Geometria discretizada: raio (0 = sem limite de curva) e zona de ultrapassagem.
		_raios.resize(_n)
		_zonas.resize(_n)
		for i in _n:
			var idx := pista.indice_em((i + 0.5) * _passo)
			var t: Dictionary = pista.trechos[idx]
			_raios[i] = float(t.get("raio_m", 0.0))
			_zonas[i] = idx if t.get("ultrapassagem", false) else -1

		for g in participantes.size():
			var p: Dictionary = participantes[g]
			var a: Dictionary = p["atributos"]
			var piloto: Dictionary = p["piloto"]
			var mu := float(a["aderencia"])
			var c := {
				"id": p["id"],
				"agressividade": float(piloto["agressividade"]),
				"potencia_w": float(a["potencia"]) * Simulacao.CV_PARA_W,
				"forca": Simulacao.forca_por_velocidade(a),
				"massa": float(a["peso"]),
				"acel_tracao": mu * Simulacao.G * Simulacao.fator_tracao(a, params),
				"s": -g * _dmin,
				"v": v_inicial_ms,
				"envelopes": [],
				"voltas": [],
				"ultima_passagem": 0.0,
				"terminou": false,
				"tempo_total": 0.0,
				"rolagens": {},
			}
			# O ruído de cada volta sai do gerador agora, na ordem de sempre; o
			# envelope (sem sorteio) fica para avancar(), que pode ser fatiado.
			var teto := INF if a.get("velocidade_max") == null else float(a["velocidade_max"]) * Simulacao.KMH_PARA_MS
			for volta in voltas:
				var ruido := absf(_rng.randfn(0.0, float(params["sigma_ruido"])))
				var fator := maxf(float(piloto["ritmo"]) * (1.0 - ruido * (1.0 - float(piloto["consistencia"]))), 0.01)
				_por_calcular.append([c, mu, float(a["freio"]), teto, fator])
			_carros.append(c)

		# Estado quente em arrays: o laço roda dezenas de milhares de vezes por
		# corrida e o offline resolve muitas corridas de uma vez.
		for c in _carros:
			_s_arr.append(c["s"])
			_v_arr.append(float(c["v"]))
			_acel_arr.append(c["acel_tracao"])
			_pot_arr.append(c["potencia_w"])
			_massa_arr.append(c["massa"])
			_forcas.append(c["forca"])
			_lim_arr.append(0.0)
			_envs.append(c["envelopes"])
		# Índices dos carros ainda correndo, mantidos em ordem de corrida.
		for k in _carros.size():
			_ativos.append(k)

	## Avança até gastar `orcamento_ms` (INF: até o fim). true = terminou.
	## Um envelope ou PASSOS_POR_CONFERENCIA passos podem passar um pouco do
	## orçamento; 0 dá a menor fatia possível.
	func avancar(orcamento_ms: float) -> bool:
		if _pronto:
			return true
		var sem_limite := is_inf(orcamento_ms)
		var prazo := 0 if sem_limite else Time.get_ticks_usec() + int(orcamento_ms * 1000.0)

		while _calculados < _por_calcular.size():
			var e: Array = _por_calcular[_calculados]
			e[0]["envelopes"].append(Simulacao._envelope(_raios, _passo, e[1], e[2], e[3], e[4]))
			_por_calcular[_calculados] = null
			_calculados += 1
			if not sem_limite and Time.get_ticks_usec() >= prazo:
				return false
		_por_calcular = []

		# Locais no laço quente (mais rápidos que membros). Os Packed* são
		# copiados na escrita: voltam para os membros ao sair.
		var comprimento := _comprimento
		var n := _n
		var passo := _passo
		var dt := _dt
		var k_arrasto := _k_arrasto
		var dmin := _dmin
		var voltas := _voltas
		var tempo_max := _tempo_max
		var carros := _carros
		var zonas := _zonas
		var s_arr := _s_arr
		var v_arr := _v_arr
		var acel_arr := _acel_arr
		var pot_arr := _pot_arr
		var massa_arr := _massa_arr
		var forcas := _forcas
		var lim_arr := _lim_arr
		var envs := _envs
		var ativos := _ativos
		var rng := _rng
		var t := _t
		var contagem := 0
		var esgotou := false

		while t < tempo_max and not ativos.is_empty():
			if not sem_limite:
				contagem += 1
				if contagem > PASSOS_POR_CONFERENCIA:
					contagem = 0
					if Time.get_ticks_usec() >= prazo:
						esgotou = true
						break
			if t >= _proxima_amostra:
				if _com_amostras:
					_amostras.append(Simulacao._amostra(t, carros, s_arr))
				_proxima_amostra += _amostra_dt

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
					acel = Simulacao._acel_livre(acel, pot_arr[idx], massa_arr[idx], v, k_arrasto, forcas[idx])
				var v_novo := clampf(v + acel * dt, 0.0, limite)
				var s_novo := s_antes + (v + v_novo) * 0.5 * dt
				lim_arr[idx] = limite

				if frente >= 0 and s_novo > s_arr[frente] - dmin:
					# Preso atrás, o carro anda na velocidade do da frente; "mais
					# rápido" é ter mais potencial ali: limite maior (curva) ou mais
					# aceleração na mesma velocidade (reta). Melhorar o carro nunca
					# tira a chance de passar.
					var vf := v_arr[frente]
					var mais_rapido := limite > lim_arr[frente] + 0.05 \
							or Simulacao._acel_livre(acel_arr[idx], pot_arr[idx], massa_arr[idx], vf, k_arrasto, forcas[idx]) \
							> Simulacao._acel_livre(acel_arr[frente], pot_arr[frente], massa_arr[frente], vf, k_arrasto,
									forcas[frente]) + 0.01
					if not Simulacao._pode_passar(carros[idx], zonas[i], volta, mais_rapido, rng):
						s_novo = maxf(s_antes, s_arr[frente] - dmin)
						v_novo = minf(v_novo, v_arr[frente])

				s_arr[idx] = s_novo
				v_arr[idx] = v_novo
				if floori(s_novo / comprimento) > volta_atual:
					Simulacao._registrar_passagem(carros[idx], s_antes, s_novo, t, dt, comprimento, voltas)
					terminaram = terminaram or carros[idx]["terminou"]
				frente = idx
			if terminaram:
				ativos = ativos.filter(func(k): return not carros[k]["terminou"])
			t += dt

		_s_arr = s_arr
		_v_arr = v_arr
		_lim_arr = lim_arr
		_ativos = ativos
		_t = t
		if esgotou:
			return false
		_concluir()
		return true

	func _concluir() -> void:
		for k in _carros.size():
			_carros[k]["s"] = _s_arr[k]
			_carros[k]["v"] = _v_arr[k]
		_amostras.append(Simulacao._amostra(_t, _carros, _s_arr))
		_resultado = {
			"classificacao": Simulacao._classificar(_carros),
			"carros": Simulacao._resumo(_carros),
			"amostras": _amostras,
			"comprimento": _comprimento,
			"voltas": _voltas,
			"duracao": _t,
		}
		_pronto = true
		# Os envelopes são o maior pedaço de memória; o resultado não usa.
		_envs = []
		for c in _carros:
			c.erase("envelopes")

	func pronto() -> bool:
		return _pronto

	## O resultado de `correr`; {} enquanto não terminou.
	func resultado() -> Dictionary:
		return _resultado


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
static func _pode_passar(c: Dictionary, zona: int, volta: int, mais_rapido: bool,
		rng: RandomNumberGenerator) -> bool:
	if zona < 0:
		return false
	var chave := "%d:%d" % [volta, zona]
	if not c["rolagens"].has(chave):
		c["rolagens"][chave] = rng.randf() < c["agressividade"]
	return c["rolagens"][chave] and mais_rapido


## Aceleração que o carro teria na velocidade v, sem ninguém na frente.
static func _acel_livre(acel_tracao: float, potencia_w: float, massa: float, v: float, k_arrasto: float,
		forca: PackedFloat64Array = PackedFloat64Array()) -> float:
	if v <= 0.0:
		return acel_tracao
	var motriz := potencia_w / v
	if not forca.is_empty():
		var x := v / PASSO_FORCA
		var i := mini(int(x), forca.size() - 2)
		motriz = lerpf(forca[i], forca[i + 1], clampf(x - i, 0.0, 1.0))
	return minf(acel_tracao, motriz / massa) - k_arrasto * v * v / massa


## Velocidade máxima (km/h) do modelo da corrida: onde a força na roda (ou P/v
## sem câmbio) iguala o arrasto, limitada pelo teto `velocidade_max` do carro.
## INF quando nada limita (sem arrasto nem teto). Para a ficha da garagem.
static func velocidade_maxima_kmh(a: Dictionary, params: Dictionary) -> float:
	var teto := INF if a.get("velocidade_max") == null else float(a["velocidade_max"])
	var k_arrasto := 0.5 * float(params.get("densidade_ar_kg_m3", 0.0)) * float(params.get("cda_m2", 0.0))
	var forca := forca_por_velocidade(a)
	if k_arrasto <= 0.0 and forca.is_empty():
		return teto
	var potencia_w := float(a["potencia"]) * CV_PARA_W
	var sobra := func(v: float) -> float:
		var motriz := potencia_w / v
		if not forca.is_empty():
			var x := v / PASSO_FORCA
			var i := mini(int(x), forca.size() - 2)
			motriz = lerpf(forca[i], forca[i + 1], clampf(x - i, 0.0, 1.0))
		return motriz - k_arrasto * v * v
	var anterior := PASSO_FORCA
	var s_ant: float = sobra.call(anterior)
	var v := anterior + PASSO_FORCA
	while v <= V_MAX_FORCA:
		var s: float = sobra.call(v)
		if s <= 0.0:
			var cruza := anterior + (v - anterior) * s_ant / maxf(s_ant - s, 1e-9)
			return minf(cruza / KMH_PARA_MS, teto)
		anterior = v
		s_ant = s
		v += PASSO_FORCA
	return minf(V_MAX_FORCA / KMH_PARA_MS, teto)


## Fração do peso sobre o eixo motriz: com "peso_dianteiro" do carro,
## dianteira para FF, traseira para FR/MR/RR e tudo no 4WD; sem ele, o fator
## fixo por tração de data/simulacao.json.
static func fator_tracao(a: Dictionary, params: Dictionary) -> float:
	if a.get("peso_dianteiro") == null:
		return float(params["fator_tracao"][a["tracao"]])
	var pd := float(a["peso_dianteiro"])
	match String(a["tracao"]):
		"FF":
			return pd
		"4WD":
			return 1.0
	return 1.0 - pd


## Faixas da tabela de força (m/s) e velocidade máxima coberta (~430 km/h).
const PASSO_FORCA := 0.5
const V_MAX_FORCA := 120.0


## Força na roda (N) em cada velocidade, na melhor marcha: torque × relação ×
## diferencial ÷ raio, só nas marchas em que o giro fica abaixo do corte. Abaixo
## do primeiro ponto da curva vale o torque dele (embreagem patinando na
## largada). Sem marcha válida, zero: o carro chegou ao corte na última.
## Carro sem curva (fixtures, dados antigos): vazio, e a simulação usa P/v,
## que equivale a um câmbio ideal.
static func forca_por_velocidade(a: Dictionary) -> PackedFloat64Array:
	var tabela := PackedFloat64Array()
	if not a.has("curva_rpm"):
		return tabela
	var rpm: PackedFloat64Array = a["curva_rpm"]
	var nm: PackedFloat64Array = a["curva_nm"]
	var corte := float(a["corte"])
	var final := float(a["final"])
	var raio := float(a["raio_roda"])
	var relacoes: PackedFloat64Array = a["relacoes"]
	var n := int(V_MAX_FORCA / PASSO_FORCA) + 1
	tabela.resize(n)
	for k in n:
		var v := k * PASSO_FORCA
		var melhor := 0.0
		for rel in relacoes:
			var giro := v / raio * rel * final * 60.0 / TAU
			if giro > corte:
				continue
			melhor = maxf(melhor, _torque(rpm, nm, giro) * rel * final / raio)
		tabela[k] = melhor
	return tabela


## Marcha (1 = primeira) e giro do motor na velocidade v (m/s): a marcha de
## maior força que não passa do corte, a mesma regra da tabela de força.
## [0, 0.0] sem motor e câmbio nos atributos. Para o HUD da corrida.
static func marcha_e_giro(a: Dictionary, v: float) -> Array:
	if not a.has("curva_rpm"):
		return [0, 0.0]
	var rpm: PackedFloat64Array = a["curva_rpm"]
	var nm: PackedFloat64Array = a["curva_nm"]
	var corte := float(a["corte"])
	var final := float(a["final"])
	var raio := float(a["raio_roda"])
	var relacoes: PackedFloat64Array = a["relacoes"]
	var melhor := -1.0
	var r := [1, rpm[0]]
	for i in relacoes.size():
		var giro := v / raio * relacoes[i] * final * 60.0 / TAU
		if giro > corte:
			continue
		var f := _torque(rpm, nm, maxf(giro, rpm[0])) * relacoes[i]
		if f > melhor:
			melhor = f
			r = [i + 1, maxf(giro, rpm[0])]
	if melhor < 0.0:
		r = [relacoes.size(), corte]
	return r


static func _torque(rpm: PackedFloat64Array, nm: PackedFloat64Array, giro: float) -> float:
	if giro <= rpm[0]:
		return nm[0]
	for i in range(1, rpm.size()):
		if giro <= rpm[i]:
			return lerpf(nm[i - 1], nm[i], (giro - rpm[i - 1]) / maxf(rpm[i] - rpm[i - 1], 1.0))
	return nm[nm.size() - 1]


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
