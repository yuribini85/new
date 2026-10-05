extends SceneTree
## Verifica, com os dados atuais, as três provas de que a simulação tem
## profundidade (docs/plano_mvp.md):
##   1. um carro menos potente vence outro por ser adequado à pista;
##   2. duas preparações do mesmo carro são melhores em pistas diferentes;
##   3. um usado barato preparado alcança um carro mais caro de fábrica.
## Mede tempo de 2 voltas sozinho na pista, piloto do jogador, pneu de fábrica,
## média de SEMENTES corridas. Só relata; não muda dados.
## Uso: godot --headless --path . --script res://tools/provas_profundidade.gd

const SEMENTES := 5
const VOLTAS := 2

var _feito := false
var _dados: Node
var _piloto: Dictionary
var _cache := {}


func _process(_delta: float) -> bool:
	if not _feito:
		_feito = true
		_verificar()
		quit()
	return false


func _verificar() -> void:
	_dados = root.get_node("Dados")
	_piloto = _dados.piloto(_dados.carreira()["piloto_jogador"])
	var pistas: Array = _dados.lista("pistas").map(func(p): return p["id"])
	var ok := [_prova_1(pistas), _prova_2(pistas), _prova_3(pistas)]
	print("resultado: %d de 3 provas atendidas" % ok.count(true))


func _prova_1(pistas: Array) -> bool:
	var carros: Array = _dados.lista("carros")
	var casos := []
	for a in carros:
		for b in carros:
			var ca := _fabrica(a)
			var cb := _fabrica(b)
			var pa: float = ca.atributos_efetivos("seco")["potencia"]
			var pb: float = cb.atributos_efetivos("seco")["potencia"]
			if pa >= pb:
				continue
			# O menos potente (a) é mais rápido em alguma pista e mais lento em outra.
			var vence := pistas.filter(func(p): return _tempo(ca, p) < _tempo(cb, p))
			var perde := pistas.filter(func(p): return _tempo(ca, p) > _tempo(cb, p))
			if not vence.is_empty() and not perde.is_empty():
				casos.append("%s (%d cv) vence %s (%d cv) em %s, perde em %s" % [
						a["id"], pa, b["id"], pb, ", ".join(vence), ", ".join(perde)])
	print("1. menos potente vence onde é adequado: %d pares" % casos.size())
	for c in casos.slice(0, 5):
		print("   " + c)
	return not casos.is_empty()


func _prova_2(pistas: Array) -> bool:
	var casos := []
	for b in _dados.lista("carros"):
		var cambio: Array = _dados.lista("pecas").filter(func(p): return p["categoria"] == "cambio" and b["id"] in p.get("carros_permitidos", []))
		if cambio.is_empty():
			continue
		var melhor_por_pista := {}
		for aj in ["curto", "", "longo"]:
			var c := _fabrica(b)
			c.instalar(cambio[0])
			c.ajuste_cambio = aj
			for p in pistas:
				var t := _tempo(c, p)
				if not melhor_por_pista.has(p) or t < melhor_por_pista[p][1]:
					melhor_por_pista[p] = [aj if aj != "" else "equilibrado", t]
		var ajustes := {}
		for p in melhor_por_pista:
			ajustes[melhor_por_pista[p][0]] = true
		if ajustes.size() > 1:
			casos.append("%s: %s" % [b["id"], ", ".join(pistas.map(func(p): return "%s→%s" % [p, melhor_por_pista[p][0]]))])
	print("2. ajuste de câmbio melhor muda com a pista: %d carros" % casos.size())
	for c in casos.slice(0, 5):
		print("   " + c)
	return not casos.is_empty()


func _prova_3(pistas: Array) -> bool:
	var casos := []
	for o in Usados.estoque(_dados.lista("carros"), 0, {}):
		var usado := _fabrica(_dados.carro(o["carro_id"]))
		for novo in _dados.lista("carros"):
			if not novo.get("novo", true) or int(novo["preco"]) <= int(o["preco"]):
				continue
			var orcamento := int(novo["preco"]) - int(o["preco"])
			var cn := _fabrica(novo)
			for p in pistas:
				var melhor := _melhor_com_pecas(usado, orcamento, p)
				if melhor[0] < _tempo(cn, p):
					casos.append("usado %s (%d Cr) + %s bate %s novo (%d Cr) em %s" % [
							o["carro_id"], o["preco"], melhor[1], novo["id"], novo["preco"], p])
	print("3. usado barato preparado alcança carro mais caro: %d casos" % casos.size())
	for c in casos.slice(0, 5):
		print("   " + c)
	return not casos.is_empty()


## Melhor tempo com até uma peça por categoria, escolhida gulosamente dentro
## do orçamento (aproximação: basta mostrar que existe uma preparação).
func _melhor_com_pecas(carro: Carro, orcamento: int, pista: String) -> Array:
	var c := carro.copiar()
	var nomes := []
	var resta := orcamento
	while true:
		var escolha := {}
		var t_atual := _tempo(c, pista)
		var t_melhor := t_atual
		for p in _dados.lista("pecas"):
			if int(p["preco"]) > resta or c.motivo_recusa(p) != "" or c.pecas.has(p["categoria"]):
				continue
			var teste := c.copiar()
			teste.instalar(p)
			var t := _tempo(teste, pista)
			if t < t_melhor - 0.01:
				t_melhor = t
				escolha = p
		if escolha.is_empty():
			break
		c.instalar(escolha)
		resta -= int(escolha["preco"])
		nomes.append(escolha["nome"])
	return [_tempo(c, pista), " + ".join(nomes) if not nomes.is_empty() else "nada"]


func _fabrica(c: Dictionary) -> Carro:
	var carro := Carro.new(c)
	carro.adicionar_pneu(_dados.pneu(_dados.economia()["pneu_de_fabrica"]))
	return carro


func _tempo(carro: Carro, pista: String) -> float:
	var a := carro.atributos_efetivos("seco")
	var chave := str(a) + pista
	if _cache.has(chave):
		return _cache[chave]
	var soma := 0.0
	for s in range(1, SEMENTES + 1):
		var res := Simulacao.correr(_dados.pista(pista), [{"id": "x", "atributos": a, "piloto": _piloto}],
				VOLTAS, _dados.simulacao(), s, false)
		soma += float(res["carros"]["x"]["tempo_total"])
	_cache[chave] = soma / SEMENTES
	return _cache[chave]
