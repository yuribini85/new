extends SceneTree
## Mede o teto do treino do piloto (decisão 54) numa licença: o maior ritmo do
## piloto do jogador que encurta em até `meta` (padrão 10%, decisão do usuário)
## o caminho até vencer as provas dessa licença. Na simulação cada carro quase
## sempre vence ou nunca vence uma prova; o treino faz carros mais fracos
## vencerem. A grade vai da base até base + `ate`, de `passo` em `passo`. Medida: fração de vitórias dos carros de
## fábrica elegíveis (`carros` por prova, do mais fraco ao mais forte) em
## `sementes` corridas, nas mesmas sementes para toda a grade; o caminho até
## vencer encurta na razão base ÷ treino.
## Imprime uma linha "TETO {json}". Só lê; quem grava é tools/calibrar_treino.py.
##
## Uso: godot --headless --path . --script res://tools/calibrar_treino.gd -- --licenca=PRO
##      [--eventos=12] [--carros=12] [--sementes=4] [--meta=0.1] [--passo=0.0025] [--ate=0.05]

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
	var a := {"licenca": "PRO", "eventos": "12", "carros": "12", "sementes": "4", "meta": "0.1", "passo": "0.0025", "ate": "0.05"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var kv := arg.trim_prefix("--").split("=")
			a[kv[0]] = kv[1]
	var lic := String(a["licenca"])
	var n_ev := int(a["eventos"])
	var n_car := int(a["carros"])
	var sementes := int(a["sementes"])
	var meta := float(a["meta"])
	var ordem := GestaoEquipe.ordem(dados)
	var licencas: Array = ordem.slice(0, ordem.find(lic) + 1)
	var piloto: Dictionary = dados.item("pilotos_ia", String(dados.carreira()["piloto_jogador"]))
	var base := float(piloto["ritmo"])
	var grade := []
	var c := base
	while c <= base + float(a["ate"]) + 1e-6:
		grade.append(snappedf(c, 0.0001))
		c += float(a["passo"])
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
	var esperadas := {}
	var vitorias := {}
	var tempos := {}
	for cc in grade:
		piloto["ritmo"] = cc
		var v := 0.0
		var t := 0.0
		for par in pares:
			var r := _corridas(dados, jogador, licencas, par[0], par[1], sementes, 0)
			v += r[0]
			t += r[1]
		vitorias[cc] = v / maxf(pares.size(), 1)
		tempos[cc] = t
		# Caminho até vencer, relativo: inverso da fração de vitórias.
		esperadas[cc] = 1.0 / maxf(vitorias[cc], 0.5 / maxf(pares.size() * sementes, 1))
		print("  ritmo %.4f: %.1f%% de vitórias (caminho %.0f%% da base), tempo de corrida %+.2f%%" % [cc,
				100.0 * vitorias[cc], 100.0 * esperadas[cc] / maxf(esperadas[grade[0]], 1e-6),
				100.0 * (tempos[cc] / maxf(tempos[grade[0]], 1e-6) - 1.0)])
	piloto["ritmo"] = base
	var teto := base
	for cc in grade:
		if esperadas[cc] >= (1.0 - meta) * esperadas[grade[0]]:
			teto = cc
		else:
			break
	print("TETO " + JSON.stringify({"licenca": lic, "teto": teto, "base": base, "pares": pares.size(),
			"meta": meta, "esperadas": esperadas, "ganho_tempo_no_teto": 1.0 - tempos[teto] / maxf(tempos[grade[0]], 1e-6)}))


## [fração de vitórias, soma do tempo do jogador] do carro de fábrica na prova,
## em `n` sementes a partir de `s0`.
func _corridas(dados: Node, jogador: Node, licencas: Array, ev: Dictionary, m: Dictionary, n: int, s0: int) -> Array:
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.licencas = licencas.duplicate()
	var carro := Carro.new(m)
	carro.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
	var uid: int = jogador.garagem.adicionar(carro)
	var carreira := Carreira.new(dados, jogador)
	var v := 0
	var t := 0.0
	if carro.pneus.is_empty():
		return [0.0, 0.0]
	for s in n:
		var r: Dictionary = carreira.preparar(ev["id"], uid, s0 + s, false)
		if r.has("erro"):
			continue
		if r["resultado"]["classificacao"][0] == "jogador":
			v += 1
		t += float(r["resultado"]["carros"]["jogador"]["tempo_total"])
	return [float(v) / n, t]
