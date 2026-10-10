class_name Diagnostico
extends RefCounted
## Diagnóstico de uma corrida, separando duas coisas:
##   potencial  o carro sozinho na pista (sem tráfego), com o mesmo piloto e a
##              mesma semente para os dois carros comparados: onde o tempo é
##              ganho ou perdido, em curvas e em retas. É o que a preparação muda.
##   tráfego    na corrida de verdade, quanto tempo o seu carro passou colado
##              atrás de outro, sem passar. Isso não é culpa da preparação.
## Só lê; não muda nada no jogo.

## Semente das voltas sozinho (a mesma da bancada dos contratos).
const SEMENTE := 1
## "Colado": a distância para o carro da frente até a cortesia mais esta folga (m).
const FOLGA_COLADO_M := 1.0


## Volta(s) sozinho: {tempo, curvas, retas} (s). Curva = trecho com raio.
static func sozinho(dados: Node, pista: Pista, attrs: Dictionary, voltas: int, piloto: Dictionary,
		semente := SEMENTE) -> Dictionary:
	var res := Simulacao.correr(pista, [{"id": "x", "atributos": attrs, "piloto": piloto}], voltas,
			dados.simulacao(), semente, true)
	var x: Dictionary = res["carros"]["x"]
	var r := {"tempo": x["tempo_total"] if x["terminou"] else INF, "curvas": 0.0, "retas": 0.0}
	var amostras: Array = res["amostras"]
	var fim := pista.comprimento * voltas
	for i in range(1, amostras.size()):
		var s0: float = amostras[i - 1]["s"]["x"]
		if s0 < 0.0 or s0 >= fim:
			continue
		var dt: float = amostras[i]["t"] - amostras[i - 1]["t"]
		if float(pista.trecho_em(fposmod(s0, pista.comprimento)).get("raio_m", 0.0)) > 0.0:
			r["curvas"] += dt
		else:
			r["retas"] += dt
	return r


## Potencial do seu carro contra o de um rival na pista da prova, os dois
## sozinhos com o piloto do jogador: {meu, rival, curvas, retas} (diferenças
## em s: positivo = você mais lento).
static func potencial(dados: Node, evento: Dictionary, meu: Dictionary, rival: Dictionary) -> Dictionary:
	var piloto: Dictionary = dados.piloto(dados.carreira()["piloto_jogador"])
	var pista: Pista = dados.pista(evento["pista"])
	var a := sozinho(dados, pista, meu, int(evento["voltas"]), piloto)
	var b := sozinho(dados, pista, rival, int(evento["voltas"]), piloto)
	return {"meu": a["tempo"], "rival": b["tempo"], "curvas": a["curvas"] - b["curvas"], "retas": a["retas"] - b["retas"]}


## Segundos em que `id` andou colado atrás de outro carro (gap até a cortesia
## + folga), pelas amostras da corrida; conta só enquanto os dois correm.
static func colado(resultado: Dictionary, id: String, dmin: float) -> float:
	var amostras: Array = resultado["amostras"]
	var final: float = float(resultado["comprimento"]) * int(resultado.get("voltas", 1 << 20))
	var total := 0.0
	for i in range(1, amostras.size()):
		var s: Dictionary = amostras[i - 1]["s"]
		if not s.has(id):
			continue
		var meu: float = s[id]
		if meu < 0.0 or meu >= final:
			continue  # ainda no grid, ou já terminou
		var gap := INF
		for outro in s:
			# Quem já terminou deixa de ser obstáculo.
			if outro != id and float(s[outro]) > meu and float(s[outro]) < final:
				gap = minf(gap, float(s[outro]) - meu)
		if gap <= dmin + FOLGA_COLADO_M:
			total += float(amostras[i]["t"]) - float(amostras[i - 1]["t"])
	return total


## Frase do gargalo pelo lado em que mais se perde tempo (curvas ou retas).
static func gargalo(curvas: float, retas: float) -> String:
	if curvas <= 0.05 and retas <= 0.05:
		return "Carro no mesmo ritmo: foi a corrida (largada, tráfego)."
	if curvas >= retas:
		return "Perde nas curvas: peso, freios e pneus ajudam."
	return "Perde nas retas: potência, câmbio e peso ajudam."
