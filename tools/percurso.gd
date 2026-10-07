extends RefCounted
## Jogador automático do percurso inicial (usado pelo teste de percurso e por
## tools/percursos_iniciais.gd): com o carro dado, corre as provas sem licença
## em ordem de prêmio, segue o "O que ajuda?" após cada derrota e tenta a
## licença B. O tempo conta só corrida.
## A licença B vem dos contratos (data/contratos.json), que não dependem do carro
## do jogador; aqui "pronto_b" mede se o carro dele já está pronto para as provas
## B: bronze em todos os testes de tempo da B.

const JogadorScript := preload("res://autoload/jogador.gd")


## oferta: item de Usados.estoque() ou {"carro_id", "preco"} de um novo.
## Retorna {log, tempo, pronto_b, ciclo, saldo, vitorias, carro}. Mede só o carro e
## o dinheiro (testes de tempo antigos da B); para progressão e renda por fase,
## use tools/medir_progressao.gd.
static func jogar(d: Node, oferta: Dictionary, limite_s: float) -> Dictionary:
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.carreira = Carreira.new(d, j)
	var log := []
	var tempo := 0.0
	var semente := 0
	var uid: int
	if oferta.has("chave"):
		uid = j.concessionaria.comprar_usado(oferta, d.carro(oferta["carro_id"]), j.usados_vendidos)
	else:
		uid = j.concessionaria.comprar_carro(d.carro(oferta["carro_id"]))
	log.append("comprou %s por %d" % [oferta["carro_id"], oferta["preco"]])
	var sem_licenca: Array = d.lista("eventos").filter(Elegibilidade.aberta_sem_licenca)
	sem_licenca.sort_custom(func(a, b): return a["premios"][0] < b["premios"][0] if a["premios"][0] != b["premios"][0] else a["nome"] < b["nome"])
	var ciclo := false
	for ev in sem_licenca:
		var comprou_aqui := false
		if tempo > limite_s * 0.7:
			break
		for tentativa in 6:
			semente += 1
			var r: Dictionary = j.carreira.disputar(ev["id"], uid, semente)
			if r.has("erro"):
				log.append("%s: não pode correr (%s)" % [ev["nome"], r["erro"]])
				break
			tempo += float(r["resultado"]["duracao"])
			log.append("%s: %dº, +%d (saldo %d, %.0f s)" % [ev["nome"], r["posicao"], r["premio"], j.economia.saldo, tempo])
			if r["posicao"] == 1:
				if comprou_aqui:
					ciclo = true
				break
			var a: Dictionary = Mecanico.analisar(j.carreira, ev["id"], uid, 1)
			if not a["opcoes"].is_empty():
				var o: Dictionary = a["opcoes"][0]
				if o["tipo"] == "peca":
					j.concessionaria.comprar_peca(j.garagem.carro(uid), o["item"])
				else:
					j.concessionaria.comprar_pneu(j.garagem.carro(uid), o["item"])
				comprou_aqui = true
				log.append("  comprou %s por %d (%s -> %s nos testes)" % [o["nome"], o["preco"],
						Mecanico.texto_faixa(a["base"]["faixa"]), Mecanico.texto_faixa(o["faixa"])])
	var licencas := Licencas.new(d, j)
	for lic in d.lista("licencas"):
		if lic["id"] != "B":
			continue
		for t in lic["testes"]:
			for tentativa in 3:
				semente += 1
				var r := licencas.fazer_teste("B", t["id"], uid, semente)
				if r.has("erro"):
					log.append("teste %s: %s" % [t["id"], r["erro"]])
					break
				tempo += float(r["tempo"])
				log.append("teste %s: %.2f s %s" % [t["id"], r["tempo"], r["grau"] if r["grau"] != "" else "reprovado"])
				if r["grau"] != "":
					break
	var vitorias := 0
	for k in j.vitorias:
		vitorias += int(j.vitorias[k])
	var res := {"log": log, "tempo": tempo, "pronto_b": _testes_b(d, j), "ciclo": ciclo,
			"saldo": j.economia.saldo, "vitorias": vitorias, "carro": j.garagem.carro(uid).copiar()}
	j.free()
	return res


static func _testes_b(d: Node, j: Node) -> bool:
	return d.item("licencas", "B")["testes"].all(func(t): return j.graus_licenca.has(t["id"]))
