extends SceneTree
## Quantos minutos de corrida cada carro custa. Ritmo de ganho: o melhor Cr por
## minuto (prêmio médio em AMOSTRAS corridas ÷ duração) que o carro de cada
## percurso consegue ao tirar a licença B, nas provas que ele pode correr com
## as licenças B e A. Serve para decidir preços e prêmios com números, sem
## mudar nada. Uso: godot --headless --script res://tools/custo_carros.gd

const Percurso := preload("res://tools/percurso.gd")
const AMOSTRAS := 6

var _feito := false


func _process(_delta: float) -> bool:
	if not _feito:
		_feito = true
		_rodar()
		quit()
	return false


func _rodar() -> void:
	var d: Node = root.get_node("Dados")
	var saldo := int(d.economia()["saldo_inicial"])
	var ritmos := []
	for o in Usados.estoque(d.lista("carros"), 0, {}):
		if int(o["preco"]) > saldo:
			continue
		var r: Dictionary = Percurso.jogar(d, o, 30.0 * 60.0)
		if not r["licenca_b"]:
			continue
		var melhor := _melhor_ritmo(d, r["carro"])
		ritmos.append(melhor["cr_min"])
		print("%s na licença B (%d cv): melhor %.0f Cr/min em %s" % [o["carro_id"],
				r["carro"].atributos_efetivos("seco")["potencia"], melhor["cr_min"], melhor["evento"]])
	ritmos.sort()
	var ritmo: float = ritmos[ritmos.size() / 2] if not ritmos.is_empty() else 0.0
	print("\nritmo de referência (mediana): %.0f Cr/min\n" % ritmo)
	print("%-20s %-10s %8s %10s %8s" % ["carro", "como", "preço", "minutos", "provas"])
	var linhas := []
	for c in d.lista("carros"):
		var precos := []
		if c.get("novo", true):
			precos.append(["novo", int(c["preco"])])
		for j in c.get("usados", []):
			precos.append(["usado", int(j[2])])
		var premio: Array = d.lista("eventos").filter(func(e): return e.get("carro_premio") == c["id"])
		var carro := Carro.new(c)
		carro.adicionar_pneu(d.pneu(d.economia()["pneu_de_fabrica"]))
		var provas := Mecanico.provas_possiveis(d, carro).size()
		if precos.is_empty():
			linhas.append("%-20s %-10s %8s %10s %8d" % [c["id"], "prêmio" if not premio.is_empty() else "-", "-", "-", provas])
			continue
		precos.sort_custom(func(a, b): return a[1] < b[1])
		var p: Array = precos[0]
		linhas.append("%-20s %-10s %8d %10.1f %8d" % [c["id"], p[0], p[1], p[1] / maxf(ritmo, 1.0), provas])
	for l in linhas:
		print(l)


func _melhor_ritmo(d: Node, carro: Carro) -> Dictionary:
	var j: Node = preload("res://autoload/jogador.gd").new()
	j.novo_jogo(d.economia(), d.pneu)
	j.licencas = ["B", "A"]
	var uid: int = j.garagem.adicionar(carro.copiar())
	var carreira := Carreira.new(d, j)
	var melhor := {"cr_min": 0.0, "evento": "-"}
	for ev in d.lista("eventos"):
		var total := 0.0
		var tempo := 0.0
		var ok := true
		for k in AMOSTRAS:
			var r := carreira.preparar(ev["id"], uid, 700000 + k, false)
			if r.has("erro"):
				ok = false
				break
			var pos: int = r["resultado"]["classificacao"].find("jogador") + 1
			total += float(ev["premios"][pos - 1]) if pos <= ev["premios"].size() else 0.0
			tempo += float(r["duracao"])
		if ok and tempo > 0.0 and total / tempo * 60.0 > melhor["cr_min"]:
			melhor = {"cr_min": total / tempo * 60.0, "evento": ev["nome"]}
	j.free()
	return melhor
