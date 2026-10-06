extends RefCounted
## Jogador automático por perfil, para medir progressão e renda por fase
## (tools/medir_progressao.gd). Segue as regras do jogo: desafio = prova ainda
## não vencida, uma inscrição; renda = repetir prova já vencida; licença B pelos
## contratos; licença A pelos testes de tempo com o próprio carro.
##
## Perfis:
##   sugestoes  segue o jogo: prova "Para você" (menor prêmio não vencida), a
##              primeira opção do "O que ajuda?", repete a última vencida para
##              juntar dinheiro e faz os contratos depois da primeira vitória.
##   explora    escolhe provas, sugestões e renda ao acaso (semente fixa) e faz
##              os contratos logo no começo.
##   renda      como sugestoes, mas compra a opção de maior ganho por crédito e
##              junta dinheiro na prova vencida de maior Cr por minuto já visto.
##
## Contabilidade: renda bruta (prêmios), gastos (carros, peças, pneus) e saldo,
## por fase (sem licença, B, A). Tempo = só corrida (a fila); decisões, menus e
## contratos não contam tempo aqui: isso vem do playtest de ritmo.

const JogadorScript := preload("res://autoload/jogador.gd")
const PERFIS := ["sugestoes", "explora", "renda"]
## Corridas simuladas por opção ao decidir (menos que o Mecanico do jogo, para
## o agente caber no tempo; a decisão é a mesma ordem de grandeza).
const AMOSTRAS := 4
## Derrotas seguidas numa prova antes de deixá-la de lado com este carro.
const MAX_TENTATIVAS := 4

var d: Node
var j: Node
var perfil: String
var rng := RandomNumberGenerator.new()
var uid := -1
var tempo := 0.0
var semente := 0
var log := []
var compras := []
var fases := {}
var marcos := {}
var _tentativas := {}
var _bloqueadas := {}
var _renda := {}  # evento_id -> {cr, s, n}
var _ultima_vencida := ""
## Prova cuja derrota motivou a última compra (para o marco "ciclo").
var _comprou_para := ""


## "Jogador" com saldo sem fim, só para listar o que existe acima do saldo.
class Rico extends Node:
	var economia := Economia.new(1 << 40)


func _init(dados: Node, perfil_: String, semente_rng: int) -> void:
	d = dados
	perfil = perfil_
	rng.seed = semente_rng
	j = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.carreira = Carreira.new(d, j)


func liberar() -> void:
	j.free()


## Joga a partir da oferta inicial (Usados.estoque() ou {carro_id, preco}) até
## `limite_s` de corrida ou até não ter prova a vencer nem carro que ajude.
func jogar(oferta: Dictionary, limite_s: float) -> Dictionary:
	_comprar_carro(oferta, "carro inicial")
	while tempo < limite_s:
		_talvez_contratos()
		_talvez_licenca_a()
		var ev := _escolher_desafio()
		if ev.is_empty():
			if not _trocar_carro():
				log.append("sem prova a vencer e sem carro que ajude: parou")
				break
			continue
		var r := _correr(ev["id"], "desafio")
		if r.is_empty():
			_bloqueadas[_chave(ev["id"])] = true
			continue
		if r["posicao"] == 1:
			_ultima_vencida = ev["id"]
			if _comprou_para == ev["id"] and not marcos.has("ciclo"):
				marcos["ciclo"] = tempo  # derrota → compra → vitória na mesma prova
			continue
		_tentativas[_chave(ev["id"])] = _tentativas.get(_chave(ev["id"]), 0) + 1
		var alvo := _sugestao(ev["id"])
		if alvo.is_empty() or _tentativas[_chave(ev["id"])] >= MAX_TENTATIVAS:
			_bloqueadas[_chave(ev["id"])] = true
			continue
		if not _juntar(int(alvo["preco"]), alvo["nome"]):
			# Sem prova vencida para render: deixa esta de lado e tenta outra.
			_bloqueadas[_chave(ev["id"])] = true
			continue
		_comprar_item(alvo)
		_comprou_para = ev["id"]
	var com_premio: Array = d.lista("eventos").filter(func(e): return not e["premios"].is_empty())
	return {"perfil": perfil, "tempo": tempo, "marcos": marcos, "fases": fases, "compras": compras, "log": log,
			"vencidas": com_premio.filter(func(e): return j.vitorias.has(e["id"])).size(), "provas": com_premio.size(),
			"carros": j.garagem.lista().size(),
			"saldo": j.economia.saldo, "licencas": j.licencas.duplicate()}


func fase() -> String:
	if "A" in j.licencas:
		return "A"
	if "B" in j.licencas:
		return "B"
	return "sem licença"


func _fase_stats() -> Dictionary:
	return fases.get_or_add(fase(), {"tempo_s": 0.0, "bruto": 0, "gastos": 0, "desafios": 0, "renda_corridas": 0,
			"renda_s": 0.0, "renda_cr": 0})


func _chave(evento_id: String) -> String:
	return "%d:%s" % [uid, evento_id]


func _correr(evento_id: String, tipo: String) -> Dictionary:
	semente += 1
	var r: Dictionary = j.carreira.disputar(evento_id, uid, hash("agente:%s:%d" % [perfil, semente]))
	if r.has("erro"):
		return {}
	var dur: float = r["resultado"]["duracao"]
	tempo += dur
	var f := _fase_stats()
	f["tempo_s"] += dur
	f["bruto"] += int(r["premio"])
	if tipo == "renda":
		f["renda_corridas"] += 1
		f["renda_s"] += dur
		f["renda_cr"] += int(r["premio"])
	else:
		f["desafios"] += 1
	var h: Dictionary = _renda.get_or_add(evento_id, {"cr": 0, "s": 0.0, "n": 0})
	h["cr"] += int(r["premio"])
	h["s"] += dur
	h["n"] += 1
	if r["posicao"] == 1 and not marcos.has("primeira_vitoria"):
		marcos["primeira_vitoria"] = tempo
	if r["posicao"] == 1 and d.evento(evento_id)["restricoes"].get("licenca") == "B" and not marcos.has("vitoria_b"):
		marcos["vitoria_b"] = tempo
	if r["carro_premio_uid"] > 0:
		log.append("carro-prêmio em %s" % d.evento(evento_id)["nome"])
	return r


## Prova não vencida que o carro pode correr, ainda não deixada de lado.
func _escolher_desafio() -> Dictionary:
	var carro: Carro = j.garagem.carro(uid)
	var lista := []
	for ev in d.lista("eventos"):
		if j.vitorias.has(ev["id"]) or ev["premios"].is_empty() or _bloqueadas.has(_chave(ev["id"])):
			continue
		if Elegibilidade.motivos(carro, ev["restricoes"], j.licencas).is_empty():
			lista.append(ev)
	if lista.is_empty():
		return {}
	if perfil == "explora":
		return lista[rng.randi_range(0, lista.size() - 1)]
	lista.sort_custom(func(a, b): return a["premios"][0] < b["premios"][0] if a["premios"][0] != b["premios"][0] else a["nome"] < b["nome"])
	return lista[0]


## O que comprar depois de uma derrota: o "O que ajuda?" (só o que o saldo
## paga). Sem opção paga, a peça ou pneu mais barato que ajudaria (meta para
## juntar dinheiro). {} se nada ajuda.
func _sugestao(evento_id: String) -> Dictionary:
	var carro: Carro = j.garagem.carro(uid)
	var a := Mecanico.analisar(j.carreira, evento_id, uid, 3, AMOSTRAS)
	var opcoes: Array = a["opcoes"]
	if not opcoes.is_empty():
		if perfil == "explora":
			return opcoes[rng.randi_range(0, opcoes.size() - 1)]
		if perfil == "renda":
			var base: float = a["base"]["media"]
			opcoes.sort_custom(func(x, y): return (base - x["media"]) / maxf(x["preco"], 1.0) > (base - y["media"]) / maxf(y["preco"], 1.0))
		return opcoes[0]
	# Nada que o saldo paga ajuda: a opção mais barata, acima do saldo, que ajuda.
	var rico := Rico.new()
	var caras: Array = Mecanico.candidatas(d, rico, carro).filter(func(o): return not j.economia.pode_pagar(o["preco"]))
	rico.free()
	caras.sort_custom(func(x, y): return x["preco"] < y["preco"])
	var base := Mecanico.avaliar(j.carreira, evento_id, uid, carro, AMOSTRAS)
	for o in caras.slice(0, 6):
		var av := Mecanico.avaliar(j.carreira, evento_id, uid, o["carro"], AMOSTRAS)
		if not av.is_empty() and av["media"] < base["media"] - Mecanico.GANHO_MINIMO:
			o.erase("carro")
			return o
	return {}


## Junta dinheiro repetindo uma prova já vencida (renda) até pagar `preco`.
## Registra a linha da tabela de compras. false se não há renda possível.
func _juntar(preco: int, nome: String) -> bool:
	var linha := {"fase": fase(), "compra": nome, "preco": preco, "saldo": j.economia.saldo,
			"falta": maxi(preco - j.economia.saldo, 0), "renda": "", "duracao_s": 0.0, "ganho_corrida": 0.0,
			"corridas": 0, "minutos": 0.0, "tempo_total_min": tempo / 60.0}
	if j.economia.pode_pagar(preco):
		compras.append(linha)
		return true
	var ev := _escolher_renda()
	if ev == "":
		return false
	linha["renda"] = d.evento(ev)["nome"]
	var cr := 0
	var s := 0.0
	while not j.economia.pode_pagar(preco):
		var r := _correr(ev, "renda")
		if r.is_empty():
			return false
		linha["corridas"] += 1
		cr += int(r["premio"])
		s += float(r["resultado"]["duracao"])
		if linha["corridas"] > 500:
			return false
	linha["duracao_s"] = s / linha["corridas"]
	linha["ganho_corrida"] = float(cr) / linha["corridas"]
	linha["minutos"] = s / 60.0
	compras.append(linha)
	return true


## Prova vencida para repetir: a última (sugestoes), ao acaso (explora) ou a de
## maior Cr/min já visto (renda). "" se nenhuma.
func _escolher_renda() -> String:
	var carro: Carro = j.garagem.carro(uid)
	var vencidas: Array = j.vitorias.keys().filter(func(e): return Elegibilidade.motivos(carro,
			d.evento(e)["restricoes"], j.licencas).is_empty() and not d.evento(e)["premios"].is_empty())
	if vencidas.is_empty():
		return ""
	if perfil == "explora":
		return vencidas[rng.randi_range(0, vencidas.size() - 1)]
	if perfil == "renda":
		vencidas.sort_custom(func(a, b): return _cr_min(a) > _cr_min(b))
		return vencidas[0]
	return _ultima_vencida if _ultima_vencida in vencidas else vencidas[0]


func _cr_min(evento_id: String) -> float:
	var h: Dictionary = _renda.get(evento_id, {})
	return 0.0 if h.is_empty() or h["s"] <= 0.0 else h["cr"] / h["s"] * 60.0


func _comprar_item(o: Dictionary) -> void:
	var carro: Carro = j.garagem.carro(uid)
	var motivo := ""
	if o["tipo"] == "peca":
		motivo = j.concessionaria.comprar_peca(carro, o["item"])
	else:
		motivo = j.concessionaria.comprar_pneu(carro, o["item"])
	if motivo == "":
		_fase_stats()["gastos"] += int(o["preco"])
		log.append("%.0f min: comprou %s (%d)" % [tempo / 60.0, o["nome"], o["preco"]])
		_tentativas.clear()


## Sem prova a vencer com este carro: outro carro da garagem que tenha prova a
## vencer; senão, o mais barato (novo ou usado de hoje) que entra numa prova
## ainda não vencida que o atual não pode correr, ou que o atual já tentou e
## deixou de lado (aí, só com mais potência por peso de fábrica).
func _trocar_carro() -> bool:
	var atual_uid := uid
	for c in j.garagem.lista():
		if c.uid == atual_uid:
			continue
		uid = c.uid
		if not _escolher_desafio().is_empty():
			log.append("%.0f min: trocou para o %s da garagem" % [tempo / 60.0, c.id])
			_tentativas.clear()
			return true
	uid = atual_uid
	var atual: Carro = j.garagem.carro(uid)
	var fab := Carro.new(atual.base)
	fab.adicionar_pneu(d.pneu(d.economia()["pneu_de_fabrica"]))
	var fa := fab.atributos_efetivos("seco")
	var ppa: float = fa["potencia"] / fa["peso"]
	var opcoes := []
	for c in d.lista("carros"):
		if c.get("novo", true):
			opcoes.append({"carro_id": c["id"], "preco": int(c["preco"])})
	opcoes.append_array(Usados.estoque(d.lista("carros"), j.dias, j.usados_vendidos))
	var possuidos: Array = j.garagem.lista().map(func(c): return c.id)
	var boas := []
	for o in opcoes:
		if o["carro_id"] in possuidos:
			continue
		var base: Dictionary = d.carro(o["carro_id"])
		var teste := Carro.new(base)
		teste.adicionar_pneu(d.pneu(d.economia()["pneu_de_fabrica"]))
		var mais_forte: bool = float(base["potencia"]) / float(base["peso"]) > ppa * 1.05
		var abre: bool = d.lista("eventos").any(func(ev):
			if j.vitorias.has(ev["id"]) or ev["premios"].is_empty():
				return false
			if not Elegibilidade.motivos(teste, ev["restricoes"], j.licencas).is_empty():
				return false
			var atual_entra := Elegibilidade.motivos(atual, ev["restricoes"], j.licencas).is_empty()
			return not atual_entra or (_bloqueadas.has(_chave(ev["id"])) and mais_forte))
		if abre:
			boas.append(o)
	if boas.is_empty():
		return false
	boas.sort_custom(func(x, y): return x["preco"] < y["preco"])
	var o: Dictionary = boas[rng.randi_range(0, mini(2, boas.size() - 1))] if perfil == "explora" else boas[0]
	if not _juntar(int(o["preco"]), "carro " + d.carro(o["carro_id"])["nome"]):
		return false
	# A oferta de usado pode ter saído enquanto juntava: confere de novo.
	if o.has("chave") and not Usados.estoque(d.lista("carros"), j.dias, j.usados_vendidos).any(func(x): return x["chave"] == o["chave"]):
		return true
	_comprar_carro(o, "troca de carro")
	return true


func _comprar_carro(o: Dictionary, motivo: String) -> void:
	var novo: int
	if o.has("chave"):
		novo = j.concessionaria.comprar_usado(o, d.carro(o["carro_id"]), j.usados_vendidos)
	else:
		novo = j.concessionaria.comprar_carro(d.carro(o["carro_id"]))
	if novo < 0:
		return
	uid = novo
	_fase_stats()["gastos"] += int(o["preco"])
	log.append("%.0f min: %s, %s (%d)" % [tempo / 60.0, motivo, o["carro_id"], o["preco"]])
	_tentativas.clear()


## Contratos da B: sugestoes e renda depois da primeira vitória; explora logo.
func _talvez_contratos() -> void:
	if "B" in j.licencas or marcos.has("contratos_b_falhou"):
		return
	if perfil != "explora" and not marcos.has("primeira_vitoria"):
		return
	var ct := Contratos.new(d, j)
	var envios := 0
	for c in Contratos.da_licenca(d, "B"):
		var m := _resolver_contrato(c)
		envios += int(m["envios"])
		ct.enviar(c["id"], m["montagem"])
	marcos["envios_contratos_b"] = envios
	if "B" in j.licencas:
		marcos["licenca_b"] = tempo
		log.append("%.0f min: licença B pelos contratos (%d envios)" % [tempo / 60.0, envios])
	else:
		marcos["contratos_b_falhou"] = tempo
		log.append("contratos da B não resolvidos")


## Montagem que cumpre o bronze: a cada envio, a opção que mais reduz o pior
## déficit, respeitando o teto de custo. "envios" conta os passos (cada passo
## é uma avaliação que o jogador mandaria).
func _resolver_contrato(c: Dictionary) -> Dictionary:
	var teto := int(c["condicoes"]["bronze"].get("custo_max", 1 << 30))
	var pecas: Array = Contratos.pecas_escola(d, c)
	var m := {"pecas": [], "ajuste_cambio": ""}
	var r := Contratos.avaliar(d, c, m, false)
	var envios := 1
	while r["grau"] == "" and envios < 30:
		var melhor := {}
		var melhor_def := _deficit(r)
		for p in pecas:
			if p["id"] in m["pecas"]:
				continue
			var ids: Array = m["pecas"].filter(func(x): return d.peca(x)["categoria"] != p["categoria"]) + [p["id"]]
			var custo := 0
			for x in ids:
				custo += int(d.peca(x)["preco"])
			if custo > teto:
				continue
			var mm := {"pecas": ids, "ajuste_cambio": m["ajuste_cambio"] if ids.any(func(x): return d.peca(x)["categoria"] == "cambio") else ""}
			var rr := Contratos.avaliar(d, c, mm, false)
			if _deficit(rr) < melhor_def - 0.005:
				melhor_def = _deficit(rr)
				melhor = mm
		if melhor.is_empty():
			break
		m = melhor
		r = Contratos.avaliar(d, c, m, false)
		envios += 1
	return {"montagem": m, "envios": envios}


static func _deficit(r: Dictionary) -> float:
	var pior := -INF
	for p in r["provas"]:
		pior = maxf(pior, -float(p["folga"]))
	return pior


## Testes de tempo da A com o próprio carro: depois de vencer uma prova B
## (explora: a cada tentativa, se já tem a B). Conta o tempo dos testes.
func _talvez_licenca_a() -> void:
	if "A" in j.licencas or not "B" in j.licencas:
		return
	if perfil != "explora" and not marcos.has("vitoria_b"):
		return
	var tentou := int(marcos.get("tentativas_a", 0))
	if tentou >= j.vitorias.size():
		return  # uma tentativa por vitória nova
	marcos["tentativas_a"] = j.vitorias.size()
	var lic := Licencas.new(d, j)
	for t in d.item("licencas", "A")["testes"]:
		if j.graus_licenca.has(t["id"]):
			continue
		semente += 1
		var r := lic.fazer_teste("A", t["id"], uid, hash("agente-a:%d" % semente))
		if r.has("erro"):
			return
		tempo += float(r["tempo"])
		_fase_stats()["tempo_s"] += float(r["tempo"])
	if "A" in j.licencas:
		marcos["licenca_a"] = tempo
		log.append("%.0f min: licença A" % (tempo / 60.0))
