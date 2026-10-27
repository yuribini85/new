extends SceneTree
## The Fastfather: acha a forca_rivais de cada pista de cada modalidade
## (data/idle/idle.json, "forca_rivais" da modalidade) que faz o menor nível de
## motor (= pneus) que vence 3 de 5 corridas ficar em ALVO, com ultrapassagem e
## vácuo no máximo e o piloto base. Toda liga pede o mesmo, e o tempo de cada
## uma sai só do custo (expoente_custo_liga). Copie os valores impressos para o
## JSON. A arena tem simulação própria e fica de fora.
## Com por_liga=1, acha a força de cada liga (o "forca_rivais" da liga, que
## vale sobre o da pista): os carros mudam muito de uma liga para outra.
## Uso: godot --headless --path . -s tools/calibrar_forca_idle.gd [-- modalidade=gt por_liga=1 alvo=12]

var ALVO := 12  # alvo=N na linha de comando

var d: Node
var e: IdleEstado


func _initialize() -> void:
	_r.call_deferred()


func nivel_min() -> int:
	var lo := 0
	var hi := 60
	while lo < hi:
		var k := (lo + hi) / 2
		e.niveis["motor"] = k
		e.niveis["pneus"] = mini(k, 40)
		var v := 0
		for s in 5:
			if IdleEstado.posicao(e.correr(d, 300 + s, false)) == 1:
				v += 1
		if v >= 3:
			hi = k
		else:
			lo = k + 1
	return lo


func _r() -> void:
	var so := ""
	var por_liga := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("modalidade="):
			so = a.trim_prefix("modalidade=")
		elif a == "por_liga=1":
			por_liga = true
		elif a.begins_with("alvo="):
			ALVO = int(a.trim_prefix("alvo="))
	d = root.get_node("Dados")
	e = IdleEstado.new()
	for m in e.cfg["modalidades"]:
		if m.get("tipo", "") == "arena" or (so != "" and m["id"] != so):
			continue
		e.mods[m["id"]] = {"liga": 0, "venceu": false, "niveis": e.niveis.duplicate(), "corridas": 0}
		e.modalidade = m["id"]
		e.niveis["ultrapassagem"] = int(e.melhoria("ultrapassagem")["max"])
		e.niveis["vacuo"] = int(e.melhoria("vacuo")["max"])
		if por_liga:
			var lista := []
			for i in m["ligas"].size():
				e.liga = i
				var lo := 0.5
				var hi := 1.6
				for it in 8:
					var f := (lo + hi) / 2.0
					m["ligas"][i]["forca_rivais"] = f
					if nivel_min() > ALVO:
						hi = f
					else:
						lo = f
				m["ligas"][i]["forca_rivais"] = snappedf(lo, 0.01)
				lista.append(snappedf(lo, 0.01))
				print("%-10s %-28s forca %.2f  nível %d" % [m["id"], m["ligas"][i]["nome"], snappedf(lo, 0.01), nivel_min()])
			print("%s ligas: %s" % [m["id"], JSON.stringify(lista)])
			continue
		var saida := {}
		for pista in m["forca_rivais"]:
			# A primeira liga da modalidade nessa pista.
			for i in m["ligas"].size():
				if m["ligas"][i]["pista"] == pista:
					e.liga = i
					break
			var lo := 0.5
			var hi := 1.6
			for it in 8:
				var f := (lo + hi) / 2.0
				m["forca_rivais"][pista] = f
				if nivel_min() > ALVO:
					hi = f
				else:
					lo = f
			m["forca_rivais"][pista] = snappedf(lo, 0.01)
			saida[pista] = snappedf(lo, 0.01)
			print("%-10s %-24s forca %.2f  nível %d" % [m["id"], pista, snappedf(lo, 0.01), nivel_min()])
		print("%s: %s" % [m["id"], JSON.stringify(saida)])
	quit()
