extends "res://tests/base_teste.gd"
## Arena (sim/arena.gd): critérios de aceite do estudo Destruction Derby —
## batida mais forte, mais dano; batida de lado desloca e gira; região certa;
## nenhum dano duplicado no mesmo contato; eliminado vira obstáculo; mesmo
## resultado com e sem amostras.


func _params() -> Dictionary:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var p: Dictionary = d.arena()
	d.free()
	return p


func _carro(id: String, peso := 1200.0, pot := 200.0, pos := Vector2.ZERO, rumo := 0.0, vel := Vector2.ZERO,
		acel = null) -> Dictionary:
	var p := {"id": id, "atributos": {"peso": peso, "potencia": pot, "aderencia": 1.0},
			"piloto": {"ritmo": 1.0, "consistencia": 1.0, "agressividade": 0.5}, "pos": pos, "rumo": rumo, "vel": vel}
	if acel != null:
		p["acelerador"] = acel
	return p


## Carro parado (sem IA) e outro vindo a `kmh` de frente para a lateral dele.
func _lateral(kmh: float, params: Dictionary) -> Dictionary:
	var v := kmh / 3.6
	var alvo := _carro("alvo", 1200.0, 200.0, Vector2(0, 0), 0.0, Vector2.ZERO, 0.0)
	var bate := _carro("bate", 1200.0, 200.0, Vector2(0, -12), PI / 2.0, Vector2(0, v), 0.0)
	var p := params.duplicate()
	p["tempo_max_s"] = 3.0
	return Arena.correr([alvo, bate], p, 1, false)


func test_dados_da_arena_completos() -> void:
	var p := _params()
	verificar(not p.is_empty(), "arena.json com todas as chaves")
	igual(float(p["limite_eliminacao"]), 1.0, "eliminação a 100% (estudo)")
	perto(float(p["limite_re"]), 0.9, 0.001, "ré a 90% (estudo)")


func test_batida_mais_forte_mais_dano() -> void:
	var p := _params()
	var fraco: PackedFloat32Array = _lateral(25.0, p)["carros"]["alvo"]["dano"]
	var r := _lateral(50.0, p)
	var d_fraco := 0.0
	var d_forte := 0.0
	for x in fraco:
		d_fraco += x
	for x in r["carros"]["alvo"]["dano"]:
		d_forte += x
	verificar(d_fraco > 0.0, "batida a 25 km/h causa dano")
	verificar(d_forte > d_fraco * 2.0, "o dobro da velocidade, bem mais dano (%.3f > %.3f)" % [d_forte, d_fraco])


func test_batida_na_lateral_marca_a_regiao_do_lado_e_empurra() -> void:
	var p := _params()
	var r := _lateral(40.0, p)
	var dano: PackedFloat32Array = r["carros"]["alvo"]["dano"]
	# O atacante vem de y<0 (à direita do alvo, que aponta para +x): lado direito.
	verificar(dano[3] > 0.0, "lado direito do alvo amassado")
	igual(dano[0] + dano[1] + dano[2] + dano[4] + dano[5], 0.0, "só a região atingida")
	var bate: PackedFloat32Array = r["carros"]["bate"]["dano"]
	verificar(bate[0] > 0.0 or bate[1] > 0.0, "quem bate amassa a frente")
	var fim: Dictionary = r["amostras"][-1]["alvo"]
	verificar(fim["pos"].y > 0.5, "o alvo foi empurrado")


func test_batida_fora_do_centro_gira() -> void:
	var p := _params()
	p["tempo_max_s"] = 3.0
	var alvo := _carro("alvo", 1200.0, 200.0, Vector2(0, 0), 0.0, Vector2.ZERO, 0.0)
	var bate := _carro("bate", 1200.0, 200.0, Vector2(-1.8, -12), PI / 2.0, Vector2(0, 50 / 3.6), 0.0)
	var r := Arena.correr([alvo, bate], p, 1, false)
	var rumo: float = r["amostras"][-1]["alvo"]["rumo"]
	verificar(absf(rumo) > 0.2, "golpe na traseira gira o alvo (%.2f rad)" % rumo)


func test_encostado_nao_cobra_de_novo() -> void:
	var p := _params()
	var r := _lateral(40.0, p)
	var impactos: Array = r["eventos"].filter(func(e): return e["tipo"] == "impacto" and e["carro"] == "alvo")
	verificar(not impactos.is_empty(), "houve o golpe")
	# Enquanto encostados depois do golpe, nada é cobrado de novo (um toque
	# posterior, depois de se separarem, é outro contato).
	var t0: float = impactos[0]["t"]
	igual(impactos.filter(func(e): return e["t"] > t0 and e["t"] < t0 + 0.3).size(), 0, "um contato, um dano")


func test_frente_destruida_elimina_e_fica_como_obstaculo() -> void:
	var p := _params()
	p["tempo_max_s"] = 4.0
	# De frente no muro bem acima da velocidade de referência.
	var v := float(p["v_ref_kmh"]) * 1.6 / 3.6
	var c := _carro("kami", 1200.0, 200.0, Vector2(float(p["raio_m"]) - 10.0, 0), 0.0, Vector2(v, 0), 0.0)
	var outro := _carro("outro", 1200.0, 200.0, Vector2(-20, 0), 0.0, Vector2.ZERO, 0.0)
	var r := Arena.correr([c, outro], p, 1, false)
	verificar(r["carros"]["kami"]["eliminado"], "frente a 100%: eliminado")
	igual(r["classificacao"][0], "outro", "quem sobra vence")
	var fim: Dictionary = r["amostras"][-1]["kami"]
	verificar(fim["pos"].length() < float(p["raio_m"]), "o destroço continua na arena")


func test_combate_com_ia_termina_e_repete_igual() -> void:
	var p := _params()
	p["tempo_max_s"] = 90.0
	var lista := []
	for i in 4:
		var c := _carro("c%d" % i, 1100.0 + 100.0 * i, 180.0 + 20.0 * i)
		c.erase("pos")
		c.erase("rumo")
		c.erase("vel")
		lista.append(c)
	var a := Arena.correr(lista, p, 42, true)
	var b := Arena.correr(lista, p, 42, false)
	igual(a["classificacao"], b["classificacao"], "mesma semente: mesma classificação com e sem amostras")
	igual(a["duracao"], b["duracao"], "mesma duração")
	var impactos: Array = a["eventos"].filter(func(e): return e["tipo"] == "impacto")
	verificar(impactos.size() >= 4, "a IA procura briga (%d impactos)" % impactos.size())
	print("  arena com IA: %.0f s, %d impactos, %d eliminados, classificação %s" % [a["duracao"], impactos.size(),
			a["eventos"].filter(func(e): return e["tipo"] == "eliminado").size(), a["classificacao"]])


const JogadorScript := preload("res://autoload/jogador.gd")


func _jogador_real(d: Node, n_carros: int) -> Node:
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	var ids := ["bancroft_arraia"]
	for c in d.lista("carros"):
		if ids.size() >= n_carros:
			break
		if not c["id"] in ids:
			ids.append(c["id"])
	for k in n_carros:
		var car := Carro.new(d.carro(ids[k]))
		car.adicionar_pneu(d.pneu(d.economia()["pneu_de_fabrica"]))
		var uid: int = j.garagem.adicionar(car)
		if k == 0:
			j.carro_ativo = uid
	return j


## Decisão 49: abre com a licença mínima, só com 2 carros; eliminado sai da
## garagem; pontos viram giros pelo prêmio de referência.
func test_arena_na_carreira() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var j := _jogador_real(d, 1)
	verificar(ArenaCarreira.bloqueio(d, j).begins_with("Abre quando"), "antes do tutorial da arena: fechada")
	j.flags[EquipeJogador.FLAG_ARENA] = true
	verificar("3 carros" in ArenaCarreira.bloqueio(d, j), "com 1 carro: não entra")
	j.free()
	# Decisão 68: 3 carros (1 de corrida, 2 de arena), segundo piloto e a escalação.
	j = _jogador_real(d, 3)
	j.flags[EquipeJogador.FLAG_ARENA] = true
	verificar("dois pilotos de arena" in ArenaCarreira.bloqueio(d, j), "sem os pilotos de arena: não entra")
	j.pilotos = {"corrida": "", "arena": ["ayla_moreno", "axel_brennan"]}
	verificar("Escale" in ArenaCarreira.bloqueio(d, j), "sem a escalação: não entra")
	var carros: Array = j.garagem.lista()
	igual(Escalacao.definir(j, "corrida", carros[2].uid), "", "corrida")
	igual(Escalacao.definir(j, "arena1", carros[0].uid), "", "arena 1")
	verificar(Escalacao.definir(j, "arena2", carros[2].uid) != "", "o carro de corrida não vai para a arena")
	igual(Escalacao.definir(j, "arena2", carros[1].uid), "", "arena 2")
	igual(ArenaCarreira.bloqueio(d, j), "", "com tudo: entra")
	j.fila = {"evento_id": "x", "uid": carros[2].uid}
	verificar("corrida em andamento" in ArenaCarreira.bloqueio(d, j), "corrida e arena nunca juntas")
	j.fila = {}
	verificar(not j.concessionaria.pode_vender(carros[0].uid), "escalado não se vende")
	var uid: int = carros[0].uid
	var m := ArenaCarreira.montar(d, j, uid, 7)
	igual(m["participantes"].size(), 4, "nível 1: 2×2, quatro carros")
	var equipes := {}
	for pt in m["participantes"]:
		equipes[pt["equipe"]] = int(equipes.get(pt["equipe"], 0)) + 1
	igual(equipes.size(), 2, "duas equipes")
	verificar(equipes.values().all(func(n): return n == 2), "duplas")
	verificar(m["parceiro"]["real"] and int(m["parceiro"]["uid"]) == carros[1].uid, "a dupla: o segundo piloto no carro da ARENA 2")
	var rival: String = m["participantes"][2]["id"]
	verificar(String(m["nomes"][rival]) != "", "rival com nome de piloto")
	verificar(m["faixas"].has(rival), "rival nas cores da equipe")
	j.arena = {"nivel": 3}
	igual(ArenaCarreira.montar(d, j, uid, 7)["participantes"].size(), 10, "nível 4: 2×2×2×2×2, dez carros")
	j.arena = {"nivel": 50}
	igual(ArenaCarreira.montar(d, j, uid, 7)["participantes"].size(), 20, "no máximo 20 carros")
	j.arena = {}
	# Derrota forçada: o carro do jogador eliminado.
	var res := {"classificacao": ["r1", "jogador"], "eventos": [
			{"t": 1.0, "tipo": "giro", "carro": "r1", "por": "jogador", "graus": 90},
			{"t": 1.2, "tipo": "giro", "carro": "r1", "por": "jogador", "graus": 180}],
		"carros": {"jogador": {"eliminado": true, "eliminou": 0}, "r1": {"eliminado": false, "eliminou": 1}}}
	var pts := ArenaCarreira.pontos(res, "jogador", d.arena())
	igual(pts, int(d.arena()["pontos"]["giro_180"]), "giro conta pelo maior limite do golpe")
	var saldo: int = j.economia.saldo
	var f := ArenaCarreira.aplicar(d, j, uid, res)
	verificar(f["perdeu"], "eliminado: perdeu")
	igual(j.garagem.lista().size(), 2, "o carro saiu da garagem")
	igual(Escalacao.uid(j, "arena1"), -1, "e a vaga ficou vazia")
	verificar(j.carro_ativo != uid and j.carro_ativo >= 0, "outro carro em uso")
	igual(j.economia.saldo, saldo + f["premio"], "pontos pagos mesmo perdendo")
	igual(int(j.arena["lutas"]), 1, "luta registrada")
	igual(ArenaCarreira.nivel(j), 0, "perdeu: o campeonato não sobe")
	var vit := {"classificacao": ["jogador", "r1"], "eventos": [], "equipe_vencedora": "jogador",
		"carros": {"jogador": {"eliminado": false, "eliminou": 1, "equipe": "jogador"}, "r1": {"eliminado": true, "eliminou": 0, "equipe": "x"}}}
	var f2 := ArenaCarreira.aplicar(d, j, j.carro_ativo, vit)
	verificar(f2["venceu_equipe"] and f2["subiu_nivel"], "dupla de pé: sobe")
	igual(ArenaCarreira.nivel(j), 1, "próximo campeonato: 2×2×2")
	verificar("3 carros" in ArenaCarreira.bloqueio(d, j), "sobraram 2 carros: não entra mais")
	j.free()
	d.free()


func test_colegas_de_dupla_nao_se_miram_e_a_luta_acaba_com_uma_equipe() -> void:
	var p := _params()
	var lista := []
	for k in 4:
		var c := _carro("c%d" % k, 1200.0, 160.0, Vector2.from_angle(TAU * k / 4.0) * 25.0, TAU * k / 4.0 + PI)
		c.erase("acelerador")
		c["equipe"] = "A" if k < 2 else "B"
		lista.append(c)
	var r := Arena.correr(lista, p, 3, false)
	var vivos: Array = r["carros"].keys().filter(func(id): return not r["carros"][id]["eliminado"])
	var equipes := {}
	for id in vivos:
		equipes[r["carros"][id]["equipe"]] = true
	verificar(equipes.size() <= 1, "acaba com uma equipe de pé")
	verificar(String(r["equipe_vencedora"]) in ["A", "B"], "equipe vencedora")


func test_chao_irregular_puxa_morro_abaixo_e_formas_seguram_os_carros() -> void:
	var p := _params()
	var forma := {"id": "teste", "muro": [[40, -40], [40, 40], [-40, 40], [-40, -40]],
			"obstaculos": [{"c": [0, 20], "r": 4.0}], "relevo": [{"c": [0, 0], "r": 30.0, "h": -4.0}]}
	p["forma"] = forma
	p["tempo_max_s"] = 3.0
	# O mesmo arranque descendo a encosta da cratera anda mais que no plano.
	var plano := p.duplicate()
	plano["forma"] = forma.duplicate()
	plano["forma"]["relevo"] = []
	var anda := func(params: Dictionary) -> float:
		var desce := _carro("desce", 1200.0, 120.0, Vector2(22, 0), PI, Vector2.ZERO, 0.5)
		var longe := _carro("longe", 1200.0, 120.0, Vector2(-30, -30), 0.0, Vector2.ZERO, 0.0)
		var rr := Arena.correr([desce, longe], params, 1, true)
		return 22.0 - float(rr["amostras"][-1]["desce"]["pos"].x)
	var com: float = anda.call(p)
	var sem: float = anda.call(plano)
	verificar(com > sem + 0.5, "descendo anda mais (%.1f m contra %.1f m no plano)" % [com, sem])
	var r: Dictionary
	# Acelerando contra a ilha e contra o muro: não atravessa nenhum.
	p["tempo_max_s"] = 6.0
	var ilha := _carro("ilha", 1200.0, 200.0, Vector2(0, 8), PI / 2.0, Vector2.ZERO, 1.0)
	var muro := _carro("muro", 1200.0, 200.0, Vector2(20, -20), 0.0, Vector2.ZERO, 1.0)
	r = Arena.correr([ilha, muro], p, 1, true)
	var fim: Dictionary = r["amostras"][-1]
	verificar((fim["ilha"]["pos"] - Vector2(0, 20)).length() >= 4.0, "não entra na ilha")
	verificar(fim["muro"]["pos"].x <= 40.0, "não passa do muro em polígono")
	# Largada: dentro do polígono, perto do muro, fora das ilhas.
	var f := ArenaForma.de(p)
	for k in 8:
		var q := f.largada(TAU * k / 8.0, 0.85)
		verificar(f.dentro(q) and f.obstaculo_perto(q)[0] > 0.0, "largada %d dentro e fora da ilha" % k)


## Decisão 78: o chão em curvas de nível (vala, rampa, platô) e o modo que
## assenta por cima sem apagar o resto.
func test_terreno_vala_rampa_plato() -> void:
	var p := _params()
	p["forma"] = {"id": "t", "muro": [[60, -60], [60, 60], [-60, 60], [-60, -60]], "obstaculos": [], "relevo": [
			{"tipo": "vala", "a": [-20, -30], "b": [20, -30], "largura": 8, "fundo": 4, "h": -2.0},
			{"tipo": "rampa", "a": [-30, 0], "b": [-20, 0], "largura": 6, "h": 2.0, "queda": 3},
			{"tipo": "plato", "pontos": [[10, 10], [30, 10], [30, 30], [10, 30]], "encosta": 3, "h": 3.0, "max": true},
			{"tipo": "rampa", "a": [20, -5], "b": [20, 10], "largura": 6, "h": 3.0, "max": true}]}
	var f := ArenaForma.de(p)
	perto(f.altura(Vector2(0, -30)), -2.0, 1e-6, "fundo da vala")
	perto(f.altura(Vector2(0, -31.9)), -2.0, 1e-6, "fundo plano da vala")
	perto(f.altura(Vector2(0, -40)), 0.0, 1e-6, "fora da vala")
	perto(f.altura(Vector2(-25, 0)), 1.0, 1e-6, "meio da rampa")
	perto(f.altura(Vector2(-20, 0)), 2.0, 1e-6, "crista da rampa")
	perto(f.altura(Vector2(-16, 0)), 0.0, 1e-6, "depois da queda")
	perto(f.altura(Vector2(20, 20)), 3.0, 1e-6, "topo plano do platô")
	perto(f.altura(Vector2(20, 2.5)), 1.5, 1e-6, "rampa até o platô sem somar")
	perto(f.altura(Vector2(0, -30)), -2.0, 1e-6, "o platô por cima não apaga a vala")
	verificar(f.gradiente(Vector2(-25, 0)).x > 0.15, "a rampa inclina o chão")


## Pedido do usuário: na subida o carro perde embalo (gravidade e motor
## rendendo menos), na descida ganha.
func test_subida_freia_e_descida_embala() -> void:
	var p := _params()
	p["tempo_max_s"] = 3.0
	var rampa := {"id": "r", "muro": [[60, -60], [60, 60], [-60, 60], [-60, -60]], "obstaculos": [],
			"relevo": [{"tipo": "rampa", "a": [-40, 0], "b": [40, 0], "largura": 30, "h": 16.0, "queda": 3}]}
	var anda := func(forma: Dictionary, rumo: float, perda: float) -> float:
		var q := p.duplicate()
		q["forma"] = forma
		q["subida_perda"] = perda
		var x0 := -20.0 if rumo == 0.0 else 20.0
		var c := _carro("c", 1200.0, 120.0, Vector2(x0, 0), rumo, Vector2.ZERO, 1.0)
		var longe := _carro("longe", 1200.0, 120.0, Vector2(-50, -50), 0.0, Vector2.ZERO, 0.0)
		var rr := Arena.correr([c, longe], q, 1, true)
		return absf(float(rr["amostras"][-1]["c"]["pos"].x) - x0)
	var plano := rampa.duplicate()
	plano["relevo"] = []
	var no_plano: float = anda.call(plano, 0.0, 0.5)
	var subindo: float = anda.call(rampa, 0.0, 0.5)
	var subindo_so_gravidade: float = anda.call(rampa, 0.0, 0.0)
	var descendo: float = anda.call(rampa, PI, 0.5)
	verificar(subindo < no_plano * 0.85, "subindo anda menos (%.1f m contra %.1f m no plano)" % [subindo, no_plano])
	verificar(subindo < subindo_so_gravidade, "o motor rende menos na subida (%.1f contra %.1f m)" % [subindo, subindo_so_gravidade])
	verificar(descendo > no_plano, "descendo anda mais (%.1f m)" % descendo)


func test_arenas_do_jogo_tem_a_area_do_circulo() -> void:
	var p := _params()
	var alvo := PI * pow(float(p["raio_m"]), 2.0)
	igual(p["arenas"].size(), 10, "dez arenas: seis do campeonato e quatro do Grid")
	igual(p["arenas"].filter(func(a): return a.get("grid", false)).size(), 4, "quatro só do Grid")
	for a in p["arenas"]:
		var q := p.duplicate()
		q["forma"] = a
		perto(ArenaForma.de(q).area(), alvo, alvo * 0.01, "%s com a área do círculo" % a["id"])


## Blindagem (pedido do usuário): espelho da redução de peso do próprio carro;
## quem não tem redução usa o fator mais comum e a razão mediana de preço.
func test_blindagem_espelha_a_reducao_de_peso() -> void:
	var lw := func(carro: String, k: int, f: float, preco: int) -> Dictionary:
		return {"id": "%s_lightweight_%d" % [carro, k], "nome": "x", "categoria": "lightweight", "preco": preco,
				"carros_permitidos": [carro], "efeitos": [{"atributo": "peso", "op": "mult", "valor": f}]}
	var pecas := [lw.call("a", 1, 0.95, 100), lw.call("a", 2, 0.92, 400), lw.call("a", 3, 0.89, 1000)]
	var carros := [{"id": "a", "preco": 10000}, {"id": "b", "preco": 20000}]
	var cfg := {"referencia": "lightweight", "niveis": 3, "nomes": ["Leve", "Média", "Pesada"]}
	var r := Blindagem.gerar(pecas, carros, cfg)
	igual(r.size(), 6, "três níveis por carro")
	var a3: Dictionary = r.filter(func(p): return p["id"] == Blindagem.id_peca("a", 3))[0]
	perto(float(a3["efeitos"][0]["valor"]), 1.0 / 0.89, 1e-9, "pesa o inverso do estágio 3")
	igual(int(a3["preco"]), 1000, "custa o mesmo que o estágio")
	igual(String(a3["nome"]), "Pesada", "nome do nível")
	var b2: Dictionary = r.filter(func(p): return p["id"] == Blindagem.id_peca("b", 2))[0]
	perto(float(b2["efeitos"][0]["valor"]), 1.0 / 0.92, 1e-9, "sem redução: fator mais comum")
	igual(int(b2["preco"]), 800, "sem redução: razão de preço (400/10000) sobre o preço do carro")
	igual(Blindagem.gerar(pecas, carros, {}), [], "sem regra, sem blindagem")


func test_blindagem_pesa_no_carro_e_some_do_mecanico() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var base: Dictionary = d.lista("carros")[0]
	var c := Carro.new(base)
	c.adicionar_pneu(d.pneu(d.economia()["pneu_de_fabrica"]))
	var itens := Blindagem.itens(d, c)
	igual(itens.size(), 3, "três níveis à venda")
	var antes := float(c.atributos_efetivos("seco")["peso"])
	verificar(c.instalar(itens[2]), "instala a pesada")
	igual(Blindagem.nivel(c), 3, "nível em uso")
	verificar(float(c.atributos_efetivos("seco")["peso"]) > antes, "mais pesado")
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000000)
	var e_blindagem := func(o: Dictionary) -> bool: return o["tipo"] == "peca" and o["item"]["categoria"] == Blindagem.CATEGORIA
	verificar(not Mecanico.candidatas(d, j, c).any(e_blindagem), "o mecânico da corrida não sugere blindagem")
	j.free()
	d.free()


## Cada loja citada pelas cenas existe, e cada falante existe em personagens.json.
func test_cenas_novas_apontam_para_lojas_e_personagens() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var lojas: Array = d.workshops().map(func(w): return w["id"])
	for c in d.lista("dialogos"):
		if String(c["trigger"]).begins_with("LOJA:"):
			verificar(String(c["trigger"]).trim_prefix("LOJA:") in lojas, "loja de %s existe" % c["id"])
		for f in c["falas"]:
			if f.has("quem"):
				verificar(d.existe("personagens", f["quem"]), "%s: %s em personagens.json" % [c["id"], f["quem"]])
	for p in ["examinador", "manobrista", "mecanico_arena", "organizadora", "pintor", "vendedor_charge_folio",
			"vendedor_relay_room", "vendedora_brace_yard", "vendedora_return_chapter", "vendedora_shared_grid"]:
		verificar(Assets.get_asset(p, "retrato") != null and Assets.get_asset(p, "corpo") != null, "arte de " + p)
	d.free()


## Identidades das equipes (pacote do usuário): rival com logo, número da vaga
## na família da equipe; nome e logo do jogador independentes.
func test_identidade_das_equipes() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var eq: Dictionary = d.item("equipes", "eq06_redline_union")
	igual(String(eq["nome"]), "Redline Union", "nome da equipe")
	verificar(ResourceLoader.exists(String(eq["logo"])), "logo da equipe existe")
	var f := PinturaCarro.da_equipe(eq, "x", 2)
	igual(int(f["numero"]), int(eq["numero"]) * 4 - 3 + 2, "número pela vaga do piloto")
	igual(String(f["fonte_numero"]), String(eq["fonte_numero"]), "família do número da equipe")
	igual(String(f["logo"]), String(eq["logo"]), "logo da equipe no carro")
	igual(PinturaCarro.da_equipe(eq, "x").has("numero"), false, "sem vaga, sem número")
	var emblemas := 0
	for e in d.lista("equipes"):
		if String(e.get("logo", "")).contains("/emblemas/"):
			emblemas += 1
			verificar(ResourceLoader.exists(String(e["logo"])), "logo de %s" % e["id"])
	igual(emblemas, 10, "as dez identidades novas")
	igual(IdentidadeEquipe.opcoes().size(), 10, "dez logos para o jogador")
	for o in IdentidadeEquipe.opcoes():
		verificar(ResourceLoader.exists(String(o["arquivo"])), "logo %s" % o["id"])
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.personagem = "dono"
	igual(IdentidadeEquipe.nome(d, j), "Wreckage Motorsport", "nome padrão")
	IdentidadeEquipe.definir(j, "  Oficina da Esquina  ", "03_wheel_sprint")
	igual(IdentidadeEquipe.nome(d, j), "Oficina da Esquina", "nome livre")
	IdentidadeEquipe.definir(j, "Outro Nome", "03_wheel_sprint")
	igual(IdentidadeEquipe.logo(j), "03_wheel_sprint", "trocar o nome mantém o logo")
	IdentidadeEquipe.definir(j, "Outro Nome", "09_forge_bolt")
	igual(IdentidadeEquipe.nome(d, j), "Outro Nome", "trocar o logo mantém o nome")
	var s := Save.serializar(j)
	var k: Node = JogadorScript.new()
	k.novo_jogo(d.economia(), d.pneu)
	igual(Save.desserializar(JSON.parse_string(JSON.stringify(s)), k, d), "", "load")
	igual(k.identidade, j.identidade, "identidade volta do save")
	j.free()
	k.free()
	d.free()



## The Grid: uma por vez, da #10 à #1; só a da vez conta.
func test_the_grid_sobe_uma_por_vez() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	var lista := TheGrid.equipes(d)
	igual(lista.size(), 10, "dez equipes no Grid")
	igual(int(lista[0]["grid"]), 10, "começa na #10")
	igual(TheGrid.posicao(d, j), 0, "fora do Grid")
	var dez: Dictionary = lista[0]
	var nove: Dictionary = lista[1]
	igual(TheGrid.registrar(d, j, [nove["id"]]), {}, "vencer a #9 antes da #10 não conta")
	igual(TheGrid.registrar(d, j, [dez["id"], "outra"])["id"], dez["id"], "venceu a da vez")
	igual(TheGrid.posicao(d, j), 10, "agora é a #10")
	igual(TheGrid.da_vez(d, j)["id"], nove["id"], "a próxima é a #9")
	for e in lista.slice(1):
		TheGrid.registrar(d, j, [e["id"]])
	igual(TheGrid.posicao(d, j), 1, "topo do Grid")
	igual(TheGrid.da_vez(d, j), {}, "ninguém acima")
	j.free()
	d.free()


## Arena: o carro perdido e os rivais que a dupla elimina viram peças.
func test_arena_rende_pecas() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000000)
	var base: Dictionary = d.lista("carros")[0]
	var uid: int = j.concessionaria.comprar_carro(base)
	j.concessionaria.comprar_carro(base)
	var rival: Dictionary = d.lista("carros")[1]
	var resultado := {"classificacao": ["r1", "jogador"], "equipe_vencedora": "x", "eventos": [],
			"carros": {"jogador": {"eliminado": true, "por": "r1", "equipe": "jogador", "eliminou": 1},
			"r1": {"eliminado": false, "por": "", "equipe": "x"},
			"r2": {"eliminado": true, "por": "jogador", "equipe": "x"}}}
	var antes: int = j.economia.credito_pecas
	var esperado_perdido := GestaoEquipe.pecas_do_carro(d, j, j.garagem.carro(uid))
	var esperado_rival := GestaoEquipe.pecas_do_carro(d, j, Carro.new(rival))
	var f := ArenaCarreira.aplicar(d, j, uid, resultado, -1, {"r1": rival, "r2": rival})
	igual(int(f["pecas_perdidos"]), esperado_perdido, "o carro perdido vira peças")
	igual(int(f["pecas_destruidos"]), esperado_rival, "só o rival eliminado pela dupla vira peças")
	igual(j.economia.credito_pecas, antes + esperado_perdido + esperado_rival, "as peças entram no estoque")
	j.free()
	d.free()


func test_simulacao_fixa_o_numero_de_equipes() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000000)
	var uid: int = j.concessionaria.comprar_carro(d.lista("carros")[0])
	var c: Dictionary = d.arena()["campeonato"]
	for n in [int(c["equipes_min"]), 7, int(c["equipes_max"])]:
		var m := ArenaCarreira.montar(d, j, uid, 99, n)
		igual(m["participantes"].size(), n * 2, "%d equipes = %d carros" % [n, n * 2])
	igual(ArenaCarreira.montar(d, j, uid, 99, 50)["participantes"].size(), int(c["equipes_max"]) * 2, "acima do máximo, o máximo")
	j.free()
	d.free()


func test_the_grid_risca_e_apresenta_uma_vez() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	var lista: Array = TheGrid.equipes(d)
	igual(TheGrid.ficha_pendente(d, j), String(lista[0]["id"]), "entrada no Grid: a ficha da #10")
	TheGrid.marcar_vista(j, String(lista[0]["id"]))
	igual(TheGrid.ficha_pendente(d, j), "", "vista não volta")
	igual(TheGrid.riscar_pendente(j), "", "nada a riscar sem vitória")
	TheGrid.registrar(d, j, [String(lista[1]["id"])])
	igual(TheGrid.riscar_pendente(j), "", "vencer outra que não a da vez não risca")
	TheGrid.registrar(d, j, [String(lista[0]["id"])])
	igual(TheGrid.riscar_pendente(j), String(lista[0]["id"]), "a vencida fica para riscar")
	igual(TheGrid.ficha_pendente(d, j), String(lista[1]["id"]), "e a próxima para apresentar")
	TheGrid.riscada(j)
	igual(TheGrid.riscar_pendente(j), "", "riscada uma vez")
	for e in lista.slice(1):
		TheGrid.registrar(d, j, [String(e["id"])])
	igual(TheGrid.ficha_pendente(d, j), "fim", "Grid vencido: a ficha do fim, não uma #0")
	TheGrid.marcar_vista(j, "fim")
	igual(TheGrid.ficha_pendente(d, j), "", "o fim também só uma vez")
	j.free()
	d.free()


## Decisão 74: cada posição do Grid tem o seu desafio (grid_desafios.json).
func test_desafios_do_grid() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var lista := TheGrid.equipes(d)
	var dez: Dictionary = lista[0]
	var tres: Dictionary = lista[7]
	var d10 := GridDesafio.de(d, dez)
	igual([d10["modo"], d10["pista"], int(d10["voltas"])], ["corrida", "pista_de_testes", 2], "#10: pista 1, 2 voltas")
	var d3 := GridDesafio.de(d, tres)
	igual([d3["modo"], d3["arena"], d3["rounds"], d3["carros_min"]], ["arena", "bacia_blackwater", 3, 6], "#3: arena 3, MD3, 6 carros")
	igual(GridDesafio.de(d, lista[9])["arena"], "claustro_vazio", "#1: o confronto")
	# A prova do desafio: 1x1 contra o carro especial, com a licença da equipe.
	var ev: Dictionary = d.evento(GridDesafio.PREFIXO + String(dez["id"]))
	igual(ev["adversarios"].size(), 1, "1x1")
	igual(ev["restricoes"]["licenca"], dez["nivel"], "pede a licença da equipe")
	igual(ev["adversarios"][0]["carro"], GridDesafio.especiais(d, dez, 1)[0]["carro"], "o carro especial")
	var esp := GridDesafio.especiais(d, tres, 2)
	verificar(esp.size() == 2 and esp[0]["carro"] != esp[1]["carro"], "arena: dois especiais diferentes")
	# Bloqueios: só a da vez, com a licença.
	var j := _jogador_real(d, 1)
	verificar("da vez" in GridDesafio.bloqueio(d, j, lista[1]), "só a da vez")
	verificar("Licença" in GridDesafio.bloqueio(d, j, dez), "sem a licença")
	j.licencas.append(String(dez["nivel"]))
	Escalacao.migrar(j)
	igual(GridDesafio.bloqueio(d, j, dez), "", "com licença, piloto-base e carro: pode")
	# A escalação do desafio: a equipe com o piloto de corrida dela.
	var esc := GridDesafio.escalacao(d, j, ev)
	igual(esc[0]["equipe"]["id"], dez["id"], "a equipe desafiada no grid")
	# A corrida do desafio roda e, vencida, deixa a equipe para trás.
	var car := Carreira.new(d, j)
	var c: Dictionary = car.preparar(ev["id"], Escalacao.uid(j, "corrida"), 3, false)
	verificar(not c.has("erro"), "o desafio corre: %s" % c.get("erro", ""))
	igual(c["resultado"]["classificacao"].size(), 2, "só os dois carros")
	c["resultado"]["classificacao"] = ["jogador"] + c["resultado"]["classificacao"].filter(func(x): return x != "jogador")
	igual(car.aplicar(c)["grid"].get("id"), dez["id"], "vencido o desafio, a #10 fica para trás")
	igual(TheGrid.posicao(d, j), 10, "agora a #10")
	j.free()
	# Arena MD3: pede 6 carros fora o de corrida; a série acaba em 2 vitórias.
	j = _jogador_real(d, 7)
	for e in lista.slice(0, 7):
		TheGrid.registrar(d, j, [e["id"]])
	igual(TheGrid.da_vez(d, j)["id"], tres["id"], "a #3 é a da vez")
	j.licencas.append(String(tres["nivel"]))
	j.flags[EquipeJogador.FLAG_ARENA] = true
	j.pilotos = {"corrida": "", "arena": ["ayla_moreno", "axel_brennan"]}
	Escalacao.migrar(j)
	igual(GridDesafio.bloqueio(d, j, tres), "", "7 carros: 1 de corrida e 6 para a arena")
	var m := GridDesafio.montar_arena(d, j, tres, 7)
	igual(m["participantes"].size(), 4, "2x2")
	igual(m["params"]["forma"]["id"], "bacia_blackwater", "na arena do desafio")
	verificar(ArenaCarreira.arenas_abertas(d, j).all(func(a): return not a.get("grid", false)), "o campeonato não usa as do Grid")
	igual(m["modelos"]["%s:1" % tres["id"]]["id"], esp[0]["carro"], "os carros especiais")
	var r1 := GridDesafio.registrar_round(d, j, tres, true)
	verificar(not r1["fim"], "1 × 0: segue")
	var r2 := GridDesafio.registrar_round(d, j, tres, false)
	verificar(not r2["fim"] and GridDesafio.serie(j)["derrotas"] == 1, "1 × 1: segue")
	var r3 := GridDesafio.registrar_round(d, j, tres, true)
	verificar(r3["fim"] and r3["venceu"], "2 × 1: venceu")
	igual(GridDesafio.serie(j), {}, "série fechada")
	# Pinturas: 6 desenhos e nenhum logo no começo; um de cada por equipe vencida.
	igual(PinturaCarro.liberados(d, j, "padroes", PinturaCarro.PADROES.size()), 13, "7 vencidas: 13 desenhos")
	igual(PinturaCarro.liberados(d, j, "logos", 10), 7, "7 logos")
	igual(PinturaCarro.posicao_que_libera(d, "padroes", 6), 10, "o 7º desenho na #10")
	j.free()
	d.free()


## Pacote de dano: motor destruído pega fogo, o piloto sai e o carro explode,
## com dano em quem está perto e nada em quem está longe.
func test_motor_destruido_pega_fogo_piloto_sai_e_explode() -> void:
	var p := _params()
	p["tempo_max_s"] = 25.0
	var alvo := _carro("alvo", 1200.0, 200.0, Vector2(0, 0), 0.0, Vector2.ZERO, 0.0)
	alvo["dano"] = [0.95, 0.95, 0, 0, 0, 0]
	# Vem de frente na frente do alvo e para perto.
	var bate := _carro("bate", 1200.0, 200.0, Vector2(9, 0), PI, Vector2(-9, 0), 0.0)
	var longe := _carro("longe", 1200.0, 200.0, Vector2(-30, 0), 0.0, Vector2.ZERO, 0.0)
	var r := Arena.correr([alvo, bate, longe], p, 1, true)
	var tipos: Array = r["eventos"].filter(func(e): return e["carro"] == "alvo").map(func(e): return e["tipo"])
	verificar("eliminado" in tipos and "fogo" in tipos and "fuga" in tipos and "explosao" in tipos,
			"eliminado → fogo → fuga → explosão (%s)" % [tipos])
	var t := {}
	for e in r["eventos"]:
		if e["carro"] == "alvo" and not t.has(e["tipo"]):
			t[e["tipo"]] = float(e["t"])
	var inc: Dictionary = p["incendio"]
	verificar(absf(t["fogo"] - t["eliminado"] - float(inc["fogo_s"])) < 0.05, "fogo depois do motor parar")
	verificar(absf(t["fuga"] - t["fogo"] - float(inc["fuga_s"])) < 0.05, "piloto sai depois do fogo")
	verificar(t["explosao"] - t["fuga"] >= float(inc["explosao_s"]) - 0.05, "explode depois da saída")
	var expl: Array = r["eventos"].filter(func(e): return e.get("explosao", false) and e["tipo"] == "impacto")
	verificar(expl.any(func(e): return e["carro"] == "bate"), "quem está perto toma dano da explosão")
	verificar(not expl.any(func(e): return e["carro"] == "longe"), "quem está longe não toma")
	var com_piloto: Array = r["amostras"].filter(func(a): return a.has("pilotos"))
	verificar(not com_piloto.is_empty(), "o piloto aparece nas amostras")


func test_frente_so_de_um_lado_nao_pega_fogo() -> void:
	var p := _params()
	p["tempo_max_s"] = 15.0
	var alvo := _carro("alvo", 1200.0, 200.0, Vector2(0, 0), 0.0, Vector2.ZERO, 0.0)
	alvo["dano"] = [0.95, 0.2, 0, 0, 0, 0]
	var bate := _carro("bate", 1200.0, 200.0, Vector2(9, 0.6), PI, Vector2(-9, 0), 0.0)
	var longe := _carro("longe", 1200.0, 200.0, Vector2(-30, 0), 0.0, Vector2.ZERO, 0.0)
	var r := Arena.correr([alvo, bate, longe], p, 1, false)
	verificar(r["carros"]["alvo"]["eliminado"], "eliminado")
	verificar(not r["eventos"].any(func(e): return e["tipo"] == "fogo"), "só fumaça, sem fogo")


func test_explosao_depois_do_fim_e_so_visual() -> void:
	var p := _params()
	p["tempo_max_s"] = 25.0
	var alvo := _carro("alvo", 1200.0, 200.0, Vector2(0, 0), 0.0, Vector2.ZERO, 0.0)
	alvo["dano"] = [0.95, 0.95, 0, 0, 0, 0]
	var bate := _carro("bate", 1200.0, 200.0, Vector2(9, 0), PI, Vector2(-9, 0), 0.0)
	var r := Arena.correr([alvo, bate], p, 1, true)
	var dano_fim: PackedFloat32Array = r["carros"]["bate"]["dano"].duplicate()
	verificar(float(r["duracao_cena"]) > float(r["duracao"]), "a cena segue depois do fim")
	var ex: Array = r["eventos"].filter(func(e): return e["tipo"] == "explosao")
	verificar(ex.size() == 1 and not ex[0]["valendo"], "explode depois do fim, sem valer")
	igual(r["carros"]["bate"]["dano"], dano_fim, "sem dano depois do fim")
	verificar(r["amostras"][-1]["t"] >= float(r["duracao_cena"]) - 0.01, "amostras até o fim da cena")


func test_piloto_atropelado_cai_levanta_e_sai() -> void:
	var p := _params()
	var forma := ArenaForma.de(p)
	var pf: Dictionary = p["piloto_fuga"]
	var dono := {"id": "dono", "pos": Vector2(-20, 0), "rumo": 0.0, "L": 4.4, "W": 1.75, "vel": Vector2.ZERO,
			"eliminado": true, "piloto": {"pos": Vector2(0, 0), "rumo": 0.0, "estado": "correndo", "t_estado": 0.0,
			"t_fuga": 0.0, "de": Vector2.ZERO, "para": Vector2.ZERO, "voo_s": 0.0}}
	var carro := {"id": "carro", "pos": Vector2(-1.8, 0), "rumo": 0.0, "L": 4.4, "W": 1.75, "vel": Vector2(10, 0),
			"eliminado": false}
	var eventos := []
	var dt := float(p["dt_s"])
	var t := 0.0
	Arena._piloto(dono, [dono, carro], pf, eventos, t, dt, forma, true)
	verificar(dono.get("atropelado", false), "carro andando atropela")
	igual(dono["piloto"]["estado"], "voando", "lançado")
	verificar((dono["piloto"]["para"] as Vector2).x > 0.5, "lançado na direção do carro")
	carro["pos"] = Vector2(30, 30)
	carro["vel"] = Vector2.ZERO
	var estados := []
	while t < 120.0 and dono["piloto"]["estado"] != "fora":
		t += dt
		Arena._piloto(dono, [dono, carro], pf, eventos, t, dt, forma, true)
		if estados.is_empty() or estados[-1] != dono["piloto"]["estado"]:
			estados.append(dono["piloto"]["estado"])
	igual(estados, ["voando", "caido", "levantando", "correndo", "fora"], "voa, cai, levanta, corre e sai")


## Atropelado na fuga: fora pelo tempo do próximo treino do piloto (sem o
## critério, não fica fora); a arena não abre enquanto ele se recupera.
func test_piloto_atropelado_fica_em_recuperacao() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var j := _jogador_real(d, 3)
	j.flags[EquipeJogador.FLAG_ARENA] = true
	j.pilotos = {"corrida": "", "arena": ["ayla_moreno", "axel_brennan"]}
	var carros: Array = j.garagem.lista()
	Escalacao.definir(j, "corrida", carros[2].uid)
	Escalacao.definir(j, "arena1", carros[0].uid)
	Escalacao.definir(j, "arena2", carros[1].uid)
	var res := {"classificacao": ["jogador", "r1"], "eventos": [], "equipe_vencedora": "jogador",
		"carros": {"jogador": {"eliminado": false, "eliminou": 0, "equipe": "jogador", "atropelado": true},
			"r1": {"eliminado": true, "eliminou": 0, "equipe": "x"}}}
	var antes = d.arena().get("recuperacao_atropelo")
	d.arena()["recuperacao_atropelo"] = ""
	var f := ArenaCarreira.aplicar(d, j, carros[0].uid, res)
	igual(f["atropelados"].size(), 1, "o atropelado aparece no resultado")
	igual(ArenaCarreira.recuperacao_s(j, "ayla_moreno"), 0.0, "sem o critério: não fica fora")
	d.arena()["recuperacao_atropelo"] = "treino"
	var esperado := float(GestaoEquipe.cfg_treino(d)["tempo_base_h"]) * 3600.0 * (GestaoEquipe.nivel_treino(j, "ayla_moreno") + 1)
	ArenaCarreira.aplicar(d, j, carros[0].uid, res)
	var falta := ArenaCarreira.recuperacao_s(j, "ayla_moreno")
	verificar(falta > esperado - 100.0 and falta <= esperado, "fora pelo tempo do próximo treino (%.0f de %.0f s)" % [falta, esperado])
	verificar("recupera" in ArenaCarreira.bloqueio(d, j), "a arena espera a recuperação")
	verificar(ArenaCarreira.recuperacao_s(j, "ayla_moreno", Aceleracao.agora(j) + esperado + 1.0) == 0.0, "depois volta")
	d.arena()["recuperacao_atropelo"] = antes
	j.free()
	d.free()


## Capotou (batida de lado forte): fica fora da luta, como no Destruction Derby.
func test_batida_de_lado_forte_capota_e_elimina() -> void:
	var p := _params()
	var r := _lateral(70.0, p)
	var capotou: Array = r["eventos"].filter(func(e): return e["tipo"] == "eliminado" and e.get("capotou", false))
	verificar(not capotou.is_empty() and capotou[0]["carro"] == "alvo" and capotou[0]["por"] == "bate",
			"batida de lado forte capota o atingido e conta para quem bateu")
	var leve := _lateral(15.0, p)
	verificar(not leve["carros"]["alvo"]["eliminado"], "batida leve não capota")


func test_canhao_dagua_empurra_o_rival_de_outra_equipe() -> void:
	var p := _params()
	p["tempo_max_s"] = 6.0
	var pc: Dictionary = p["canhao"]
	perto(float(pc["vazao_kg_s"]) * float(pc["v_ms"]), 1000.0, 1.0, "jato de canhão real: ~1.000 N")
	var parado := func(com: bool) -> Dictionary:
		var cam := _carro("caminhao", 39000.0, 600.0, Vector2(0, 0), 0.0, Vector2.ZERO, 0.0)
		if com:
			cam["canhao"] = true
		# vem rolando na direção do caminhão, sem acelerar: o jato freia
		var alvo := _carro("alvo", 1250.0, 150.0, Vector2(18, 0), PI, Vector2(-5, 0), 0.0)
		return Arena.correr([cam, alvo], p, 1, true)
	var sem: Dictionary = parado.call(false)
	var com: Dictionary = parado.call(true)
	var x_sem: float = sem["amostras"][-1]["alvo"]["pos"].x
	var x_com: float = com["amostras"][-1]["alvo"]["pos"].x
	verificar(x_com > x_sem + 1.0, "o jato empurra contra quem vem (%.2f > %.2f)" % [x_com, x_sem])
	var levou := false
	for a in com["amostras"]:
		levou = levou or String(a["caminhao"].get("jato", "")) == "alvo"
	verificar(levou, "a amostra diz quem leva água (a tela desenha)")
	verificar(not sem["amostras"][-1]["caminhao"].has("jato"), "sem canhão, sem jato")
