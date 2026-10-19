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
## Campanha (jogar_campanha): começa como o jogo novo da história (o carro e o
## saldo do Prologo) e compra primeiro a peça da demanda, como a cena pede.
## `ouvinte` (opcional) recebe cada ação (corrida, carro, peca, treino,
## licenca) com o contexto, para o playtest da história (tools/playtest_campanha.gd).
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
var ouvinte := Callable()


func _avisar(acao: String, ctx: Dictionary) -> void:
	if ouvinte.is_valid():
		ouvinte.call(acao, ctx)


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


## Joga a partir da oferta inicial ({carro_id, preco}) até
## `limite_s` de corrida ou até não ter prova a vencer nem carro que ajude.
func jogar(oferta: Dictionary, limite_s: float) -> Dictionary:
	_comprar_carro(oferta, "carro inicial")
	return _laco(limite_s)


## Jogo novo pela campanha `id` (historia.json): o carro da campanha e a peça
## da demanda comprada antes da primeira prova.
func jogar_campanha(id: String, limite_s: float) -> Dictionary:
	var erro := Prologo.iniciar(d, j, id)
	if erro != "":
		return {"erro": erro}
	j.carreira = Carreira.new(d, j)
	uid = j.carro_ativo
	_avisar("inicio", {})
	if uid < 0:
		_primeiro_carro()
	var demanda := Prologo.demanda(d, j)
	if d.existe("pecas", demanda):
		var p: Dictionary = d.peca(demanda)
		_comprar_item({"tipo": "peca", "item": p, "nome": String(p["nome"]), "preco": int(p["preco"])})
	return _laco(limite_s)


## Decisão 85: a campanha do dono começa com a garagem vazia; como a cena
## CW_C00 pede, o primeiro carro sai da loja pela força na estreia (decisão 96;
## o selo saiu da loja, o agente segue como um jogador que compara as fichas):
## o mais barato que chega MAIS FORTE na prova mais favorável (sem nenhum, o de
## maior força); explora: um dos três mais baratos, sem olhar a força.
func _primeiro_carro() -> void:
	var opcoes := []
	for c in d.lista("carros"):
		if int(c["preco"]) <= j.economia.saldo:
			opcoes.append({"carro_id": c["id"], "preco": int(c["preco"])})
	if opcoes.is_empty():
		log.append("campanha: o saldo inicial não paga nenhum carro")
		return
	opcoes.sort_custom(func(x, y): return x["preco"] < y["preco"])
	var o: Dictionary = opcoes[rng.randi_range(0, mini(2, opcoes.size() - 1))] if perfil == "explora" else opcoes[0]
	if perfil != "explora":
		var melhor := -1.0
		for x in opcoes:
			var c := Carro.new(d.carro(x["carro_id"]))
			c.adicionar_pneu(d.pneu(d.economia()["pneu_de_fabrica"]))
			var fav: Array = j.carreira.provas_favoraveis(c)
			var f: float = float(fav[0]["melhor"]) if not fav.is_empty() else -1.0
			if Carreira.nivel_forca(f) == 2:
				o = x  # o mais barato MAIS FORTE (a lista está por preço)
				break
			if f > melhor:
				melhor = f
				o = x
	_comprar_carro(o, "primeiro carro")


func _laco(limite_s: float) -> Dictionary:
	while tempo < limite_s:
		_talvez_licencas()
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
	if "SPORT" in j.licencas:
		return "SPORT"
	if "CLUB" in j.licencas:
		return "CLUB"
	return "sem licença"


func _fase_stats() -> Dictionary:
	return fases.get_or_add(fase(), {"tempo_s": 0.0, "bruto": 0, "gastos": 0, "desafios": 0, "renda_corridas": 0,
			"renda_s": 0.0, "renda_cr": 0})


func _chave(evento_id: String) -> String:
	return "%d:%s" % [uid, evento_id]


func _correr(evento_id: String, tipo: String) -> Dictionary:
	_avisar("largada", {"evento": evento_id, "tipo": tipo})
	semente += 1
	# O período das repetições (prêmio menor) corre no tempo de corrida simulado.
	var r: Dictionary = j.carreira.disputar(evento_id, uid, hash("agente:%s:%d" % [perfil, semente]), tempo)
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
	if r["posicao"] == 1 and d.evento(evento_id)["restricoes"].get("licenca") == "CLUB" and not marcos.has("vitoria_b"):
		marcos["vitoria_b"] = tempo
	if r["carro_premio_uid"] > 0:
		log.append("carro-prêmio em %s" % d.evento(evento_id)["nome"])
	_avisar("corrida", {"evento": evento_id, "posicao": int(r["posicao"]), "tipo": tipo,
			"campeao": bool(r.get("campeonato", {}).get("campeao", false)),
			"campeonato": not r.get("campeonato", {}).is_empty()})
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
	# A "Próxima prova" da tela (Carreira.provas_favoraveis): a mais favorável
	# ao carro, frente ao rival mais forte.
	for f in j.carreira.provas_favoraveis(carro):
		if f["ev"] in lista:
			return f["ev"]
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
		ev = _escolher_renda()  # o prêmio cai a cada repetição: troca quando outra rende mais
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


## Prova vencida para repetir: ao acaso (explora); senão a de maior Cr/min já
## visto com o prêmio de agora (cai a cada repetição, Carreira.fator_repeticao,
## e a tela mostra o valor reduzido); no empate, a última vencida (sugestoes).
## "" se nenhuma.
func _escolher_renda() -> String:
	var carro: Carro = j.garagem.carro(uid)
	var vencidas: Array = j.vitorias.keys().filter(func(e): return Elegibilidade.motivos(carro,
			d.evento(e)["restricoes"], j.licencas).is_empty() and not d.evento(e)["premios"].is_empty())
	if vencidas.is_empty():
		return ""
	if perfil == "explora":
		return vencidas[rng.randi_range(0, vencidas.size() - 1)]
	var valor := func(e: String) -> float: return _cr_min(e) * j.carreira.fator_repeticao(e, tempo)
	if perfil == "sugestoes" and _ultima_vencida in vencidas:
		vencidas.erase(_ultima_vencida)
		vencidas.push_front(_ultima_vencida)
	var melhor: String = vencidas[0]
	for e in vencidas:
		if valor.call(e) > valor.call(melhor):
			melhor = e
	return melhor


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
		_avisar("peca", {"id": String(o["item"]["id"]), "peca": String(o["nome"])})


## Sem prova a vencer com este carro: outro carro da garagem que tenha prova a
## vencer; senão, o carro que o jogo sugere (Mecanico.carro_sugerido).
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
	# O carro que o jogo sugere quando nada no saldo resolve (Mecanico.carro_sugerido).
	var travadas := []
	for k in _bloqueadas:
		if String(k).begins_with("%d:" % uid):
			travadas.append(String(k).get_slice(":", 1))
	var s := Mecanico.carro_sugerido(d, j, j.garagem.carro(uid), travadas)
	if s.is_empty():
		return false
	var o := {"carro_id": s["carro"]["id"], "preco": int(s["carro"]["preco"])}
	if not _juntar(int(o["preco"]), "carro " + String(s["carro"]["nome"])):
		return false
	_comprar_carro(o, "troca de carro")
	return true


func _comprar_carro(o: Dictionary, motivo: String) -> void:
	var novo: int = j.concessionaria.comprar_carro(d.carro(o["carro_id"]))
	if novo < 0:
		return
	uid = novo
	_fase_stats()["gastos"] += int(o["preco"])
	log.append("%.0f min: %s, %s (%d)" % [tempo / 60.0, motivo, o["carro_id"], o["preco"]])
	_tentativas.clear()
	j.carro_ativo = uid
	_avisar("carro", {"carro_id": String(o["carro_id"]), "preco": int(o["preco"]), "novo": true})


## Licenças por treino no relógio (decisão do usuário, 2026-10-17): treino
## assim que os requisitos permitem; terminado, a licença sai sozinha. O relógio
## é o tempo de corrida do agente.
func _talvez_licencas() -> void:
	var lic := Licencas.new(d, j)
	for l in d.lista("licencas"):
		var id := String(l["id"])
		if lic.estado(id, tempo) == Licencas.AVAILABLE:
			_avisar("disponivel", {"licenca": id})
			lic.iniciar_treino(id, tempo)
			_avisar("treino", {"licenca": id})
	for id in lic.atualizar(tempo):
		_avisar("licenca", {"licenca": id})
		if id == "CLUB":
			marcos["licenca_b"] = tempo
		elif id == "SPORT":
			marcos["licenca_a"] = tempo
		log.append("%.0f min: licença %s" % [tempo / 60.0, id])
