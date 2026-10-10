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
	igual(impactos.size(), 1, "um contato, um dano")


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
