extends SceneTree
## Preenche os tempos de data/licencas.json com a própria simulação.
## Para cada teste: tempo de cada carro de data/carros.json que cabe na
## restrição, de fábrica (pneu de fábrica, piloto do jogador). Ouro = o mais
## rápido, bronze = o mais lento, prata = a média dos dois.
## Uso: godot --headless --script res://tools/calibrar_licencas.gd

const CAMINHO := "res://data/licencas.json"


func _initialize() -> void:
	var dados: Node = root.get_node("Dados")
	var licencas: Array = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
	var piloto: Dictionary = dados.piloto(dados.carreira()["piloto_jogador"])
	for lic in licencas:
		for t in lic["testes"]:
			var tempos := []
			for c in dados.lista("carros"):
				var carro := Carro.new(c)
				carro.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
				if not Elegibilidade.motivos(carro, t.get("restricoes", {}), [lic["id"], lic.get("requisito")]).is_empty():
					continue
				var r := Simulacao.correr(dados.pista(t["pista"]), [{"id": "x", "atributos": carro.atributos_efetivos(t["condicao"]), "piloto": piloto}],
						int(t["voltas"]), dados.simulacao(), 1, false)
				tempos.append(snappedf(r["carros"]["x"]["tempo_total"], 0.01))
			if tempos.is_empty():
				push_error("teste %s: nenhum carro cabe na restrição" % t["id"])
				continue
			var ouro: float = tempos.min()
			var bronze: float = tempos.max()
			t["tempos"] = {"ouro": ouro, "prata": snappedf((ouro + bronze) / 2.0, 0.01), "bronze": bronze}
			print("%s: ouro %.2f · prata %.2f · bronze %.2f (%d carros)" % [t["id"], ouro, t["tempos"]["prata"], bronze, tempos.size()])
	var f := FileAccess.open(CAMINHO, FileAccess.WRITE)
	f.store_string(JSON.stringify(licencas, "\t") + "\n")
	f.close()
	quit()
