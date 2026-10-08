class_name Tatica
extends RefCounted
## Leitura tática da pista para a vista DADOS da corrida, sem renderizar nada:
## as curvas (trechos com raio seguidos, do mesmo sentido), onde o carro começa
## a frear para cada uma e a velocidade com que a contorna. Usa o mesmo
## envelope de velocidade da Simulacao (limite de curva e frenagem), sem o
## ruído do piloto: é a referência do carro, não uma volta sorteada.


## [{nome, inicio, fim, frenagem, sentido, raio, v_kmh}] na ordem da volta;
## distâncias em m dentro da volta (frenagem pode ser de antes da linha de
## chegada: já vem normalizada para 0..comprimento). `nomes`: curvas.json.
static func curvas(pista: Pista, atributos: Dictionary, params: Dictionary, nomes: Array = []) -> Array:
	var lista := []
	var anterior_curva := false
	for i in pista.trechos.size():
		var t: Dictionary = pista.trechos[i]
		var raio := float(t.get("raio_m", 0.0))
		var ini := pista.inicios[i]
		var fim := ini + float(t["comprimento_m"])
		var sentido := String(t.get("sentido", "esquerda"))
		if raio > 0.0:
			if anterior_curva and lista[-1]["sentido"] == sentido:
				lista[-1]["fim"] = fim
				lista[-1]["raio"] = minf(lista[-1]["raio"], raio)
			else:
				lista.append({"inicio": ini, "fim": fim, "sentido": sentido, "raio": raio})
		anterior_curva = raio > 0.0
	for k in lista.size():
		lista[k]["nome"] = String(nomes[k]) if k < nomes.size() else "Curva %d" % (k + 1)
	if lista.is_empty():
		return lista
	# Envelope do carro, na mesma discretização da simulação.
	var comprimento := pista.comprimento
	var n := maxi(int(ceil(comprimento / float(params["passo_m"]))), 1)
	var passo := comprimento / n
	var raios := PackedFloat64Array()
	raios.resize(n)
	for i in n:
		raios[i] = float(pista.trechos[pista.indice_em((i + 0.5) * passo)].get("raio_m", 0.0))
	var teto := INF if atributos.get("velocidade_max") == null else float(atributos["velocidade_max"]) * Simulacao.KMH_PARA_MS
	var env := Simulacao._envelope(raios, passo, float(atributos["aderencia"]), float(atributos["freio"]), teto, 1.0)
	for c in lista:
		var i0 := int(floor(c["inicio"] / passo)) % n
		var i1 := int(floor(c["fim"] / passo)) % n
		var v := INF
		var i := i0
		while true:
			v = minf(v, env[i])
			if i == i1:
				break
			i = (i + 1) % n
		c["v_kmh"] = v / Simulacao.KMH_PARA_MS
		# Frenagem: voltando da entrada enquanto o envelope sobe (o carro já
		# estava freando para esta curva). No máximo uma volta.
		var j := i0
		for _k in n:
			var antes := (j - 1 + n) % n
			if env[antes] <= env[j] + 0.01:
				break
			j = antes
		c["frenagem"] = fposmod(j * passo, comprimento)
	return lista


## Próxima referência a partir de `s_volta` (m dentro da volta):
## {curva, estado ("frear", "freando", "na_curva"), distancia (m até frear)}.
static func proxima(lista: Array, s_volta: float, comprimento: float) -> Dictionary:
	if lista.is_empty():
		return {}
	var melhor := {}
	var menor := INF
	for c in lista:
		# Dentro da curva?
		if _entre(s_volta, c["inicio"], c["fim"], comprimento):
			return {"curva": c, "estado": "na_curva", "distancia": 0.0}
		if _entre(s_volta, c["frenagem"], c["inicio"], comprimento):
			return {"curva": c, "estado": "freando", "distancia": 0.0}
		var d := fposmod(c["frenagem"] - s_volta, comprimento)
		if d < menor:
			menor = d
			melhor = c
	return {"curva": melhor, "estado": "frear", "distancia": menor}


static func _entre(s: float, a: float, b: float, comprimento: float) -> bool:
	var largura := fposmod(b - a, comprimento)
	return largura > 0.0 and fposmod(s - a, comprimento) < largura
