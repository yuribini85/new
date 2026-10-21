extends SceneTree
## Calibra a pilotagem por toques (decisão 127, data/simulacao.json
## "pilotagem"). Mede, nas provas disputadas que o carro do cenário pode correr,
## a posição média com cada jeito de pilotar (as ordens dadas na hora, como na
## tela: a corrida anda junto e cada toque vale a partir do instante dele):
##   base      sem toque (o piloto contratado dirige)
##   perfeita  toda freada perfeita, toda saída limpa e ATACAR sempre que puder
##   boa       toda freada boa, toda saída limpa
##   ruim      toda freada tarde e toda saída solta no meio
##   ataque    só o ATACAR
##   peça      sem toque, com a peça mais barata que o carro aceita
## Uso: godot --headless --path . -s tools/calibrar_pilotagem.gd [-- sementes=10 cenario=carro_3d provas=5]

var d: Node
var j: Node
var p: Dictionary


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var args := {"sementes": "10", "cenario": "carro_3d", "provas": "5"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	d = root.get_node("Dados")
	j = root.get_node("Jogador")
	root.get_node("SaveManager").caminho = "user://save_calibrar_pilotagem.json"
	Cenarios.montar(d, j, String(args["cenario"]))
	p = Pilotagem.params(d)
	var carro: Carro = j.garagem.carro(j.carro_ativo)
	var com_peca := _com_peca(carro)
	var provas := []
	for ev in d.lista("eventos"):
		if provas.size() >= int(args["provas"]):
			break
		var teste: Dictionary = j.carreira.preparar(ev["id"], carro.uid, 1, false)
		if teste.has("erro"):
			continue
		var total: int = teste["resultado"]["classificacao"].size()
		var media := 0.0
		for k in 4:
			media += _posicao(j.carreira.preparar(ev["id"], carro.uid, 500 + k, false)["resultado"]) / 4.0
		if media >= 2.0 and media <= total - 1.0:
			provas.append(ev["id"])
	print("carro ", carro.id, " · peça de comparação ", com_peca[1], " · provas ", provas)
	var politicas := ["base", "perfeita", "boa", "ruim", "ataque", "peca"]
	var soma := {}
	var vit := {}
	var toques := {}
	for c in politicas:
		soma[c] = 0.0
		vit[c] = 0
		toques[c] = 0
	var n := 0
	for ev_id in provas:
		for k in int(args["sementes"]):
			var semente := 1000 + k
			for c in politicas:
				var r := _jogar(ev_id, com_peca[0] if c == "peca" else carro, semente, "base" if c == "peca" else c)
				soma[c] += r[0]
				vit[c] += 1 if r[0] == 1 else 0
				toques[c] += r[1]
			n += 1
	print("corridas ", n)
	for c in politicas:
		print("%-8s posição média %.3f  vitórias %5.1f%%  ganho sobre a base %+.3f  toques/corrida %.1f" % [c,
				soma[c] / n, 100.0 * vit[c] / n, (soma["base"] - soma[c]) / n, float(toques[c]) / n])
	quit()


## [posição final, toques] pilotando com a política, a corrida andando junto.
func _jogar(ev_id: String, carro: Carro, semente: int, politica: String) -> Array:
	var piloto: Dictionary = EquipeJogador.piloto_do_jogador(d, j).duplicate(true)
	piloto["ordens"] = []
	var prep: Dictionary = j.carreira.iniciar_preparo(ev_id, carro.uid, semente, false, carro, null, piloto)
	var a: Simulacao.Andamento = prep["andamento"]
	if politica == "base":
		a.avancar(INF)
		return [_posicao(a.resultado()), 0]
	var ev: Dictionary = d.evento(ev_id)
	var pista: Pista = d.pista(ev["pista"])
	var comp := pista.comprimento
	var curvas := Tatica.curvas(pista, carro.atributos_efetivos(ev["condicao"]), d.simulacao())
	var dt := float(d.simulacao()["dt_s"])
	var t := 0.0
	var s_antes := 0.0
	var toques := 0
	var ultimo_ataque := -INF
	var saida_ate := -1.0
	var soltar_em := -1.0
	while not a.pronto():
		t += dt
		a.avancar_ate(t)
		if a.pronto():
			break
		var est := a.estado()
		var s: float = est["jogador"][0]
		var v: float = maxf(est["jogador"][1], 1.0)
		for c in curvas:
			var frear := politica != "ataque" and Pilotagem.tem_frenagem(c, comp, p)
			if frear and _cruzou(s_antes, s, float(c["frenagem"]), comp):
				var nota := Pilotagem.PERFEITA if politica == "perfeita" else (Pilotagem.BOA if politica == "boa"
						else Pilotagem.TARDE)
				var ate := t + fposmod(float(c["fim"]) - float(c["frenagem"]), comp) / v
				a.ordenar("jogador", Pilotagem.ordem_frenagem(nota, a.tempo(), ate, p))
				toques += 1
			if frear and _cruzou(s_antes, s, float(c["fim"]), comp):
				saida_ate = a.tempo() + Pilotagem.dura_saida(p)
				a.ordenar("jogador", Pilotagem.ordem_saida(Pilotagem.LIMPA, a.tempo(), saida_ate, p))
				soltar_em = a.tempo() + Pilotagem.dura_saida(p) * 0.4 if politica == "ruim" else -1.0
		if soltar_em > 0.0 and a.tempo() >= soltar_em:
			a.ordenar("jogador", Pilotagem.ordem_saida(Pilotagem.SOLTOU, a.tempo(), saida_ate, p))
			soltar_em = -1.0
		if politica in ["perfeita", "ataque"]:
			var frente := INF
			for id in est:
				var dist: float = est[id][0] - s
				if id != "jogador" and dist > 0.0:
					frente = minf(frente, dist)
			if Pilotagem.pode_atacar(frente, a.tempo(), ultimo_ataque, p):
				a.ordenar("jogador", Pilotagem.ordem_ataque(a.tempo(), p))
				ultimo_ataque = a.tempo()
				toques += 1
		s_antes = s
	return [_posicao(a.resultado()), toques]


## O carro passou pelo ponto `x` da volta entre s_antes e s (distâncias na corrida).
func _cruzou(s_antes: float, s: float, x: float, comp: float) -> bool:
	if s <= s_antes:
		return false
	var k := floorf((s - x) / comp)
	return x + k * comp > s_antes and x + k * comp <= s


func _posicao(res: Dictionary) -> int:
	return res["classificacao"].find("jogador") + 1


## O carro com a peça mais barata que ele aceita (a primeira compra típica).
func _com_peca(carro: Carro) -> Array:
	var melhor := {}
	for pc in d.lista("pecas"):
		if carro.motivo_recusa(pc) == "" and Array(pc.get("carros_permitidos", [])).has(carro.id) \
				and not pc["id"] in carro.pecas_possuidas \
				and (melhor.is_empty() or int(pc["preco"]) < int(melhor["preco"])):
			melhor = pc
	var c := carro.copiar()
	if not melhor.is_empty():
		c.instalar(melhor)
	return [c, String(melhor.get("id", "nenhuma"))]
