extends SceneTree
## Preenche os tempos de data/licencas.json com a própria simulação, em
## SEMENTES corridas por configuração (piloto do jogador, pneu de fábrica):
##   bronze  tolerante: pior tempo de qualquer carro elegível de fábrica, em
##           qualquer semente. Serve de desbloqueio inicial.
##   prata   percentil 75 do melhor carro inicial de fábrica (carro inicial =
##           usado do dia 0 que cabe no saldo inicial). Escolher bem o carro.
##   ouro    percentil 75 da melhor combinação carro inicial + uma melhoria
##           (peça ou pneu) que caiba no saldo inicial. Preparar para o teste:
##           pistas diferentes pedem peças diferentes.
## Licença A (exige a B): o mesmo critério, mas com o carro e o dinheiro que o
## jogador tem ao tirar a B (tools/percurso.gd, um percurso por carro inicial)
## no lugar dos carros iniciais de fábrica e do saldo inicial.
## Imprime também com que frequência o melhor carro de fábrica alcança o ouro.
## Uso: godot --headless --script res://tools/calibrar_licencas.gd

const CAMINHO := "res://data/licencas.json"
const Percurso := preload("res://tools/percurso.gd")
const SEMENTES := 20
const PERCENTIL := 0.75

var _feito := false
var _dados: Node
var _piloto: Dictionary


## Roda no primeiro quadro: em _initialize os autoloads ainda não carregaram
## os dados, e um erro ali deixa o Godot aberto.
func _process(_delta: float) -> bool:
	if not _feito:
		_feito = true
		_calibrar()
		quit()
	return false


func _calibrar() -> void:
	_dados = root.get_node("Dados")
	_piloto = _dados.piloto(_dados.carreira()["piloto_jogador"])
	var saldo := int(_dados.economia()["saldo_inicial"])
	var iniciais := []
	for o in Usados.estoque(_dados.lista("carros"), 0, {}):
		if o["preco"] <= saldo:
			iniciais.append(_dados.carro(o["carro_id"]))
	var licencas: Array = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
	var na_b := []
	for lic in licencas:
		if lic.get("requisito") != null and na_b.is_empty():
			# Ponto de partida da A: carro (com as peças) e saldo de cada
			# percurso que tirou a B, já com os tempos da B calibrados acima.
			for anterior in licencas:
				var carregada: Dictionary = _dados.item("licencas", anterior["id"])
				for k in anterior["testes"].size():
					carregada["testes"][k]["tempos"] = anterior["testes"][k]["tempos"]
			for o in Usados.estoque(_dados.lista("carros"), 0, {}):
				if o["preco"] <= saldo:
					var r: Dictionary = Percurso.jogar(_dados, o, 30.0 * 60.0)
					if r["licenca_b"]:
						na_b.append({"carro": r["carro"], "saldo": r["saldo"]})
						print("percurso com %s: licença B com %d cv e %d Cr" % [o["carro_id"],
								r["carro"].atributos_efetivos("seco")["potencia"], r["saldo"]])
		var possui := [lic["id"], lic.get("requisito")]
		for t in lic["testes"]:
			# Bronze: todos os carros elegíveis de fábrica.
			var pior := 0.0
			var elegiveis := 0
			for c in _dados.lista("carros"):
				var tempos := _tempos(_fabrica(c), t, possui)
				if tempos.is_empty():
					continue
				elegiveis += 1
				pior = maxf(pior, tempos.back())
			# Prata e ouro: carros iniciais, de fábrica e com uma melhoria.
			var prata := INF
			var ouro := INF
			var melhor_fabrica := []
			var receita := ""
			var pontos_de_partida := []
			if lic["id"] == "A" and not na_b.is_empty():
				pontos_de_partida = na_b
			else:
				for c in iniciais:
					pontos_de_partida.append({"carro": _fabrica(c), "saldo": saldo})
			for pp in pontos_de_partida:
				var base: Carro = pp["carro"]
				var tempos := _tempos(base, t, possui)
				if tempos.is_empty():
					continue
				if _percentil(tempos) < prata:
					prata = _percentil(tempos)
					melhor_fabrica = tempos
				for m in _melhorias(base, int(pp["saldo"])):
					var tm := _tempos(m["carro"], t, possui)
					if not tm.is_empty() and _percentil(tm) < ouro:
						ouro = _percentil(tm)
						receita = "%s + %s" % [base.base["nome"], m["nome"]]
			if elegiveis == 0 or prata == INF:
				push_error("teste %s: nenhum carro (inicial) cabe na restrição" % t["id"])
				continue
			ouro = minf(ouro, prata)
			var bronze := snappedf(pior + 0.01, 0.01)
			t["tempos"] = {"ouro": snappedf(ouro, 0.01), "prata": snappedf(prata, 0.01), "bronze": bronze}
			var chance_ouro_fabrica := melhor_fabrica.filter(func(x): return x <= ouro).size() * 100.0 / melhor_fabrica.size()
			print("%s: ouro %.2f (%s) · prata %.2f · bronze %.2f · melhor inicial de fábrica faz ouro em %.0f%% · %d elegíveis" % [
				t["id"], ouro, receita, prata, bronze, chance_ouro_fabrica, elegiveis])
	var f := FileAccess.open(CAMINHO, FileAccess.WRITE)
	f.store_string(JSON.stringify(licencas, "\t") + "\n")
	f.close()


func _fabrica(c: Dictionary) -> Carro:
	var carro := Carro.new(c)
	carro.adicionar_pneu(_dados.pneu(_dados.economia()["pneu_de_fabrica"]))
	return carro


## Peças e pneus do carro até o orçamento, cada um numa cópia.
func _melhorias(carro: Carro, orcamento: int) -> Array:
	var r := []
	for p in _dados.lista("pecas"):
		if carro.motivo_recusa(p) == "" and int(p["preco"]) <= orcamento:
			var c := carro.copiar()
			c.instalar(p)
			r.append({"nome": p["nome"], "carro": c})
	for pn in _dados.lista("pneus"):
		if int(pn["preco"]) > 0 and int(pn["preco"]) <= orcamento:
			var c := carro.copiar()
			c.adicionar_pneu(pn)
			r.append({"nome": pn["nome"], "carro": c})
	return r


## Tempos ordenados em SEMENTES corridas; [] se o carro não cabe no teste.
func _tempos(carro: Carro, t: Dictionary, licencas: Array) -> Array:
	if not Elegibilidade.motivos(carro, t.get("restricoes", {}), licencas).is_empty():
		return []
	var r := []
	for s in range(1, SEMENTES + 1):
		var res := Simulacao.correr(_dados.pista(t["pista"]),
				[{"id": "x", "atributos": carro.atributos_efetivos(t["condicao"]), "piloto": _piloto}],
				int(t["voltas"]), _dados.simulacao(), s, false)
		r.append(res["carros"]["x"]["tempo_total"])
	r.sort()
	return r


func _percentil(tempos: Array) -> float:
	return tempos[int(ceil(PERCENTIL * tempos.size())) - 1]
