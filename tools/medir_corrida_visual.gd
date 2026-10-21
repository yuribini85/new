extends SceneTree
## Mede na tela da corrida (Corrida3D, só visual) os defeitos do segundo teste
## com pessoas (docs/plano_acao_testes_2.md, itens 2 e 3), em provas reais:
##   sobreposição  quadros em que dois carros ocupam o mesmo lugar (retângulos
##                 dos carros se cruzando: menos de um comprimento na pista e
##                 menos de uma largura de lado)
##   fora          quadros com o centro do carro além da zebra (roda fora dela)
##   rumo          ângulo entre a frente do carro e a direção em que ele anda
##                 (média e pior, em graus), fora das batidas
## Uso: godot --headless --path . -s tools/medir_corrida_visual.gd [-- provas=6 cenario=carro_3d]

const FPS := 30.0
## Segundos medidos de cada prova (as provas longas repetem as mesmas voltas).
const SEGUNDOS := 240.0
const COMPRIMENTO_M := 4.2
const LARGURA_M := 1.75


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var args := {"provas": "6", "cenario": "carro_3d"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var r := medir(root, String(args["cenario"]), int(args["provas"]))
	print(r)
	quit()


## {quadros, sobreposicao, fora, rumo_medio, rumo_pior, por_prova}.
static func medir(raiz: Node, cenario: String, provas: int) -> Dictionary:
	var d: Node = raiz.get_node("Dados")
	var j: Node = raiz.get_node("Jogador")
	raiz.get_node("SaveManager").caminho = "user://save_medir_corrida_visual.json"
	Cenarios.montar(d, j, cenario)
	var carro: Carro = j.garagem.carro(j.carro_ativo)
	var tot := {"quadros": 0, "sobreposicao": 0, "fora": 0, "rumo_soma": 0.0, "rumo_n": 0, "rumo_pior": 0.0,
			"por_prova": {}}
	var feitas := 0
	for ev in d.lista("eventos"):
		if feitas >= provas:
			break
		var prep: Dictionary = j.carreira.preparar(ev["id"], carro.uid, 7, true)
		if prep.has("erro"):
			continue
		var res: Dictionary = prep["resultado"]
		if res["classificacao"].size() < 4:
			continue
		feitas += 1
		var pista: Pista = d.pista(d.evento(ev["id"])["pista"])
		var m := _uma(raiz, pista, res)
		tot["por_prova"][ev["id"]] = m
		for k in ["quadros", "sobreposicao", "fora", "rumo_soma", "rumo_n"]:
			tot[k] += m[k]
		tot["rumo_pior"] = maxf(tot["rumo_pior"], m["rumo_pior"])
	tot["rumo_medio"] = tot["rumo_soma"] / maxf(tot["rumo_n"], 1.0)
	return tot


static func _uma(raiz: Node, pista: Pista, res: Dictionary) -> Dictionary:
	var fonte := CorridaVisual.new()
	var v3 := Corrida3D.new()
	v3.size = Vector2(360, 640)
	raiz.add_child(v3)
	fonte.mostrar(pista, res)
	v3.mostrar(pista, fonte, {})
	var m := {"quadros": 0, "sobreposicao": 0, "fora": 0, "rumo_soma": 0.0, "rumo_n": 0, "rumo_pior": 0.0}
	var erros := PackedFloat32Array()
	var quando := []
	var dt := 1.0 / FPS
	var antes := {}
	var fim := fonte.duracao()
	while fonte.tempo < minf(fim - 1.0, SEGUNDOS):
		fonte.tempo += dt
		v3.atualizar(dt)
		m["quadros"] += 1
		var ids: Array = v3._carros.keys()
		var pos := {}
		for id in ids:
			var c: Node3D = v3._carros[id]
			pos[id] = Vector2(c.position.x, -c.position.z)
			if absf(float(v3._lateral[id])) > Corrida3D.LARGURA_PISTA_M * 0.5 + 1.2 - LARGURA_M * 0.5:
				m["fora"] += 1
			# Rumo: a frente (rotation.y) contra o deslocamento do quadro.
			if antes.has(id) and fonte.tempo > 6.0 and float(v3._tranco.get(id, 0.0)) <= 0.0 \
					and absf(float(v3._giro_batida.get(id, 0.0))) < 0.01:
				var mov: Vector2 = pos[id] - antes[id]
				if mov.length() > 0.3:
					var erro := absf(rad_to_deg(angle_difference(mov.angle(), c.rotation.y)))
					m["rumo_soma"] += erro
					m["rumo_n"] += 1
					m["rumo_pior"] = maxf(m["rumo_pior"], erro)
					erros.append(erro)
					if erro > 15.0 and OS.has_environment("MEDIR_DBG"):
						print("rumo %.0f %s t=%.1f lat=%.2f off=%.2f" % [erro, id, fonte.tempo, v3._lateral[id], v3._off[id]])
		# Sobreposição: retângulos orientados dos dois carros se cruzando.
		for a in ids.size():
			for b in range(a + 1, ids.size()):
				var ca: Node3D = v3._carros[ids[a]]
				var cb: Node3D = v3._carros[ids[b]]
				if _cruzam(pos[ids[a]], ca.rotation.y, pos[ids[b]], cb.rotation.y):
					m["sobreposicao"] += 1
					quando.append(snappedf(fonte.tempo, 1.0))
		antes = pos
	v3.free()
	fonte.free()
	erros.sort()
	if erros.size() > 0:
		m["rumo_p95"] = erros[int(erros.size() * 0.95)]
		m["rumo_p99"] = erros[int(erros.size() * 0.99)]
	if OS.has_environment("MEDIR_DBG"):
		print("sobreposição em t=", quando)
	return m


## Dois retângulos COMPRIMENTO_M x LARGURA_M (centro, ângulo) se cruzam (eixos separadores).
static func _cruzam(pa: Vector2, aa: float, pb: Vector2, ab: float) -> bool:
	if pa.distance_to(pb) > COMPRIMENTO_M:
		return false
	var eixos := [Vector2.from_angle(aa), Vector2.from_angle(aa + PI / 2.0), Vector2.from_angle(ab),
			Vector2.from_angle(ab + PI / 2.0)]
	for e in eixos:
		var ra := _projecao(e, aa)
		var rb := _projecao(e, ab)
		if absf((pb - pa).dot(e)) > ra + rb:
			return false
	return true


static func _projecao(e: Vector2, ang: float) -> float:
	return absf(e.dot(Vector2.from_angle(ang))) * COMPRIMENTO_M * 0.5 \
			+ absf(e.dot(Vector2.from_angle(ang + PI / 2.0))) * LARGURA_M * 0.5
