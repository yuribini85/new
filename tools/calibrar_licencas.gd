extends SceneTree
## Preenche os tempos dos testes de data/licencas.json com a própria simulação,
## em SEMENTES corridas (piloto do jogador, pneu de fábrica). Regra simples:
##   bronze  pior tempo de qualquer carro elegível de fábrica (desbloqueio).
##   prata   percentil 75 do melhor carro inicial de fábrica (usado do dia 0
##           que cabe no saldo inicial).
##   ouro    percentil 25 do mesmo carro.
## Licenças concedidas por contratos (data/contratos.json) ficam de fora: o
## jogo ignora os testes delas.
## Uso: godot --headless --script res://tools/calibrar_licencas.gd

const CAMINHO := "res://data/licencas.json"
const SEMENTES := 20

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
	for lic in licencas:
		var possui := [lic["id"], lic.get("requisito")]
		for t in lic["testes"]:
			var pior := 0.0
			for c in _dados.lista("carros"):
				var tempos := _tempos(c, t, possui)
				if not tempos.is_empty():
					pior = maxf(pior, tempos.back())
			var melhor := []
			var nome := ""
			for c in iniciais:
				var tempos := _tempos(c, t, possui)
				if not tempos.is_empty() and (melhor.is_empty() or _percentil(tempos, 0.75) < _percentil(melhor, 0.75)):
					melhor = tempos
					nome = c["nome"]
			if pior == 0.0 or melhor.is_empty():
				push_error("teste %s: nenhum carro (inicial) cabe na restrição" % t["id"])
				continue
			t["tempos"] = {"ouro": snappedf(_percentil(melhor, 0.25), 0.01),
					"prata": snappedf(_percentil(melhor, 0.75), 0.01),
					"bronze": snappedf(pior + 0.01, 0.01)}
			print("%s: %s (%s)" % [t["id"], t["tempos"], nome])
	var f := FileAccess.open(CAMINHO, FileAccess.WRITE)
	f.store_string(JSON.stringify(licencas, "\t") + "\n")
	f.close()


## Tempos ordenados em SEMENTES corridas, de fábrica; [] se o carro não cabe.
func _tempos(c: Dictionary, t: Dictionary, licencas: Array) -> Array:
	var carro := Carro.new(c)
	carro.adicionar_pneu(_dados.pneu(_dados.economia()["pneu_de_fabrica"]))
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


func _percentil(tempos: Array, p: float) -> float:
	return tempos[maxi(int(ceil(p * tempos.size())) - 1, 0)]
