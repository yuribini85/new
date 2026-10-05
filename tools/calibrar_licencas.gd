extends SceneTree
## Preenche os tempos de data/licencas.json com a própria simulação.
## Para cada teste: cada carro de data/carros.json que cabe na restrição, de
## fábrica (pneu de fábrica, piloto do jogador), em SEMENTES corridas. Ouro =
## melhor média; bronze = pior tempo de qualquer carro em qualquer semente (com
## a variação ligada, todo carro elegível passa no bronze); prata = a média.
## Uso: godot --headless --script res://tools/calibrar_licencas.gd

const CAMINHO := "res://data/licencas.json"
const SEMENTES := 5


var _feito := false


## Roda no primeiro quadro: em _initialize os autoloads ainda não carregaram
## os dados, e um erro ali deixa o Godot aberto.
func _process(_delta: float) -> bool:
	if not _feito:
		_feito = true
		_calibrar()
		quit()
	return false


func _calibrar() -> void:
	var dados: Node = root.get_node("Dados")
	var licencas: Array = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
	var piloto: Dictionary = dados.piloto(dados.carreira()["piloto_jogador"])
	for lic in licencas:
		for t in lic["testes"]:
			var medias := []
			var piores := []
			for c in dados.lista("carros"):
				var carro := Carro.new(c)
				carro.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
				if not Elegibilidade.motivos(carro, t.get("restricoes", {}), [lic["id"], lic.get("requisito")]).is_empty():
					continue
				var tempos := []
				for semente in range(1, SEMENTES + 1):
					var r := Simulacao.correr(dados.pista(t["pista"]), [{"id": "x", "atributos": carro.atributos_efetivos(t["condicao"]), "piloto": piloto}],
							int(t["voltas"]), dados.simulacao(), semente, false)
					tempos.append(r["carros"]["x"]["tempo_total"])
				medias.append(tempos.reduce(func(a, b): return a + b) / tempos.size())
				piores.append(tempos.max())
			if medias.is_empty():
				push_error("teste %s: nenhum carro cabe na restrição" % t["id"])
				continue
			var ouro: float = snappedf(medias.min(), 0.01)
			var bronze: float = snappedf(piores.max() + 0.01, 0.01)
			t["tempos"] = {"ouro": ouro, "prata": snappedf((ouro + bronze) / 2.0, 0.01), "bronze": bronze}
			print("%s: ouro %.2f · prata %.2f · bronze %.2f (%d carros)" % [t["id"], ouro, t["tempos"]["prata"], bronze, medias.size()])
	var f := FileAccess.open(CAMINHO, FileAccess.WRITE)
	f.store_string(JSON.stringify(licencas, "\t") + "\n")
	f.close()
