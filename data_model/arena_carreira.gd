class_name ArenaCarreira
extends RefCounted
## A arena na carreira (decisão 49). Inscrição: licença `licenca_minima` e ao
## menos 2 carros na garagem (nunca se perde o único carro); o carro na fila de
## corrida não entra. Rivais: os carros do catálogo de potência mais parecida com
## a do inscrito, com pilotos das equipes rivais e a mesma IA e piloto-base do
## jogador (as mesmas regras para todos). A luta é resolvida e aplicada na
## inscrição (fechar o app não salva o carro); a tela só mostra.
## Resultado: pontos (giros provocados, eliminações, vencer) viram giros pelo
## prêmio de 1º lugar médio das corridas da licença mínima; carro eliminado sai
## da garagem para sempre.


## "" se pode se inscrever; senão, o motivo (texto da tela).
static func bloqueio(dados: Node, jogador: Node) -> String:
	var p: Dictionary = dados.arena()
	if p.is_empty():
		return "A arena ainda não está aberta."
	var lic := String(p.get("licenca_minima", ""))
	if lic != "" and not lic in jogador.licencas:
		var nome := String(dados.item("licencas", lic).get("nome", lic)) if dados.existe("licencas", lic) else lic
		return "Abre com a %s." % nome
	if jogador.garagem.lista().size() < 2:
		return "Só entra quem tem pelo menos 2 carros na garagem: carro eliminado na arena não volta."
	if aptos(jogador).is_empty():
		return "Nenhum carro livre: o outro está na fila de corridas."
	return ""


## Carros da garagem que podem entrar (o da fila de corrida não).
static func aptos(jogador: Node) -> Array:
	var na_fila := int(jogador.fila.get("uid", -1)) if not jogador.fila.is_empty() else -1
	return jogador.garagem.lista().filter(func(c): return c.uid != na_fila)


## Prêmio de referência: média do 1º lugar das corridas da licença mínima.
static func premio_base(dados: Node) -> int:
	var lic := String(dados.arena().get("licenca_minima", ""))
	var soma := 0
	var n := 0
	for ev in dados.lista("eventos"):
		if String(ev["restricoes"].get("licenca", "")) == lic and not ev["premios"].is_empty():
			soma += int(ev["premios"][0])
			n += 1
	return soma / n if n > 0 else 0


## Participantes da luta: o carro do jogador ("jogador") e os rivais ("r1".."rN").
## {participantes, modelos (id -> dados do carro), nomes (id -> piloto)}.
static func montar(dados: Node, jogador: Node, uid: int, semente: int) -> Dictionary:
	var p: Dictionary = dados.arena()
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var carro: Carro = jogador.garagem.carro(uid)
	var piloto: Dictionary = EquipeJogador.piloto_do_jogador(dados, jogador)
	var attrs := carro.atributos_efetivos("seco")
	var parts := [{"id": "jogador", "atributos": attrs, "piloto": piloto}]
	var modelos := {"jogador": carro.base}
	var nomes := {"jogador": EquipeJogador.nome_jogador(dados, jogador)}
	# Rivais: os mais parecidos em potência (de fábrica), sem repetir modelo.
	var cv := float(attrs["potencia"])
	var catalogo: Array = dados.lista("carros").filter(func(c): return c["id"] != carro.id)
	catalogo.sort_custom(func(a, b): return absf(float(a["potencia"]) - cv) < absf(float(b["potencia"]) - cv))
	var pilotos := []
	for e in dados.lista("equipes"):
		if not e.get("jogador", false):
			pilotos.append_array(e.get("pilotos", []))
	var n := int(p.get("rivais", 3))
	var escolhidos := catalogo.slice(0, n * 2)
	for k in n:
		if escolhidos.is_empty():
			break
		var m: Dictionary = escolhidos.pop_at(rng.randi_range(0, escolhidos.size() - 1))
		var rival := Carro.new(m)
		rival.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
		var id := "r%d" % (k + 1)
		parts.append({"id": id, "atributos": rival.atributos_efetivos("seco"), "piloto": piloto})
		modelos[id] = m
		nomes[id] = String(pilotos.pop_at(rng.randi_range(0, pilotos.size() - 1))["nome"]) if not pilotos.is_empty() \
				else "Rival %d" % (k + 1)
	return {"participantes": parts, "modelos": modelos, "nomes": nomes}


## Pontos de um participante: giros provocados (pelo maior limite de cada
## giro), eliminações e vencer (o último de pé).
static func pontos(resultado: Dictionary, id: String, params: Dictionary) -> int:
	var tabela: Dictionary = params.get("pontos", {})
	var total := 0
	var maior := {}  # carro girado -> maior giro provocado por `id` naquele golpe
	for e in resultado["eventos"]:
		if e["tipo"] == "giro" and e["por"] == id:
			var chave := "%s:%s" % [e["carro"], snappedf(float(e["t"]), 0.5)]
			maior[chave] = maxi(int(maior.get(chave, 0)), int(e["graus"]))
	for k in maior:
		total += int(tabela.get("giro_%d" % maior[k], 0))
	total += int(tabela.get("eliminacao", 0)) * int(resultado["carros"][id]["eliminou"])
	if resultado["classificacao"][0] == id and not resultado["carros"][id]["eliminado"]:
		total += int(tabela.get("vencer", 0))
	return total


## Giros pelos pontos: o prêmio de referência paga `pontos_referencia` pontos.
static func premio(dados: Node, pts: int) -> int:
	var ref := maxf(float(dados.arena().get("pontos_referencia", 1)), 1.0)
	return roundi(premio_base(dados) * pts / ref)


## Aplica a luta: prêmio no saldo, registro e, se o carro do jogador foi
## eliminado, ele sai da garagem. {posicao, pontos, premio, perdeu, carro, uid}.
static func aplicar(dados: Node, jogador: Node, uid: int, resultado: Dictionary) -> Dictionary:
	var p: Dictionary = dados.arena()
	var pts := pontos(resultado, "jogador", p)
	var valor := premio(dados, pts)
	var carro: Carro = jogador.garagem.carro(uid)
	var nome := String(carro.base["nome"]) if carro != null else ""
	var perdeu: bool = resultado["carros"]["jogador"]["eliminado"]
	jogador.economia.saldo += valor
	var reg: Dictionary = jogador.arena
	reg["lutas"] = int(reg.get("lutas", 0)) + 1
	var posicao: int = resultado["classificacao"].find("jogador") + 1
	if posicao == 1:
		reg["vitorias"] = int(reg.get("vitorias", 0)) + 1
	if perdeu:
		reg["perdidos"] = Array(reg.get("perdidos", [])) + [String(carro.id)]
		jogador.garagem.remover(uid)
		if jogador.carro_ativo == uid:
			var resto: Array = jogador.garagem.lista()
			jogador.carro_ativo = resto[0].uid if not resto.is_empty() else -1
		if jogador.carro_companheiro == uid:
			jogador.carro_companheiro = -1
	jogador.arena = reg
	return {"posicao": posicao, "pontos": pts, "premio": valor, "perdeu": perdeu, "carro": nome, "uid": uid}
