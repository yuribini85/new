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


## Campeonato da arena em duplas (decisão 61): o nível do jogador diz quantas
## equipes entram, de 2 (2×2, 4 carros) até `equipes_max` (20 carros); vencer
## (a sua equipe ficar de pé) sobe um nível.
static func nivel(jogador: Node) -> int:
	return int(jogador.arena.get("nivel", 0))


static func equipes_no_nivel(dados: Node, n: int) -> int:
	var c: Dictionary = dados.arena().get("campeonato", {})
	return clampi(int(c.get("equipes_min", 2)) + n, int(c.get("equipes_min", 2)), int(c.get("equipes_max", 10)))


## "2×2×2" para 3 equipes.
static func nome_nivel(equipes: int) -> String:
	var partes := []
	for k in equipes:
		partes.append("2")
	return "×".join(partes)


## A dupla do jogador: o segundo piloto no carro dele (se tem um, livre e
## diferente do inscrito) ou o piloto da casa num carro emprestado (que não se
## perde). {real (bool), uid, nome}.
static func parceiro(dados: Node, jogador: Node, uid: int) -> Dictionary:
	var cu: int = jogador.carro_companheiro
	if jogador.segundo_piloto != "" and cu != uid and aptos(jogador).any(func(c): return c.uid == cu):
		return {"real": true, "uid": cu, "nome": EquipeJogador.nome_segundo(dados, jogador)}
	return {"real": false, "uid": -1, "nome": String(dados.arena().get("campeonato", {}).get("parceiro_casa", "Piloto da casa"))}


## Participantes da luta em duplas: o jogador ("jogador") e o parceiro
## ("parceiro") na equipe "jogador"; as equipes rivais sorteadas, cada uma com
## dois dos seus pilotos ("<equipe>:1", "<equipe>:2") em carros de potência
## parecida, nas cores da equipe. {participantes, modelos, nomes, cores,
## faixas, params (com a arena sorteada), equipes (id -> equipe), parceiro}.
static func montar(dados: Node, jogador: Node, uid: int, semente: int) -> Dictionary:
	var p: Dictionary = dados.arena()
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var carro: Carro = jogador.garagem.carro(uid)
	var base_piloto: Dictionary = EquipeJogador.piloto_do_jogador(dados, jogador)
	var attrs := carro.atributos_efetivos("seco")
	var parts := [{"id": "jogador", "atributos": attrs, "piloto": base_piloto, "equipe": "jogador"}]
	var modelos := {"jogador": carro.base}
	var nomes := {"jogador": EquipeJogador.nome_jogador(dados, jogador)}
	var cores := {}
	var faixas := {}
	var equipes := {"jogador": EquipeJogador.dados_equipe(dados, jogador)}
	# Carros de potência parecida (de fábrica), sem repetir modelo.
	var cv := float(attrs["potencia"])
	var catalogo: Array = dados.lista("carros").filter(func(c): return c["id"] != carro.id)
	catalogo.sort_custom(func(a, b): return absf(float(a["potencia"]) - cv) < absf(float(b["potencia"]) - cv))
	var n_equipes := equipes_no_nivel(dados, nivel(jogador))
	var escolhidos := catalogo.slice(0, n_equipes * 4)
	var sortear_modelo := func() -> Dictionary:
		return escolhidos.pop_at(rng.randi_range(0, escolhidos.size() - 1)) if not escolhidos.is_empty() else carro.base
	# Parceiro: o segundo piloto no carro dele, ou o da casa num emprestado.
	var par := parceiro(dados, jogador, uid)
	var car_par: Carro
	if par["real"]:
		car_par = jogador.garagem.carro(int(par["uid"]))
	else:
		car_par = Carro.new(sortear_modelo.call())
		car_par.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
		cores["parceiro"] = CarroBloco.cor_do_carro(carro)
	parts.append({"id": "parceiro", "atributos": car_par.atributos_efetivos("seco"),
			"piloto": EquipeJogador.piloto_corrida(dados, jogador), "equipe": "jogador"})
	modelos["parceiro"] = car_par.base
	nomes["parceiro"] = String(par["nome"])
	if par["real"]:
		cores["parceiro"] = CarroBloco.cor_do_carro(car_par)
		faixas["parceiro"] = car_par.faixas
	# Equipes rivais sorteadas, dois pilotos de cada.
	var rivais: Array = dados.lista("equipes").filter(func(e): return not e.get("jogador", false) and e.get("pilotos", []).size() >= 2)
	rivais.sort_custom(func(a, b): return a["id"] < b["id"])
	var perfis: Dictionary = dados.carreira().get("perfis_piloto", {})
	for k in mini(n_equipes - 1, rivais.size()):
		var eq: Dictionary = rivais.pop_at(rng.randi_range(0, rivais.size() - 1))
		equipes[eq["id"]] = eq
		var pilotos: Array = eq["pilotos"].duplicate()
		for m in 2:
			var pl: Dictionary = pilotos.pop_at(rng.randi_range(0, pilotos.size() - 1))
			var id := "%s:%d" % [eq["id"], m + 1]
			var mod: Dictionary = sortear_modelo.call()
			var rival := Carro.new(mod)
			rival.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
			var piloto := base_piloto.duplicate()
			if perfis.has(String(pl.get("perfil", ""))):
				piloto["agressividade"] = float(perfis[pl["perfil"]]["agressividade"])
			parts.append({"id": id, "atributos": rival.atributos_efetivos("seco"), "piloto": piloto, "equipe": eq["id"]})
			modelos[id] = mod
			nomes[id] = String(pl["nome"])
			if eq.has("cores"):
				cores[id] = Color(String(eq["cores"]["carro"]))
				faixas[id] = PinturaCarro.da_equipe(eq, "%d|%s" % [semente, id], Array(eq["pilotos"]).find(pl))
	# A arena da luta: sorteada entre as abertas pelas licenças do jogador
	# (decisão 59); a forma vai nos parâmetros da simulação e da tela.
	var params := p.duplicate()
	var abertas := arenas_abertas(dados, jogador)
	if not abertas.is_empty():
		params["forma"] = abertas[rng.randi_range(0, abertas.size() - 1)]
	return {"participantes": parts, "modelos": modelos, "nomes": nomes, "cores": cores, "faixas": faixas,
			"params": params, "equipes": equipes, "parceiro": par}


## Arenas (data/arena.json → arenas) cuja licença o jogador já tem.
static func arenas_abertas(dados: Node, jogador: Node) -> Array:
	var ordem := GestaoEquipe.ordem(dados)
	var maior := GestaoEquipe.maior_licenca(dados, jogador)
	return dados.arena().get("arenas", []).filter(func(a): return ordem.find(String(a.get("licenca", ""))) <= maior)


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
	# Vencer: a equipe do participante ficou de pé (em dupla, mesmo caído).
	var equipe := String(resultado["carros"][id].get("equipe", id))
	var venceu: bool = resultado.get("equipe_vencedora", "") == equipe if resultado.has("equipe_vencedora") \
			else (resultado["classificacao"][0] == id and not resultado["carros"][id]["eliminado"])
	if venceu:
		total += int(tabela.get("vencer", 0))
	return total


## Giros pelos pontos: o prêmio de referência paga `pontos_referencia` pontos.
static func premio(dados: Node, pts: int) -> int:
	var ref := maxf(float(dados.arena().get("pontos_referencia", 1)), 1.0)
	return roundi(premio_base(dados) * pts / ref)


## Aplica a luta: prêmio no saldo, registro e, se o carro do jogador foi
## eliminado, ele sai da garagem. {posicao, pontos, premio, perdeu, carro, uid}.
static func aplicar(dados: Node, jogador: Node, uid: int, resultado: Dictionary, parceiro_uid: int = -1) -> Dictionary:
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
	# O carro do segundo piloto (real, da garagem) também se perde se cair.
	var perdeu_parceiro := false
	if parceiro_uid >= 0 and resultado["carros"].has("parceiro") and resultado["carros"]["parceiro"]["eliminado"]:
		var cp: Carro = jogador.garagem.carro(parceiro_uid)
		if cp != null:
			perdeu_parceiro = true
			reg["perdidos"] = Array(reg.get("perdidos", [])) + [String(cp.id)]
			jogador.garagem.remover(parceiro_uid)
			if jogador.carro_ativo == parceiro_uid:
				var resto2: Array = jogador.garagem.lista()
				jogador.carro_ativo = resto2[0].uid if not resto2.is_empty() else -1
			jogador.carro_companheiro = -1
	# Campeonato: a equipe do jogador ficou de pé → sobe de nível (até o último).
	var venceu_equipe: bool = resultado.get("equipe_vencedora", "") == "jogador"
	var nivel_antes := nivel(jogador)
	if venceu_equipe:
		var maximo := int(p.get("campeonato", {}).get("equipes_max", 10)) - int(p.get("campeonato", {}).get("equipes_min", 2))
		reg["nivel"] = mini(nivel_antes + 1, maximo)
	jogador.arena = reg
	return {"posicao": posicao, "pontos": pts, "premio": valor, "perdeu": perdeu, "carro": nome, "uid": uid,
			"perdeu_parceiro": perdeu_parceiro, "venceu_equipe": venceu_equipe,
			"subiu_nivel": int(reg.get("nivel", 0)) > nivel_antes}
