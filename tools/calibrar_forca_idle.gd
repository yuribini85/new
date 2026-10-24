extends SceneTree
## Chrome Racing Team: acha a forca_rivais de cada liga (data/idle/idle.json)
## que faz o menor nível de motor (= pneus) que vence 3 de 5 corridas ficar em
## ALVO, com ultrapassagem e vácuo no máximo. Toda liga pede o mesmo, e o tempo
## de cada uma sai só do custo (expoente_custo_liga). Copie os valores impressos
## para o JSON; a 1ª liga fica mais fácil à mão (1ª vitória cedo).
## Uso: godot --headless --path . -s tools/calibrar_forca_idle.gd
const ALVO := 12

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
	d = root.get_node("Dados")
	e = IdleEstado.new()
	e.niveis["ultrapassagem"] = int(e.melhoria("ultrapassagem")["max"])
	e.niveis["vacuo"] = int(e.melhoria("vacuo")["max"])
	var saida := []
	for l in e.cfg["ligas"].size():
		e.liga = l
		var lo := 0.5
		var hi := 1.6
		for it in 8:
			var f := (lo + hi) / 2.0
			e.cfg["ligas"][l]["forca_rivais"] = f
			if nivel_min() > ALVO:
				hi = f
			else:
				lo = f
		e.cfg["ligas"][l]["forca_rivais"] = snappedf(lo, 0.01)
		var n := nivel_min()
		print("%-24s forca %.2f  nível %d" % [e.dados_liga()["nome"], snappedf(lo, 0.01), n])
		saida.append(snappedf(lo, 0.01))
	print(JSON.stringify(saida))
	quit()
