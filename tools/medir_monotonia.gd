extends SceneTree
## Mede se melhorar o carro pode piorar o resultado: para cada carro, evento e
## peça/pneu do próprio carro, compara a posição (média de SEMENTES corridas)
## com e sem a melhoria. Variáveis de ambiente: SIGMA (sigma_ruido), CONS
## (consistência de todos os pilotos), SEMENTES. Não altera data/.
## Uso: SIGMA=0.02 CONS=0.7 SEMENTES=6 godot --headless --script res://tools/medir_monotonia.gd
var _f := false
func _process(_d: float) -> bool:
	if _f: return false
	_f = true
	var dados: Node = root.get_node("Dados")
	var jog: Node = root.get_node("Jogador")
	var total := 0
	var piores := 0
	var melhores := 0
	var exemplos := []
	var sigma := float(OS.get_environment("SIGMA") if OS.has_environment("SIGMA") else "0")
	var cons := float(OS.get_environment("CONS") if OS.has_environment("CONS") else "1")
	var sementes := int(OS.get_environment("SEMENTES") if OS.has_environment("SEMENTES") else "1")
	dados._objetos["simulacao"]["sigma_ruido"] = sigma
	for pid in dados._listas["pilotos_ia"]:
		dados._listas["pilotos_ia"][pid]["consistencia"] = cons
	var limiar := 0.5 if sementes > 1 else 0.0
	for base in dados.lista("carros"):
		var cid: String = base["id"]
		var extras: Array = dados.lista("pecas").filter(func(p): return cid in p.get("carros_permitidos", []))
		for pn in dados.lista("pneus"):
			if pn["preco"] > 0 and pn["aderencia"]["seco"] > 1.0: extras.append(pn)
		for ev in dados.lista("eventos"):
			var pos := {}
			for cfg in [null] + extras:
				jog.novo_jogo(dados.economia(), dados.pneu)
				jog.licencas = ["B", "A"]
				var c := Carro.new(base)
				c.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
				if cfg != null:
					if cfg.has("categoria"): c.instalar(cfg)
					else: c.adicionar_pneu(cfg)
				var uid: int = jog.garagem.adicionar(c)
				var soma := 0.0
				var erro := false
				for sem in range(1, sementes + 1):
					var r: Dictionary = Carreira.new(dados, jog).preparar(ev["id"], uid, sem, false)
					if r.has("erro"):
						erro = true
						break
					soma += r["resultado"]["classificacao"].find("jogador") + 1
				if erro:
					break
				var p: float = soma / sementes
				if cfg == null:
					pos["base"] = p
				else:
					total += 1
					if p > pos["base"] + limiar:
						piores += 1
						if exemplos.size() < 12: exemplos.append("%s + %s em %s: %.1f -> %.1f" % [cid, cfg["nome"], ev["nome"], pos["base"], p])
					elif p < pos["base"] - limiar:
						melhores += 1
	print("comparações: %d · pioraram: %d · melhoraram: %d" % [total, piores, melhores])
	for e in exemplos: print("  ", e)
	quit()
	return false
