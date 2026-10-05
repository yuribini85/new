extends SceneTree
## Progressão e renda por fase, por perfil de jogador (tools/agente.gd), com cada
## carro inicial que o saldo inicial paga. Substitui tools/custo_carros.gd.
## Só mede: não muda dados.
##
## Mede, por fase (sem licença, B, A):
##   - créditos por minuto de corrida (renda bruta ÷ tempo de fila);
##   - créditos por minuto nas corridas de renda (provas já vencidas);
##   - renda bruta, gastos e saldo (saldo baixo pode ser só compra);
## e a tabela de compras: fase · compra · saldo · falta · renda usada · duração da
## corrida · ganho por corrida · corridas e minutos de fila até pagar.
##
## Sessões e retornos dependem do comportamento, que vem do playtest de ritmo
## (docs/playtest_percurso.md). Passe os valores observados (vários, separados
## por vírgula, para ver a faixa):
##   --ausencia_h=2,8     horas entre sessões: retornos = minutos de fila ÷ min(ausência, teto offline)
##   --sessao_min=10,20   minutos de jogo aberto com a fila correndo: sessões = minutos de fila ÷ sessão
## Renda ativa e offline são a mesma fila: não se somam.
## Uso: godot --headless --path . --script res://tools/medir_progressao.gd -- [--limite_min=120] [--perfis=sugestoes,renda] [--ausencia_h=..] [--sessao_min=..]

const Agente := preload("res://tools/agente.gd")

var _feito := false


func _process(_delta: float) -> bool:
	if not _feito:
		_feito = true
		_rodar()
		quit()
	return false


func _rodar() -> void:
	var d: Node = root.get_node("Dados")
	var args := _args()
	var limite := float(args.get("limite_min", "120")) * 60.0
	var perfis: Array = String(args.get("perfis", ",".join(Agente.PERFIS))).split(",")
	var ausencias := _numeros(args.get("ausencia_h", ""))
	var sessoes := _numeros(args.get("sessao_min", ""))
	var teto_h := float(d.carreira()["teto_offline_s"]) / 3600.0
	var saldo := int(d.economia()["saldo_inicial"])
	var ofertas := []
	for o in Usados.estoque(d.lista("carros"), 0, {}):
		if int(o["preco"]) <= saldo:
			ofertas.append(o)
	print("limite %.0f min de corrida · teto offline %.1f h · %d carros iniciais · perfis %s" % [limite / 60.0, teto_h,
			ofertas.size(), ", ".join(perfis)])
	if ausencias.is_empty() and sessoes.is_empty():
		print("sem --ausencia_h/--sessao_min: retornos e sessões ficam pendentes do playtest de ritmo\n")
	var agregado := {}  # perfil -> fase -> listas
	for perfil in perfis:
		for o in ofertas:
			var ag = Agente.new(d, perfil, hash(perfil + o["carro_id"]))
			var r: Dictionary = ag.jogar(o, limite)
			ag.liberar()
			_imprimir(r, o, ausencias, sessoes, teto_h)
			for f in r["fases"]:
				var a: Dictionary = agregado.get_or_add(perfil, {}).get_or_add(f, {"cr_min": [], "renda_cr_min": []})
				var st: Dictionary = r["fases"][f]
				if st["tempo_s"] > 0.0:
					a["cr_min"].append(st["bruto"] / st["tempo_s"] * 60.0)
				if st["renda_s"] > 0.0:
					a["renda_cr_min"].append(st["renda_cr"] / st["renda_s"] * 60.0)
	print("\n=== Resumo: mediana [mín–máx] entre carros iniciais ===")
	for perfil in agregado:
		for f in agregado[perfil]:
			var a: Dictionary = agregado[perfil][f]
			print("%-10s %-12s Cr/min de corrida %s · Cr/min de renda %s · Cr por hora ausente (fila de renda, até o teto) %s" % [
					perfil, f, _faixa(a["cr_min"]), _faixa(a["renda_cr_min"]), _faixa(a["renda_cr_min"].map(func(x): return x * 60.0))])


func _imprimir(r: Dictionary, o: Dictionary, ausencias: Array, sessoes: Array, teto_h: float) -> void:
	var m: Dictionary = r["marcos"]
	print("\n--- %s · %s (%d Cr) · %.0f min de corrida · licenças %s · saldo %d" % [r["perfil"], o["carro_id"], o["preco"],
			r["tempo"] / 60.0, ",".join(r["licencas"]) if not r["licencas"].is_empty() else "-", r["saldo"]])
	print("    %d de %d provas vencidas · %d carros na garagem · fim: %s" % [r["vencidas"], r["provas"], r["carros"],
			r["log"].back() if not r["log"].is_empty() else "-"])
	print("    marcos (min de corrida): 1ª vitória %s · B %s (%s envios) · 1ª vitória B %s · A %s" % [_min(m, "primeira_vitoria"),
			_min(m, "licenca_b"), m.get("envios_contratos_b", "-"), _min(m, "vitoria_b"), _min(m, "licenca_a")])
	for f in r["fases"]:
		var st: Dictionary = r["fases"][f]
		print("    %-12s %5.1f min · bruto %7d · gastos %7d · %5.0f Cr/min · renda %d corridas, %5.0f Cr/min · %d desafios" % [
				f, st["tempo_s"] / 60.0, st["bruto"], st["gastos"], st["bruto"] / maxf(st["tempo_s"], 1.0) * 60.0,
				st["renda_corridas"], st["renda_cr"] / maxf(st["renda_s"], 1.0) * 60.0, st["desafios"]])
	var cab := "    %-12s %-30s %7s %7s %7s %-28s %6s %7s %4s %6s" % ["fase", "compra", "preço", "saldo", "falta", "renda", "dur s",
			"Cr/corr", "corr", "min"]
	for a in ausencias:
		cab += " ret@%sh" % a
	for s in sessoes:
		cab += " ses@%smin" % s
	print(cab)
	for c in r["compras"]:
		var l := "    %-12s %-30s %7d %7d %7d %-28s %6.0f %7.0f %4d %6.1f" % [c["fase"], String(c["compra"]).left(30), c["preco"],
				c["saldo"], c["falta"], String(c["renda"]).left(28), c["duracao_s"], c["ganho_corrida"], c["corridas"], c["minutos"]]
		for a in ausencias:
			l += " %7d" % ceili(c["minutos"] / (minf(a, teto_h) * 60.0)) if c["minutos"] > 0.0 else "       0"
		for s in sessoes:
			l += " %9d" % ceili(c["minutos"] / s) if c["minutos"] > 0.0 else "         0"
		print(l)


static func _min(m: Dictionary, k: String) -> String:
	return "%.0f" % (float(m[k]) / 60.0) if m.has(k) else "-"


static func _faixa(xs: Array) -> String:
	if xs.is_empty():
		return "-"
	var s := xs.duplicate()
	s.sort()
	return "%.0f [%.0f–%.0f]" % [s[s.size() / 2], s[0], s[s.size() - 1]]


static func _numeros(t: String) -> Array:
	return Array(t.split(",", false)).map(func(x): return float(x))


static func _args() -> Dictionary:
	var r := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.trim_prefix("--").split("=", true, 1)
			r[kv[0]] = kv[1]
	return r
