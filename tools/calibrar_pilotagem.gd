extends SceneTree
## Calibra a pilotagem por toques (decisão 127, data/simulacao.json
## "pilotagem"). Mede, nas provas disputadas que o carro do cenário pode correr,
## a posição média com cada jeito de pilotar (as ordens dadas na hora, como na
## tela: a corrida anda junto e cada toque vale a partir do instante dele):
##   base      sem toque (o piloto contratado dirige)
##   perfeita  largada perfeita, toda freada perfeita, toda saída limpa, a
##             passagem no vácuo e a porta fechada sempre que puder
##   beira     como a perfeita, tocando no começo da faixa verde: a freada boa ou
##             perfeita vale do ponto em diante, então dá o mesmo (fora do padrão)
##   boa       largada boa, toda freada boa, toda saída limpa
##   ruim      largada queimada, toda freada tarde e o dedo solto antes da
##             saída em toda curva (perdeu tração)
##   largada   só a largada perfeita
##   ataque    só a passagem no vácuo
##   defesa    só a porta fechada (deslize no lado certo sempre que puder)
##   forcar    só o modo do pneu (provas longas): no começo de cada volta,
##             ATAQUE com um rival a até ataque.distancia_m à frente, POUPAR
##             sozinho (ninguém a 3× isso), senão NORMAL
##   forcou    ATAQUE toda volta
##   peça      sem toque, com a peça mais barata que o carro aceita
## Uso: godot --headless --path . -s tools/calibrar_pilotagem.gd [-- sementes=10 cenario=carro_3d provas=5
##        politicas=base,largada voltas_min=30]

var d: Node
var j: Node
var p: Dictionary


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var args := {"sementes": "10", "cenario": "carro_3d", "provas": "5", "voltas_min": "0"}
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
		if int(ev["voltas"]) < int(args["voltas_min"]):
			continue
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
	var politicas := ["base", "perfeita", "boa", "ruim", "largada", "ataque", "defesa", "forcar", "forcou", "peca"]
	if args.has("politicas"):
		politicas = Array(String(args["politicas"]).split(","))
		if not "base" in politicas:
			politicas.push_front("base")  # o ganho é sobre ela
	var soma := {}
	var vit := {}
	var toques := {}
	var tempo := {}
	for c in politicas:
		tempo[c] = 0.0
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
				tempo[c] += r[2]
			n += 1
	print("corridas ", n)
	for c in politicas:
		print("%-8s posição média %.3f  vitórias %5.1f%%  ganho sobre a base %+.3f  toques/corrida %.1f  tempo %+.2f%%" % [c,
				soma[c] / n, 100.0 * vit[c] / n, (soma["base"] - soma[c]) / n, float(toques[c]) / n,
				100.0 * (tempo[c] - tempo["base"]) / maxf(tempo["base"], 1e-6)])
	quit()


## [posição final, toques, tempo de prova] pilotando com a política, a corrida andando junto.
func _jogar(ev_id: String, carro: Carro, semente: int, politica: String) -> Array:
	var piloto: Dictionary = EquipeJogador.piloto_do_jogador(d, j).duplicate(true)
	piloto["ordens"] = []
	var prep: Dictionary = j.carreira.iniciar_preparo(ev_id, carro.uid, semente, false, carro, null, piloto)
	var a: Simulacao.Andamento = prep["andamento"]
	if politica == "base":
		a.avancar(INF)
		return [_posicao(a.resultado()), 0, _tempo(a.resultado())]
	var ev: Dictionary = d.evento(ev_id)
	var pista: Pista = d.pista(ev["pista"])
	var comp := pista.comprimento
	var curvas := Tatica.curvas(pista, carro.atributos_efetivos(ev["condicao"]), d.simulacao())
	var dt := float(d.simulacao()["dt_s"])
	var t := 0.0
	var s_antes := 0.0
	var v_antes := 0.0
	var freadas := {}  # curva (início na corrida, m) -> true depois do toque
	var toques := 0
	var ultimo_ataque := -INF
	var ultima_defesa := -INF
	var volta_antes := 0
	var inicio_volta := 0.0
	var volta_s := 0.0
	var guardados := 0
	var forca := Pilotagem.pode_forcar(int(d.evento(ev_id)["voltas"]), p)
	# Largada: perfeita, boa ou queimada (ruim); vale do apagar das luzes.
	var largada := {"perfeita": Pilotagem.LARGADA_PERFEITA, "beira": Pilotagem.LARGADA_PERFEITA,
			"largada": Pilotagem.LARGADA_PERFEITA, "boa": Pilotagem.LARGADA_BOA, "ruim": Pilotagem.QUEIMOU}
	if largada.has(politica):
		a.ordenar("jogador", Pilotagem.ordem_largada(largada[politica], p))
		toques += 1
	while not a.pronto():
		t += dt
		a.avancar_ate(t)
		if a.pronto():
			break
		var est := a.estado()
		var s: float = est["jogador"][0]
		var v: float = maxf(est["jogador"][1], 1.0)
		for c in curvas:
			var frear := not politica in ["ataque", "largada", "defesa", "forcar", "forcou"] and Pilotagem.tem_frenagem(c, comp, p)
			# O ponto da freada é onde o carro começa a perder velocidade antes da
			# curva, como na tela (CorridaVisual.inicio_freada): a frenagem da
			# Tatica é só o começo possível (sem velocidade máxima, o fim da curva
			# anterior). Tocar antes (beira) vale do ponto em diante: o mesmo efeito.
			var falta := fposmod(float(c["inicio"]) - s, comp)
			var chave := roundi(s + falta)
			if frear and not freadas.has(chave) and v < v_antes - 0.01 and falta >= float(p["frenagem"]["minimo_m"]) \
					and fposmod(s - float(c["frenagem"]), comp) < fposmod(float(c["inicio"]) - float(c["frenagem"]), comp):
				freadas[chave] = true
				var nota := Pilotagem.PERFEITA if politica in ["perfeita", "beira"] else (Pilotagem.BOA if politica == "boa"
						else Pilotagem.TARDE)
				var ate := t + fposmod(float(c["fim"]) - s, comp) / v
				a.ordenar("jogador", Pilotagem.ordem_frenagem(nota, a.tempo(), ate, p, a.tempo()))
				toques += 1
			if frear and _cruzou(s_antes, s, float(c["fim"]), comp):
				var nota_saida := Pilotagem.SOLTOU if politica == "ruim" else Pilotagem.LIMPA
				a.ordenar("jogador", Pilotagem.ordem_saida(nota_saida, a.tempo(), a.tempo() + Pilotagem.dura_saida(p), p))
		if politica in ["perfeita", "beira", "ataque"]:
			var frente := INF
			for id in est:
				var dist: float = est[id][0] - s
				if id != "jogador" and dist > 0.0:
					frente = minf(frente, dist)
			if Pilotagem.pode_atacar(frente, a.tempo(), ultimo_ataque, p):
				a.ordenar("jogador", Pilotagem.ordem_ataque(a.tempo(), p))
				ultimo_ataque = a.tempo()
				toques += 1
		var volta := floori(s / comp)
		if volta != volta_antes and s > 0.0:
			volta_s = a.tempo() - inicio_volta
			inicio_volta = a.tempo()
			volta_antes = volta
			if forca and volta_s > 0.0 and politica in ["perfeita", "beira", "forcar", "forcou"]:
				var perto := INF
				var longe := INF
				for id in est:
					if id != "jogador":
						var dist: float = est[id][0] - s
						if dist > 0.0:
							perto = minf(perto, dist)
						longe = minf(longe, absf(dist))
				# O modo da volta (botão do pneu): ATAQUE com um rival perto, POUPAR
				# sozinho, senão NORMAL.
				var dist_ataque := float(p["ataque"]["distancia_m"])
				var modo := Pilotagem.NORMAL
				if politica == "forcou" or perto <= dist_ataque:
					modo = Pilotagem.ATAQUE
				elif longe > 3.0 * dist_ataque:
					modo = Pilotagem.POUPAR
				var r := Pilotagem.ordens_modo(modo, a.tempo(), a.tempo() + volta_s, volta_s, guardados, p)
				for o in r[0]:
					a.ordenar("jogador", o)
				guardados = int(r[1])
				if modo != Pilotagem.NORMAL:
					toques += 1
		if politica in ["perfeita", "beira", "defesa"]:
			var tras := INF
			for id in est:
				var dist: float = s - est[id][0]
				if id != "jogador" and dist > 0.0:
					tras = minf(tras, dist)
			if Pilotagem.pode_defender(tras, a.tempo(), ultima_defesa, p):
				a.ordenar("jogador", Pilotagem.ordem_defesa(a.tempo(), p))
				ultima_defesa = a.tempo()
				toques += 1
		s_antes = s
		v_antes = v
	return [_posicao(a.resultado()), toques, _tempo(a.resultado())]


## O carro passou pelo ponto `x` da volta entre s_antes e s (distâncias na corrida).
func _cruzou(s_antes: float, s: float, x: float, comp: float) -> bool:
	if s <= s_antes:
		return false
	var k := floorf((s - x) / comp)
	return x + k * comp > s_antes and x + k * comp <= s


func _tempo(res: Dictionary) -> float:
	return float(res["carros"]["jogador"].get("tempo_total", 0.0))


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
