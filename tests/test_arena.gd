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
	var ids := ["bancroft_sidewinder"]
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
	verificar(ArenaCarreira.bloqueio(d, j).begins_with("Abre com"), "sem a licença: fechada")
	j.licencas = ["CLUB", "SPORT", "NATIONAL"]
	verificar("2 carros" in ArenaCarreira.bloqueio(d, j), "com 1 carro: não entra")
	j.free()
	j = _jogador_real(d, 2)
	j.licencas = ["CLUB", "SPORT", "NATIONAL"]
	igual(ArenaCarreira.bloqueio(d, j), "", "com 2 carros e a licença: entra")
	var uid: int = j.carro_ativo
	var m := ArenaCarreira.montar(d, j, uid, 7)
	igual(m["participantes"].size(), 1 + int(d.arena()["rivais"]), "jogador + rivais")
	verificar(m["nomes"]["r1"] != "", "rival com nome de piloto")
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
	igual(j.garagem.lista().size(), 1, "o carro saiu da garagem")
	verificar(j.carro_ativo != uid and j.carro_ativo >= 0, "outro carro em uso")
	igual(j.economia.saldo, saldo + f["premio"], "pontos pagos mesmo perdendo")
	igual(int(j.arena["lutas"]), 1, "luta registrada")
	verificar("2 carros" in ArenaCarreira.bloqueio(d, j), "sobrou 1 carro: não entra mais")
	j.free()
	d.free()


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


func test_arenas_do_jogo_tem_a_area_do_circulo() -> void:
	var p := _params()
	var alvo := PI * pow(float(p["raio_m"]), 2.0)
	igual(p["arenas"].size(), 4, "quatro arenas")
	for a in p["arenas"]:
		var q := p.duplicate()
		q["forma"] = a
		perto(ArenaForma.de(q).area(), alvo, alvo * 0.01, "%s com a área do círculo" % a["id"])
