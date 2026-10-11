extends SceneTree
## Mede o teto do treino do piloto (decisão 54) numa licença: o maior ritmo do
## piloto do jogador que encurta em até `meta` (padrão 10%, decisão do usuário)
## o caminho até vencer as provas dessa licença.
##
## Medida: pares prova + carro de fábrica elegível (`carros` por prova, do mais
## fraco ao mais forte), cada um em `sementes` corridas. Em cada corrida, o
## ritmo a partir do qual o jogador vence (r*): a base se já vence; senão, onde
## a volta média do jogador alcança a do melhor rival, interpolando entre a
## base e base + `delta` (os rivais não mudam: mesma semente). A fração de
## vitórias com ritmo r é a fração de corridas com r* <= r, e o caminho até
## vencer encurta na razão inversa dela. Assim cada corrida pesa pelo quanto
## falta, e não só por vencer ou não, e a medida resolve passos pequenos.
## Imprime uma linha "TETO {json}". Só lê; quem grava é tools/calibrar_treino.py.
##
## Uso: godot --headless --path . --script res://tools/calibrar_treino.gd -- --licenca=PRO
##      [--eventos=12] [--carros=24] [--sementes=1] [--meta=0.1] [--passo=0.001] [--ate=0.05] [--delta=0.02]

var _feito := false


func _process(_d: float) -> bool:
	if not _feito:
		_feito = true
		_rodar()
		quit()
	return false


func _rodar() -> void:
	var dados: Node = root.get_node("Dados")
	var jogador: Node = root.get_node("Jogador")
	var a := {"licenca": "PRO", "eventos": "12", "carros": "24", "sementes": "1", "meta": "0.1",
			"passo": "0.001", "ate": "0.05", "delta": "0.02"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var kv := arg.trim_prefix("--").split("=")
			a[kv[0]] = kv[1]
	var lic := String(a["licenca"])
	var n_ev := int(a["eventos"])
	var n_car := int(a["carros"])
	var sementes := int(a["sementes"])
	var meta := float(a["meta"])
	var delta := float(a["delta"])
	var ordem := GestaoEquipe.ordem(dados)
	var licencas: Array = ordem.slice(0, ordem.find(lic) + 1)
	var piloto: Dictionary = dados.item("pilotos_ia", String(dados.carreira()["piloto_jogador"]))
	var base := float(piloto["ritmo"])
	var eventos: Array = dados.lista("eventos").filter(func(e):
		return String(e["restricoes"].get("licenca", "")) == lic and not e["premios"].is_empty())
	eventos.sort_custom(func(x, y): return x["id"] < y["id"])
	var passo := maxf(float(eventos.size()) / maxf(n_ev, 1), 1.0)
	var amostra := []
	var f := 0.0
	while int(f) < eventos.size() and amostra.size() < n_ev:
		amostra.append(eventos[int(f)])
		f += passo
	var carros: Array = dados.lista("carros").duplicate()
	carros.sort_custom(func(x, y): return float(x["potencia"]) < float(y["potencia"]))
	# Pares (prova, carro): carros elegíveis espalhados do mais fraco ao mais forte.
	var pares := []
	for ev in amostra:
		var elegiveis := carros.filter(func(m):
			return Elegibilidade.motivos(Carro.new(m), ev["restricoes"], licencas).is_empty())
		var vistos := {}
		for k in n_car:
			if elegiveis.is_empty():
				break
			var m: Dictionary = elegiveis[int(float(k) / n_car * elegiveis.size())]
			if not vistos.has(m["id"]):
				vistos[m["id"]] = true
				pares.append([ev, m])
	print("licença %s: %d provas na amostra, %d pares prova+carro" % [lic, amostra.size(), pares.size()])
	# r* de cada corrida (INF: não alcança nem com base + delta extrapolado).
	var limiares := PackedFloat64Array()
	for par in pares:
		for s in sementes:
			piloto["ritmo"] = base
			var r0 := _corrida(dados, jogador, licencas, par[0], par[1], s)
			if r0.is_empty():
				continue
			if r0["venceu"]:
				limiares.append(base)
				continue
			piloto["ritmo"] = base + delta
			var r1 := _corrida(dados, jogador, licencas, par[0], par[1], s)
			var ganho := float(r0["minha"]) - float(r1["minha"])  # volta média mais curta
			var falta := float(r0["minha"]) - float(r0["rival"])
			# Perdeu na base: vence só acima dela, mesmo com a volta média já melhor.
			limiares.append(maxf(base + delta * falta / ganho, base + 1e-6) if ganho > 1e-9 else INF)
	piloto["ritmo"] = base
	var ordenados := Array(limiares)
	ordenados.sort()
	print("  r* (ritmo para vencer, ordenado): ", ordenados.map(func(x): return snappedf(x, 0.001)))
	var total := maxf(limiares.size(), 1)
	var vitorias := func(r: float) -> float:
		var n := 0
		for x in limiares:
			if x <= r + 1e-9:
				n += 1
		return float(n) / total
	var v0: float = vitorias.call(base)
	var teto := base
	var grade := {}
	var r := base
	while r <= base + float(a["ate"]) + 1e-9:
		var v: float = vitorias.call(r)
		grade[snappedf(r, 0.0001)] = v
		# Caminho relativo = v0 / v (inverso da fração de vitórias): até 1 - meta.
		if v0 > 0.0 and v0 / v >= 1.0 - meta - 1e-9:
			teto = snappedf(r, 0.0001)
		r += float(a["passo"])
	for k in grade:
		if fmod(k - base + 1e-6, 0.005) < 2e-6 or k == teto:
			print("  ritmo %.4f: %.1f%% de vitórias (caminho %.0f%% da base)%s" % [k, 100.0 * grade[k],
					100.0 * v0 / maxf(grade[k], 1e-9), "  <- teto" if k == teto else ""])
	print("TETO " + JSON.stringify({"licenca": lic, "teto": teto, "base": base, "pares": pares.size(),
			"corridas": limiares.size(), "meta": meta, "vitorias_base": v0}))


## {venceu, minha, rival}: volta média do jogador e a do melhor rival (quem
## não termina no tempo máximo conta pelas voltas que deu).
func _corrida(dados: Node, jogador: Node, licencas: Array, ev: Dictionary, m: Dictionary, semente: int) -> Dictionary:
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.licencas = licencas.duplicate()
	var carro := Carro.new(m)
	carro.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
	if carro.pneus.is_empty():
		return {}
	var uid: int = jogador.garagem.adicionar(carro)
	var r: Dictionary = Carreira.new(dados, jogador).preparar(ev["id"], uid, semente, false)
	if r.has("erro"):
		return {}
	var cr: Dictionary = r["resultado"]["carros"]
	var rival := INF
	for id in cr:
		if id != "jogador":
			rival = minf(rival, _volta_media(cr[id]))
	return {"venceu": r["resultado"]["classificacao"][0] == "jogador", "minha": _volta_media(cr["jogador"]), "rival": rival}


static func _volta_media(c: Dictionary) -> float:
	var voltas: Array = c["voltas"]
	if voltas.is_empty():
		return INF
	var soma := 0.0
	for v in voltas:
		soma += float(v)
	return soma / voltas.size()
