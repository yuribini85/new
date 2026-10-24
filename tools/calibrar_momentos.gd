extends SceneTree
## Calibra os momentos de decisão (decisão 117, data/simulacao.json "momentos").
## Critério: uma corrida inteira bem decidida rende mais ou menos o mesmo que
## uma peça a mais no carro ("ajuda, não decide"). Mede, nas provas que o carro
## do cenário pode correr, a posição média:
##   base     sem decisões
##   melhor   em cada momento, a melhor das duas escolhas (refaz a corrida com cada)
##   curta    sempre a escolha imediata (atacar/defender)
##   longa    sempre a de efeito longo (esperar/poupar)
##   peça     sem decisões, com a peça mais barata que o carro aceita
## Uso: godot --headless --path . -s tools/calibrar_momentos.gd [-- sementes=20 cenario=carro_3d provas=6]

var d: Node
var j: Node
var p: Dictionary


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var args := {"sementes": "20", "cenario": "carro_3d", "provas": "6"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	d = root.get_node("Dados")
	j = root.get_node("Jogador")
	root.get_node("SaveManager").caminho = "user://save_calibrar_momentos.json"
	Cenarios.montar(d, j, String(args["cenario"]))
	p = d.simulacao()["momentos"]
	var carro: Carro = j.garagem.carro(j.carro_ativo)
	var com_peca := _com_peca(carro)
	# Só provas disputadas: na média de 4 corridas o carro não vence nem fica em
	# último sempre (onde uma peça ou uma decisão podem mudar a posição).
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
	var soma := {"base": 0.0, "melhor": 0.0, "curta": 0.0, "longa": 0.0, "peca": 0.0}
	var vit := {"base": 0, "melhor": 0, "curta": 0, "longa": 0, "peca": 0}
	var momentos := 0
	var n := 0
	for ev_id in provas:
		for k in int(args["sementes"]):
			var semente := 1000 + k
			var r := {
				"base": _jogar(ev_id, carro, semente, "nenhuma"),
				"melhor": _jogar(ev_id, carro, semente, "melhor"),
				"curta": _jogar(ev_id, carro, semente, "curta"),
				"longa": _jogar(ev_id, carro, semente, "longa"),
				"peca": _jogar(ev_id, com_peca[0], semente, "nenhuma"),
			}
			momentos += int(r["melhor"][1])
			for c in r:
				soma[c] += r[c][0]
				vit[c] += 1 if r[c][0] == 1 else 0
			n += 1
	print("corridas ", n, " · momentos por corrida (melhor) %.2f" % (float(momentos) / maxi(n, 1)))
	for c in soma:
		print("%-7s posição média %.3f  vitórias %5.1f%%  ganho sobre a base %+.3f" % [c, soma[c] / n,
				100.0 * vit[c] / n, (soma["base"] - soma[c]) / n])
	quit()


## [posição final, momentos usados] com a política dada.
func _jogar(ev_id: String, carro: Carro, semente: int, politica: String) -> Array:
	var piloto: Dictionary = EquipeJogador.piloto_do_jogador(d, j).duplicate(true)
	piloto["ordens"] = []
	var res := _correr(ev_id, carro, semente, piloto)
	if politica == "nenhuma":
		return [_posicao(res), 0]
	var t := float(p["inicio_s"])
	var usados := 0
	while usados < int(p["max_por_corrida"]) and t < float(res["duracao"]):
		var m := MomentosCorrida.detectar(res, t, p)
		if m.is_empty():
			t += 0.5
			continue
		var opcoes := MomentosCorrida.escolhas(m["tipo"], p)
		var escolhida := ""
		var melhor_res := {}
		for o in opcoes:
			var id: String = o[0]
			var curta := float(o[1]["atraso_s"]) <= 2.0
			if politica == "curta" and not curta or politica == "longa" and curta:
				continue
			var tentativa: Dictionary = piloto.duplicate(true)
			tentativa["ordens"].append(MomentosCorrida.ordem(id, t, p))
			var r := _correr(ev_id, carro, semente, tentativa)
			if melhor_res.is_empty() or _melhor(r, melhor_res):
				melhor_res = r
				escolhida = id
		piloto["ordens"].append(MomentosCorrida.ordem(escolhida, t, p))
		res = melhor_res
		usados += 1
		t += float(p["intervalo_s"])
	return [_posicao(res), usados]


func _correr(ev_id: String, carro: Carro, semente: int, piloto: Dictionary) -> Dictionary:
	return j.carreira.preparar(ev_id, carro.uid, semente, true, carro, null, piloto)["resultado"]


func _posicao(res: Dictionary) -> int:
	return res["classificacao"].find("jogador") + 1


func _melhor(a: Dictionary, b: Dictionary) -> bool:
	var pa := _posicao(a)
	var pb := _posicao(b)
	if pa != pb:
		return pa < pb
	return float(a["carros"]["jogador"]["tempo_total"]) < float(b["carros"]["jogador"]["tempo_total"])


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
