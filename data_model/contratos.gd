class_name Contratos
extends RefCounted
## Contratos de certificação do piloto automático (docs/plano_mvp.md, decisão 4).
## A escola empresta o carro e as peças, sem custo. O jogador monta a solução
## (peças da escola e ajuste do câmbio) e envia para avaliação: cada prova é
## uma bancada cronometrada — o carro da escola e cada rival correm sozinhos a
## mesma pista, com o mesmo piloto (o do jogador), na semente fixa da
## bancada. Mesma montagem, mesmo resultado: o que muda o resultado é a
## preparação, não a sorte. Não conta dia nem paga prêmio.
##
## Condições (data/contratos.json, "condicoes"): bronze cumpre o contrato e
## conta para a licença; prata e ouro somam condições explícitas ao bronze.
##   vencer: true          mais rápido que todos os rivais em todas as provas
##   folga_s: x            pelo menos x segundos à frente do rival mais rápido, em cada prova
##   custo_max: n          soma dos preços de tabela das peças escolhidas até n
##   pecas_max: n          no máximo n peças
##   sem_categorias: [..]  nenhuma peça dessas categorias

const GRAUS := ["ouro", "prata", "bronze"]
## Categorias de peça que aumentam a potência (condição "sem_categorias").
const CATEGORIAS_POTENCIA := ["aspiracao", "muffler", "portpolish", "enginebalance", "displacement",
		"computer", "intercooler"]

var dados: Node
var jogador: Node


func _init(dados_: Node, jogador_: Node) -> void:
	dados = dados_
	jogador = jogador_


## Contratos de uma licença, na ordem do arquivo.
static func da_licenca(dados_: Node, licenca_id: String) -> Array:
	return dados_.lista("contratos").filter(func(c): return c["licenca"] == licenca_id)


## Peças que a escola oferece para o carro do contrato: as da lista do
## contrato ou, sem lista, todas as do catálogo que servem nele.
static func pecas_escola(dados_: Node, contrato: Dictionary) -> Array:
	var carro := Carro.new(dados_.carro(contrato["carro"]))
	var ids: Array = contrato.get("pecas_escola", [])
	return dados_.lista("pecas").filter(func(p): return carro.motivo_recusa(p) == "" and (ids.is_empty() or p["id"] in ids))


## Carro da escola com a montagem {pecas: [ids], ajuste_cambio}.
static func carro_montado(dados_: Node, contrato: Dictionary, montagem: Dictionary) -> Carro:
	var c := Carro.new(dados_.carro(contrato["carro"]))
	c.adicionar_pneu(dados_.pneu(dados_.economia()["pneu_de_fabrica"]))
	var permitidas: Array = pecas_escola(dados_, contrato).map(func(p): return p["id"])
	var cfg := {"pecas": Array(montagem.get("pecas", [])).filter(func(x): return x in permitidas),
			"ajuste_cambio": montagem.get("ajuste_cambio", "")}
	return c.com_configuracao(cfg, dados_.peca)


## Avalia sem guardar nada. Retorna {"provas": [{pista, tempo, rivais: [{id,
## nome, tempo}], folga, posicao, diagnostico}], "custo", "n_pecas", "graus":
## {grau: [condições que faltaram]}, "grau"} ("" = não cumpriu o bronze).
static func avaliar(dados_: Node, contrato: Dictionary, montagem: Dictionary, com_diagnostico := true) -> Dictionary:
	var carro := carro_montado(dados_, contrato, montagem)
	var piloto: Dictionary = dados_.piloto(dados_.carreira()["piloto_jogador"])
	var semente := semente_de(contrato)
	var provas := []
	for prova in contrato["provas"]:
		var pista: Pista = dados_.pista(prova["pista"])
		var condicao: String = prova.get("condicao", "seco")
		var meu := _correr(dados_, pista, carro, prova, piloto, semente, com_diagnostico)
		var rivais := []
		var melhor_rival := INF
		var melhor_rival_corrida := {}
		for rv in prova["rivais"]:
			var rc := Carro.new(dados_.carro(rv["carro"]))
			for pid in rv.get("pecas", []):
				rc.instalar(dados_.peca(pid))
			rc.adicionar_pneu(dados_.pneu(dados_.economia()["pneu_de_fabrica"]))
			var r := _correr(dados_, pista, rc, prova, piloto, semente, com_diagnostico)
			rivais.append({"id": rv["carro"], "nome": rc.base["nome"], "tempo": r["tempo"],
					"atributos": rc.atributos_efetivos(condicao)})
			if r["tempo"] < melhor_rival:
				melhor_rival = r["tempo"]
				melhor_rival_corrida = r
		var posicao := 1 + rivais.filter(func(x): return x["tempo"] < meu["tempo"]).size()
		var p := {"pista": prova["pista"], "tempo": meu["tempo"], "rivais": rivais, "folga": melhor_rival - meu["tempo"],
				"posicao": posicao, "atributos": carro.atributos_efetivos(condicao)}
		if com_diagnostico and not melhor_rival_corrida.is_empty():
			p["diagnostico"] = {"curvas": meu["curvas"] - melhor_rival_corrida["curvas"],
					"retas": meu["retas"] - melhor_rival_corrida["retas"]}
		provas.append(p)
	var ids: Array = carro.configuracao()["pecas"]
	var custo := 0
	for pid in ids:
		custo += int(dados_.peca(pid)["preco"])
	var r := {"provas": provas, "custo": custo, "n_pecas": ids.size(), "graus": {}, "grau": ""}
	var cond: Dictionary = contrato["condicoes"]
	var falta_bronze := _faltam(cond.get("bronze", {}), r, carro)
	for g in GRAUS:
		var falta := falta_bronze.duplicate()
		if g != "bronze":
			falta.append_array(_faltam(cond.get(g, {}), r, carro))
		r["graus"][g] = falta
		if falta.is_empty() and r["grau"] == "":
			r["grau"] = g
	return r


## Avalia, guarda o melhor grau e concede a licença quando todos os contratos
## dela têm ao menos bronze. Retorna avaliar() + {"licenca_concedida"}.
func enviar(contrato_id: String, montagem: Dictionary, agora: float = Time.get_unix_time_from_system()) -> Dictionary:
	var contrato: Dictionary = dados.item("contratos", contrato_id)
	if contrato.is_empty():
		return {"erro": "contrato %s não existe" % contrato_id}
	var lic: Dictionary = dados.item("licencas", contrato["licenca"])
	if lic.get("requisito") != null and not lic["requisito"] in jogador.licencas:
		return {"erro": "exige a licença %s" % lic["requisito"]}
	if not Licencas.new(dados, jogador).pode_avaliar(lic["id"], agora):
		return {"erro": "termine o treino da %s antes da avaliação" % lic.get("nome", lic["id"])}
	jogador.montagens[contrato_id] = {"pecas": Array(montagem.get("pecas", [])).duplicate(),
			"ajuste_cambio": String(montagem.get("ajuste_cambio", ""))}
	var r := avaliar(dados, contrato, montagem)
	var grau: String = r["grau"]
	if grau != "":
		var atual: String = jogador.graus_licenca.get(contrato_id, "")
		if atual == "" or GRAUS.find(grau) < GRAUS.find(atual):
			jogador.graus_licenca[contrato_id] = grau
	r["licenca_concedida"] = false
	if not lic["id"] in jogador.licencas and completa(dados, jogador, lic["id"]):
		jogador.licencas.append(lic["id"])
		r["licenca_concedida"] = true
	return r


## Todos os contratos da licença com ao menos bronze.
static func completa(dados_: Node, jogador_: Node, licenca_id: String) -> bool:
	var lista := da_licenca(dados_, licenca_id)
	return not lista.is_empty() and lista.all(func(c): return jogador_.graus_licenca.has(c["id"]))


## Condição em texto curto, para a tela e o diagnóstico.
static func texto_condicao(chave: String, valor: Variant) -> String:
	match chave:
		"vencer":
			return "mais rápido em todas as pistas"
		"folga_s":
			return "%.1f s à frente do rival" % float(valor)
		"custo_max":
			return "peças até %s G" % Aba.dinheiro(int(valor))
		"pecas_max":
			return "até %d peça%s" % [int(valor), "" if int(valor) == 1 else "s"]
		"sem_categorias":
			return "sem peças de potência" if Array(valor) == CATEGORIAS_POTENCIA else "sem peças de " + ", ".join(valor)
	return chave


## Semente da bancada: fixa, a mesma de tools/calibrar_contratos.gd.
const SEMENTE := 1


static func semente_de(_contrato: Dictionary) -> int:
	return SEMENTE


static func _faltam(cond: Dictionary, r: Dictionary, carro: Carro) -> Array:
	var falta := []
	for chave in cond:
		var ok := true
		match chave:
			"vencer":
				ok = r["provas"].all(func(p): return p["folga"] > 0.0)
			"folga_s":
				ok = r["provas"].all(func(p): return p["folga"] >= float(cond[chave]))
			"custo_max":
				ok = r["custo"] <= int(cond[chave])
			"pecas_max":
				ok = r["n_pecas"] <= int(cond[chave])
			"sem_categorias":
				ok = not carro.pecas.keys().any(func(k): return k in cond[chave])
		if not ok:
			falta.append(texto_condicao(chave, cond[chave]))
	return falta


## Corrida sozinho; com diagnóstico, separa o tempo em curvas e retas
## (Diagnostico.sozinho). Sem, só o tempo (mais rápido: sem amostras).
static func _correr(dados_: Node, pista: Pista, carro: Carro, prova: Dictionary, piloto: Dictionary, semente: int,
		com_diagnostico: bool) -> Dictionary:
	var attrs := carro.atributos_efetivos(prova.get("condicao", "seco"))
	if com_diagnostico:
		return Diagnostico.sozinho(dados_, pista, attrs, int(prova["voltas"]), piloto, semente)
	var res := Simulacao.correr(pista, [{"id": "x", "atributos": attrs, "piloto": piloto}], int(prova["voltas"]),
			dados_.simulacao(), semente, false)
	var x: Dictionary = res["carros"]["x"]
	return {"tempo": x["tempo_total"] if x["terminou"] else INF, "curvas": 0.0, "retas": 0.0}
