class_name ArenaCarreira
extends RefCounted
## A arena na carreira (decisão 49). Inscrição: `carros_minimos` na garagem
## (decisão 121) e o carro e o piloto da ARENA 1; sem os da ARENA 2, a casa
## empresta um carro e um piloto. O carro na fila de corrida não entra. Rivais: os carros do catálogo de potência mais parecida com
## a do inscrito, com pilotos das equipes rivais e a mesma IA e piloto-base do
## jogador (as mesmas regras para todos). A luta é resolvida e aplicada na
## inscrição (fechar o app não salva o carro); a tela só mostra.
## Resultado: pontos (giros provocados, eliminações, vencer) viram giros pelo
## prêmio de 1º lugar médio das corridas da licença mínima; carro eliminado vai
## para o reparo (revisão da decisão 49): fica fora pelo tempo de tempo_reparo,
## com o app fechado também, ou conserta na hora pagando custo_reparo.


## "" se pode se inscrever; senão, o motivo (texto da tela).
static func bloqueio(dados: Node, jogador: Node) -> String:
	var p: Dictionary = dados.arena()
	if p.is_empty():
		return "A arena ainda não está aberta."
	# Decisão 69: a arena abre com o tutorial dela, ao chegar a carros_minimos
	# (EquipeJogador.FLAG_ARENA); a licença mínima só dá o prêmio de referência.
	if not jogador.flags.has(EquipeJogador.FLAG_ARENA):
		return "Abre quando a garagem tiver %d carros." % carros_minimos(dados)
	# Decisão 116 (pedido do usuário, 2026-10-17): a arena abre também com uma
	# corrida em andamento (a luta é resolvida na hora). Decisão 121: basta o
	# carro e o piloto da ARENA 1; sem os da ARENA 2, a casa empresta os dois.
	if jogador.garagem.lista().size() < carros_minimos(dados):
		return "A arena pede %d carros: 1 de corrida e 1 de arena." % carros_minimos(dados)
	if EquipeJogador.piloto_vaga(jogador, "arena1") == "":
		return "Contrate um piloto de arena (aba Equipe)."
	if Escalacao.carro(jogador, "arena1") == null:
		return "Escale o carro da ARENA 1 na Oficina."
	for c: Carro in aptos(jogador):
		var falta_r := reparo_s(jogador, c.uid)
		if falta_r > 0.0:
			return "%s está no reparo: faltam %s (ou conserte na Oficina)." % [String(c.base["nome"]), texto_tempo(falta_r)]
	return ""


## Reparo (revisão da decisão 49, pedido do usuário em 2026-10-18): o carro
## eliminado não sai da garagem; fica no reparo pelo relógio real, também com o
## app fechado. jogador.arena["reparo"]: uid (texto) -> instante em que fica
## pronto (Aceleracao.agora). Segundos que faltam; 0 = pronto.
static func reparo_s(jogador: Node, uid: int, agora: float = -1.0) -> float:
	var r: Dictionary = jogador.arena.get("reparo", {})
	if not r.has(str(uid)):
		return 0.0
	if agora < 0.0:
		agora = Aceleracao.agora(jogador)
	return maxf(float(r[str(uid)]) - agora, 0.0)


static func em_reparo(jogador: Node, uid: int) -> bool:
	return reparo_s(jogador, uid) > 0.0


## Tempo de reparo (s): arena.json → reparo.tempo "treino" = um nível do
## treino de piloto (equipe.json treino.tempo_base_h); sem o critério, nenhum.
static func tempo_reparo(dados: Node) -> float:
	if String(dados.arena().get("reparo", {}).get("tempo", "")) != "treino":
		return 0.0
	return float(GestaoEquipe.cfg_treino(dados).get("tempo_base_h", 1.0)) * 3600.0


## Consertar na hora (giros): arena.json → reparo.custo "revenda" = o que o
## carro vale na revenda (economia.json fracao_revenda), o que ele custava
## quando era perdido.
static func custo_reparo(dados: Node, carro: Carro) -> int:
	if carro == null or String(dados.arena().get("reparo", {}).get("custo", "")) != "revenda":
		return 0
	return int(floor(float(carro.base.get("preco", 0)) * float(dados.economia().get("fracao_revenda", 0.0))))


## Tira o carro do reparo; `pagar` cobra custo_reparo (false: o vídeo do
## resultado). false se não estava no reparo ou se o saldo não paga.
static func consertar(dados: Node, jogador: Node, uid: int, pagar: bool = true) -> bool:
	var r: Dictionary = jogador.arena.get("reparo", {})
	if not r.has(str(uid)):
		return false
	if pagar:
		var custo := custo_reparo(dados, jogador.garagem.carro(uid))
		if not jogador.economia.pode_pagar(custo):
			return false
		jogador.economia.debitar(custo)
	r.erase(str(uid))
	jogador.arena["reparo"] = r
	return true


static func _quebrar(dados: Node, jogador: Node, uid: int, reg: Dictionary) -> void:
	var fora := tempo_reparo(dados)
	if fora <= 0.0:
		return
	var r: Dictionary = reg.get("reparo", {})
	r[str(uid)] = Aceleracao.agora(jogador) + fora
	reg["reparo"] = r


## Carros na garagem para a arena abrir (arena.json → carros_minimos).
static func carros_minimos(dados: Node) -> int:
	return int(dados.arena().get("carros_minimos", 3))


## Os carros escalados para a arena (Escalacao): o seu e o do segundo piloto.
static func aptos(jogador: Node) -> Array:
	return ["arena1", "arena2"].map(func(v): return Escalacao.carro(jogador, v)).filter(func(c): return c != null)


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


static func texto_tempo(s: float) -> String:
	var m := int(ceil(s / 60.0))
	return "%d h %02d min" % [m / 60, m % 60] if m >= 60 else "%d min" % m


## A dupla do jogador: o segundo piloto no carro da vaga ARENA 2 (decisão 68;
## sem carro emprestado). {real (bool), uid, nome}; real = false sem a vaga ou
## sem o piloto (a luta não abre: ver bloqueio).
static func parceiro(dados: Node, jogador: Node, _uid: int) -> Dictionary:
	var cu := Escalacao.uid(jogador, "arena2")
	if EquipeJogador.piloto_vaga(jogador, "arena2") != "" and cu >= 0:
		return {"real": true, "uid": cu, "nome": EquipeJogador.nome_segundo(dados, jogador)}
	return {"real": false, "uid": -1, "nome": String(dados.arena().get("campeonato", {}).get("parceiro_casa", "Piloto da casa"))}


## Participantes da luta em duplas: o jogador ("jogador") e o parceiro
## ("parceiro") na equipe "jogador"; as equipes rivais sorteadas, cada uma com
## dois dos seus pilotos ("<equipe>:1", "<equipe>:2") em carros de potência
## parecida, nas cores da equipe. {participantes, modelos, nomes, cores,
## faixas, params (com a arena sorteada), equipes (id -> equipe), parceiro}.
## `n_equipes` > 0 fixa quantas equipes (simulação de teste); senão, o nível.
## `desafio` (decisão 74): a equipe do Grid desafiada; a luta é 2x2 contra os
## carros especiais dela (GridDesafio.especiais), na arena do desafio.
## `arena_fixa`: id da arena (simulação de teste: qualquer uma, até as do Grid).
## `espectador`: só equipes rivais (a demonstração: o jogador assiste); o
## carro `uid` serve só de referência de potência.
static func montar(dados: Node, jogador: Node, uid: int, semente: int, n_equipes_fixo: int = -1,
		desafio: Dictionary = {}, arena_fixa: String = "", espectador := false) -> Dictionary:
	var p: Dictionary = dados.arena()
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var carro: Carro = jogador.garagem.carro(uid)
	# Decisão 70: na arena luta o piloto de arena 1 (os atributos dele).
	var base_piloto: Dictionary = EquipeJogador.piloto_da_vaga(dados, jogador, "arena1")
	if base_piloto.is_empty():
		base_piloto = EquipeJogador.piloto_do_jogador(dados, jogador)
	var attrs := carro.atributos_efetivos("seco")
	var parts := [{"id": "jogador", "atributos": attrs, "piloto": base_piloto, "equipe": "jogador"}]
	var modelos := {"jogador": carro.base}
	var arena1 := EquipeJogador.nome_arena(dados, jogador, "arena1")
	var nomes := {"jogador": arena1 if arena1 != "" else EquipeJogador.nome_jogador(dados, jogador)}
	var cores := {}
	var faixas := {}
	var equipes := {"jogador": EquipeJogador.dados_equipe(dados, jogador)}
	# Carros de potência parecida (de fábrica), sem repetir modelo.
	var cv := float(attrs["potencia"])
	var catalogo: Array = dados.lista("carros").filter(func(c): return c["id"] != carro.id and not c.get("chefe", false))
	catalogo.sort_custom(func(a, b): return absf(float(a["potencia"]) - cv) < absf(float(b["potencia"]) - cv))
	var c_camp: Dictionary = p.get("campeonato", {})
	var n_equipes := equipes_no_nivel(dados, nivel(jogador)) if n_equipes_fixo <= 0 \
			else clampi(n_equipes_fixo, int(c_camp.get("equipes_min", 2)), int(c_camp.get("equipes_max", 10)))
	if not desafio.is_empty():
		n_equipes = 2
	var escolhidos := catalogo.slice(0, n_equipes * 4)
	var sortear_modelo := func() -> Dictionary:
		return escolhidos.pop_at(rng.randi_range(0, escolhidos.size() - 1)) if not escolhidos.is_empty() else carro.base
	if espectador:
		parts.clear()
		modelos.clear()
		nomes.clear()
		equipes.clear()
	# Parceiro: o segundo piloto no carro dele, ou o da casa num emprestado.
	var par := parceiro(dados, jogador, uid) if not espectador else {"real": false, "nome": ""}
	var car_par: Carro
	if espectador:
		pass
	elif par["real"]:
		car_par = jogador.garagem.carro(int(par["uid"]))
	else:
		car_par = Carro.new(sortear_modelo.call())
		car_par.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
		cores["parceiro"] = CarroBloco.cor_do_carro(carro)
	if not espectador:
		parts.append({"id": "parceiro", "atributos": car_par.atributos_efetivos("seco"),
				"piloto": EquipeJogador.piloto_corrida(dados, jogador), "equipe": "jogador"})
		modelos["parceiro"] = car_par.base
		nomes["parceiro"] = String(par["nome"])
	if par["real"]:
		cores["parceiro"] = CarroBloco.cor_do_carro(car_par)
		faixas["parceiro"] = car_par.faixas
	# Equipes rivais sorteadas, dois pilotos de cada.
	var rivais: Array = dados.lista("equipes").filter(func(e): return not e.get("jogador", false) and e.get("pilotos", []).size() >= 2)
	if not desafio.is_empty():
		rivais = [desafio]
	var especiais: Array = GridDesafio.especiais(dados, desafio, 2) if not desafio.is_empty() else []
	rivais.sort_custom(func(a, b): return a["id"] < b["id"])
	var perfis: Dictionary = dados.carreira().get("perfis_piloto", {})
	for k in mini(n_equipes - (0 if espectador else 1), rivais.size()):
		var eq: Dictionary = rivais.pop_at(rng.randi_range(0, rivais.size() - 1))
		equipes[eq["id"]] = eq
		var pilotos: Array = eq["pilotos"].filter(func(pl): return EquipeJogador.vaga_do_piloto(jogador, String(pl["id"])) == "")
		if pilotos.size() < 2:
			pilotos = eq["pilotos"].duplicate()
		if not desafio.is_empty():
			pilotos = GridDesafio.pilotos(dados, jogador, eq, "arena", 2)
		for m in 2:
			var pl: Dictionary = pilotos.pop_at(0 if not desafio.is_empty() else rng.randi_range(0, pilotos.size() - 1))
			var id := "%s:%d" % [eq["id"], m + 1]
			# Desafio: os carros especiais da equipe, com o ajuste de potência deles.
			var adv: Dictionary = especiais[m] if m < especiais.size() else {}
			var mod: Dictionary = dados.carro(adv["carro"]) if not adv.is_empty() else sortear_modelo.call()
			var rival := Carro.new(mod)
			rival.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
			var piloto: Dictionary = dados.piloto(dados.carreira()["piloto_jogador"]).duplicate()  # rival: o piloto-base
			if perfis.has(String(pl.get("perfil", ""))):
				piloto["agressividade"] = float(perfis[pl["perfil"]]["agressividade"])
			var at_rival := rival.atributos_efetivos("seco")
			if not adv.is_empty():
				at_rival["potencia"] = float(at_rival["potencia"]) * float(adv.get("potencia_mult", 1.0))
			parts.append({"id": id, "atributos": at_rival, "piloto": piloto, "equipe": eq["id"]})
			modelos[id] = mod
			nomes[id] = String(pl["nome"])
			if eq.has("cores"):
				cores[id] = Color(String(eq["cores"]["carro"]))
				faixas[id] = PinturaCarro.da_equipe(eq, "%d|%s" % [semente, id], Array(eq["pilotos"]).find(pl))
	# A arena da luta: sorteada entre as abertas pelas licenças do jogador
	# (decisão 59); a forma vai nos parâmetros da simulação e da tela.
	var params := p.duplicate()
	var abertas := arenas_abertas(dados, jogador)
	var alvo := String(GridDesafio.de(dados, desafio).get("arena", "")) if not desafio.is_empty() else arena_fixa
	if alvo != "":
		abertas = p.get("arenas", []).filter(func(a): return a["id"] == alvo)
	if not abertas.is_empty():
		params["forma"] = abertas[rng.randi_range(0, abertas.size() - 1)]
	# Blindagem à vista nos seus carros (decisão 80): solta na batida.
	var blindagens := {} if espectador else {"jogador": Blindagem.nivel(carro)}
	if par["real"]:
		blindagens["parceiro"] = Blindagem.nivel(car_par)
	# Canhão d'água (arena.json → canhao): os carros da lista empurram com o jato.
	var com_canhao: Array = p.get("canhao", {}).get("carros", [])
	for part in parts:
		if String(modelos[part["id"]].get("id", "")) in com_canhao:
			part["canhao"] = true
	return {"participantes": parts, "modelos": modelos, "nomes": nomes, "cores": cores, "faixas": faixas,
			"params": params, "equipes": equipes, "parceiro": par, "blindagens": blindagens}


## Arenas (data/arena.json → arenas) cuja licença o jogador já tem.
static func arenas_abertas(dados: Node, jogador: Node) -> Array:
	var ordem := GestaoEquipe.ordem(dados)
	var maior := GestaoEquipe.maior_licenca(dados, jogador)
	# Decisão 75: as do The Grid (grid: true) são só dos desafios.
	var aberta := func(a) -> bool: return not a.get("grid", false) and ordem.find(String(a.get("licenca", ""))) <= maior
	return dados.arena().get("arenas", []).filter(aberta)


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


## Aplica a luta: prêmio no saldo, registro e, se o carro do jogador (ou o do
## parceiro) foi eliminado, ele vai para o reparo (_quebrar). {posicao, pontos,
## premio, perdeu, carro, uid}; `perdeu` = o carro quebrou.
static func aplicar(dados: Node, jogador: Node, uid: int, resultado: Dictionary, parceiro_uid: int = -1,
		desafio: Dictionary = {}) -> Dictionary:
	var p: Dictionary = dados.arena()
	MetaDia.registrar(jogador, "arena")  # meta do dia (decisão 109)
	var pts := pontos(resultado, "jogador", p)
	var valor := premio(dados, pts)
	var carro: Carro = jogador.garagem.carro(uid)
	var nome := String(carro.base["nome"]) if carro != null else ""
	var perdeu: bool = resultado["carros"]["jogador"]["eliminado"]
	jogador.economia.creditar(valor)
	var reg: Dictionary = jogador.arena
	reg["lutas"] = int(reg.get("lutas", 0)) + 1
	var posicao: int = resultado["classificacao"].find("jogador") + 1
	if posicao == 1:
		reg["vitorias"] = int(reg.get("vitorias", 0)) + 1
	# Para o vídeo que conserta na hora os carros quebrados (resgatar).
	var resgate := {"uids": []}
	if perdeu and carro != null:
		resgate["uids"].append(uid)
		reg["quebrados"] = int(reg.get("quebrados", 0)) + 1
		_quebrar(dados, jogador, uid, reg)
	var perdeu_parceiro := false
	if parceiro_uid >= 0 and resultado["carros"].has("parceiro") and resultado["carros"]["parceiro"]["eliminado"] \
			and jogador.garagem.carro(parceiro_uid) != null:
		perdeu_parceiro = true
		resgate["uids"].append(parceiro_uid)
		reg["quebrados"] = int(reg.get("quebrados", 0)) + 1
		_quebrar(dados, jogador, parceiro_uid, reg)
	# Campeonato: a equipe do jogador ficou de pé → sobe de nível (até o último).
	var venceu_equipe: bool = resultado.get("equipe_vencedora", "") == "jogador"
	var subiram := EquipeJogador.apos_prova(dados, jogador, ["arena1", "arena2"], venceu_equipe)
	var nivel_antes := nivel(jogador)
	var grid := {}
	var serie := {}
	if not desafio.is_empty():
		# Decisão 74: o Grid só anda no desafio (melhor de N rounds).
		serie = GridDesafio.registrar_round(dados, jogador, desafio, venceu_equipe)
		if serie["venceu"]:
			grid = TheGrid.registrar(dados, jogador, [String(desafio["id"])])
	elif venceu_equipe:
		var maximo := int(p.get("campeonato", {}).get("equipes_max", 10)) - int(p.get("campeonato", {}).get("equipes_min", 2))
		reg["nivel"] = mini(nivel_antes + 1, maximo)
	# O piloto atropelado não fica fora depois da luta: o carro eliminado já
	# vai para o reparo (decisão 118), e a pausa dobrava a mesma espera.
	jogador.arena = reg
	return {"reparo_s": tempo_reparo(dados), "posicao": posicao, "pontos": pts, "premio": valor, "perdeu": perdeu, "carro": nome, "uid": uid,
			"perdeu_parceiro": perdeu_parceiro, "venceu_equipe": venceu_equipe,
			"subiu_nivel": int(reg.get("nivel", 0)) > nivel_antes,
			"grid": grid, "pilotos_subiram": subiram,
			"serie": serie, "resgate": resgate if not resgate["uids"].is_empty() else {}}


## Vídeo depois da luta (pedido do usuário, 2026-10-17): os carros quebrados
## saem do reparo na hora, sem pagar. Só na tela do resultado; o resto da luta
## (prêmio, pontos, campeonato, Grid) fica como foi. false se não havia o que
## consertar.
static func resgatar(dados: Node, jogador: Node, final: Dictionary) -> bool:
	var r: Dictionary = final.get("resgate", {})
	if r.is_empty() or r.get("feito", false):
		return false
	r["feito"] = true
	for u in r["uids"]:
		consertar(dados, jogador, int(u), false)
	return true
